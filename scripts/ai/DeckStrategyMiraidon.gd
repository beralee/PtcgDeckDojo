class_name DeckStrategyMiraidon
extends "res://scripts/ai/DeckStrategyBase.gd"

## 密勒顿卡组专属 AI 策略
##
## 核心运作逻辑：
## 1. 密勒顿ex 放后备，特性「串联装置」每回合从牌库搜 2 只雷属性基础宝可梦上板
## 2. 电气发生器（×4）从牌组顶翻雷能量贴到后备雷系 → 核心加速
## 3. 铁臂膀ex 主力输出：LLC=160，LCCC=120+多拿1奖品
## 4. 闪电鸟/雷公V/雷丘V 轮替攻击
## 5. 月月熊·赫月ex 非规则备选打手
## 6. 全基础宝可梦，无进化线，铺板速度极快

const VERSION := "v1.3"
const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const MiraidonStateEncoderScript = preload("res://scripts/ai/MiraidonStateEncoder.gd")

## 密勒顿专用 value net（可选）
var miraidon_value_net: RefCounted = null  # NeuralNetInference
var miraidon_encoder_class: GDScript = MiraidonStateEncoderScript


func get_strategy_id() -> String:
	return "miraidon"


func get_signature_names() -> Array[String]:
	return [MIRAIDON_EX, IRON_HANDS_EX, RAIKOU_V]


func get_state_encoder_class() -> GDScript:
	return miraidon_encoder_class


func load_value_net(path: String) -> bool:
	return load_miraidon_value_net(path)


func get_value_net() -> RefCounted:
	return miraidon_value_net


func load_miraidon_value_net(path: String) -> bool:
	var net := NeuralNetInferenceScript.new()
	if net.load_weights(path):
		miraidon_value_net = net
		return true
	miraidon_value_net = null
	return false


func has_miraidon_value_net() -> bool:
	return miraidon_value_net != null and miraidon_value_net.is_loaded()

# -- 卡牌名称常量 --
const MIRAIDON_EX := "密勒顿ex"
const IRON_HANDS_EX := "铁臂膀ex"
const ZAPDOS := "闪电鸟"
const RAIKOU_V := "雷公V"
const RAICHU_V := "雷丘V"
const URSALUNA_EX := "月月熊·赫月ex"
const MEW_EX := "梦幻ex"
const LUMINEON_V := "霓虹鱼V"
const RADIANT_GRENINJA := "光辉甲贺忍蛙"
const SQUAWKABILLY_EX := "怒鹦哥ex"
const KILOWATTREL_EX := "吉雉鸡ex"

const ELECTRIC_GENERATOR := "电气发生器"
const NEST_BALL := "巢穴球"
const SWITCH_CART := "交替推车"
const HEAVY_BALL := "沉重球"
const LOST_VACUUM := "放逐吸尘器"
const SUPER_ROD := "厉害钓竿"
const PRIME_CATCHER := "顶尖捕捉器"
const BOSSS_ORDERS := "老大的指令"
const PAIPA := "派帕"
const CRYPTO_DECODE := "暗码迷解读"
const ARTAZON := "奇树"
const SERENA := "星月"
const BRAVERY_CHARM := "勇气护符"
const EMERGENCY_BOARD := "紧急滑板"
const HEAVY_BATON := "沉重接力棒"
const FOREST_SEAL_STONE := "森林封印石"
const LIGHTNING_ENERGY := "基本雷能量"
const DOUBLE_TURBO_ENERGY := "双重涡轮能量"
const GRAVITY_MOUNTAIN := "重力山"

# -- 角色分类 --
const ENGINE_NAMES: Array[String] = ["密勒顿ex"]
const MAIN_ATTACKER_NAMES: Array[String] = ["铁臂膀ex"]
const SUB_ATTACKER_NAMES: Array[String] = ["闪电鸟", "雷公V", "雷丘V"]
const SUPPORT_NAMES: Array[String] = ["梦幻ex", "霓虹鱼V", "光辉甲贺忍蛙", "怒鹦哥ex", "吉雉鸡ex"]
const ALL_ATTACKER_NAMES: Array[String] = ["铁臂膀ex", "闪电鸟", "雷公V", "雷丘V", "密勒顿ex"]
const NON_RULE_ATTACKER: Array[String] = ["月月熊·赫月ex"]
const LIGHTNING_POKEMON: Array[String] = ["密勒顿ex", "铁臂膀ex", "闪电鸟", "雷公V", "雷丘V"]

const BENCH_PRIORITY_NAMES: Array[String] = [
	"密勒顿ex", "铁臂膀ex", "闪电鸟", "雷公V", "雷丘V",
	"怒鹦哥ex", "梦幻ex", "霓虹鱼V", "光辉甲贺忍蛙", "吉雉鸡ex", "月月熊·赫月ex"
]


# ============================================================
#  1. 绝对分评估（贪心循环核心）
# ============================================================

func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var kind: String = str(action.get("kind", ""))
	var player: PlayerState = game_state.players[player_index]
	var turn: int = int(game_state.turn_number)
	var phase: String = _detect_game_phase(turn, player)
	match kind:
		"play_basic_to_bench":
			return _abs_play_basic(action, player, phase)
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
			return _abs_attack(action, game_state, player_index)
	return 0.0


