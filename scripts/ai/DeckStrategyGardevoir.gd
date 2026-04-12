class_name DeckStrategyGardevoir
extends "res://scripts/ai/DeckStrategyBase.gd"

## 沙奈朵卡组专属 AI 策略
##
## 核心运作逻辑：
## 1. 铺拉鲁拉丝进化线 → Kirlia → Gardevoir ex
## 2. 经营弃牌堆（超能量丢入弃牌堆，为 Psychic Embrace 提供燃料）
## 3. 通过 Psychic Embrace 从弃牌堆加速贴能给攻击手
## 4. 攻击手：飘飘球/吼叫尾 通过 Embrace 贴能进攻
## 5. 愿增猿（Munkidori）转移伤害指示物收割低血量目标

const VERSION := "v8.0"
const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const GardevoirStateEncoderScript = preload("res://scripts/ai/GardevoirStateEncoder.gd")

## 沙奈朵专用 value net（可选）
var gardevoir_value_net: RefCounted = null  # NeuralNetInference
var gardevoir_encoder_class: GDScript = GardevoirStateEncoderScript


func get_strategy_id() -> String:
	return "gardevoir"


func get_signature_names() -> Array[String]:
	return [GARDEVOIR_EX, KIRLIA, RALTS]


func get_state_encoder_class() -> GDScript:
	return gardevoir_encoder_class


func load_value_net(path: String) -> bool:
	return load_gardevoir_value_net(path)


func get_value_net() -> RefCounted:
	return gardevoir_value_net


func load_gardevoir_value_net(path: String) -> bool:
	var net := NeuralNetInferenceScript.new()
	if net.load_weights(path):
		gardevoir_value_net = net
		return true
	gardevoir_value_net = null
	return false


func has_gardevoir_value_net() -> bool:
	return gardevoir_value_net != null and gardevoir_value_net.is_loaded()

# -- 卡牌名称常量 --
const GARDEVOIR_EX := "沙奈朵ex"
const KIRLIA := "奇鲁莉安"
const RALTS := "拉鲁拉丝"
const KLEFKI := "钥圈儿"
const MUNKIDORI := "愿增猿"
const MANAPHY := "玛纳霏"
const DRIFLOON := "飘飘球"
const DRIFBLIM := "附和气球"
const SCREAM_TAIL := "吼叫尾"
const BRAVERY_CHARM := "勇气护符"
const RESCUE_STRETCHER := "救援担架"
const NIGHT_STRETCHER := "夜间担架"
const FLUTTER_MANE := "振翼发"
const RADIANT_GRENINJA := "光辉甲贺忍蛙"
const TM_EVOLUTION := "招式学习器 进化"
const IONO := "奇树"
const ARTAZON := "深钵镇"
const PROF_TURO := "弗图博士的剧本"

const BUDDY_BUDDY_POFFIN := "友好宝芬"
const ARVEN := "派帕"
const EARTHEN_VESSEL := "大地容器"
const COUNTER_CATCHER := "反击捕捉器"
const BOSSS_ORDERS := "老大的指令"
const RARE_CANDY := "神奇糖果"
const SUPER_ROD := "厉害钓竿"
const ULTRA_BALL := "高级球"
const NEST_BALL := "巢穴球"
const SECRET_BOX := "秘密箱"
const HISUIAN_HEAVY_BALL := "洗翠的沉重球"
const PSYCHIC_ENERGY := "基本超能量"
const DARK_ENERGY := "基本恶能量"

# -- 角色分类 --
const CORE_NAMES: Array[String] = ["拉鲁拉丝", "奇鲁莉安", "沙奈朵ex"]
const CONTROL_NAMES: Array[String] = ["振翼发", "钥圈儿"]
const ATTACKER_NAMES: Array[String] = ["飘飘球", "附和气球", "吼叫尾"]
const SUPPORT_NAMES: Array[String] = ["玛纳霏", "钥圈儿", "拉鲁拉丝", "奇鲁莉安"]
const BENCH_PRIORITY_NAMES: Array[String] = ["拉鲁拉丝", "玛纳霏", "愿增猿", "飘飘球", "吼叫尾", "钥圈儿", "振翼发"]
const SEARCH_PRIORITY_NAMES: Array[String] = ["拉鲁拉丝", "奇鲁莉安", "沙奈朵ex", "愿增猿", "飘飘球", "吼叫尾", "玛纳霏", "振翼发"]


# ============================================================
#  1. Combo 知识（作为打分条件的索引，不再是固定执行序列）
# ============================================================

const COMBO_RULES: Array[Dictionary] = [
	{"name": "弃牌堆加速", "desc": "精练/大地容器弃超能 → Embrace 连续贴能给攻击手"},
	{"name": "吼叫尾狙杀", "desc": "Embrace 贴能叠指示物 → 凶暴吼叫 ×20 狙后排"},
	{"name": "飘飘球高伤", "desc": "Embrace 贴能叠指示物 → 气球炸弹 ×30 前场爆发"},
	{"name": "担架复活", "desc": "救援担架恢复被击倒攻击手 → 上板 → Embrace 加速"},
	{"name": "愿增猿收割", "desc": "恶能贴 Munkidori → 转移指示物 → 击倒弱目标"},
]


# ============================================================
#  1b. 绝对分评估（贪心循环核心）
# ============================================================

func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	## 返回动作的绝对收益分。>0 执行，≤0 不执行。
	## 每步重新评估全部合法动作，选最高分执行。
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var kind: String = str(action.get("kind", ""))
	var player: PlayerState = game_state.players[player_index]
	var turn: int = int(game_state.turn_number)
	var phase: String = _detect_game_phase(turn, player)
	match kind:
		"play_basic_to_bench":
			return _abs_play_basic(action, player, phase)
		"evolve":
			return _abs_evolve(action, player, phase)
		"attach_energy":
			return _abs_attach_energy(action, game_state, player, player_index)
		"attach_tool":
			return _abs_attach_tool(action, player, phase)
		"use_ability":
			return _abs_use_ability(action, game_state, player, player_index, phase)
		"play_trainer":
			return _abs_play_trainer(action, game_state, player, player_index, phase)
		"retreat":
			return _abs_retreat(action, game_state, player, player_index)
		"attack":
			return _abs_attack(action, game_state, player_index)
		"granted_attack":
			return _abs_granted_attack(action, game_state, player, player_index, phase)
	return 0.0


func _abs_play_basic(action: Dictionary, player: PlayerState, phase: String) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	var bench_size: int = player.bench.size()
	if bench_size >= 5:
		return 0.0  # 满板

	# --- 板位预算系统 ---
	# 目标阵容（5 板位）：2× 拉鲁拉丝线 + 1× 愿增猿 + 1× 攻击手 + 1× 灵活位
	# 核心位未满时不放非核心宝可梦占位
	var essential_slots_needed: int = _count_essential_slots_needed(player)
	var free_slots: int = 5 - bench_size
	var is_essential: bool = _is_essential_pokemon(name, player)

	# 非核心宝可梦 + 板位紧张（空位 ≤ 核心缺口）→ 不放
	if not is_essential and free_slots <= essential_slots_needed:
		return -50.0  # 留位给核心

	# --- 核心宝可梦评分 ---
	if name == RALTS:
		var ralts_on_field: int = _count_pokemon_on_field(player, RALTS)
		var kirlia_on_field: int = _count_pokemon_on_field(player, KIRLIA)
		var total_line: int = ralts_on_field + kirlia_on_field + _count_pokemon_on_field(player, GARDEVOIR_EX)
		if total_line >= 3:
			return 0.0  # 进化线已够
		return 350.0 if phase == "early" else 280.0
	if name == MUNKIDORI:
		if _count_pokemon_on_field(player, MUNKIDORI) >= 1:
			return 0.0
		return 200.0 if phase == "early" else 150.0
	if name == DRIFLOON:
		if _count_attackers_on_field(player) >= 1:
			return 150.0  # 已有攻击手，第二个优先级降低
		return 280.0
	if name == SCREAM_TAIL:
		if _count_attackers_on_field(player) >= 1:
			return 130.0
		return 260.0

	# --- 非核心宝可梦（仅在有空余板位时放）---
	if name == MANAPHY:
		return 120.0 if _count_pokemon_on_field(player, MANAPHY) == 0 else 0.0
	if name == RADIANT_GRENINJA:
		return 100.0
	if name == KLEFKI:
		return 80.0
	if name == FLUTTER_MANE:
		return 80.0
	return 50.0


func _abs_evolve(action: Dictionary, player: PlayerState, phase: String) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	# S 段：首只 Gardevoir ex；第二只要考虑是否值得失去精炼引擎
	if name == GARDEVOIR_EX:
		if _count_pokemon_on_field(player, GARDEVOIR_EX) == 0:
			return 800.0  # S 段：首只引擎启动
		# 第二只：如果会导致场上没有奇鲁莉安（失去精炼引擎），大幅降分
		var kirlia_count: int = _count_pokemon_on_field(player, KIRLIA)
		if kirlia_count <= 1:
			return 100.0  # C 段：保留精炼引擎比第二只沙奈朵更重要
		return 350.0  # B 段：有富余奇鲁莉安
	# A 段：Kirlia 进化（Combo: 弃牌堆加速 — 精炼需要 Kirlia）
	if name == KIRLIA:
		var base: float = 450.0 if phase != "late" else 300.0
		if _hand_has_card(player, GARDEVOIR_EX):
			base += 100.0  # 手握沙奈朵ex可下回合跳阶
		return base
	if name == DRIFBLIM:
		return 200.0  # B 段: 飘飘球高伤 前置
	return 50.0


