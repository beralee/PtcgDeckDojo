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
const CHARIZARD_EX_EN := "Charizard ex"
const PIDGEOT_EX_EN := "Pidgeot ex"
const PIDGEY_EN := "Pidgey"
const CHARMANDER_EN := "Charmander"
const DUSKULL_EN := "Duskull"
const ROTOM_V_EN := "Rotom V"

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
			return _abs_play_basic(action, game_state, player, player_index, phase)
		"play_stadium":
			return _abs_play_trainer(action, game_state, player, player_index, phase)
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


func _abs_play_basic(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var name: String = str(card.card_data.name)
	var bench_size: int = player.bench.size()
	if bench_size >= 5:
		return 0.0  # 婵犲ň鍓濆?
	var shell_lock: bool = _shell_lock_active(player)
	var transition_shell: bool = _has_transition_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var essential_slots_needed: int = _count_essential_slots_needed(player)
	var free_slots: int = 5 - bench_size
	var is_essential: bool = _is_essential_pokemon(name, player)
	var charizard_rebuild_lock: bool = _charizard_rebuild_lock(game_state, player, player_index)

	if not is_essential and free_slots <= essential_slots_needed:
		return 0.0

	if shell_lock:
		if name == RALTS:
			if _count_primary_shell_bodies(player) >= 2:
				return 20.0
			return 420.0 if phase == "early" else 340.0
		if name in [SCREAM_TAIL, MUNKIDORI, RADIANT_GRENINJA, DRIFLOON, MANAPHY]:
			return -120.0
		if name in [KLEFKI, FLUTTER_MANE]:
			return -40.0
		return -80.0

	if not transition_shell:
		if name == RALTS:
			return 120.0
		if name == DRIFLOON:
			if attacker_bodies == 0 and _opponent_has_scream_tail_prize_target(game_state, player_index):
				return 260.0
			return 320.0 if attacker_bodies == 0 else 80.0
		if name == SCREAM_TAIL:
			if attacker_bodies == 0 and _opponent_has_scream_tail_prize_target(game_state, player_index):
				return 360.0
			return 260.0 if attacker_bodies == 0 else 40.0
		if name == MUNKIDORI:
			return -80.0 if attacker_bodies == 0 else 20.0
		if name == RADIANT_GRENINJA:
			return -60.0
		if name in [KLEFKI, FLUTTER_MANE]:
			return 20.0
		if name == MANAPHY:
			return 60.0 if _count_pokemon_on_field(player, MANAPHY) == 0 else 0.0
		return -20.0

	if charizard_rebuild_lock:
		if name == MUNKIDORI:
			return -140.0
		if name == RALTS:
			return -80.0
		if name in [FLUTTER_MANE, KLEFKI, MANAPHY, RADIANT_GRENINJA]:
			return -120.0

	if transition_shell and _opponent_has_scream_tail_prize_target(game_state, player_index):
		if name == SCREAM_TAIL and _count_pokemon_on_field(player, SCREAM_TAIL) == 0:
			if ready_attackers >= 1:
				return 180.0
			if attacker_bodies >= 1:
				return 240.0

	if transition_shell and attacker_bodies >= 1 and ready_attackers == 0:
		if name in [FLUTTER_MANE, KLEFKI, MANAPHY, MUNKIDORI]:
			return -90.0
		if name == RADIANT_GRENINJA:
			return -60.0
		if name == RALTS:
			return 0.0

	if _has_deck_out_pressure(player) and ready_attackers >= 1:
		if name == RALTS:
			return -40.0
		if name in [RADIANT_GRENINJA, FLUTTER_MANE, KLEFKI, MANAPHY, MUNKIDORI]:
			return -80.0

	if attacker_bodies == 0:
		if name == DRIFLOON:
			if _opponent_has_scream_tail_prize_target(game_state, player_index):
				return 260.0
			return 320.0
		if name == SCREAM_TAIL:
			if _opponent_has_scream_tail_prize_target(game_state, player_index):
				return 360.0
			return 260.0
		if name == RALTS:
			return 20.0
		if name == MUNKIDORI:
			return -60.0
		if name == RADIANT_GRENINJA:
			return -50.0
		return 0.0

	if ready_attackers >= 1:
		if name == RALTS:
			return -80.0
		if name in [FLUTTER_MANE, KLEFKI, RADIANT_GRENINJA, MUNKIDORI, MANAPHY]:
			return -100.0
		if name in [DRIFLOON, SCREAM_TAIL]:
			return -20.0
	return 20.0


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
	var shell_lock: bool = _shell_lock_active(player)
	var tm_live: bool = _tm_setup_priority_live(player, "mid")
	var stage2_shell: bool = _has_established_stage2_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var live_attackers: int = _count_live_attackers(player)
	var active_name: String = player.active_pokemon.get_pokemon_name() if player.active_pokemon != null else ""
	var charizard_matchup: bool = _is_charizard_pressure_matchup(game_state, player_index)
	var delay_attacker_investment: bool = _should_delay_attacker_investment_during_shell_lock(player)

	if target_slot == player.active_pokemon and target_name == SCREAM_TAIL and _get_attack_energy_gap(target_slot) <= 1:
		if delay_attacker_investment:
			return -160.0
		if energy_type == "D":
			return 900.0
		if energy_type == "P":
			return 520.0
	if target_slot == player.active_pokemon and target_name == DRIFLOON and _get_attack_energy_gap(target_slot) <= 1 and energy_type == "P":
		if delay_attacker_investment:
			return -160.0
		return 520.0
	if shell_lock and target_slot == player.active_pokemon and (_hand_has_card(player, TM_EVOLUTION) or _active_has_tm_evolution(player)) and _count_evolvable_bench_targets(player) >= 2:
		return 760.0
	if tm_live and target_slot == player.active_pokemon and _tm_attack_payment_gap(target_slot) <= 1:
		return 760.0
	if shell_lock and target_slot == player.active_pokemon and _count_primary_shell_bodies(player) >= 2:
		if active_name in [FLUTTER_MANE, KLEFKI, MUNKIDORI, DRIFLOON]:
			if target_slot.attached_energy.size() == 0:
				return 260.0

	# --- 闂侇偅姘ㄩ弫銈囨喆閸曨偄鐏熼柨娑欑婢ф粎鎷圭壕瀣幋闂佹彃绻掔划浼村礈瀹ュ懏绨氶梻鍫㈠仦閺侀箖宕欑紒妯侯杹濞寸姰鍎磋闂佸じ鐒﹂幐娆撴焻閳?---
	if target_slot == player.active_pokemon \
	   and target_name not in ATTACKER_NAMES and target_name != SCREAM_TAIL:
		var retreat_gap: int = _get_retreat_energy_gap(target_slot)
		if retreat_gap > 0 and retreat_gap <= 1:  # 鐎?闁煎疇妫勫銊╂嚄閼恒儲瀵甸梺顐熷亾
			var has_bench_attacker: bool = false
			for bench_slot: PokemonSlot in player.bench:
				if _is_ready_attacker(bench_slot):
					has_bench_attacker = true
					break
			if has_bench_attacker:
				return 380.0  # B 婵炲牏顣槐浼村箥鐎ｎ厼鍨遍悷娆欑秮閺€锝夊箻閵堝鍋撻埀?闁?闁衡偓鐠囨彃姣婇柟闈涱儎缁楀倿宕?

	if energy_type == "P":
		if shell_lock:
			return -100.0
		if stage2_shell and live_attackers == 0:
			if target_name == DRIFLOON or target_name == DRIFBLIM:
				if _get_attack_energy_gap(target_slot) <= 1:
					return 520.0 if target_slot == player.active_pokemon else 420.0
			if target_name == SCREAM_TAIL and _get_attack_energy_gap(target_slot) <= 1:
				if _opponent_has_scream_tail_prize_target(game_state, player_index):
					return 560.0 if target_slot == player.active_pokemon else 460.0
				return 480.0 if target_slot == player.active_pokemon else 380.0
		if target_slot == player.active_pokemon and target_name == DRIFLOON and live_attackers == 0 and _get_attack_energy_gap(target_slot) <= 1:
			return 560.0
		if target_slot == player.active_pokemon and target_name == SCREAM_TAIL and live_attackers == 0 and _get_attack_energy_gap(target_slot) <= 1:
			return 520.0
		return -100.0
	if energy_type == "D":
		if target_name == SCREAM_TAIL and live_attackers == 0 and _get_attack_energy_gap(target_slot) <= 1:
			if stage2_shell:
				if _opponent_has_scream_tail_prize_target(game_state, player_index):
					return 720.0 if target_slot == player.active_pokemon else 620.0
				return 640.0 if target_slot == player.active_pokemon else 520.0
			if target_slot == player.active_pokemon:
				return 580.0
		if shell_lock and not (tm_live and target_slot == player.active_pokemon):
			return -100.0
		if target_name == MUNKIDORI:
			if charizard_matchup and _has_transition_shell(player) and not _munkidori_can_threaten_ko(game_state, player_index):
				return -140.0
			if _has_transition_shell(player) and ready_attackers >= 1:
				return 0.0
			if not _slot_has_energy_type(target_slot, "D"):
				return 120.0
			return -100.0
		if target_slot == player.active_pokemon and target_name not in ATTACKER_NAMES and target_name != SCREAM_TAIL:
			var retreat_gap: int = _get_retreat_energy_gap(target_slot)
			if retreat_gap > 0 and retreat_gap <= 1:
				for bench_slot: PokemonSlot in player.bench:
					if _is_ready_attacker(bench_slot):
						return 350.0
		return -100.0
	return -100.0


func _abs_attach_tool(action: Dictionary, player: PlayerState, phase: String = "mid") -> float:
	var card: CardInstance = action.get("card")
	var target_slot: PokemonSlot = action.get("target_slot")
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var tool_name: String = str(card.card_data.name)
	var target_name: String = target_slot.get_pokemon_name()
	if tool_name == TM_EVOLUTION:
		if target_slot != player.active_pokemon:
			return -200.0
		if _tm_support_carrier_cools_off(player, phase):
			return -220.0
		if _has_online_shell(player):
			return -180.0
		if _must_force_first_gardevoir(player):
			return 10.0
		if not _has_evolvable_bench_targets(player):
			return -100.0
		var active_energy: int = target_slot.attached_energy.size()
		var can_power: bool = active_energy >= 1 or _hand_has_any_energy(player)
		if _shell_lock_active(player):
			if can_power:
				return 550.0
			return 180.0
		if _tm_precharge_window(player):
			return 160.0
		return -80.0
	if tool_name == BRAVERY_CHARM:
		if _shell_lock_active(player):
			return -120.0
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
	# 缂侇喖澧介〃锝夊箯閵夛箑小 / Psychic Embrace闁挎稑婀憃mbo: 鐎殿喖鍟版晶婵嬪醇閸℃顫ｉ梺?/ 濡炲锕㈤ˉ婵嬫偠閸愵喚褰ù?/ 闁告氨鍘цぐ銊т焊閸撗冪彙闁哄鍋撻柨?
	if source_name == GARDEVOIR_EX and _has_any_ability(card_data, ["精神拥抱", "Psychic Embrace"]):
		return _abs_psychic_embrace(game_state, player, player_index)
	# 缂侇喖澧介崑?/ Refinement闁挎稑婀憃mbo: 鐎殿喖鍟版晶婵嬪醇閸℃顫ｉ梺?闁?鐎殿喖鍟崇粔鎾嚄?+ 闁瑰墎鏅晶婵嬫晬?
	if source_name == KIRLIA and _has_any_ability(card_data, ["精炼", "Refinement"]):
		if _has_deck_out_pressure(player) and _count_ready_attackers(player) >= 1:
			return 0.0
		if _has_transition_shell(player) and _count_ready_attackers(player) >= 1:
			return 30.0
		var hand_size: int = player.hand.size()
		if hand_size <= 1:
			return 50.0
		return 400.0 if phase != "late" else 250.0
	# 闂傚懏鍔樺Λ宀勬偋?/ Concealed Cards 闁?闁稿繐顦崇欢锝夋偨閼艰埖妲煫鍥хХ濞叉劙鏁嶉崼婵堢＞闁煎厖绮欓崳娲箮?鐎殿喚濯寸槐?
	if source_name == RADIANT_GRENINJA and _has_any_ability(card_data, ["隐藏牌", "Concealed Cards"]):
		if _has_deck_out_pressure(player) and _count_ready_attackers(player) >= 1:
			return 0.0
		if _shell_lock_active(player) and _count_primary_shell_bodies(player) >= 2 and _hand_has_energy_type(player, "P"):
			return 460.0
		if _shell_lock_active(player):
			if _count_primary_shell_bodies(player) < 2 or _has_shell_search(player):
				return -40.0
		if _has_transition_shell(player) and _count_ready_attackers(player) >= 1:
			return 20.0
		if _hand_has_energy_type(player, "P"):
			return 420.0
		if _hand_has_energy_type(player, "D"):
			return 300.0
		return 0.0  # 闁哄啰濮鹃崗姗€鏌岃箛鎾宠鐎?	# Munkidori 闁绘顫夐埀顑秶绀凜ombo: 闁规澘鐏濋·鍐偖閹稿孩鏆柛鎾诡嚋缁?
	if source_name == MUNKIDORI:
		if _munkidori_can_threaten_ko(game_state, player_index):
			return 600.0  # A 婵炲牏顣槐浼村矗椤栨艾娅?KO
		if _is_charizard_pressure_matchup(game_state, player_index) and _has_transition_shell(player):
			return -120.0
		if _has_transition_shell(player) and _count_ready_attackers(player) >= 1:
			return -80.0
		return -20.0
	if source_name == MANAPHY:
		return 120.0  # C 婵?
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
	var shell_lock: bool = _shell_lock_active(player)
	var transition_shell: bool = _has_transition_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var attacker_recovery_mode: bool = _needs_attacker_recovery(game_state, player, player_index)
	var charizard_rebuild_lock: bool = _charizard_rebuild_lock(game_state, player, player_index)

	# === 闁瑰吋绮庨崒銊╁垂鐎ｎ剙鈷栭柛?===

	# 闁告瑥顑呴妶鐣屸偓瑙勭箚婵噣鏁嶅顓熷仢闁绘鑻花?闁?=70HP闁糕晞娅ｉ、鍛偓瑙勭箓瑜版彃顫忛敂璺ㄧ憪闁?
	# 闂佺偓鎷濈槐鎵偓瑙勭箚婵?闁?闁瑰嘲顦甸惉楣冨箯婢跺顐緓2濞戞挸锕ュ?闁?濞戞挸顑呭ú鏍触閸絿绠婚柛鏍ㄧ墪椤ㄥ本銇旀担钘夌閻?闁?缂侇喖澧介崑褍顕ｉ弴鐔告儧
	if name == BUDDY_BUDDY_POFFIN:
		if bench_full:
			return 0.0
		if charizard_rebuild_lock:
			return -140.0
		if attacker_recovery_mode:
			return 40.0
		if shell_lock and _count_primary_shell_bodies(player) >= 2:
			return -40.0
		if transition_shell and ready_attackers >= 1:
			return -120.0
		var essential_needed: int = _count_essential_slots_needed(player)
		if essential_needed >= 2 and phase == "early":
			return 380.0  # 闁哄秶顭堢缓鐐媴瀹ュ洤绻侀柛娆欑到閵囧洭鏁嶇仦鐣屾澓闁间警鍓熼悵顔藉濡搫甯?
		if essential_needed >= 1:
			return 300.0
		return 150.0  # 闁哄秶顭堢缓鎯ь啅閺屻儳绉烽柨娑樿嫰閻ゅ倿鎳為璺ㄥ箚闁稿﹪妫跨粭鍛存⒔?

	# 鐎规悶鍨婚埞鎰版偠閸愯法绐楅柟鍏肩矌婢ф繃鎯?闁告瑯浜滈悢鈧痪顓涘亾閻庤绻傝ぐ鎻掝潖閿旇法鐟愰柡?
	# 闂佺偓鎷濈槐鏉款啅閵忊懇鏀奸柣?闁?闁瑰嘲顦甸惉楣冨箯婢跺顐?濡炲锕㈤ˉ婵嬫偠?闁告氨鍘цぐ銊т焊閸欍儳鐟愰柡?
	if name == NEST_BALL:
		if bench_full:
			return 0.0
		if charizard_rebuild_lock:
			return -140.0
		if attacker_recovery_mode:
			return 30.0
		if shell_lock and _count_primary_shell_bodies(player) >= 2:
			return -20.0
		if transition_shell and ready_attackers >= 1:
			return -120.0
		var essential_needed: int = _count_essential_slots_needed(player)
		if essential_needed >= 1 and phase == "early":
			return 300.0  # 闁哄秶顭堢缓鐐媴瀹ュ棙绠掔紓?		if essential_needed >= 1:
			return 200.0
		return 100.0  # 闁哄秶顭堢缓鎯ь啅閺屻儳绉?

	# 濡ゅ倹顭囨鍥偠閸愯法绐楃€?闁瑰吋绮堥幑銏ゅ箛韫囨挾鏉洪柛娆樺灡閳?
	# 闂?闁挎稒宀搁悵顔剧棯瑜忛幃?鐎?閻℃帒鎳撻崗? 闁?婵炲本鐟ラ〃宥夊嫉缁€绉?闁?閺夆晜绋戠€垫煡宕ラ姘楃€殿喗娲橀幖鎼佹晬閸繄纾鹃悺鎺戞嚀閸忔ɑ娼诲Ο鍝勵潱闂侇偆鍠撻崳褔寮▎娆戠
	# 闂?闁挎稒宀搁悵顔剧棯瑜忛幃?鐎?閻℃帒鎳撻崗? 闁?濠靛倸娲惉楣冩嚔婢跺﹦鏆?闁?閺夆晜绋戠€垫煡鎳㈠畡鎵箒缂侇喖澧介崑?
	# 闂?闁挎稒宀搁悵顔剧棯瑜忛幃?闁?闁衡偓鐠囨彃姣婇柟?鐎规悶鍎遍崣璺ㄢ偓瑙勭箓瑜版彃顫?
	if name == ULTRA_BALL:
		return _abs_ultra_ball(game_state, player, player_index, phase, hand_size)

	# 缂佸锚閻︽垹绮婚幉瀣獥鐎?闁?闁绘せ鏅涢幖?闂侇剚鎸搁崣?闁衡偓椤栨稑鑳堕柤?闁革箑鎼﹢鎾触?)
	# 闂佺偓鎷濈槐鎵矓濡櫣妲曠紒?鐎?闁告凹鍋夌粔鎾嚄? 闁?闁兼儳鍢茬欢?鐎殿喚濮村畷閬嶆晬閸繃纭跺鍫嗗啫骞㈢€瑰壊鍣槐姘跺焼?闁告艾娴烽悽鑽や沪閺囩偟纾?
	if name == SECRET_BOX:
		if transition_shell and ready_attackers >= 1:
			return -120.0
		return _abs_secret_box(game_state, player, player_index, phase, hand_size)

	# 婵炲弶鍎崇粭妤呮晬濮橆厽鍋?闁绘せ鏅涢幖?1闂侇剚鎸搁崣?
	# 闂佺偓鎷濈槐鏉棵洪幆褏鐟?闁?濡ゅ倹顭囨鍥偠?TM閺夆晜绋戠€?/ 閻庤绻嗘慨?闁告洖娲﹂惃鐢稿箮閵堝浂鍎?缂?
	if name == ARVEN:
		if transition_shell and ready_attackers >= 1:
			return -120.0
		return _abs_arven(game_state, player, player_index, phase)

	# === 鐎殿喖鍟版晶婵嬪醇閸℃顫ｉ梺顐ゅ枎閻庣兘鎮ч埡浣规儌 ===

	# 濠㈠爢鍐╁嬀閻庡湱鎳撳▍鎺楁晬濮橆剛纾?閻℃帒鎳撻崗姗€鏁嶇仦鑲╃煠闁绘鑻花閬嶅箹?鐎殿喚濮撮悢鈧痪顓涘亾闁煎厖绮欓崳?
	# 闂佺偓鎷濈槐鐗堝緞瑜嶅﹢瀵糕偓鍦嚀濞?鐎殿喖鍟崇粔鎾嚄鐟欙絽鏅柣鏇炲暞閺? 闁?闁?闁煎厖绮欓崳?闁诡厽鍎奸崗妯肩磼濞嗘劕濮藉褏鍋熺亸?閻℃帒鎳撻崗姗€宕戝顒夋У闁?
	if name == EARTHEN_VESSEL:
		if _tm_setup_priority_live(player, phase) and not _hand_has_any_energy(player):
			return 340.0
		if shell_lock and _count_primary_shell_bodies(player) < 2:
			return -40.0
		if transition_shell and ready_attackers >= 1:
			return -70.0
		if _hand_has_energy_type(player, "P"):
			return 350.0 if phase != "late" else 120.0  # 鐎殿喖鍟崇粔鎾嚄?= 闁告瑥鐭傞崳鎼佸绩閸撲焦鎶?
		return 200.0 if phase != "late" else 80.0

	# === 闁搞儳鍋為弫褰掑垂鐎ｎ剙鈷栭柛?===

	# 濠㈣埖绮撳Λ鍧楀箯閸涱喚浠搁柨娑欑煯缁姴顕ｉ崘顏勵杺闁割偄妫欏畷?闁告瑯浜滈悿鍌炲矗椤栨稈鍙洪柛鎺斿婢?2闁告瑯浜滈崺宀勬偋鐏炵晫姘?
	# 闂?闁挎稒鑹鹃¨渚€姊荤€涙ê顎撻柡?闁?闁瑰厜鍓濋惌娆愮附閸喐鏋別x/濠靛倸娲惉楣冩嚔婢跺﹦鏆旈柛鎺斿婢?闁?閺夆晜绋戠€?
	# 闂?闁挎稒鑹鹃¨渚€姊荤€涙ê顎撻柡?闁?闁瑰厜鍓濋弫楣冨礄缂佹ê顤?闁?濞戞挸锕ュ?闁?Embrace闁告梻濞€閳?
	if name == NIGHT_STRETCHER:
		if attacker_recovery_mode:
			return 360.0
		return _abs_night_stretcher(game_state, player, player_index, phase)

	# 闁轰焦鍨惰ぐ娲箯閸涱喚浠搁柨娑欒壘閹挻绋夋繝蹇曠闁哄唲鍛暭闁?
	if name == RESCUE_STRETCHER:
		if attacker_recovery_mode:
			return 360.0
		return _abs_night_stretcher(game_state, player, player_index, phase)

	# 闁告ê顦濠囨煢閹鹃浼￠柨娑欑煯缁姴顕ｉ崘顏勵杺闁割偄妫濋埀顒€顦板〒鑸靛緞?鐎殿喚濮撮悿鍌炲矗椤栨稈鍙?闁糕晞娅ｉ、鍛存嚄娴犲娅ゆ繛鍙夘殔濞叉牠鎮х仦鐣屾皑
	# 闂佺偓鎷濈槐浼存煢閹鹃浼?闁?闁搞儳鍋為弫鍦惥閸涙澘鍘撮梺鎻掔箰閸╁矂鎮х仦鐣屾皑闁挎稑鐗嗛妵鍥捶閺夋鍟囬柛锝冨妼閸熲偓闁瑰吋绮岄崵顓㈠级閵夘垳绀? 闁搞儳鍋為弫褰掑冀缁嬭法濡囬悗瑙勭箓瑜版彃顫?
	if name == SUPER_ROD:
		if attacker_recovery_mode:
			return 180.0
		var discard_value: int = 0
		if _has_core_in_discard(game_state, player_index):
			discard_value += 80
		if _has_attacker_in_discard(game_state, player_index):
			discard_value += 60
		if discard_p >= 3:
			discard_value += 40
		if shell_lock and discard_value <= 80:
			return -40.0
		if transition_shell and ready_attackers >= 1 and discard_value <= 120:
			return -80.0
		return float(maxi(60, discard_value))

	# 婵炲弶顨堢换婵嬫儍閸曨剛鐒介梺鎻掔Ф閹棝鏁嶅杈╁€崇€殿喒鍋撳┑鍌涚墪閹佳囧礌閻氬绀夐柛?闁告瑯浜滈悢鈧痪顓涘亾閻庤绻傝ぐ鎻掝潖閿曗偓閸╁矂骞嶇€ｅ墎绀夋繛灞筋樀閸ｆ悂鎮堕崘銊ュ汲濠靛倹鐗曢幖?
	# 闂佺偓鎷濈槐鏉库柦婢舵劕娅㈤柣?闁?闁轰焦鍨甸崵顓犳偖椤愩垹骞㈤柛锔哄妼椤ㄦ盯宕担绋块殬闁汇劌瀚刊鐑樸仈娴ｇ懓顎欏☉?濡炲锕㈤ˉ婵嬫偠?
	if name == HISUIAN_HEAVY_BALL:
		if attacker_recovery_mode:
			return 10.0
		if charizard_rebuild_lock:
			return -100.0
		if _count_pokemon_on_field(player, RALTS) < 2 and not _has_shell_search(player):
			return 220.0
		if transition_shell and ready_attackers >= 1:
			return -60.0
		return 20.0

	# === 妤犵偛寮舵竟?闁绘瑦鐟ラ崵顕€宕?===

	# 闁告瑥绉撮崵顕€骞戦弴鐔风８闁革綆鐓夌槐鏉款啅鏉堛劍鐓欏┑鍌涚墪閹?閻庝絻顫夋晶婊堝籍鐠佸湱绀夐柟骞垮灩椤曨噣骞嶇€ｎ亝鍊靛璺烘搐閸╁矂宕滃鍛皻
	# 闂佺偓鎷濈槐浼村矗瀹ュ懎姣婇柟瑙勬礃瀹曞繘宕?闁?闁瑰嘲顦幀銉╂儎椤旂晫鍨奸柛鎺撴緲婢х娀宕?闁?闁衡偓鐠囨彃姣婇柛鎴犵帛濞?
	if name == COUNTER_CATCHER:
		if not _has_immediate_attack_window(game_state, player, player_index):
			return -40.0
		if _can_ko_bench_target(game_state, player, player_index):
			return 700.0
		return 120.0

	# 闁奸绀侀妵鍥儍閸曨剙鐦瑰ù鐘€х槐浼村箲閵忕媭鍤犻柟闈涱儏閹寰勯崶褍鐓傞柛鎾崇Т濠р偓闁挎稑鐗婇弫顕€骞撶壕瀣у亾閸滃啰绀?
	# 闂佺偓鎷濈槐浼存嚀娴ｆ悶浜ｉ柟绋挎矗閹?闁?闁瑰嘲鈥/V鐎殿喛浜ú浼村冀閸パ冪厒闁告挸绉村┃鈧?闁?闁衡偓鐠囨彃姣婇柟?-3鐎殿喚濮撮〃娑㈠传?
	if name == BOSSS_ORDERS:
		if not _has_immediate_attack_window(game_state, player, player_index):
			return -40.0
		if _can_ko_bench_target(game_state, player, player_index):
			return 800.0
		if phase == "late":
			return 120.0
		return 40.0

	# === 闁衡偓椤栨稑鑳堕柤?===

	# 濠靛倸娲﹂悥?Iono)闁挎稒鑹惧濠氬棘鐟欏嫮顦ч柟闈涱儑婢ф繈宕堕悙闈涱杺閹煎瓨鎼槐婵嬪触閸曨剙鈻曞┑鍌涚墪閹佳囧极閺夎法鐐?
	# 闂?闁?鐎规瓕椴搁弻鐔煎箥鐎ｎ剙顤傜€? 濠靛倸娲﹂悥?闁?闁瑰箍鍨烘晶婊堝箮?-6鐎?闁?缂傚牊妲掑ù鍡涘箥鐎ｎ剙顤傞悹鎰╁姂閸?
	# 闂?闁?閻庝絻顫夋晶婊呬焊閹存繍娈柛? 濠靛倸娲﹂悥?闁?閻庝絻顫夋晶婊堝矗椤忓懎鈻?-2鐎?闁?闁告ê顑囩紓澶屸偓浣冾潐婢ф粓骞嶇€ｎ剙顤?
	if name == IONO:
		if attacker_recovery_mode and hand_size >= 3:
			return -20.0
		return _abs_iono(game_state, player, player_index, phase, hand_size)

	# 婵烇綁浜堕幐濂告⒐?Artazon)闁挎稒鑹惧┃鈧柛锕€搴滅槐婵喰掕箛鎾寸闁告艾鐗嗚ぐ鏌ュ箹?闁告瑯浜滈悢鈧痪顓涘亾閻庤绻傝ぐ鎻掝潖閿旇法鐟愰柡?
	# 闂佺偓鎷濈槐鏉壳庨柆宥嗗安闂傗偓?闁?婵絽绻愬ú鏍触閸繂甯抽悹鎰扳偓娑氱憪闁糕晞娅ｉ、?闁?闁归晲鑳堕悽濠氭煣閻戞ɑ绶?
	if name == ARTAZON:
		if bench_full or _count_searchable_basic_targets(player) == 0:
			return 0.0
		if charizard_rebuild_lock:
			return -140.0
		if attacker_recovery_mode:
			return 40.0
		if shell_lock and _count_primary_shell_bodies(player) >= 2:
			return -20.0
		if shell_lock and _count_primary_shell_bodies(player) < 2:
			var other_shell_search: bool = _hand_has_card(player, ULTRA_BALL) \
				or _hand_has_card(player, NEST_BALL) \
				or _hand_has_card(player, BUDDY_BUDDY_POFFIN) \
				or _hand_has_card(player, ARVEN) \
				or _hand_has_card(player, SECRET_BOX)
			return 40.0 if other_shell_search else 220.0
		if transition_shell and ready_attackers >= 1:
			return -120.0
		return 120.0

	# 鐎殿喗顨呭ù姗€宕″顒婄礈闁汇劌瀚晶浠嬪嫉椤掑﹦绐楅柡鈧捄鐑樼1闁告瑯浜滅换渚€寮悷鎵澓闁告瑯鍨遍埅鐢稿礆閻楀牆顤侀柨娑樼墕缁辨棃骞嶉埀顒勫嫉婢舵劖顎嶉柛妞绘缁?
	# 闂?闁挎稒鑹剧槐顒勫炊?闁?闁衡偓鐠虹儤绀€闊浂鍋夐～锕傚箥閹炬枼鍋撻幒鏃€鐣眅x闁挎稑鐗呯换姘附閺嵮勬儌闁挎稑顦崯?闂佹彃绉甸弻濠冪▔婵犲啯绶?
	# 闂?闁挎稒鑹剧槐顒勫炊?闁?闁衡偓鐠虹儤绀€閻犳劗绻濈花锟犳嚄娴犲娅ら柣銊ュ缁剁喖宕濋埡浣衡偓鐑芥晬閸喐娅濋柤鍏呯矙閸ｆ椽鏁?
	if name == PROF_TURO:
		return _abs_prof_turo(game_state, player, player_index, phase)

	# Rare Candy闁挎稑婀憃mbo: 閻犵儤濞婂Ο?闁?闊浂鍋婇埀顒傚枎閹酣宕?Gardevoir ex 鐎殿喗娲橀幖鎼佹晬?
	if name == RARE_CANDY:
		if has_ralts and _hand_has_card(player, GARDEVOIR_EX):
			return 500.0  # A 婵?
		return 50.0

	return 50.0  # C 婵?濮掓稒顭堥?


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
	var phase: String = _detect_game_phase(int(game_state.turn_number), player)
	if _active_has_tm_evolution(player) and active.attached_energy.size() >= 1 and _has_evolvable_bench_targets(player):
		if _shell_lock_active(player) or _tm_precharge_window(player) or not _tm_support_carrier_cools_off(player, phase):
			return -250.0
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
	if _should_delay_attacker_investment_during_shell_lock(player) and player.active_pokemon != null:
		var opening_name: String = player.active_pokemon.get_pokemon_name()
		if opening_name in ATTACKER_NAMES or opening_name == SCREAM_TAIL:
			return -180.0
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
	if attack_name == "进化" or attack_name == "Evolution":
		if _tm_support_carrier_cools_off(player, phase):
			return -220.0
		if _has_online_shell(player):
			return -180.0
		if _must_force_first_gardevoir(player):
			return 10.0
		if _shell_lock_active(player) and _count_evolvable_bench_targets(player) >= 2:
			return 900.0
		if _has_evolvable_bench_targets(player):
			return 600.0
		return 50.0
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
	var bench_full: bool = player.bench.size() >= 5

	var priority_list: Array[String] = []
	if _count_pokemon_on_field(player, GARDEVOIR_EX) == 0 and _count_pokemon_on_field(player, KIRLIA) >= 1 and _discard_has_card(game_state, player_index, GARDEVOIR_EX):
		priority_list.append(NIGHT_STRETCHER)
		priority_list.append(RESCUE_STRETCHER)
	if _shell_lock_active(player):
		if _count_pokemon_on_field(player, RALTS) < 2 and not bench_full:
			priority_list.append(BUDDY_BUDDY_POFFIN)
		elif not _hand_has_any_energy(player):
			priority_list.append(EARTHEN_VESSEL)
		priority_list.append(ULTRA_BALL)
		if not bench_full:
			priority_list.append(NEST_BALL)
	elif _must_force_first_gardevoir(player):
		priority_list.append(ULTRA_BALL)
		priority_list.append(SECRET_BOX)
	else:
		priority_list.append(ULTRA_BALL)
		if phase == "early" and not bench_full:
			priority_list.append(BUDDY_BUDDY_POFFIN)
		priority_list.append(EARTHEN_VESSEL)
		if not bench_full:
			priority_list.append(NEST_BALL)
	priority_list.append(NIGHT_STRETCHER)
	priority_list.append(RESCUE_STRETCHER)
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
	var phase: String = _detect_game_phase(int(game_state.turn_number), player)
	var priority_list: Array[String] = []
	if _shell_lock_active(player) and _count_pokemon_on_field(player, RALTS) < 2 and _count_pokemon_on_field(player, KIRLIA) == 0:
		priority_list.append(TM_EVOLUTION)
	elif _shell_lock_active(player) and _count_evolvable_bench_targets(player) >= 2:
		priority_list.append(TM_EVOLUTION)
	priority_list.append(BRAVERY_CHARM)
	if TM_EVOLUTION not in priority_list and not _tm_support_carrier_cools_off(player, phase) and not _must_force_first_gardevoir(player):
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
	var shell_lock: bool = _shell_lock_active(player)
	var transition_shell: bool = _has_transition_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	if has_gardevoir_in_discard and _count_pokemon_on_field(player, GARDEVOIR_EX) == 0:
		if _count_pokemon_on_field(player, KIRLIA) >= 1:
			return 460.0
		return 320.0
	if has_kirlia_in_discard and _count_pokemon_on_field(player, RALTS) >= 1 and _count_pokemon_on_field(player, KIRLIA) == 0:
		return 320.0
	if has_attacker and transition_shell and attacker_bodies == 0:
		return 250.0
	if has_ralts and not player.bench.size() >= 5:
		return 180.0 if _count_primary_shell_bodies(player) < 2 else 60.0
	if shell_lock:
		return -40.0
	if transition_shell and ready_attackers >= 1:
		return 20.0
	if attacker_bodies >= 1 and ready_attackers == 0:
		return 20.0
	return 20.0


func _abs_iono(game_state: GameState, player: PlayerState, player_index: int, phase: String, hand_size: int) -> float:
	var my_prizes: int = player.prizes.size()
	var opp_index: int = 1 - player_index
	var opp_prizes: int = game_state.players[opp_index].prizes.size() if opp_index >= 0 and opp_index < game_state.players.size() else 6
	var shell_lock: bool = _shell_lock_active(player)
	var shell_online: bool = _has_established_stage2_shell(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var stable_hand: bool = hand_size >= 3
	var strong_comeback_need: bool = my_prizes >= opp_prizes + 2
	if shell_lock and hand_size >= 4:
		return 0.0
	if _has_deck_out_pressure(player) and ready_attackers >= 1:
		return 0.0
	if shell_online and ready_attackers >= 1:
		if opp_prizes <= 2 and my_prizes > opp_prizes:
			return 120.0
		if stable_hand:
			return -40.0
		if not strong_comeback_need:
			return 0.0
	var my_gain: float = float(my_prizes) - float(hand_size) * 0.5
	var opp_loss: float = 0.0
	if opp_prizes <= 2:
		opp_loss = 80.0
	elif opp_prizes <= 3:
		opp_loss = 40.0

	var base: float = 100.0 + my_gain * 15.0 + opp_loss
	if phase == "early" and hand_size >= 4:
		base -= 80.0
	if hand_size <= 2:
		base += 100.0
	return maxf(base, 0.0)


func _abs_prof_turo(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	if _has_transition_shell(player) and _count_ready_attackers(player) >= 1:
		return 20.0
	var best: float = 20.0
	for slot: PokemonSlot in _get_all_slots(player):
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		var remaining_hp: int = slot.get_remaining_hp()
		if cd.mechanic == "ex" and remaining_hp <= 60:
			best = maxf(best, 500.0)
		elif cd.mechanic == "ex" and remaining_hp <= 100:
			best = maxf(best, 300.0)
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
	for b in basics:
		if str(b["name"]) == RALTS:
			ralts_count += 1
	var active_index: int = -1
	var active_preference: Array[String] = [RALTS, FLUTTER_MANE, KLEFKI, DRIFLOON]
	if ralts_count >= 2:
		active_preference = [FLUTTER_MANE, KLEFKI, DRIFLOON, MUNKIDORI, RALTS]
	for preferred in active_preference:
		if active_index != -1:
			break
		for b in basics:
			if str(b["name"]) != preferred:
				continue
			if preferred != FLUTTER_MANE and ralts_count < 1:
				continue
			active_index = int(b["index"])
			break
	if active_index == -1:
		active_index = int(basics[0]["index"])
	var bench_indices: Array[int] = []
	var non_essentials: Array[int] = []
	for b in basics:
		if int(b["index"]) == active_index:
			continue
		var bname: String = str(b["name"])
		if bname == RALTS and bench_indices.size() < 2:
			bench_indices.append(int(b["index"]))
		else:
			non_essentials.append(int(b["index"]))
	for idx in non_essentials:
		if bench_indices.size() >= 2:
			break
		bench_indices.append(idx)
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func _get_setup_priority(pokemon_name: String) -> int:
	match pokemon_name:
		RALTS: return 110
		FLUTTER_MANE: return 95
		KLEFKI: return 90
		DRIFLOON: return 80
		SCREAM_TAIL: return 70
		MUNKIDORI: return 60
		MANAPHY: return 40
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
	if _shell_lock_active(player):
		if cname == TM_EVOLUTION:
			return 20
		if cname == ARVEN:
			return 30
		if cname == ULTRA_BALL:
			return 60
		if cname == NIGHT_STRETCHER or cname == RESCUE_STRETCHER:
			return 100

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
			if game_state != null and player_index >= 0:
				return _score_search_pokemon_target(card, game_state, player_index)
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


func _score_search_pokemon_target(card: CardInstance, game_state: GameState, player_index: int) -> float:
	if card == null or card.card_data == null or game_state == null:
		return float(get_search_priority(card))
	if player_index < 0 or player_index >= game_state.players.size():
		return float(get_search_priority(card))
	var player: PlayerState = game_state.players[player_index]
	var name: String = str(card.card_data.name)
	var shell_online: bool = _has_established_stage2_shell(player)
	var attacker_bodies: int = _count_attackers_on_field(player)
	var ready_attackers: int = _count_ready_attackers(player)
	var weak_bench_target: bool = _opponent_has_scream_tail_prize_target(game_state, player_index)
	var charizard_rebuild_lock: bool = _charizard_rebuild_lock(game_state, player, player_index)
	if _must_force_first_gardevoir(player):
		if name == GARDEVOIR_EX:
			return 1000.0
		if name == RALTS:
			return -40.0
	if shell_online and weak_bench_target and name == SCREAM_TAIL and _count_pokemon_on_field(player, SCREAM_TAIL) == 0:
		return 360.0 if ready_attackers == 0 else 320.0
	if shell_online and attacker_bodies == 0:
		if name == DRIFLOON:
			return 320.0
		if name == SCREAM_TAIL:
			return 260.0
		if name == MUNKIDORI:
			return -40.0
	if charizard_rebuild_lock:
		if name == MUNKIDORI:
			return -80.0
		if name == RALTS:
			return -60.0
	if name == RALTS and _count_pokemon_on_field(player, RALTS) >= 2:
		return -20.0
	return float(get_search_priority(card))


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
	var needed: int = 0
	var ralts_line: int = _count_primary_shell_bodies(player)
	needed += maxi(0, 2 - ralts_line)
	if _has_established_stage2_shell(player):
		if _count_attackers_on_field(player) == 0:
			needed += 1
	return needed


func _is_essential_pokemon(pname: String, player: PlayerState) -> bool:
	if pname == RALTS:
		return _count_primary_shell_bodies(player) < 2
	if _has_established_stage2_shell(player) and (pname == DRIFLOON or pname == SCREAM_TAIL):
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
	# 闁哄秶顭堢缓鍓р偓瑙勭箓瑜版彃顫忛敃鈧～鎰磼閸繂璁查柡鈧?
	if _is_essential_pokemon(pname, player):
		return true
	# 闂傚牏鍋為悧瀹犵疀閸愩劎鏉洪柛娆樺灡閳敻鏁嶅顒€娑ч柛锔哄妽濠€浣虹矚鏉炴壆绋囬柡澶娿仒缂嶅懘寮懜鍨澒
	var essential_needed: int = _count_essential_slots_needed(player)
	var free_slots: int = 5 - player.bench.size()
	if free_slots <= essential_needed:
		return false  # 闁伙絾鐟ょ紞鍛磼濞嗘劗澹嬮煫?
	# 闁稿繑婀圭划顒勬⒔閹邦剙鐓?
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
	## 闁归潧顑堥崚娑氭惥閸涙澘鍘撮梺鎻掔箰缁ㄦ煡骞€閵壯勭獥闁哄秴娴勭槐姗brace 濞戞挸绉磋ぐ鏌ユ偨閵婏附顦ч柨?
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


func _count_evolvable_bench_targets(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		var cd: CardData = slot.get_card_data()
		if cd == null:
			continue
		if cd.stage == "Basic" and cd.name == RALTS:
			count += 1
		elif cd.stage == "Stage 1" and cd.name == KIRLIA:
			count += 1
	return count


func _active_has_tm_evolution(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	for card: CardInstance in player.active_pokemon.pokemon_stack:
		if card != null and card.card_data != null and str(card.card_data.name) == TM_EVOLUTION:
			return true
	return false


func _shell_lock_active(player: PlayerState) -> bool:
	return not _has_online_shell(player)


func _should_delay_attacker_investment_during_shell_lock(player: PlayerState) -> bool:
	if not _shell_lock_active(player):
		return false
	if _count_primary_shell_bodies(player) < 2:
		return true
	if _must_force_first_gardevoir(player):
		return true
	if _has_shell_search(player):
		return true
	return false


func _must_force_first_gardevoir(player: PlayerState) -> bool:
	return _count_pokemon_on_field(player, GARDEVOIR_EX) == 0 and _count_pokemon_on_field(player, KIRLIA) >= 1


func _has_transition_shell(player: PlayerState) -> bool:
	return _has_established_stage2_shell(player)


func _has_online_shell(player: PlayerState) -> bool:
	return _count_pokemon_on_field(player, GARDEVOIR_EX) >= 1


func _tm_precharge_window(player: PlayerState) -> bool:
	return _shell_lock_active(player) and _count_pokemon_on_field(player, RALTS) >= 2


func _tm_support_carrier_cools_off(player: PlayerState, phase: String) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var active_name: String = player.active_pokemon.get_pokemon_name()
	if active_name not in [MUNKIDORI, KLEFKI]:
		return false
	if _count_pokemon_on_field(player, KIRLIA) >= 1:
		return true
	if _has_transition_shell(player) and phase != "early":
		return true
	return false


func _charizard_rebuild_lock(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if not _is_charizard_pressure_matchup(game_state, player_index):
		return false
	if not _has_established_stage2_shell(player):
		return false
	if _needs_attacker_recovery(game_state, player, player_index):
		return false
	return _count_attackers_on_field(player) >= 1


func _is_charizard_pressure_matchup(game_state: GameState, player_index: int) -> bool:
	if game_state == null:
		return false
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	for slot: PokemonSlot in _get_all_slots(opponent):
		if slot == null or slot.get_top_card() == null:
			continue
		var cd: CardData = slot.get_card_data()
		var cname: String = slot.get_pokemon_name()
		var name_en: String = str(cd.name_en) if cd != null else ""
		if cname in ["喷火龙ex", "大比鸟ex", "波波", "小火龙", "夜巡灵", "洛托姆V"]:
			return true
		if name_en in [CHARIZARD_EX_EN, PIDGEOT_EX_EN, PIDGEY_EN, CHARMANDER_EN, DUSKULL_EN, ROTOM_V_EN]:
			return true
	return false
func _tm_setup_priority_live(player: PlayerState, phase: String) -> bool:
	if not _shell_lock_active(player):
		return false
	if not _has_evolvable_bench_targets(player):
		return false
	if player.active_pokemon == null:
		return false
	if _tm_support_carrier_cools_off(player, phase):
		return false
	if not (_hand_has_card(player, TM_EVOLUTION) or _active_has_tm_evolution(player)):
		return false
	if player.active_pokemon.attached_energy.size() >= 1 or _hand_has_any_energy(player):
		return true
	return phase == "early"


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


func _count_ready_attackers(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		if _is_ready_attacker(slot):
			count += 1
	return count


func _count_live_attackers(player: PlayerState) -> int:
	var count: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		if slot == null or slot.get_top_card() == null:
			continue
		var name: String = slot.get_pokemon_name()
		if name not in ATTACKER_NAMES and name != SCREAM_TAIL:
			continue
		var pred: Dictionary = predict_attacker_damage(slot)
		if bool(pred.get("can_attack", false)) and int(pred.get("damage", 0)) > 0:
			count += 1
	return count


func _count_primary_shell_bodies(player: PlayerState) -> int:
	return _count_pokemon_on_field(player, RALTS) + _count_pokemon_on_field(player, KIRLIA)


func _has_established_stage2_shell(player: PlayerState) -> bool:
	return _has_online_shell(player) and _count_pokemon_on_field(player, KIRLIA) >= 1


func _needs_attacker_recovery(state: GameState, player: PlayerState, player_index: int) -> bool:
	if state == null:
		return false
	if not _has_established_stage2_shell(player):
		return false
	if _count_ready_attackers(player) >= 1:
		return false
	if _count_attackers_on_field(player) >= 1:
		return false
	return _has_attacker_in_discard(state, player_index)


func _has_deck_out_pressure(player: PlayerState) -> bool:
	return player.deck.size() > 0 and player.deck.size() <= 8


func _has_shell_search(player: PlayerState) -> bool:
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var cname: String = str(card.card_data.name)
		if cname in [ULTRA_BALL, NEST_BALL, BUDDY_BUDDY_POFFIN, ARVEN, ARTAZON]:
			return true
	return false


func _opponent_has_scream_tail_prize_target(game_state: GameState, player_index: int) -> bool:
	return _best_scream_tail_bench_prize_value(game_state, player_index, 120) > 0.0




func _tm_attack_payment_gap(slot: PokemonSlot) -> int:
	if slot == null:
		return 999
	return maxi(0, 1 - slot.attached_energy.size())




func _has_immediate_attack_window(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var pred: Dictionary = predict_attacker_damage(player.active_pokemon)
	if bool(pred.get("can_attack", false)) and int(pred.get("damage", 0)) > 0:
		return true
	return _count_ready_attackers(player) >= 1




func _count_searchable_basic_targets(player: PlayerState) -> int:
	if player.bench.size() >= 5:
		return 0
	if player.deck.size() > 0:
		var searchable_in_deck: bool = false
		for card: CardInstance in player.deck:
			if card == null or card.card_data == null:
				continue
			if str(card.card_data.card_type) != "Pokemon" or str(card.card_data.stage) != "Basic":
				continue
			searchable_in_deck = true
			break
		if not searchable_in_deck:
			return 0
	var count: int = 0
	if _count_primary_shell_bodies(player) < 2:
		count += 1
	elif _has_established_stage2_shell(player) and _count_attackers_on_field(player) == 0:
		count += 1
	return count




func _best_scream_tail_bench_prize_value(game_state: GameState, player_index: int, damage: int) -> float:
	if game_state == null or damage <= 0:
		return 0.0
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0.0
	var best: float = 0.0
	for slot: PokemonSlot in game_state.players[opponent_index].bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() > damage:
			continue
		var slot_value: float = 220.0
		var cd: CardData = slot.get_card_data()
		if cd != null:
			var name_en: String = str(cd.name_en)
			if cd.mechanic == "ex" or cd.mechanic == "V":
				slot_value = 420.0
			elif name_en in ["Pidgey", "Charmander", "Duskull"]:
				slot_value = 320.0
			elif name_en in ["Rotom V", "Lumineon V"]:
				slot_value = 380.0
		best = maxf(best, slot_value)
	return best




func _discard_has_card(state: GameState, player_index: int, card_name: String) -> bool:
	if state == null or player_index < 0 or player_index >= state.players.size():
		return false
	for card: CardInstance in state.players[player_index].discard_pile:
		if card != null and card.card_data != null and str(card.card_data.name) == card_name:
			return true
	return false




func _active_attack_can_be_finished_with_one_attach(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var active_name: String = player.active_pokemon.get_pokemon_name()
	if active_name not in [SCREAM_TAIL, DRIFLOON]:
		return false
	return _get_attack_energy_gap(player.active_pokemon) <= 1




func _should_cool_off_tm_evolution(player: PlayerState, phase: String) -> bool:
	if _must_force_first_gardevoir(player) and _count_pokemon_on_field(player, KIRLIA) >= 2:
		return true
	if _has_transition_shell(player) and (_count_ready_attackers(player) >= 1 or phase != "early"):
		return true
	if _has_online_shell(player) and phase == "late":
		return true
	return false