func _abs_play_basic(action: Dictionary, player: PlayerState, phase: String) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var pname: String = str(card.card_data.name)
	var bench_size: int = player.bench.size()
	if bench_size >= 5:
		return 0.0

	# --- 板位预算系统 ---
	# 目标阵容（5板位）：1× 密勒顿ex + 1× 铁臂膀ex + 2× 副攻手 + 1× 灵活位
	var essential_needed: int = _count_essential_slots_needed(player)
	var free_slots: int = 5 - bench_size
	var is_essential: bool = _is_essential_pokemon(pname, player)

	# 非核心宝可梦 + 板位紧张 → 不放
	if not is_essential and free_slots <= essential_needed:
		return -50.0

	# 密勒顿ex — 引擎，后备最高优先
	if pname == MIRAIDON_EX:
		if _count_pokemon_on_field(player, MIRAIDON_EX) >= 2:
			return 0.0
		return 350.0

	# 铁臂膀ex — 主攻手
	if pname == IRON_HANDS_EX:
		return 300.0

	# 闪电鸟 — buff（场上时雷系基础+10伤害）+ 副攻
	if pname == ZAPDOS:
		return 280.0

	# 雷公V — 前期核心打手：撤退1费极低，LC=20+后备×20，前期就能输出
	if pname == RAIKOU_V:
		if phase == "early":
			return 290.0  # 前期比闪电鸟还优先（LC 仅2能就能打，灵活）
		return 250.0

	# 雷丘V — 终结者：LL 弃全部雷能×60，只在后期最后一击用
	# 前期拍到场上浪费板位且容易被狙（200HP ex 拿2奖品）
	if pname == RAICHU_V:
		if phase == "late":
			return 250.0  # 后期收割
		if phase == "mid":
			return 120.0  # 中期可以准备
		return 30.0  # 前期不拍（浪费板位，留给雷公/铁臂膀）

	# 月月熊·赫月ex — 后期非规则打手
	if pname == URSALUNA_EX:
		return 180.0 if phase == "late" else 120.0

	# 怒鹦哥ex — 首回合引擎
	if pname == SQUAWKABILLY_EX:
		return 200.0 if phase == "early" else 80.0

	# 辅助型
	if pname in SUPPORT_NAMES:
		return 100.0
	if str(card.card_data.card_type) == "Pokemon" and str(card.card_data.stage) == "Basic":
		if str(card.card_data.energy_type) == "L":
			return 220.0
		return 40.0

	return 50.0