func _abs_attach_energy(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var target_slot: PokemonSlot = action.get("target_slot")
	var energy_card: CardInstance = action.get("card")
	if target_slot == null or energy_card == null or energy_card.card_data == null:
		return 0.0
	var target_name: String = target_slot.get_pokemon_name()
	var energy_type: String = str(energy_card.card_data.energy_provides)

	# --- 通用规则：手贴能量给前场非攻击手以解锁撤退 ---
	if target_slot == player.active_pokemon \
	   and target_name not in ATTACKER_NAMES and target_name != SCREAM_TAIL:
		var retreat_gap: int = _get_retreat_energy_gap(target_slot)
		if retreat_gap > 0 and retreat_gap <= 1:  # 差1能就能撤退
			var has_bench_attacker: bool = false
			for bench_slot: PokemonSlot in player.bench:
				if _is_ready_attacker(bench_slot):
					has_bench_attacker = true
					break
			if has_bench_attacker:
				return 380.0  # B 段：手贴解锁撤退 → 攻击手上前

	# 超能量一般走弃牌堆 + Embrace，不手贴
	if energy_type == "P":
		return -100.0
	# 恶能量只给 Munkidori（Combo: 愿增猿收割），且只贴1个
	if energy_type == "D":
		if target_name == MUNKIDORI:
			if not _slot_has_energy_type(target_slot, "D"):
				return 250.0  # B 段：首贴
			return -100.0  # D 段：已有1恶能，绝不贴第2个
		# 恶能量贴给前场非攻击手也能支付撤退费（通用能量）
		if target_slot == player.active_pokemon and target_name not in ATTACKER_NAMES and target_name != SCREAM_TAIL:
			var retreat_gap: int = _get_retreat_energy_gap(target_slot)
			if retreat_gap > 0 and retreat_gap <= 1:
				for bench_slot: PokemonSlot in player.bench:
					if _is_ready_attacker(bench_slot):
						return 350.0  # B 段：恶能当撤退费
				# 没有就绪攻击手就别贴
		return -100.0
	return -100.0


func _abs_attach_tool(action: Dictionary, player: PlayerState, phase: String = "mid") -> float:
	var card: CardInstance = action.get("card")
	var target_slot: PokemonSlot = action.get("target_slot")
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var tool_name: String = str(card.card_data.name)
	var target_name: String = target_slot.get_pokemon_name()
	# TM Evolution：必须贴给战斗场宝可梦，且必须能配套贴能量使用进化招式
	# 进化招式费用 = C（1个任意能量）
	if tool_name == TM_EVOLUTION:
		# 只贴给前场
		if target_slot != player.active_pokemon:
			return -200.0  # 不贴后备
		if not _has_evolvable_bench_targets(player):
			return -100.0  # 无可进化目标
		# 检查能否配套贴能量：前场已有≥1能量 或 手里有能量可贴
		var active_energy: int = target_slot.attached_energy.size()
		var can_power: bool = active_energy >= 1 or _hand_has_any_energy(player)
		if not can_power:
			return -50.0  # 无法支付进化招式费用
		return 550.0  # A 段：完整 combo
	if tool_name == BRAVERY_CHARM:
		if target_name == SCREAM_TAIL:
			return 250.0  # B 段
		if target_name == DRIFBLIM or target_name == DRIFLOON:
			return 200.0  # B 段
		return -100.0  # D 段：不贴给辅助
	if target_name in ATTACKER_NAMES or target_name == SCREAM_TAIL:
		return 100.0  # C 段
	return -100.0


func _abs_use_ability(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var source_slot: PokemonSlot = action.get("source_slot")
	if source_slot == null:
		return 0.0
	var source_name: String = source_slot.get_pokemon_name()
	var card_data: CardData = source_slot.get_card_data()
	if card_data == null:
		return 0.0
	# 精神拥抱 / Psychic Embrace（Combo: 弃牌堆加速 / 飘飘球高伤 / 吼叫尾狙杀）
	if source_name == GARDEVOIR_EX and _has_any_ability(card_data, ["精神拥抱", "Psychic Embrace"]):
		return _abs_psychic_embrace(game_state, player, player_index)
	# 精炼 / Refinement（Combo: 弃牌堆加速 — 弃超能 + 抽牌）
	if source_name == KIRLIA and _has_any_ability(card_data, ["精炼", "Refinement"]):
		# 手牌越多弃牌选择越好，优先级高
		var hand_size: int = player.hand.size()
		if hand_size <= 1:
			return 50.0  # 手牌太少不值得精炼
		return 400.0 if phase != "late" else 250.0  # A/B 段
	# 隐藏牌 / Concealed Cards — 光辉甲贺忍蛙（弃能量抽2张）
	if source_name == RADIANT_GRENINJA and _has_any_ability(card_data, ["隐藏牌", "Concealed Cards"]):
		if _hand_has_energy_type(player, "P"):
			return 420.0  # A 段：弃超能 = Embrace 燃料 + 抽牌
		if _hand_has_energy_type(player, "D"):
			return 300.0  # B 段
		return 0.0  # 无能量可弃
	# Munkidori 特性（Combo: 愿增猿收割）
	if source_name == MUNKIDORI:
		if _munkidori_can_threaten_ko(game_state, player_index):
			return 600.0  # A 段：可凑 KO
		return 80.0  # C 段
	if source_name == MANAPHY:
		return 120.0  # C 段
	return 0.0


func _abs_psychic_embrace(game_state: GameState, player: PlayerState, player_index: int) -> float:
	## Embrace 评分 — 统一标尺，与 attack/retreat 直接竞争
	## 分数含义：Embrace 这一步能带来的真实增量价值
	var discard_psychic: int = _count_psychic_energy_in_discard(game_state, player_index)
	if discard_psychic <= 0:
		return -50.0  # 无燃料

	var active: PokemonSlot = player.active_pokemon
	var active_name: String = active.get_pokemon_name() if active != null else ""
	var opponent_index: int = 1 - player_index
	var defender: PokemonSlot = null
	if opponent_index >= 0 and opponent_index < game_state.players.size():
		defender = game_state.players[opponent_index].active_pokemon

	var best_value: float = 0.0

	# --- 评估每个攻击手从 Embrace 中获得的增量价值 ---
	for slot: PokemonSlot in _get_all_slots(player):
		var name: String = slot.get_pokemon_name()
		if name not in ATTACKER_NAMES and name != SCREAM_TAIL:
			continue
		if slot.get_remaining_hp() <= 20:
			continue  # 会自杀
		var now: Dictionary = predict_attacker_damage(slot, 0)
		var after: Dictionary = predict_attacker_damage(slot, 1)
		var now_dmg: int = int(now.get("damage", 0))
		var after_dmg: int = int(after.get("damage", 0))
		var can_now: bool = bool(now.get("can_attack", false))
		var can_after: bool = bool(after.get("can_attack", false))

		var dmg_gain: int = after_dmg - now_dmg  # 每次 Embrace 的伤害增量
		# 情况 1：Embrace 后能攻击（之前不能）→ 高价值
		if not can_now and can_after:
			if defender != null and after_dmg >= defender.get_remaining_hp():
				best_value = maxf(best_value, 700.0)  # 解锁 KO
			else:
				best_value = maxf(best_value, 500.0)  # 解锁攻击
		# 情况 2：已能攻击，Embrace 后解锁 KO
		elif can_now and defender != null and now_dmg < defender.get_remaining_hp() and after_dmg >= defender.get_remaining_hp():
			best_value = maxf(best_value, 600.0)  # 从"打不死"到"打得死"
		# 情况 3：已能攻击且已能 KO → Embrace 只是多余伤害（前场攻击手时不做）
		elif can_now and defender != null and now_dmg >= defender.get_remaining_hp():
			if slot == player.active_pokemon:
				best_value = maxf(best_value, 30.0)  # 前场已能 KO → 去攻击
			else:
				# 后备攻击手：继续蓄力有价值（将来上前场时伤害更高）
				best_value = maxf(best_value, 200.0 + float(dmg_gain))
		# 情况 4：已能攻击但不能 KO → 继续贴能提升伤害
		elif can_now:
			# 飘飘球/吼叫尾每次 Embrace 贴能 = +30/+20 真实伤害
			# 这个伤害增量有意义：不是边际值，是核心伤害来源
			best_value = maxf(best_value, 200.0 + float(dmg_gain) * 3.0)
		# 情况 5：还不能攻击，Embrace 后也不能 → 蓄力中
		else:
			best_value = maxf(best_value, 300.0)

	# --- 通用规则：前场非攻击手需要能量撤退 ---
	# 适用于沙奈朵ex、钥圈儿、振翼发、玛纳霏等一切非攻击手
	if active != null and active_name not in ATTACKER_NAMES and active_name != SCREAM_TAIL:
		var retreat_gap: int = _get_retreat_energy_gap(active)
		if retreat_gap > 0 and active.get_remaining_hp() > 20:
			for bench_slot: PokemonSlot in player.bench:
				if _is_ready_attacker(bench_slot):
					best_value = maxf(best_value, 400.0)  # 解锁撤退 → 攻击手上前
					break

	if best_value <= 0.0:
		return 50.0  # 有燃料但无好目标
	return best_value


func _abs_play_trainer(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	var bench_full: bool = player.bench.size() >= 5
	var hand_size: int = player.hand.size()
	var need_gardevoir: bool = _count_pokemon_on_field(player, GARDEVOIR_EX) == 0
	var has_kirlia: bool = _count_pokemon_on_field(player, KIRLIA) >= 1
	var has_ralts: bool = _count_pokemon_on_field(player, RALTS) >= 1
	var discard_p: int = _count_psychic_energy_in_discard(game_state, player_index)

	# === 搜索型物品 ===

	# 友好宝芬：搜牌库2只<=70HP基础宝可梦上板
	# 链：宝芬 → 拉鲁拉丝x2上板 → 下回合进化奇鲁莉安 → 精炼引擎
	if name == BUDDY_BUDDY_POFFIN:
		if bench_full:
			return 0.0
		var essential_needed: int = _count_essential_slots_needed(player)
		if essential_needed >= 2 and phase == "early":
			return 380.0  # 核心位缺口大，宝芬高优先
		if essential_needed >= 1:
			return 300.0
		return 150.0  # 核心已齐，宝芬价值下降

	# 巢穴球：搜牌库1只基础宝可梦上板
	# 链：巢穴球 → 拉鲁拉丝/飘飘球/吼叫尾上板
	if name == NEST_BALL:
		if bench_full:
			return 0.0
		var essential_needed: int = _count_essential_slots_needed(player)
		if essential_needed >= 1 and phase == "early":
			return 300.0  # 核心位有缺
		if essential_needed >= 1:
			return 200.0
		return 100.0  # 核心已齐

	# 高级球：弃2搜任意宝可梦
	# 链1：高级球(弃2超能) → 沙奈朵ex → 进化启动引擎（弃超能还加速燃料）
	# 链2：高级球(弃2超能) → 奇鲁莉安 → 进化获得精炼
	# 链3：高级球 → 攻击手/工具宝可梦
	if name == ULTRA_BALL:
		return _abs_ultra_ball(game_state, player, player_index, phase, hand_size)

	# 秘密箱：弃3搜(物品+道具+支援者+场地各1)
	# 链：秘密箱(弃3含超能) → 获得4张卡（巨大卡差）→ 后续展开
	if name == SECRET_BOX:
		return _abs_secret_box(game_state, player, player_index, phase, hand_size)

	# 派帕：搜1物品+1道具
	# 链：派帕 → 高级球+TM进化 / 宝芬+勇气护符 等
	if name == ARVEN:
		return _abs_arven(game_state, player, player_index, phase)

	# === 弃牌堆加速型物品 ===

	# 大地容器：弃1超能，从牌库搜2张基础能量
	# 链：大地容器(弃超能→燃料) → 搜2能量(恶能给愿增猿/超能做备用)
	if name == EARTHEN_VESSEL:
		if _hand_has_energy_type(player, "P"):
			return 350.0 if phase != "late" else 120.0  # 弃超能 = 双重收益
		return 200.0 if phase != "late" else 80.0

	# === 回收型物品 ===

	# 夜间担架：从弃牌堆捡1只宝可梦到手/2只到牌库
	# 链1：夜间担架 → 捡沙奈朵ex/奇鲁莉安到手 → 进化
	# 链2：夜间担架 → 捡攻击手 → 上板 → Embrace加速
	if name == NIGHT_STRETCHER:
		return _abs_night_stretcher(game_state, player, player_index, phase)

	# 救援担架：同上（旧版）
	if name == RESCUE_STRETCHER:
		return _abs_night_stretcher(game_state, player, player_index, phase)

	# 厉害钓竿：从弃牌堆选最多3张宝可梦/基础能量洗回牌库
	# 链：钓竿 → 回收超能量到牌库（大地容器再搜出来）/ 回收核心宝可梦
	if name == SUPER_ROD:
		var discard_value: int = 0
		if _has_core_in_discard(game_state, player_index):
			discard_value += 80
		if _has_attacker_in_discard(game_state, player_index):
			discard_value += 60
		if discard_p >= 3:
			discard_value += 40  # 弃牌堆超能量充足，不急回收
		else:
			discard_value += 80  # 超能量不足，回收有价值
		return float(maxi(60, discard_value))

	# 洗翠的沉重球：翻开奖品区，取1只基础宝可梦到手，沉重球入奖品
	# 链：沉重球 → 救出被卡在奖品区的拉鲁拉丝/飘飘球
	if name == HISUIAN_HEAVY_BALL:
		if phase == "early" and _count_pokemon_on_field(player, RALTS) < 2:
			return 200.0  # 可能救出关键拉鲁拉丝
		return 100.0

	# === 干扰/狙击型 ===

	# 反击捕捉器：己方奖品>对手时，换对手后备到前场
	# 链：反击捕捉器 → 拉弱目标到前场 → 攻击击杀
	if name == COUNTER_CATCHER:
		if _can_ko_bench_target(game_state, player, player_index):
			return 700.0  # A 段：能击杀
		return 200.0  # B 段：干扰对手节奏

	# 老大的指令：换对手后备到前场（支援者）
	# 链：老大指令 → 拉ex/V弱目标到前场 → 攻击拿2-3张奖品
	if name == BOSSS_ORDERS:
		if _can_ko_bench_target(game_state, player, player_index):
			return 800.0  # S 段
		if phase == "late":
			return 300.0  # B 段：后期干扰
		return 200.0

	# === 支援者 ===

	# 奇树(Iono)：双方洗手牌回牌库，各抽奖品数张
	# 链1：(己方手牌差) 奇树 → 换手抽4-6张 → 翻转手牌质量
	# 链2：(对手少奖品) 奇树 → 对手只抽1-2张 → 压缩对手手牌
	if name == IONO:
		return _abs_iono(game_state, player, player_index, phase, hand_size)

	# 深钵镇(Artazon)：场地，每回合可搜1只基础宝可梦上板
	# 链：深钵镇 → 每回合免费上基础 → 持续铺板
	if name == ARTAZON:
		if bench_full:
			return 30.0
		if phase == "early" and _count_pokemon_on_field(player, RALTS) < 3:
			return 250.0  # A 段：早期铺板引擎
		return 150.0

	# 弗图博士的剧本：收回1只己方宝可梦到手（弃所有附卡）
	# 链1：弗图 → 收回快被打倒的ex（保奖品）→ 重新上板
	# 链2：弗图 → 收回贴了能量的辅助型（救能量）
	if name == PROF_TURO:
		return _abs_prof_turo(game_state, player, player_index, phase)

	# Rare Candy（Combo: 跳阶 → 快速启动 Gardevoir ex 引擎）
	if name == RARE_CANDY:
		if has_ralts and _hand_has_card(player, GARDEVOIR_EX):
			return 500.0  # A 段
		return 50.0

	return 50.0  # C 段 默认


func _abs_retreat(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return 0.0
	var active_name: String = active.get_pokemon_name()
	var bench_target: PokemonSlot = action.get("bench_target")
	if bench_target == null:
		return 0.0
	var bench_name: String = bench_target.get_pokemon_name()
	var bench_is_ready_attacker: bool = _is_ready_attacker(bench_target)
	# 关键检查：前场是能打伤害的攻击手 → 不要撤退（攻击分会在攻击阶段评估）
	if active_name in ATTACKER_NAMES or active_name == SCREAM_TAIL:
		var pred: Dictionary = predict_attacker_damage(active)
		if int(pred.get("damage", 0)) > 0 and bool(pred.get("can_attack", false)):
			return -200.0  # D 段：已经能攻击，绝不撤退
	# --- 通用规则：非攻击手前场 + 后备有就绪攻击手 → 撤退 ---
	var is_non_attacker: bool = active_name not in ATTACKER_NAMES and active_name != SCREAM_TAIL
	if is_non_attacker and bench_is_ready_attacker:
		return 350.0  # B 段：让攻击手上前
	if is_non_attacker:
		return 0.0  # 后备没准备好，先不换
	# 前场快被击倒
	if active.get_remaining_hp() < 40:
		if bench_is_ready_attacker:
			return 200.0
		return 80.0
	return 0.0  # 其他情况不换


func _abs_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	## 攻击评分
	var damage: int = int(action.get("projected_damage", 0))
	var player: PlayerState = game_state.players[player_index]
	# 对于伤害指示物型攻击手，projected_damage 可能为 0，用 predict 补算
	if damage <= 0 and player.active_pokemon != null:
		var pred: Dictionary = predict_attacker_damage(player.active_pokemon)
		damage = int(pred.get("damage", 0))
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 100.0 if damage > 0 else 0.0
	var defender: PokemonSlot = game_state.players[opponent_index].active_pokemon
	if defender == null:
		return 100.0 if damage > 0 else 0.0
	# 吼叫尾可打后排 — 检查是否能 KO 任意对手宝可梦
	var active_name: String = player.active_pokemon.get_pokemon_name() if player.active_pokemon != null else ""
	if active_name == SCREAM_TAIL and damage > 0:
		# 扫描对手全场，找最有价值的击杀目标
		var best_ko_value: float = 0.0
		for opp_slot: PokemonSlot in _get_all_slots(game_state.players[opponent_index]):
			if opp_slot.get_remaining_hp() <= damage:
				var ko_val: float = 800.0
				var opp_cd: CardData = opp_slot.get_card_data()
				if opp_cd != null and (opp_cd.mechanic == "ex" or opp_cd.mechanic == "V"):
					ko_val = 1000.0  # S 段：KO ex/V
				if ko_val > best_ko_value:
					best_ko_value = ko_val
		if best_ko_value > 0.0:
			return best_ko_value
		return 300.0 + float(damage)  # B 段 + 伤害加成
	# S 段：击倒 ex/V
	if damage >= defender.get_remaining_hp():
		var ko_score: float = 800.0
		var defender_data: CardData = defender.get_card_data()
		if defender_data != null and (defender_data.mechanic == "ex" or defender_data.mechanic == "V"):
			ko_score = 1000.0  # S 段：KO ex
		return ko_score
	if damage > 0:
		return 300.0 + float(damage)  # B 段 + 伤害加成
	return 0.0


func _abs_granted_attack(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	## 道具赋予招式（TM Evolution 等）的评分
	var ga_data: Dictionary = action.get("granted_attack_data", {})
	var attack_name: String = str(ga_data.get("name", ""))
	# TM Evolution 进化招式：早期有可进化后备时 A 段
	if attack_name == "进化" or attack_name == "Evolution":
		if _has_evolvable_bench_targets(player):
			return 600.0  # A 段：核心 combo
		return 50.0  # 无目标时低分
	# 通用 granted_attack：按伤害评估
	var damage: int = int(ga_data.get("damage", 0))
	if damage > 0:
		var opponent_index: int = 1 - player_index
		if opponent_index >= 0 and opponent_index < game_state.players.size():
			var defender: PokemonSlot = game_state.players[opponent_index].active_pokemon
			if defender != null and damage >= defender.get_remaining_hp():
				return 800.0
		return 300.0
	return 100.0


# ============================================================
#  1c. 派帕决策链评估
# ============================================================

func _abs_arven(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	## 派帕（Arven）价值 = 它能从牌库找到的最佳 物品+道具 组合的链式收益
	## 决策链：派帕 → 高级球 → 沙奈朵ex（启动引擎）
	##         派帕 → 秘密箱 → (弃3抽4，更多选项)
	##         派帕 → 宝芬 + TM Evolution（combo 启动）
	##         派帕 → 大地容器 + 道具（弃牌堆加速 + 装备）
	var deck_items: Array[String] = _get_deck_card_names_by_type(player, "Item")
	var deck_tools: Array[String] = _get_deck_card_names_by_type(player, "Tool")
	if deck_items.is_empty() and deck_tools.is_empty():
		return 50.0  # 牌库没有道具可找

	var best_item_value: float = _eval_best_search_item(game_state, player, player_index, phase, deck_items)
	var best_tool_value: float = _eval_best_search_tool(game_state, player, player_index, phase, deck_tools)

	# 派帕总价值 = 两个搜索的价值之和（找 1 物品 + 1 道具）
	var total: float = best_item_value + best_tool_value
	# 基础分 150（使用支援者回合的机会成本）
	return maxf(total, 150.0) if phase != "late" else maxf(total * 0.7, 100.0)


func _eval_best_search_item(game_state: GameState, player: PlayerState, player_index: int, phase: String, deck_items: Array[String]) -> float:
	## 评估从牌库找 1 张物品卡的最佳价值
	var best: float = 50.0  # 基底：找到任意道具的最低价值
	var need_gardevoir: bool = _count_pokemon_on_field(player, GARDEVOIR_EX) == 0
	var has_kirlia_on_field: bool = _count_pokemon_on_field(player, KIRLIA) >= 1
	var has_ralts_on_field: bool = _count_pokemon_on_field(player, RALTS) >= 1
	var bench_full: bool = player.bench.size() >= 5

	# 链1：高级球 → 搜沙奈朵ex/奇鲁莉安（启动引擎）
	if ULTRA_BALL in deck_items:
		if need_gardevoir and has_kirlia_on_field:
			# 场上有奇鲁莉安 → 搜沙奈朵ex可立即进化
			var kirlia_count: int = _count_pokemon_on_field(player, KIRLIA)
			if kirlia_count >= 2:
				best = maxf(best, 350.0)  # SS 链：2只奇鲁莉安等待进化，极度紧迫
			else:
				best = maxf(best, 280.0)  # S 链：1只奇鲁莉安
		elif need_gardevoir and has_ralts_on_field:
			best = maxf(best, 220.0)  # A 链：有拉鲁拉丝，搜进化线
		elif need_gardevoir:
			best = maxf(best, 180.0)  # B 链：搜进化线
		else:
			best = maxf(best, 100.0)  # C：已有引擎，搜其他宝可梦

	# 链2：秘密箱 → 弃3搜4（物品+道具+支援者+场地）
	if SECRET_BOX in deck_items:
		if phase == "early":
			best = maxf(best, 200.0)  # 高：早期展开加速
		else:
			best = maxf(best, 120.0)

	# 链3：宝芬 → 铺板
	if BUDDY_BUDDY_POFFIN in deck_items and not bench_full:
		if phase == "early":
			best = maxf(best, 180.0)
		else:
			best = maxf(best, 100.0)

	# 链4：巢穴球 → 铺单只基础
	if NEST_BALL in deck_items and not bench_full:
		best = maxf(best, 130.0 if phase == "early" else 80.0)

	# 链5：大地容器 → 弃超能加速
	if EARTHEN_VESSEL in deck_items:
		best = maxf(best, 150.0 if phase != "late" else 60.0)

	# 链6：夜间担架/救援担架 → 复活
	if NIGHT_STRETCHER in deck_items or RESCUE_STRETCHER in deck_items:
		if _has_attacker_in_discard(game_state, player_index) or _has_core_in_discard(game_state, player_index):
			best = maxf(best, 160.0)

	return best


func _eval_best_search_tool(game_state: GameState, player: PlayerState, player_index: int, phase: String, deck_tools: Array[String]) -> float:
	## 评估从牌库找 1 张道具卡的最佳价值
	var best: float = 30.0

	# TM Evolution → combo 核心
	if TM_EVOLUTION in deck_tools and _has_evolvable_bench_targets(player):
		var active_name: String = player.active_pokemon.get_pokemon_name() if player.active_pokemon != null else ""
		if active_name in CONTROL_NAMES or active_name == DRIFLOON:
			best = maxf(best, 200.0)  # 高：可立即使用进化招式
		else:
			best = maxf(best, 100.0)

	# 勇气护符 → 给攻击手提升生存力
	if BRAVERY_CHARM in deck_tools:
		best = maxf(best, 80.0)

	return best


func _get_deck_card_names_by_type(player: PlayerState, card_type: String) -> Array[String]:
	var names: Array[String] = []
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and str(card.card_data.card_type) == card_type:
			var cname: String = str(card.card_data.name)
			if cname not in names:
				names.append(cname)
	return names


# ============================================================
#  1d. 派帕搜索目标选择（供 AILegalActionBuilder 调用）
# ============================================================

func pick_search_item(items: Array, game_state: GameState, player_index: int) -> Variant:
	## 从派帕/其他搜索效果的物品列表中选最优物品
	if items.is_empty():
		return null
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return items[0]

	var player: PlayerState = game_state.players[player_index]
	var phase: String = _detect_game_phase(int(game_state.turn_number), player)
	var need_gardevoir: bool = _count_pokemon_on_field(player, GARDEVOIR_EX) == 0
	var has_kirlia_on_field: bool = _count_pokemon_on_field(player, KIRLIA) >= 1
	var has_ralts_on_field: bool = _count_pokemon_on_field(player, RALTS) >= 1
	var bench_full: bool = player.bench.size() >= 5

	# 按决策链优先级排序
	var priority_list: Array[String] = []
	# 最高优先：高级球（搜沙奈朵ex启动引擎 — 尤其是2只奇鲁莉安等进化时）
	if need_gardevoir and (has_kirlia_on_field or has_ralts_on_field):
		priority_list.append(ULTRA_BALL)
	# 秘密箱（弃3搜4，展开加速）— 但不如高级球找沙奈朵紧迫
	if phase == "early" and not (need_gardevoir and has_kirlia_on_field):
		priority_list.append(SECRET_BOX)
	# 宝芬（铺板）
	if not bench_full and phase == "early":
		priority_list.append(BUDDY_BUDDY_POFFIN)
	# 高级球（通用搜索）
	if ULTRA_BALL not in priority_list:
		priority_list.append(ULTRA_BALL)
	# 大地容器
	priority_list.append(EARTHEN_VESSEL)
	# 巢穴球
	if not bench_full:
		priority_list.append(NEST_BALL)
	# 夜间/救援担架
	priority_list.append(NIGHT_STRETCHER)
	priority_list.append(RESCUE_STRETCHER)
	# 秘密箱（兜底）
	if SECRET_BOX not in priority_list:
		priority_list.append(SECRET_BOX)

	for preferred: String in priority_list:
		for item: Variant in items:
			if item is CardInstance and (item as CardInstance).card_data != null:
				if str((item as CardInstance).card_data.name) == preferred:
					return item
	return items[0]


func pick_search_tool(items: Array, game_state: GameState, player_index: int) -> Variant:
	## 从派帕搜索的道具列表中选最优道具
	if items.is_empty():
		return null
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return items[0]

	var player: PlayerState = game_state.players[player_index]
	var priority_list: Array[String] = []
	# TM Evolution：有可进化后备时最优
	if _has_evolvable_bench_targets(player):
		priority_list.append(TM_EVOLUTION)
	# 勇气护符
	priority_list.append(BRAVERY_CHARM)
	# TM Evolution 兜底
	if TM_EVOLUTION not in priority_list:
		priority_list.append(TM_EVOLUTION)

	for preferred: String in priority_list:
		for item: Variant in items:
			if item is CardInstance and (item as CardInstance).card_data != null:
				if str((item as CardInstance).card_data.name) == preferred:
					return item
	return items[0]


# ============================================================
#  1e. 各卡牌决策链评估
# ============================================================

func _abs_ultra_ball(game_state: GameState, player: PlayerState, player_index: int, phase: String, hand_size: int) -> float:
	## 高级球：弃2搜任意宝可梦
	## 链1：弃2超能 → 搜沙奈朵ex → 进化启动引擎（弃超能还充当燃料 = 零成本）
	## 链2：弃2超能 → 搜奇鲁莉安 → 获得精炼引擎
	## 链3：弃杂牌 → 搜攻击手
	## 关键：弃牌成本取决于手牌质量和数量
	var need_gardevoir: bool = _count_pokemon_on_field(player, GARDEVOIR_EX) == 0
	var has_kirlia: bool = _count_pokemon_on_field(player, KIRLIA) >= 1
	var has_ralts: bool = _count_pokemon_on_field(player, RALTS) >= 1
	# 弃牌成本：手牌少时弃牌更痛
	var discard_penalty: float = 0.0
	if hand_size <= 3:
		discard_penalty = 80.0  # 手牌极少，弃2张很痛
	elif hand_size <= 5:
		discard_penalty = 30.0
	# 搜索价值
	var search_value: float = 100.0  # 基底：搜到任意宝可梦
	if need_gardevoir and has_kirlia:
		var kirlia_count: int = _count_pokemon_on_field(player, KIRLIA)
		if kirlia_count >= 2:
			search_value = 450.0  # SS 链：2只奇鲁莉安等进化，极度紧迫
		else:
			search_value = 350.0  # S 链：搜沙奈朵ex启动引擎
	elif need_gardevoir and has_ralts:
		search_value = 280.0  # A 链：搜进化线
	elif need_gardevoir:
		search_value = 250.0  # A 链：搜进化线
	elif _count_pokemon_on_field(player, KIRLIA) < 2:
		search_value = 200.0  # B 链：搜奇鲁莉安扩展精炼
	# 弃超能量 = 额外收益（Embrace 燃料）
	var psychic_in_hand: int = _count_energy_in_hand(player, "P")
	if psychic_in_hand >= 2:
		discard_penalty -= 40.0  # 弃2超能反而是收益
	elif psychic_in_hand >= 1:
		discard_penalty -= 20.0
	return maxf(search_value - discard_penalty, 50.0)


func _abs_secret_box(game_state: GameState, player: PlayerState, player_index: int, phase: String, hand_size: int) -> float:
	## 秘密箱：弃3搜(物品+道具+支援者+场地各1)
	## 链：弃3(含超能=燃料) → 搜4张 → 净赚1张卡差 + 弃牌堆超能量
	## 关键：手牌需>=4才能弃3张，弃牌要选好
	if hand_size < 4:  # 秘密箱自己 + 3张弃牌
		return 0.0  # 手牌不够
	var psychic_in_hand: int = _count_energy_in_hand(player, "P")
	var base: float = 200.0
	if phase == "early":
		base = 300.0  # 早期展开加速
	# 弃超能量收益
	var fuel_bonus: float = float(mini(psychic_in_hand, 3)) * 20.0
	# 搜索价值：牌库有什么好东西
	var deck_items: Array[String] = _get_deck_card_names_by_type(player, "Item")
	var deck_tools: Array[String] = _get_deck_card_names_by_type(player, "Tool")
	var deck_supporters: Array[String] = _get_deck_card_names_by_type(player, "Supporter")
	var types_available: int = 0
	if not deck_items.is_empty():
		types_available += 1
	if not deck_tools.is_empty():
		types_available += 1
	if not deck_supporters.is_empty():
		types_available += 1
	# 能搜到的种类越多越值
	base += float(types_available) * 20.0
	return base + fuel_bonus


func _abs_night_stretcher(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	## 夜间担架/救援担架：从弃牌堆取宝可梦
	## 链1：捡沙奈朵ex到手 → 立即进化（如果有奇鲁莉安在场）
	## 链2：捡攻击手到手 → 上板 → Embrace加速
	## 链3：捡2只宝可梦洗入牌库（长期资源）
	var discard: Array[CardInstance] = game_state.players[player_index].discard_pile
	var has_gardevoir_in_discard: bool = false
	var has_kirlia_in_discard: bool = false
	var has_attacker: bool = false
	var has_ralts: bool = false
	for card: CardInstance in discard:
		if card == null or card.card_data == null:
			continue
		var cname: String = str(card.card_data.name)
		if cname == GARDEVOIR_EX:
			has_gardevoir_in_discard = true
		elif cname == KIRLIA:
			has_kirlia_in_discard = true
		elif cname in ATTACKER_NAMES or cname == SCREAM_TAIL:
			has_attacker = true
		elif cname == RALTS:
			has_ralts = true
	# 链1：捡沙奈朵ex + 场上有奇鲁莉安 → 可立即进化
	if has_gardevoir_in_discard and _count_pokemon_on_field(player, GARDEVOIR_EX) == 0:
		if _count_pokemon_on_field(player, KIRLIA) >= 1:
			return 450.0  # A 段：恢复引擎
		return 300.0  # B 段
	# 链2：捡奇鲁莉安 + 场上有拉鲁拉丝
	if has_kirlia_in_discard and _count_pokemon_on_field(player, RALTS) >= 1:
		return 300.0  # B 段
	# 链3：捡攻击手
	if has_attacker:
		return 250.0
	# 链4：捡拉鲁拉丝
	if has_ralts and not player.bench.size() >= 5:
		return 200.0
	return 60.0  # 弃牌堆没好东西


func _abs_iono(game_state: GameState, player: PlayerState, player_index: int, phase: String, hand_size: int) -> float:
	## 奇树(Iono)：双方洗手牌回牌库，各抽奖品数张
	## 链1：己方手牌差 → 换手翻转手牌质量
	## 链2：对手少奖品 → 压缩对手手牌
	## 关键：己方奖品多=自己抽多张，对手奖品少=对手只抽少量
	var my_prizes: int = player.prizes.size()
	var opp_index: int = 1 - player_index
	var opp_prizes: int = game_state.players[opp_index].prizes.size() if opp_index >= 0 and opp_index < game_state.players.size() else 6

	# 己方收益 = 抽 my_prizes 张（替代当前 hand_size 张手牌）
	var my_gain: float = float(my_prizes) - float(hand_size) * 0.5  # 手牌少时换手更值
	# 对手损失 = 对手当前手牌被压缩到 opp_prizes 张
	var opp_loss: float = 0.0
	if opp_prizes <= 2:
		opp_loss = 80.0  # 对手只能抽1-2张，强力干扰
	elif opp_prizes <= 3:
		opp_loss = 40.0

	var base: float = 100.0 + my_gain * 15.0 + opp_loss
	# 早期使用奇树不好（自己手牌质量还可以，且奖品多不算优势）
	if phase == "early" and hand_size >= 4:
		base -= 60.0
	# 手牌只剩1-2张时急需换手
	if hand_size <= 2:
		base += 100.0
	return maxf(base, 50.0)


func _abs_prof_turo(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	## 弗图博士的剧本：收回1只己方宝可梦到手（弃所有附卡）
	## 链1：收回快被打倒的ex（保住2张奖品）
	## 链2：收回前场辅助型，换攻击手上前
	## 链3：收回贴了很多能量的宝可梦（能量进弃牌堆 = Embrace 燃料）
	var best: float = 80.0

	# 检查是否有快被打倒的ex
	for slot: PokemonSlot in _get_all_slots(player):
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		var remaining_hp: int = slot.get_remaining_hp()
		var energy_count: int = slot.attached_energy.size()

		if cd.mechanic == "ex" and remaining_hp <= 60:
			# 保ex = 保2张奖品，极高价值
			best = maxf(best, 500.0)
		elif cd.mechanic == "ex" and remaining_hp <= 100:
			best = maxf(best, 300.0)
		# 收回贴了超能量的宝可梦 = 超能量进弃牌堆 = 燃料
		if energy_count >= 2:
			var psychic_energy_attached: int = 0
			for e: CardInstance in slot.attached_energy:
				if e != null and e.card_data != null and str(e.card_data.energy_provides) == "P":
					psychic_energy_attached += 1
			if psychic_energy_attached >= 2:
				best = maxf(best, 200.0)  # 能量回收价值
	return best


func _count_energy_in_hand(player: PlayerState, etype: String) -> int:
	var count: int = 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == etype:
			count += 1
	return count


func _detect_game_phase(turn: int, player: PlayerState) -> String:
	if turn <= 2:
		return "early"
	if _count_pokemon_on_field(player, GARDEVOIR_EX) >= 1 and turn >= 5:
		return "late"
	if turn <= 4:
		return "mid"
	return "late"


func _estimate_heuristic_base(kind: String) -> float:
	## AIHeuristics 通用基础分的估计值，用于 delta 推导
	match kind:
		"attack": return 500.0
		"granted_attack": return 500.0
		"attach_energy": return 220.0
		"play_basic_to_bench": return 180.0
		"evolve": return 170.0
		"use_ability": return 160.0
		"play_trainer": return 110.0
		"retreat": return 90.0
		"end_turn": return 0.0
	return 10.0


# ============================================================
#  1f. MCTS 配置导出
# ============================================================

func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"max_actions_per_turn": 8,
		"rollouts_per_sequence": 0,   # 不 rollout，用 evaluate_board
		"time_budget_ms": 3000,
	}


# ============================================================
#  2. 局面评估（供 MCTS 叶节点使用）
# ============================================================

func evaluate_board(game_state: GameState, player_index: int) -> float:
	## 评估当前局面对 player_index 的价值
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent_index: int = 1 - player_index
	var opponent: PlayerState = game_state.players[opponent_index] if opponent_index < game_state.players.size() else null
	var score: float = 0.0

	# 奖赏卡差距（最重要指标）
	if opponent != null:
		score += float(opponent.prizes.size() - player.prizes.size()) * 400.0

	# Gardevoir ex 就位 = 引擎启动
	score += float(_count_pokemon_on_field(player, GARDEVOIR_EX)) * 500.0
	score += float(_count_pokemon_on_field(player, KIRLIA)) * 120.0

	# 攻击手就绪程度（用伤害预测评估实际收益）
	for slot: PokemonSlot in _get_all_slots(player):
		var name: String = slot.get_pokemon_name()
		if name in ATTACKER_NAMES or name == SCREAM_TAIL:
			var pred: Dictionary = predict_attacker_damage(slot)
			score += float(int(pred.get("damage", 0))) * 2.0
			if bool(pred.get("can_attack", false)):
				score += 250.0

	# 弃牌堆超能量燃料
	score += float(_count_psychic_energy_in_discard(game_state, player_index)) * 30.0

	# 后备区宝可梦数量
	score += float(player.bench.size()) * 25.0

	# Munkidori 有恶能量就绪
	for slot: PokemonSlot in _get_all_slots(player):
		if slot.get_pokemon_name() == MUNKIDORI and _slot_has_energy_type(slot, "D"):
			score += 150.0

	return score


# ============================================================
#  3. Embrace 贴能目标偏好
# ============================================================

func score_assignment_target(slot: PokemonSlot) -> int:
	## 兼容旧接口（无上下文）— 只给攻击手评分
	if slot == null or slot.get_top_card() == null:
		return 0
	var name: String = slot.get_pokemon_name()
	if name == SCREAM_TAIL or name == DRIFBLIM or name == DRIFLOON:
		if slot.get_remaining_hp() <= 20:
			return 0
		var base: int = 170 if (name == DRIFBLIM or name == DRIFLOON) else 150
		return base + slot.get_remaining_hp() / 10
	return 0


func pick_embrace_target(target_slots: Array, game_state: GameState = null, player_index: int = -1) -> Variant:
	## Embrace 目标选择 — 与评分层使用同一套收益逻辑
	## 核心原则：贴给「边际收益最高」的目标
	##   - 还不能攻击的攻击手 > 能攻击但不能 KO 的 > 已能 KO 的
	##   - 沙奈朵ex 需要撤退能量 + 后备有就绪攻击手 → 最高优先
	if target_slots.is_empty():
		return null

	var active_slot: PokemonSlot = null
	var player: PlayerState = null
	var defender: PokemonSlot = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
		active_slot = player.active_pokemon
		var opp_idx: int = 1 - player_index
		if opp_idx >= 0 and opp_idx < game_state.players.size():
			defender = game_state.players[opp_idx].active_pokemon

	var best: Variant = null
	var best_score: float = -1.0

	# 先检查：前场非攻击手是否需要撤退能量（通用规则）
	var active_needs_retreat: bool = false
	if active_slot != null:
		var aname: String = active_slot.get_pokemon_name()
		if aname not in ATTACKER_NAMES and aname != SCREAM_TAIL:
			if _get_retreat_energy_gap(active_slot) > 0 and active_slot.get_remaining_hp() > 20:
				if player != null:
					for bench_slot: PokemonSlot in player.bench:
						if _is_ready_attacker(bench_slot):
							active_needs_retreat = true
							break

	for slot_variant: Variant in target_slots:
		if not (slot_variant is PokemonSlot):
			continue
		var slot: PokemonSlot = slot_variant as PokemonSlot
		var name: String = slot.get_pokemon_name()
		var score: float = 0.0

		if slot.get_remaining_hp() <= 20:
			continue  # Embrace 会杀死，跳过

		if name in ATTACKER_NAMES or name == SCREAM_TAIL:
			var pred: Dictionary = predict_attacker_damage(slot, 0)
			var pred_after: Dictionary = predict_attacker_damage(slot, 1)
			var can_now: bool = bool(pred.get("can_attack", false))
			var now_dmg: int = int(pred.get("damage", 0))
			var after_dmg: int = int(pred_after.get("damage", 0))
			var can_after: bool = bool(pred_after.get("can_attack", false))

			if not can_now and can_after:
				# Embrace 解锁攻击 → 最高优先级
				score = 500.0
			elif not can_now:
				# 还需要多次 Embrace → 高优先级（蓄力中）
				score = 400.0
			elif can_now and defender != null and now_dmg < defender.get_remaining_hp() and after_dmg >= defender.get_remaining_hp():
				# Embrace 解锁 KO → 比撤退更紧迫
				score = 600.0
			elif can_now and defender != null and now_dmg >= defender.get_remaining_hp():
				# 已能 KO → Embrace 几乎无价值
				score = 10.0
			else:
				# 能攻击但不能 KO，边际 +伤害
				score = 50.0 + float(after_dmg - now_dmg)

		# 前场非攻击手撤退贴能：高于已就绪攻击手，低于未就绪攻击手
		if slot == active_slot and active_needs_retreat and (name not in ATTACKER_NAMES and name != SCREAM_TAIL):
			score = maxf(score, 450.0)  # 高于"已能 KO"(10) 和"边际伤害"(50+)

		if score > best_score:
			best_score = score
			best = slot_variant

	if best != null:
		return best
	# 兜底：用旧逻辑
	var fallback_best: Variant = null
	var fallback_score: int = -1
	for slot_variant: Variant in target_slots:
		if not (slot_variant is PokemonSlot):
			continue
		var s: int = score_assignment_target(slot_variant as PokemonSlot)
		if s > fallback_score:
			fallback_score = s
			fallback_best = slot_variant
	return fallback_best


# ============================================================
#  3b. 攻击手伤害预测
# ============================================================

func predict_attacker_damage(slot: PokemonSlot, extra_embrace_count: int = 0) -> Dictionary:
	## 预测攻击手在当前状态（或额外 N 次 Embrace 后）的伤害输出
	## 返回 {damage, can_attack, description}
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var name: String = slot.get_pokemon_name()
	var current_dc: int = slot.damage_counters + extra_embrace_count * 20
	var counter_count: int = current_dc / 10

	if name == DRIFLOON or name == DRIFBLIM:
		# 气球炸弹：伤害指示物数 × 30
		var damage: int = counter_count * 30
		var energy_gap: int = _get_attack_energy_gap(slot) - extra_embrace_count
		return {
			"damage": damage,
			"can_attack": energy_gap <= 0,
			"description": "气球炸弹 %d 伤害（%d指示物×30）" % [damage, counter_count],
		}

	if name == SCREAM_TAIL:
		# 凶暴吼叫：伤害指示物数 × 20（可打后排）
		var damage: int = counter_count * 20
		var energy_gap: int = _get_attack_energy_gap(slot) - extra_embrace_count
		return {
			"damage": damage,
			"can_attack": energy_gap <= 0,
			"description": "凶暴吼叫 %d 伤害（%d指示物×20，可狙后排）" % [damage, counter_count],
		}

	return {"damage": 0, "can_attack": false, "description": ""}


# ============================================================
#  4. 动作评分（兼容 AIHeuristics 叠加机制，delta = 绝对分 - 基础分估计）
# ============================================================

func score_action(action: Dictionary, context: Dictionary) -> float:
	## 返回 delta 分（供 AIHeuristics 叠加到通用基础分上）
	## 内部从 score_action_absolute 推导
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var abs_score: float = score_action_absolute(action, game_state, player_index)
	# 用估计的 heuristic 基础分推导 delta
	var base_estimate: float = _estimate_heuristic_base(str(action.get("kind", "")))
	return abs_score - base_estimate


# ============================================================
#  5. 开局规划
# ============================================================

func plan_opening_setup(player: PlayerState) -> Dictionary:
	var basics: Array[Dictionary] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type != "Pokemon" or str(card.card_data.stage) != "Basic":
			continue
		basics.append({"index": i, "name": str(card.card_data.name), "priority": _get_setup_priority(str(card.card_data.name))})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	basics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) > int(b["priority"])
	)
	var ralts_count: int = 0
	for b: Dictionary in basics:
		if str(b["name"]) == RALTS:
			ralts_count += 1
	var active_index: int = -1
	# 优先选控制型上前场：振翼发 > 钥圈儿 > 飘飘球
	for preferred: String in [FLUTTER_MANE, KLEFKI, DRIFLOON]:
		if active_index != -1:
			break
		for b: Dictionary in basics:
			if str(b["name"]) == preferred:
				# 钥圈儿/飘飘球需要至少有 1 只拉鲁拉丝才值得上前场
				if preferred != FLUTTER_MANE and ralts_count < 1:
					continue
				active_index = int(b["index"])
				break
	if active_index == -1:
		active_index = int(basics[0]["index"])
	# 开局铺板：核心宝可梦优先，非核心只在有空余位时放
	# 核心：拉鲁拉丝(最多2), 愿增猿(1), 攻击手(1)
	var bench_indices: Array[int] = []
	var essentials_placed: Array[String] = []
	var non_essentials: Array[int] = []
	for b: Dictionary in basics:
		if int(b["index"]) == active_index:
			continue
		var bname: String = str(b["name"])
		if bname == RALTS and essentials_placed.count(RALTS) < 2:
			bench_indices.append(int(b["index"]))
			essentials_placed.append(RALTS)
		elif bname == MUNKIDORI and MUNKIDORI not in essentials_placed:
			bench_indices.append(int(b["index"]))
			essentials_placed.append(MUNKIDORI)
		elif (bname == DRIFLOON or bname == SCREAM_TAIL) and "ATTACKER" not in essentials_placed:
			bench_indices.append(int(b["index"]))
			essentials_placed.append("ATTACKER")
		else:
			non_essentials.append(int(b["index"]))
	# 非核心补满剩余位（最多 1 个灵活位）
	for idx: int in non_essentials:
		if bench_indices.size() >= 5:
			break
		bench_indices.append(idx)
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func _get_setup_priority(pokemon_name: String) -> int:
	## 开局前场优先级（高 = 更适合做前场挡板）
	match pokemon_name:
		FLUTTER_MANE: return 95  # 控制型优先上前场
		KLEFKI: return 90
		DRIFLOON: return 80       # 攻击手也可以挡
		SCREAM_TAIL: return 75
		MUNKIDORI: return 70      # 核心
		RALTS: return 65          # 核心但不想在前场
		MANAPHY: return 40        # 非核心
		RADIANT_GRENINJA: return 35
		_: return 30


# ============================================================
#  6. 弃牌 / 检索偏好
# ============================================================

func get_discard_priority(card: CardInstance) -> int:
	## 无上下文版本（后备兼容）
	if card == null or card.card_data == null:
		return 0
	var card_type: String = str(card.card_data.card_type)
	var cname: String = str(card.card_data.name)
	# 超能量 → 最高优先（Combo: 弃牌堆加速 → Embrace 燃料）
	if card_type == "Basic Energy" and str(card.card_data.energy_provides) == "P":
		return 250
	# 控制型宝可梦（多余的振翼发/钥圈儿）
	if cname in CONTROL_NAMES:
		return 200
	# 恶能量
	if card_type == "Basic Energy" and str(card.card_data.energy_provides) == "D":
		return 150
	# 其他能量
	if card_type == "Basic Energy":
		return 120
	# 一般道具/工具（非搜索型）
	if card_type == "Item" or card_type == "Tool":
		if cname in [ULTRA_BALL, NEST_BALL, BUDDY_BUDDY_POFFIN, SECRET_BOX]:
			return 40  # 搜索型道具不轻易弃
		return 100
	# 基础宝可梦
	if cname in [RALTS, DRIFLOON, FLUTTER_MANE, RADIANT_GRENINJA]:
		return 80
	# 核心进化卡（沙奈朵ex/奇鲁莉安）
	if cname in [GARDEVOIR_EX, KIRLIA]:
		return 5
	# 支援者/场地 — 能搜索拿牌的绝不轻弃
	if card_type == "Supporter" or card_type == "Stadium":
		if _get_supporter_search_value(cname) > 0:
			return 10  # 极低 = 几乎不弃
		return 20
	return 50


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	## 场面感知版弃牌优先级
	## 核心原则：弃牌价值 = 弃掉后的 Embrace 燃料价值 - 保留卡牌的未来使用价值
	## 高分 = 优先弃；低分 = 尽量保留
	if card == null or card.card_data == null:
		return 0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	var card_type: String = str(card.card_data.card_type)
	var cname: String = str(card.card_data.name)
	var bench_full: bool = player.bench.size() >= 5
	var hand_size: int = player.hand.size()

	# --- 第一层：弃了反而有收益的牌 ---
	# 超能量 → 最高优先（弃入弃牌堆 = Embrace 燃料，正收益）
	if card_type == "Basic Energy" and str(card.card_data.energy_provides) == "P":
		return 250
	# 控制型宝可梦已在场 → 多余的优先弃
	if cname in CONTROL_NAMES and _count_pokemon_on_field(player, cname) >= 1:
		return 220

	# --- 第二层：失去效用的牌（弃掉无损失） ---
	# 满板时搜索球/宝芬无法使用
	if bench_full and (cname == NEST_BALL or cname == BUDDY_BUDDY_POFFIN):
		return 180
	# 恶能量（只给愿增猿用，场上已有恶能贴好的愿增猿则多余）
	if card_type == "Basic Energy" and str(card.card_data.energy_provides) == "D":
		return 150
	# 其他能量
	if card_type == "Basic Energy":
		return 120
	# TM Evolution 无可进化目标时
	if cname == TM_EVOLUTION and not _has_evolvable_bench_targets(player):
		return 110

	# --- 第三层：有一定使用价值但不关键的牌 ---
	# 一般道具（不是搜索型）
	if card_type == "Item" or card_type == "Tool":
		# 搜索型道具保留优先级更高
		if cname in [ULTRA_BALL, NEST_BALL, BUDDY_BUDDY_POFFIN, SECRET_BOX]:
			return 40  # 低分 = 不愿意弃
		return 100
	# 控制型宝可梦（未在场但不急需）
	if cname in CONTROL_NAMES:
		return 90
	# 已铺够的拉鲁拉丝
	if cname == RALTS and _count_pokemon_on_field(player, RALTS) >= 3:
		return 85
	# 场上已有的基础宝可梦
	if cname in [RALTS, DRIFLOON, FLUTTER_MANE, RADIANT_GRENINJA, MANAPHY]:
		if bench_full:
			return 80
		return 50

	# --- 第四层：高价值保留牌（不应弃除） ---
	# 能搜索/拿牌的支援者 — 手少时价值极高
	# 计算支援者价值：能拿牌的支援者 >> 其他支援者
	if card_type == "Supporter" or card_type == "Stadium":
		var search_value: int = _get_supporter_search_value(cname)
		if search_value > 0:
			# 手少时支援者更珍贵：hand_size penalty
			var hand_penalty: int = maxi(0, 6 - hand_size) * 3  # 手牌少于6时每少1张多扣3分
			return maxi(5, 15 - search_value - hand_penalty)
		return 20
	# 核心进化卡
	if cname in [GARDEVOIR_EX, KIRLIA]:
		return 5
	# TM Evolution 有目标时
	if cname == TM_EVOLUTION:
		return 25
	return 50


func _get_supporter_search_value(cname: String) -> int:
	## 返回支援者/场地的搜索/抽牌价值（越高越不应弃）
	## 0 = 无搜索价值
	if cname == ARVEN:
		return 15  # 找 2 张道具 — 极高价值
	if cname == IONO:
		return 12  # 换手 — 补牌
	if cname == ARTAZON:
		return 10  # 找基础宝可梦 — 铺板
	if cname == PROF_TURO:
		return 8   # 换回宝可梦
	if cname == BOSSS_ORDERS:
		return 6   # 不搜索但是进攻关键牌
	if cname == COUNTER_CATCHER:
		return 4
	return 0


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var name: String = str(card.card_data.name)
	for i: int in SEARCH_PRIORITY_NAMES.size():
		if name == SEARCH_PRIORITY_NAMES[i]:
			return 100 - i * 10
	return 10


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id: String = str(step.get("id", ""))
	var game_state: GameState = context.get("game_state", null)
	var player_index: int = int(context.get("player_index", -1))
	var all_items: Array = context.get("all_items", [])
	if item is CardInstance:
		var card: CardInstance = item as CardInstance
		if card.card_data == null:
			return 0.0
		if step_id == "search_item":
			return _score_search_item_target(card, all_items, game_state, player_index)
		if step_id == "search_tool":
			return _score_search_tool_target(card, all_items, game_state, player_index)
		if step_id in ["search_pokemon", "search_cards", "basic_pokemon", "buddy_poffin_pokemon", "bench_pokemon"]:
			return float(get_search_priority(card))
		if step_id in ["discard_cards", "discard_card", "discard_energy"]:
			if game_state != null and player_index >= 0:
				return float(get_discard_priority_contextual(card, game_state, player_index))
			return float(get_discard_priority(card))
		if card.card_data.card_type == "Tool":
			return _score_search_tool_target(card, all_items, game_state, player_index)
		if card.card_data.card_type == "Item":
			return _score_search_item_target(card, all_items, game_state, player_index)
		return float(get_search_priority(card))
	if item is PokemonSlot:
		var slot: PokemonSlot = item as PokemonSlot
		if step_id == "embrace_target" and game_state != null and player_index >= 0 and not all_items.is_empty():
			var best_slot: Variant = pick_embrace_target(all_items, game_state, player_index)
			if best_slot == slot:
				return 1000.0
		return float(score_assignment_target(slot))
	return 0.0


func _score_search_item_target(card: CardInstance, all_items: Array, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	if game_state != null and player_index >= 0 and not all_items.is_empty():
		var best_item: Variant = pick_search_item(all_items, game_state, player_index)
		if best_item == card:
			return 1000.0
	var name: String = str(card.card_data.name)
	if name == ULTRA_BALL:
		return 400.0
	if name == NEST_BALL or name == BUDDY_BUDDY_POFFIN:
		return 300.0
	if name == SECRET_BOX or name == EARTHEN_VESSEL:
		return 250.0
	if name == COUNTER_CATCHER or name == NIGHT_STRETCHER or name == RESCUE_STRETCHER:
		return 200.0
	return 50.0


func _score_search_tool_target(card: CardInstance, all_items: Array, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null:
		return 0.0
	if game_state != null and player_index >= 0 and not all_items.is_empty():
		var best_tool: Variant = pick_search_tool(all_items, game_state, player_index)
		if best_tool == card:
			return 1000.0
	var name: String = str(card.card_data.name)
	if name == TM_EVOLUTION:
		return 300.0
	if name == BRAVERY_CHARM:
		return 250.0
	return 50.0


# ============================================================
#  辅助函数
# ============================================================

func _count_pokemon_on_field(player: PlayerState, pokemon_name: String) -> int:
	var count: int = 0
	if player.active_pokemon != null and player.active_pokemon.get_pokemon_name() == pokemon_name:
		count += 1
	for slot: PokemonSlot in player.bench:
		if slot != null and slot.get_top_card() != null and slot.get_pokemon_name() == pokemon_name:
			count += 1
	return count


func _has_pokemon_on_bench(player: PlayerState, pokemon_name: String) -> bool:
	for slot: PokemonSlot in player.bench:
		if slot != null and slot.get_top_card() != null and slot.get_pokemon_name() == pokemon_name:
			return true
	return false


func _hand_has_card(player: PlayerState, card_name: String) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and str(card.card_data.name) == card_name:
			return true
	return false


func _get_retreat_energy_gap(slot: PokemonSlot) -> int:
	## 计算撤退还差多少能量
	if slot == null or slot.get_card_data() == null:
		return 999
	var retreat_cost: int = int(slot.get_card_data().retreat_cost)
	var attached: int = slot.attached_energy.size()
	return maxi(0, retreat_cost - attached)


func _is_ready_attacker(slot: PokemonSlot) -> bool:
	## 检查一个宝可梦是否是已准备好的攻击手（有能量、能打伤害）
	if slot == null or slot.get_top_card() == null:
		return false
	var name: String = slot.get_pokemon_name()
	if name not in ATTACKER_NAMES and name != SCREAM_TAIL:
		return false
	var pred: Dictionary = predict_attacker_damage(slot)
	if int(pred.get("damage", 0)) > 0 and bool(pred.get("can_attack", false)):
		return true
	# 退而求其次：至少有1个能量
	return slot.attached_energy.size() >= 1


func _hand_has_any_energy(player: PlayerState) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy():
			return true
	return false


func _hand_has_energy_type(player: PlayerState, etype: String) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == etype:
			return true
	return false


func _slot_has_energy_type(slot: PokemonSlot, etype: String) -> bool:
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.energy_provides) == etype:
			return true
	return false


func _get_attack_energy_gap(slot: PokemonSlot) -> int:
	var card_data: CardData = slot.get_card_data()
	if card_data == null or card_data.attacks.is_empty():
		return 999
	var attached: int = slot.attached_energy.size()
	var min_gap: int = 999
	for attack: Dictionary in card_data.attacks:
		var cost: String = str(attack.get("cost", ""))
		var gap: int = maxi(0, cost.length() - attached)
		if gap < min_gap:
			min_gap = gap
	return min_gap


func _count_psychic_energy_in_discard(state: GameState, player_index: int) -> int:
	if player_index < 0 or player_index >= state.players.size():
		return 0
	var count: int = 0
	for card: CardInstance in state.players[player_index].discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == "P":
			count += 1
	return count


func _has_attacker_in_discard(state: GameState, player_index: int) -> bool:
	if player_index < 0 or player_index >= state.players.size():
		return false
	for card: CardInstance in state.players[player_index].discard_pile:
		if card != null and card.card_data != null and str(card.card_data.name) in ATTACKER_NAMES:
			return true
		if card != null and card.card_data != null and str(card.card_data.name) == SCREAM_TAIL:
			return true
	return false


func _munkidori_can_threaten_ko(state: GameState, player_index: int) -> bool:
	if player_index < 0 or player_index >= state.players.size():
		return false
	var player: PlayerState = state.players[player_index]
	var total_dc: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		total_dc += slot.damage_counters
	if total_dc < 20:
		return false
	var opponent: PokemonSlot = state.players[1 - player_index].active_pokemon if (1 - player_index) < state.players.size() else null
	if opponent == null:
		return false
	return opponent.get_remaining_hp() <= total_dc


func _has_ability_named(card_data: CardData, ability_name: String) -> bool:
	if card_data == null:
		return false
	for ability: Dictionary in card_data.abilities:
		if str(ability.get("name", "")) == ability_name:
			return true
	return false


func _has_any_ability(card_data: CardData, ability_names: Array) -> bool:
	if card_data == null:
		return false
	for ability: Dictionary in card_data.abilities:
		var aname: String = str(ability.get("name", ""))
		for candidate: Variant in ability_names:
			if aname == str(candidate):
				return true
	return false


func _get_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _count_essential_slots_needed(player: PlayerState) -> int:
	## 计算核心阵容还差几个板位
	## 目标：2× 拉鲁拉丝线（拉鲁拉丝/奇鲁莉安/沙奈朵ex）+ 1× 愿增猿 + 1× 攻击手
	var needed: int = 0
	# 拉鲁拉丝线：目标 2 只（1 只进化成沙奈朵，1 只留奇鲁莉安精炼）
	var ralts_line: int = _count_pokemon_on_field(player, RALTS) \
		+ _count_pokemon_on_field(player, KIRLIA) \
		+ _count_pokemon_on_field(player, GARDEVOIR_EX)
	needed += maxi(0, 2 - ralts_line)
	# 愿增猿：目标 1 只
	if _count_pokemon_on_field(player, MUNKIDORI) == 0:
		needed += 1
	# 攻击手：目标 1 只
	if _count_attackers_on_field(player) == 0:
		needed += 1
	return needed


func _is_essential_pokemon(pname: String, player: PlayerState) -> bool:
	## 判断一只基础宝可梦是否是核心阵容所需
	if pname == RALTS:
		var line: int = _count_pokemon_on_field(player, RALTS) \
			+ _count_pokemon_on_field(player, KIRLIA) \
			+ _count_pokemon_on_field(player, GARDEVOIR_EX)
		return line < 3  # 目标 2-3 只拉鲁拉丝线
	if pname == MUNKIDORI:
		return _count_pokemon_on_field(player, MUNKIDORI) == 0
	if pname == DRIFLOON or pname == SCREAM_TAIL:
		return _count_attackers_on_field(player) == 0
	return false


func _count_attackers_on_field(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		var name: String = slot.get_pokemon_name()
		if name in ATTACKER_NAMES or name == SCREAM_TAIL:
			count += 1
	return count


func _should_bench(pname: String, player: PlayerState, phase: String) -> bool:
	if not _hand_has_card(player, pname):
		return false
	if player.bench.size() >= 5:
		return false
	# 核心宝可梦始终可放
	if _is_essential_pokemon(pname, player):
		return true
	# 非核心宝可梦：只在有空余板位时放
	var essential_needed: int = _count_essential_slots_needed(player)
	var free_slots: int = 5 - player.bench.size()
	if free_slots <= essential_needed:
		return false  # 留位给核心
	# 其他限制
	if pname == MANAPHY and _count_pokemon_on_field(player, MANAPHY) >= 1:
		return false
	return true


func _best_attacker_for_tool(player: PlayerState) -> String:
	## 勇气护符只给攻击手
	for pname: String in [SCREAM_TAIL, DRIFBLIM, DRIFLOON]:
		for slot: PokemonSlot in _get_all_slots(player):
			if slot.get_pokemon_name() == pname and not _slot_has_tool(slot):
				return pname
	return ""


func _best_energy_target(player: PlayerState) -> String:
	## 手贴超能量应急目标（Embrace 不可用时）
	for pname: String in [GARDEVOIR_EX, DRIFBLIM, DRIFLOON, SCREAM_TAIL]:
		for slot: PokemonSlot in _get_all_slots(player):
			if slot.get_pokemon_name() == pname and _get_attack_energy_gap(slot) > 0:
				return pname
	return ""


func _best_retreat_target(player: PlayerState) -> String:
	## 如果前场不是攻击手且后备有能攻击的攻击手
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return ""
	var active_name: String = active.get_pokemon_name()
	if active_name in ATTACKER_NAMES or active_name == SCREAM_TAIL or active_name == GARDEVOIR_EX:
		if active.attached_energy.size() >= 1:
			return ""  # 前场已经是攻击手且有能量，不换
	# 找后备攻击手
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		var name: String = slot.get_pokemon_name()
		if (name in ATTACKER_NAMES or name == SCREAM_TAIL or name == GARDEVOIR_EX) and slot.attached_energy.size() >= 1:
			return name
	return ""


func _slot_has_tool(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var card_data: CardData = slot.get_card_data()
	if card_data == null:
		return false
	# 检查是否已有道具
	for card: CardInstance in slot.pokemon_stack:
		if card != null and card.card_data != null and card.card_data.card_type == "Tool":
			return true
	return false


func _has_evolvable_bench_targets(player: PlayerState) -> bool:
	## 后备区是否有可进化的基础/1阶宝可梦（TM Evolution 的目标）
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		# 基础或1阶宝可梦且有对应进化目标
		if cd.stage == "Basic" and cd.name == RALTS:
			return true
		if cd.stage == "Stage 1" and cd.name == KIRLIA:
			return true
	return false


func _can_ko_bench_target(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	## 检查当前攻击手是否能击倒对手后备的某个弱目标
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return false
	var pred: Dictionary = predict_attacker_damage(active)
	var my_damage: int = int(pred.get("damage", 0))
	if my_damage <= 0:
		# 尝试用卡数据的基础伤害
		var cd: CardData = active.get_card_data()
		if cd != null:
			for attack: Dictionary in cd.attacks:
				var dmg: int = int(str(attack.get("damage", "0")).strip_edges())
				if dmg > my_damage:
					my_damage = dmg
	if my_damage <= 0:
		return false
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	for slot: PokemonSlot in game_state.players[opponent_index].bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= my_damage:
			return true
	return false


func _has_core_in_discard(state: GameState, player_index: int) -> bool:
	if player_index < 0 or player_index >= state.players.size():
		return false
	for card: CardInstance in state.players[player_index].discard_pile:
		if card != null and card.card_data != null and str(card.card_data.name) in CORE_NAMES:
			return true
	return false