func _abs_attach_energy(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var target_slot: PokemonSlot = action.get("target_slot")
	var energy_card: CardInstance = action.get("card")
	if target_slot == null or energy_card == null or energy_card.card_data == null:
		return 0.0
	var target_name: String = target_slot.get_pokemon_name()
	var energy_type: String = str(energy_card.card_data.energy_provides)

	# 双重涡轮能量 — 只给差2能即可攻击的攻击手
	if str(energy_card.card_data.name) == DOUBLE_TURBO_ENERGY:
		if target_name in ALL_ATTACKER_NAMES or target_name in NON_RULE_ATTACKER:
			var gap: int = _get_attack_energy_gap(target_slot)
			if gap <= 2 and gap > 0:
				return 350.0  # 贴上去就能攻击
			if gap == 0:
				return 30.0  # 已能攻击，无意义
			return 150.0  # 差太多，应急用
		return 50.0  # 非攻击手不值得贴双涡轮

	# 雷能量贴给雷系攻击手
	if energy_type == "L":
		# 密勒顿ex 特殊处理：后备时低优先级，前场或无其他好目标时可以贴
		if target_name == MIRAIDON_EX:
			# 在前场时（被拉出来了）：需要能量撤退或打 220
			if target_slot == player.active_pokemon:
				var gap: int = _get_attack_energy_gap(target_slot)
				if gap == 1:
					return 380.0  # 差1能打 220，极高价值
				if gap <= 2:
					return 250.0  # 蓄力中
				# 差太多但需要撤退
				var retreat_gap: int = _get_retreat_energy_gap(target_slot)
				if retreat_gap > 0 and retreat_gap <= 1:
					return 200.0
				return 100.0
			# 后备时：有其他攻击手优先贴给它们，没有则给密勒顿蓄力
			if _has_better_energy_target(player, target_slot):
				return -50.0  # 有更好目标，暂不贴给密勒顿
			return 150.0  # 无其他好目标，蓄力密勒顿也行
		# --- 按角色分层的能量路由 ---
		# 充能优先级：雷公V（灵活前期）> 铁臂膀ex（稳定主攻）> 闪电鸟（副攻）> 月月熊（后期）> 雷丘V（终结者，最后贴）

		# 雷公V — LC 仅2能就能打 20+后备×20，撤退1费，最灵活的前期打手
		if target_name == RAIKOU_V:
			var gap: int = _get_attack_energy_gap(target_slot)
			if gap == 1:
				return 420.0  # 差1能就能打，最高优先
			if gap == 0:
				return 40.0  # 已满，不再贴
			return 300.0

		# 铁臂膀ex — LLC=160 稳定输出，LCCC=120+多拿1奖品
		if target_name == IRON_HANDS_EX:
			var gap: int = _get_attack_energy_gap(target_slot)
			if gap == 1:
				return 400.0  # 差1能解锁160伤害
			if gap == 2:
				return 300.0
			if gap == 0:
				# 已能用第一招（LLC），继续贴能解锁第二招（LCCC 多拿奖品）
				var total_energy: int = target_slot.attached_energy.size()
				if total_energy < 4:
					return 150.0  # 蓄力第二招
				return 30.0  # 4能已满
			return 250.0

		# 闪电鸟 — LLC=110，后备时+10 buff，副攻手
		if target_name == ZAPDOS:
			var gap: int = _get_attack_energy_gap(target_slot)
			if gap == 1:
				return 380.0
			if gap == 0:
				return 30.0
			return 250.0

		# 雷丘V — LL 弃全部雷能×60，只在最后一击时贴能
		# 过早贴能 = 浪费（能量会被弃掉），且雷丘被打倒 = 能量全失
		if target_name == RAICHU_V:
			var opponent_index: int = 1 - player_index
			var opp_prizes: int = 6
			if opponent_index >= 0 and opponent_index < game_state.players.size():
				opp_prizes = game_state.players[opponent_index].prizes.size()
			# 对手只剩1-2张奖品 = 接近结束，可以给雷丘蓄力
			if opp_prizes <= 2:
				var gap: int = _get_attack_energy_gap(target_slot)
				if gap <= 1:
					return 350.0  # 终结时刻
				return 250.0
			# 还早，不急着给雷丘
			return 20.0

		# 月月熊·赫月ex — 后期非规则打手
		if target_name == URSALUNA_EX:
			var gap: int = _get_attack_energy_gap(target_slot)
			if gap == 1:
				return 350.0
			if gap == 0:
				return 30.0
			return 200.0

		# 其他雷系宝可梦（通用）
		if target_name in ALL_ATTACKER_NAMES:
			var gap: int = _get_attack_energy_gap(target_slot)
			if gap == 1:
				return 400.0
			if gap == 0:
				return 50.0
			return 250.0
		# 非攻击手但在前场需要撤退费
		if target_slot == player.active_pokemon:
			var retreat_gap: int = _get_retreat_energy_gap(target_slot)
			if retreat_gap > 0 and retreat_gap <= 1:
				return 200.0
		return 100.0

	# 非雷能量
	return 50.0


func _abs_attach_tool(action: Dictionary, player: PlayerState, phase: String = "mid") -> float:
	var card: CardInstance = action.get("card")
	var target_slot: PokemonSlot = action.get("target_slot")
	if card == null or card.card_data == null or target_slot == null:
		return 0.0
	var tool_name: String = str(card.card_data.name)
	var target_name: String = target_slot.get_pokemon_name()

	if tool_name == BRAVERY_CHARM:
		if target_name in ALL_ATTACKER_NAMES or target_name in NON_RULE_ATTACKER:
			return 200.0
		return 50.0
	if tool_name == EMERGENCY_BOARD:
		# 紧急滑板贴给重撤退费宝可梦
		var cd: CardData = target_slot.get_card_data()
		if cd != null and cd.retreat_cost >= 3:
			return 250.0
		return 100.0
	if tool_name == HEAVY_BATON:
		# 沉重接力棒只贴给铁臂膀ex（撤退费4，被KO后转移能量给下一只）
		if target_name == IRON_HANDS_EX:
			return 300.0
		return -100.0
	if tool_name == FOREST_SEAL_STONE:
		if target_name == MEW_EX:
			return 300.0
		return 100.0
	return 50.0


func _abs_use_ability(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var source_slot: PokemonSlot = action.get("source_slot")
	if source_slot == null:
		return 0.0
	var source_name: String = source_slot.get_pokemon_name()
	var card_data: CardData = source_slot.get_card_data()
	if card_data == null:
		return 0.0

	# 串联装置 / Tandem Unit（密勒顿ex）
	if source_name == MIRAIDON_EX and _has_any_ability(card_data, ["串联装置", "Tandem Unit"]):
		if player.bench.size() >= 5:
			return 50.0  # 满板无目标
		# 检查牌库是否有雷系基础宝可梦（串联装置的搜索目标）
		var lightning_basics_in_deck: int = _count_lightning_basics_in_deck(player)
		if lightning_basics_in_deck == 0:
			return 30.0  # 牌库没有雷系基础了
		if player.bench.size() >= 4 and lightning_basics_in_deck >= 1:
			return 300.0  # 只剩1个板位，价值下降但仍可用
		return 500.0

	# 英武 / Squawk and Seize（怒鹦哥ex）— 首回合弃手牌抽6张
	if source_name == SQUAWKABILLY_EX and _has_any_ability(card_data, ["英武", "Squawk and Seize"]):
		if phase == "early":
			return 450.0
		return 100.0

	# 隐藏牌 / Concealed Cards（光辉甲贺忍蛙）
	if source_name == RADIANT_GRENINJA and _has_any_ability(card_data, ["隐藏牌", "Concealed Cards"]):
		if _hand_has_energy_type(player, "L"):
			return 400.0
		return 0.0

	# 瞬步 / Fleet Feet（雷公V）— 前场时抽1张
	if source_name == RAIKOU_V and _has_any_ability(card_data, ["瞬步", "Fleet Feet"]):
		if source_slot == player.active_pokemon:
			return 300.0
		return 0.0  # 非前场不能用

	# 再起动 / Restart（梦幻ex）
	if source_name == MEW_EX and _has_any_ability(card_data, ["再起动", "Restart"]):
		if player.hand.size() <= 3:
			return 250.0
		return 100.0

	# 亮鳞 / Luminous Sign（霓虹鱼V）
	if source_name == LUMINEON_V and _has_any_ability(card_data, ["亮鳞", "Luminous Sign"]):
		return 350.0  # 搜支援者

	# 化危为吉 / Covert Flight（吉雉鸡ex）
	if source_name == KILOWATTREL_EX:
		return 200.0

	return 0.0


func _abs_play_trainer(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	var card: CardInstance = action.get("card")
	if card == null or card.card_data == null:
		return 0.0
	var tname: String = str(card.card_data.name)
	var bench_full: bool = player.bench.size() >= 5

	# 电气发生器 — 核心加速（牌库有雷能量时价值最高）
	if tname == ELECTRIC_GENERATOR or tname == "Electric Generator":
		if player.deck.is_empty():
			return 350.0
		var deck_lightning: int = _count_lightning_in_deck(player)
		if deck_lightning == 0:
			return 0.0  # 牌库没雷能量了，翻不出来
		if deck_lightning <= 2:
			return 300.0  # 燃料少，价值下降
		return 500.0

	# 老大的指令 — 拉弱目标 KO 拿奖品
	if tname == BOSSS_ORDERS:
		if _can_ko_bench_target(game_state, player, player_index):
			return 800.0
		if phase == "late":
			return 300.0  # 后期干扰
		return 200.0

	# 顶尖捕捉器 — 同老大但不占支援者，更灵活
	if tname == PRIME_CATCHER:
		if _can_ko_bench_target(game_state, player, player_index):
			return 800.0
		return 300.0

	# 派帕 — 搜物品+道具（决策链评估）
	if tname == PAIPA:
		return _abs_paipa(game_state, player, player_index, phase)

	# 暗码迷解读 — 手牌刷新（手牌质量评估）
	if tname == CRYPTO_DECODE:
		var hand_size: int = player.hand.size()
		if hand_size <= 2:
			return 400.0  # 手牌极少，急需刷新
		if hand_size <= 4:
			return 300.0
		return 150.0  # 手牌多时不急

	# 巢穴球 — 铺板（考虑核心缺口）
	if tname == NEST_BALL:
		if bench_full:
			return 0.0
		var essential: int = _count_essential_slots_needed(player)
		if essential >= 2 and phase == "early":
			return 350.0
		if essential >= 1:
			return 250.0
		return 150.0

	# 交替推车 — 换前场（评估换谁上来能不能 KO）
	if tname == SWITCH_CART:
		return _abs_switch_cart(game_state, player, player_index)

	# 沉重球 — 搜重撤退宝可梦
	if tname == HEAVY_BALL:
		if bench_full:
			return 0.0
		var essential: int = _count_essential_slots_needed(player)
		if essential >= 1:
			return 250.0
		return 150.0

	# 厉害钓竿 — 回收（看弃牌堆有没有好东西）
	if tname == SUPER_ROD:
		var has_attacker_in_discard: bool = _has_attacker_in_discard(game_state, player_index)
		if has_attacker_in_discard:
			return 250.0
		return 100.0

	# 放逐吸尘器 — 移除对手道具/场地
	if tname == LOST_VACUUM:
		if game_state.stadium_card != null:
			return 200.0  # 有场地可以移除
		return 100.0

	# 奇树（场地）— 搜基础宝可梦
	if tname == ARTAZON:
		if bench_full:
			return 30.0
		if phase == "early" and _count_essential_slots_needed(player) >= 1:
			return 300.0
		return 150.0

	# 星月（Serena）— 拉弱/弃牌抽牌
	if tname == SERENA:
		if _can_ko_bench_target(game_state, player, player_index):
			return 600.0
		return 200.0

	# 重力山（场地）— 减少撤退费
	if tname == GRAVITY_MOUNTAIN:
		# 铁臂膀ex 在场时重力山价值更高（撤退费4→2）
		if _count_pokemon_on_field(player, IRON_HANDS_EX) >= 1:
			return 300.0
		return 150.0

	return 50.0


func _abs_retreat(action: Dictionary, game_state: GameState, player: PlayerState, player_index: int) -> float:
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return 0.0
	var active_name: String = active.get_pokemon_name()
	var bench_target: PokemonSlot = action.get("bench_target")
	if bench_target == null:
		return 0.0
	var bench_name: String = bench_target.get_pokemon_name()

	# 前场是能攻击的攻击手 → 不撤退
	if active_name in ALL_ATTACKER_NAMES or active_name in NON_RULE_ATTACKER:
		if _can_slot_attack(active):
			return -200.0

	# 前场是引擎/辅助 + 后备有就绪攻击手 → 撤退
	if active_name in ENGINE_NAMES or active_name in SUPPORT_NAMES:
		if _can_slot_attack(bench_target) or bench_target.attached_energy.size() >= 1:
			return 350.0

	# 铁臂膀ex 撤退费4 → 极力避免手动撤退
	if active_name == IRON_HANDS_EX:
		return -100.0

	# 前场快被击倒
	if active.get_remaining_hp() < 40:
		return 200.0

	return 0.0


func _abs_attack(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var damage: int = int(action.get("projected_damage", 0))
	var player: PlayerState = game_state.players[player_index]
	var active: PokemonSlot = player.active_pokemon
	var active_name: String = active.get_pokemon_name() if active != null else ""
	if damage <= 0 and active != null:
		var cd: CardData = active.get_card_data()
		if cd != null:
			for attack: Dictionary in cd.attacks:
				var dmg: int = int(str(attack.get("damage", "0")).strip_edges())
				if dmg > damage:
					damage = dmg
	var opponent_index: int = 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 100.0 if damage > 0 else 0.0
	var defender: PokemonSlot = game_state.players[opponent_index].active_pokemon
	if defender == null:
		return 100.0 if damage > 0 else 0.0
	var defender_hp: int = defender.get_remaining_hp()
	var defender_data: CardData = defender.get_card_data()
	var defender_is_ex: bool = defender_data != null and (defender_data.mechanic == "ex" or defender_data.mechanic == "V")

	# --- 密勒顿ex 手酸：光子冲击 220 后下回合不能攻击 ---
	# 如果不能 KO，打 220 然后被动挨一回合是巨大风险
	if active_name == MIRAIDON_EX:
		if damage >= defender_hp:
			# 能 KO → 值得打（220 一击必杀 ex 最有价值）
			return 1000.0 if defender_is_ex else 800.0
		# 打不死 → 手酸惩罚（除非对手剩血很少，下回合换人收割）
		if defender_hp - damage <= 60:
			return 300.0 + float(damage)  # 打残了，队友能收割
		return 150.0  # 打不死又手酸，非常差

	# --- 铁臂膀ex：第二招 LCCC 120 + 多拿1奖品 ---
	# 检查是否在使用第二招（attack_index=1 且有4能量）
	var attack_index: int = int(action.get("attack_index", 0))
	if active_name == IRON_HANDS_EX and attack_index == 1:
		# 多拿奖品招式：KO 非规则拿2张，KO ex 拿3张
		if damage >= defender_hp:
			if defender_is_ex:
				return 1200.0  # 拿3张奖品！极高价值
			return 1000.0  # 非规则也拿2张
		return 250.0 + float(damage)  # 打不死价值一般

	# --- 雷丘V：弃全部雷能×60，一击毕命 ---
	# 只有在能 KO 时才值得用（否则弃能量白亏）
	if active_name == RAICHU_V:
		if damage >= defender_hp:
			return 1000.0 if defender_is_ex else 800.0
		# 打不死 = 弃掉所有能量还没收益，极差
		return 80.0

	# --- 通用攻击评估 ---
	if damage >= defender_hp:
		return 1000.0 if defender_is_ex else 800.0
	if damage > 0:
		return 300.0 + float(damage)
	return 0.0


# ============================================================
#  2. 局面评估（供 MCTS 叶节点使用）
# ============================================================

func evaluate_board(game_state: GameState, player_index: int) -> float:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var opponent_index: int = 1 - player_index
	var opponent: PlayerState = game_state.players[opponent_index] if opponent_index < game_state.players.size() else null
	var score: float = 0.0

	# 奖赏差 × 400
	if opponent != null:
		score += float(opponent.prizes.size() - player.prizes.size()) * 400.0

	# 密勒顿ex 在场（引擎启动）× 400
	score += float(_count_pokemon_on_field(player, MIRAIDON_EX)) * 400.0

	# 铁臂膀ex 在场 × 200
	score += float(_count_pokemon_on_field(player, IRON_HANDS_EX)) * 200.0

	# 就绪攻击手 × 300
	for slot: PokemonSlot in _get_all_slots(player):
		var sname: String = slot.get_pokemon_name()
		if sname in ALL_ATTACKER_NAMES or sname in NON_RULE_ATTACKER:
			if _can_slot_attack(slot):
				score += 300.0

	# 后备雷系宝可梦数 × 30
	for slot: PokemonSlot in player.bench:
		if slot != null:
			var cd: CardData = slot.get_card_data()
			if cd != null and str(cd.energy_type) == "L":
				score += 30.0

	# 场上总雷能量 × 40
	for slot: PokemonSlot in _get_all_slots(player):
		for e: CardInstance in slot.attached_energy:
			if e != null and e.card_data != null and str(e.card_data.energy_provides) == "L":
				score += 40.0

	# 牌库雷能量存量 × 10（电气发生器燃料）
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == "L":
			score += 10.0

	# --- 对手因子 ---
	if opponent != null:
		# 对手前场威胁：能打多少伤害
		var opp_active: PokemonSlot = opponent.active_pokemon
		if opp_active != null:
			var opp_cd: CardData = opp_active.get_card_data()
			if opp_cd != null:
				var opp_max_dmg: int = 0
				for attack: Dictionary in opp_cd.attacks:
					var dmg: int = int(str(attack.get("damage", "0")).strip_edges())
					if dmg > opp_max_dmg:
						opp_max_dmg = dmg
				# 对手能一击 KO 我方前场 → 负分
				if player.active_pokemon != null and opp_max_dmg >= player.active_pokemon.get_remaining_hp():
					score -= 150.0

		# 对手就绪攻击手数量（后备有能量的）
		var opp_ready: int = 0
		for opp_slot: PokemonSlot in opponent.bench:
			if opp_slot != null and opp_slot.attached_energy.size() >= 2:
				opp_ready += 1
		score -= float(opp_ready) * 50.0

		# 对手最弱后备（我方有机会 KO 的目标）
		var weakest_opp_bench_hp: int = 999
		for opp_slot: PokemonSlot in opponent.bench:
			if opp_slot == null:
				continue
			var hp: int = opp_slot.get_remaining_hp()
			if hp < weakest_opp_bench_hp:
				weakest_opp_bench_hp = hp
		if weakest_opp_bench_hp < 120:
			score += 80.0  # 有弱目标可以狙

	return score


# ============================================================
#  3. 动作评分（兼容 AIHeuristics 叠加机制）
# ============================================================

func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var abs_score: float = score_action_absolute(action, game_state, player_index)
	var base_estimate: float = _estimate_heuristic_base(str(action.get("kind", "")))
	return abs_score - base_estimate


# ============================================================
#  4. MCTS 配置
# ============================================================

func get_mcts_config() -> Dictionary:
	return {
		"branch_factor": 3,
		"max_actions_per_turn": 8,
		"rollouts_per_sequence": 0,
		"time_budget_ms": 3000,
	}


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

	# 前场选择：铁臂膀ex > 闪电鸟 > 雷丘V > 雷公V > 月月熊
	# 绝不把密勒顿ex 放前场
	var active_index: int = -1
	for b: Dictionary in basics:
		var bname: String = str(b["name"])
		if bname == MIRAIDON_EX:
			continue  # 密勒顿必须后备
		if bname == MEW_EX or bname == LUMINEON_V:
			continue  # 辅助不上前场
		active_index = int(b["index"])
		break
	if active_index == -1:
		active_index = int(basics[0]["index"])

	# 后备：密勒顿ex 最高，其余按分数
	var bench_indices: Array[int] = []
	for b: Dictionary in basics:
		if int(b["index"]) == active_index:
			continue
		bench_indices.append(int(b["index"]))
		if bench_indices.size() >= 5:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func _get_setup_priority(pokemon_name: String) -> int:
	match pokemon_name:
		IRON_HANDS_EX: return 95
		ZAPDOS: return 90
		RAICHU_V: return 85
		RAIKOU_V: return 80
		URSALUNA_EX: return 75
		SQUAWKABILLY_EX: return 70
		MIRAIDON_EX: return 65  # 后备最高但不上前场
		KILOWATTREL_EX: return 50
		MEW_EX: return 40
		LUMINEON_V: return 35
		RADIANT_GRENINJA: return 30
		_: return 20


# ============================================================
#  6. 弃牌偏好
# ============================================================

func get_discard_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var cname: String = str(card.card_data.name)
	var card_type: String = str(card.card_data.card_type)
	# 多余的辅助宝可梦优先弃
	if cname in SUPPORT_NAMES:
		return 200
	if card_type == "Basic Energy":
		return 100
	if card_type == "Item" or card_type == "Tool":
		return 80
	# 核心宝可梦不弃
	if cname in ALL_ATTACKER_NAMES or cname in ENGINE_NAMES:
		return 5
	return 50


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	if card == null or card.card_data == null:
		return 0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return get_discard_priority(card)
	var player: PlayerState = game_state.players[player_index]
	var cname: String = str(card.card_data.name)
	var card_type: String = str(card.card_data.card_type)
	var bench_full: bool = player.bench.size() >= 5

	# --- 弃了反而有收益 / 无损失的牌 ---
	# 多余辅助宝可梦（场上已有同名）
	if cname in SUPPORT_NAMES and _count_pokemon_on_field(player, cname) >= 1:
		return 220
	# 满板时搜索球/巢穴球无法使用
	if bench_full and (cname == NEST_BALL or cname == HEAVY_BALL):
		return 200
	# 多余的密勒顿ex（场上已有2只）
	if cname == MIRAIDON_EX and _count_pokemon_on_field(player, MIRAIDON_EX) >= 2:
		return 180
	# 辅助宝可梦（不急需）
	if cname in SUPPORT_NAMES:
		return 150

	# --- 能量 ---
	if card_type == "Basic Energy":
		# 雷能量是电气发生器的燃料，但手里太多也没用
		var hand_lightning: int = 0
		for c: CardInstance in player.hand:
			if c != null and c.card_data != null and c.card_data.is_energy() and str(c.card_data.energy_provides) == "L":
				hand_lightning += 1
		if hand_lightning >= 4:
			return 130  # 手里雷能量过多，可以弃一些
		return 80  # 保留给手贴

	# --- 道具/工具 ---
	if card_type == "Item" or card_type == "Tool":
		# 电气发生器是核心，不轻易弃
		if cname == ELECTRIC_GENERATOR:
			return 10
		# 搜索型保留
		if cname == NEST_BALL or cname == HEAVY_BALL:
			return 30 if not bench_full else 180
		return 90

	# --- 支援者 ---
	if card_type == "Supporter":
		# 手少时支援者更珍贵
		var hand_size: int = player.hand.size()
		if hand_size <= 3:
			return 5
		if cname == BOSSS_ORDERS or cname == PRIME_CATCHER:
			return 10  # 进攻关键牌
		return 30

	# --- 核心宝可梦 ---
	if cname in ALL_ATTACKER_NAMES or cname in ENGINE_NAMES:
		return 5

	return 50


func get_search_priority(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 0
	var cname: String = str(card.card_data.name)
	for i: int in BENCH_PRIORITY_NAMES.size():
		if cname == BENCH_PRIORITY_NAMES[i]:
			return 100 - i * 8
	return 10


# ============================================================
#  辅助函数
# ============================================================

func _detect_game_phase(turn: int, player: PlayerState) -> String:
	# 早期：前2回合，或引擎（密勒顿ex）还没上板
	if turn <= 2:
		return "early"
	if _count_pokemon_on_field(player, MIRAIDON_EX) == 0:
		return "early"  # 引擎未就位，仍在展开
	# 后期：有就绪攻击手且回合数>=5
	var has_ready_attacker: bool = false
	for slot: PokemonSlot in _get_all_slots(player):
		var sname: String = slot.get_pokemon_name()
		if (sname in ALL_ATTACKER_NAMES or sname in NON_RULE_ATTACKER) and _can_slot_attack(slot):
			has_ready_attacker = true
			break
	if has_ready_attacker and turn >= 5:
		return "late"
	return "mid"


func _estimate_heuristic_base(kind: String) -> float:
	match kind:
		"attack": return 500.0
		"granted_attack": return 500.0
		"attach_energy": return 220.0
		"play_basic_to_bench": return 180.0
		"use_ability": return 160.0
		"play_trainer": return 110.0
		"retreat": return 90.0
		"end_turn": return 0.0
	return 10.0


func _count_pokemon_on_field(player: PlayerState, pokemon_name: String) -> int:
	var count: int = 0
	if player.active_pokemon != null and player.active_pokemon.get_pokemon_name() == pokemon_name:
		count += 1
	for slot: PokemonSlot in player.bench:
		if slot != null and slot.get_top_card() != null and slot.get_pokemon_name() == pokemon_name:
			count += 1
	return count


func _get_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _get_retreat_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 999
	var retreat_cost: int = int(slot.get_card_data().retreat_cost)
	var attached: int = slot.attached_energy.size()
	return maxi(0, retreat_cost - attached)


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


func _can_slot_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_top_card() == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null or cd.attacks.is_empty():
		return false
	var attached: int = slot.attached_energy.size()
	for attack: Dictionary in cd.attacks:
		var cost: String = str(attack.get("cost", ""))
		if attached >= cost.length():
			return true
	return false


func _hand_has_energy_type(player: PlayerState, etype: String) -> bool:
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == etype:
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


func _abs_paipa(game_state: GameState, player: PlayerState, player_index: int, phase: String) -> float:
	## 派帕决策链：搜 1 物品 + 1 道具
	var deck_has_eg: bool = false
	var deck_has_nest: bool = false
	var deck_has_heavy: bool = false
	var deck_has_rod: bool = false
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		var cname: String = str(card.card_data.name)
		if cname == ELECTRIC_GENERATOR: deck_has_eg = true
		elif cname == NEST_BALL: deck_has_nest = true
		elif cname == HEAVY_BALL: deck_has_heavy = true
		elif cname == SUPER_ROD: deck_has_rod = true

	var best_item: float = 50.0
	# 电气发生器是最高价值物品
	if deck_has_eg and _count_lightning_in_deck(player) > 0:
		best_item = maxf(best_item, 250.0)
	# 巢穴球/沉重球（板位有空）
	if (deck_has_nest or deck_has_heavy) and player.bench.size() < 5:
		best_item = maxf(best_item, 150.0)
	# 厉害钓竿
	if deck_has_rod and _has_attacker_in_discard(game_state, player_index):
		best_item = maxf(best_item, 120.0)

	# 道具价值
	var best_tool: float = 30.0
	var deck_has_baton: bool = false
	var deck_has_board: bool = false
	var deck_has_charm: bool = false
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		var cname: String = str(card.card_data.name)
		if cname == HEAVY_BATON: deck_has_baton = true
		elif cname == EMERGENCY_BOARD: deck_has_board = true
		elif cname == BRAVERY_CHARM: deck_has_charm = true
	if deck_has_baton and _count_pokemon_on_field(player, IRON_HANDS_EX) >= 1:
		best_tool = maxf(best_tool, 150.0)
	if deck_has_board:
		best_tool = maxf(best_tool, 80.0)
	if deck_has_charm:
		best_tool = maxf(best_tool, 60.0)

	return maxf(best_item + best_tool, 200.0) if phase != "late" else maxf((best_item + best_tool) * 0.7, 150.0)


func _abs_switch_cart(game_state: GameState, player: PlayerState, player_index: int) -> float:
	## 交替推车：评估换谁上前场能打多少伤害
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return 100.0
	var active_name: String = active.get_pokemon_name()

	# 前场已是能攻击的攻击手 → 不急着换
	if (active_name in ALL_ATTACKER_NAMES or active_name in NON_RULE_ATTACKER) and _can_slot_attack(active):
		return 50.0

	# 找后备最优攻击手
	var opponent_index: int = 1 - player_index
	var opp_hp: int = 999
	if opponent_index >= 0 and opponent_index < game_state.players.size():
		var opp_active: PokemonSlot = game_state.players[opponent_index].active_pokemon
		if opp_active != null:
			opp_hp = opp_active.get_remaining_hp()

	var best_bench_score: float = 0.0
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		var pred: Dictionary = predict_attacker_damage(slot)
		var dmg: int = int(pred.get("damage", 0))
		var can_atk: bool = bool(pred.get("can_attack", false))
		if can_atk and dmg >= opp_hp:
			best_bench_score = maxf(best_bench_score, 600.0)  # 换上来能 KO
		elif can_atk and dmg > 0:
			best_bench_score = maxf(best_bench_score, 350.0)  # 换上来能打伤害
		elif slot.attached_energy.size() >= 1:
			best_bench_score = maxf(best_bench_score, 200.0)  # 有能量

	# 前场是引擎/辅助时额外加分
	if active_name in ENGINE_NAMES or active_name in SUPPORT_NAMES:
		best_bench_score += 50.0

	return maxf(best_bench_score, 100.0)


func _count_lightning_basics_in_deck(player: PlayerState) -> int:
	## 牌库中雷属性基础宝可梦数（串联装置的搜索目标）
	var count: int = 0
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null \
			and card.card_data.card_type == "Pokemon" \
			and str(card.card_data.stage) == "Basic" \
			and str(card.card_data.energy_type) == "L":
			count += 1
	return count


func _count_lightning_in_deck(player: PlayerState) -> int:
	var count: int = 0
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and card.card_data.is_energy() and str(card.card_data.energy_provides) == "L":
			count += 1
	return count


func _has_attacker_in_discard(game_state: GameState, player_index: int) -> bool:
	if player_index < 0 or player_index >= game_state.players.size():
		return false
	for card: CardInstance in game_state.players[player_index].discard_pile:
		if card != null and card.card_data != null:
			var cname: String = str(card.card_data.name)
			if cname in ALL_ATTACKER_NAMES or cname in NON_RULE_ATTACKER:
				return true
	return false


func _count_essential_slots_needed(player: PlayerState) -> int:
	## 核心阵容还差几个板位
	## 目标：1× 密勒顿ex + 1× 铁臂膀ex + 2× 副攻手（闪电鸟/雷公V/雷丘V）
	var needed: int = 0
	if _count_pokemon_on_field(player, MIRAIDON_EX) == 0:
		needed += 1
	if _count_pokemon_on_field(player, IRON_HANDS_EX) == 0:
		needed += 1
	var sub_attacker_count: int = 0
	for slot: PokemonSlot in _get_all_slots(player):
		var sname: String = slot.get_pokemon_name()
		if sname in SUB_ATTACKER_NAMES:
			sub_attacker_count += 1
	needed += maxi(0, 1 - sub_attacker_count)  # 至少1只副攻手
	return needed


func _is_essential_pokemon(pname: String, player: PlayerState) -> bool:
	if pname == MIRAIDON_EX:
		return _count_pokemon_on_field(player, MIRAIDON_EX) == 0
	if pname == IRON_HANDS_EX:
		return _count_pokemon_on_field(player, IRON_HANDS_EX) == 0
	if pname in SUB_ATTACKER_NAMES:
		var sub_count: int = 0
		for slot: PokemonSlot in _get_all_slots(player):
			if slot.get_pokemon_name() in SUB_ATTACKER_NAMES:
				sub_count += 1
		return sub_count < 1
	return false


func _has_better_energy_target(player: PlayerState, exclude_slot: PokemonSlot) -> bool:
	## 检查是否有比 exclude_slot 更需要能量的攻击手
	for slot: PokemonSlot in _get_all_slots(player):
		if slot == exclude_slot:
			continue
		var sname: String = slot.get_pokemon_name()
		# 排除密勒顿自身和辅助型
		if sname == MIRAIDON_EX or sname in SUPPORT_NAMES:
			continue
		if sname in ALL_ATTACKER_NAMES or sname in NON_RULE_ATTACKER:
			var gap: int = _get_attack_energy_gap(slot)
			if gap > 0:
				return true  # 这个攻击手还需要能量
	return false


func _has_ready_attacker_on_bench(player: PlayerState) -> bool:
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		var sname: String = slot.get_pokemon_name()
		if sname in ALL_ATTACKER_NAMES or sname in NON_RULE_ATTACKER:
			if _can_slot_attack(slot) or slot.attached_energy.size() >= 1:
				return true
	return false


func _can_ko_bench_target(game_state: GameState, player: PlayerState, player_index: int) -> bool:
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return false
	var my_damage: int = 0
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


# ============================================================
#  7. 交互目标评分（供 AIStepResolver 调用）
# ============================================================

func score_interaction_target(item: Variant, step: Dictionary, _context: Dictionary = {}) -> float:
	## 为交互步骤中的候选目标打分（搜索目标、贴能目标等）。
	## item 可能是 CardInstance（搜索结果）或 PokemonSlot（贴能目标）。
	## 高分 = 优先选择。

	# --- CardInstance: 搜索宝可梦/道具选择 ---
	if item is CardInstance:
		var card: CardInstance = item as CardInstance
		if card.card_data == null:
			return 0.0
		var cname: String = str(card.card_data.name)
		var card_type: String = str(card.card_data.card_type)

		# 宝可梦搜索优先级（串联装置/巢穴球/沉重球）
		if card_type == "Pokemon":
			return _score_search_pokemon(cname)

		# 物品搜索（派帕等）
		if card_type == "Item":
			if cname == ELECTRIC_GENERATOR or cname == "Electric Generator": return 500.0
			if cname == NEST_BALL or cname == "Nest Ball": return 300.0
			if cname == SWITCH_CART: return 250.0
			if cname == HEAVY_BALL or cname == "Heavy Ball": return 200.0
			if cname == SUPER_ROD: return 150.0
			return 100.0

		# 道具搜索
		if card_type == "Tool":
			if cname == HEAVY_BATON: return 300.0
			if cname == EMERGENCY_BOARD: return 250.0
			if cname == BRAVERY_CHARM: return 200.0
			if cname == FOREST_SEAL_STONE: return 150.0
			return 100.0

		# 能量
		if card.card_data.is_energy():
			if str(card.card_data.energy_provides) == "L":
				return 200.0
			return 50.0

		return 50.0

	# --- PokemonSlot: 贴能目标选择（电气发生器等）---
	if item is PokemonSlot:
		var slot: PokemonSlot = item as PokemonSlot
		return _score_energy_attach_target(slot)

	return 0.0


func _score_search_pokemon(cname: String) -> float:
	## 串联装置/巢穴球搜索宝可梦优先级
	## 前期核心：铁臂膀ex > 雷公V > 闪电鸟 > 密勒顿ex(第2只)
	## 不搜：雷丘V（前中期不拍）、辅助型（低优先）
	if cname == IRON_HANDS_EX: return 500.0  # 主攻手，必搜
	if cname == RAIKOU_V: return 450.0       # 前期灵活打手
	if cname == ZAPDOS: return 400.0         # buff + 副攻
	if cname == MIRAIDON_EX: return 350.0    # 第2只引擎
	if cname == URSALUNA_EX: return 200.0    # 后期非规则
	if cname == SQUAWKABILLY_EX: return 180.0
	if cname == KILOWATTREL_EX: return 150.0
	if cname == MEW_EX: return 120.0
	if cname == LUMINEON_V: return 100.0
	if cname == RADIANT_GRENINJA: return 80.0
	# 雷丘V — 终结者，前中期不搜
	if cname == RAICHU_V: return 50.0
	return 50.0


func _score_energy_attach_target(slot: PokemonSlot) -> float:
	## 电气发生器贴能目标优先级
	## 原则：需要能量打伤害的攻击手 > 已满的 > 引擎/辅助
	if slot == null or slot.get_top_card() == null:
		return 0.0
	var sname: String = slot.get_pokemon_name()
	var gap: int = _get_attack_energy_gap(slot)

	# 雷公V — 前期最灵活，LC=2能，差1能打100+
	if sname == RAIKOU_V:
		if gap == 1: return 600.0   # 贴1能就能打！
		if gap > 1: return 400.0
		return 50.0                  # 已满

	# 铁臂膀ex — 主攻手 LLC=160
	if sname == IRON_HANDS_EX:
		if gap == 1: return 550.0
		if gap == 2: return 400.0
		if gap == 0:
			# 已能用第一招，继续贴解锁第二招（LCCC 多拿奖品）
			var total: int = slot.attached_energy.size()
			if total < 4: return 200.0
			return 30.0              # 4能已满
		return 350.0

	# 闪电鸟 — buff + 副攻 LLC=110
	if sname == ZAPDOS:
		if gap == 1: return 500.0
		if gap > 1: return 300.0
		return 30.0

	# 密勒顿ex — 引擎，一般不贴能给它（电枪只贴后备）
	if sname == MIRAIDON_EX:
		return 10.0  # 极低优先

	# 雷丘V — 终结者，前中期不贴
	if sname == RAICHU_V:
		return 20.0  # 极低

	# 月月熊·赫月ex
	if sname == URSALUNA_EX:
		if gap == 1: return 350.0
		if gap > 1: return 200.0
		return 30.0

	# 辅助型/其他
	return 10.0


## 预测攻击手伤害（兼容接口）
func predict_attacker_damage(slot: PokemonSlot, extra_energy: int = 0) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var cd: CardData = slot.get_card_data()
	if cd == null or cd.attacks.is_empty():
		return {"damage": 0, "can_attack": false, "description": ""}
	var attached: int = slot.attached_energy.size() + extra_energy
	var best_dmg: int = 0
	var can_attack: bool = false
	for attack: Dictionary in cd.attacks:
		var cost: String = str(attack.get("cost", ""))
		var dmg: int = int(str(attack.get("damage", "0")).strip_edges())
		if attached >= cost.length():
			can_attack = true
			if dmg > best_dmg:
				best_dmg = dmg
	return {"damage": best_dmg, "can_attack": can_attack, "description": ""}
