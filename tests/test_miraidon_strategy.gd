## 密勒顿卡组 AI 策略单元测试
class_name TestMiraidonStrategy
extends TestBase

const DeckStrategyMiraidonScript = preload("res://scripts/ai/DeckStrategyMiraidon.gd")
const MiraidonStateEncoderScript = preload("res://scripts/ai/MiraidonStateEncoder.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const MIRAIDON_BASELINE_SCRIPT_PATH := "res://scripts/ai/DeckStrategyMiraidonBaseline.gd"


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	return DeckStrategyMiraidonScript.new()


# -- 辅助函数 --

func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "L",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = [],
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	cd.abilities.clear()
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy_cd(pname: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = card_type
	return cd


func _make_tool_cd(pname: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Tool"
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_player(pi: int = 0) -> PlayerState:
	var p := PlayerState.new()
	p.player_index = pi
	return p


func _make_game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := _make_player(pi)
		p.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi, "Basic", "C"), pi)
		gs.players.append(p)
	return gs


func _ctx(gs: GameState, pi: int = 0) -> Dictionary:
	return {"game_state": gs, "player_index": pi}


# ============================================================
#  开局规划测试
# ============================================================

func test_setup_miraidon_bench_not_active() -> String:
	## 密勒顿ex 优先上后备不上前场
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex",
		[{"name": "串联装置", "text": "搜雷系基础宝可梦"}],
		[{"name": "光子冲击", "cost": "LLC", "damage": "220"}]), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	return assert_eq(active_name, "铁臂膀ex", "密勒顿ex 不应上前场，应选铁臂膀ex")


func test_setup_iron_hands_active() -> String:
	## 铁臂膀优先上前场
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("闪电鸟", "Basic", "L", 120), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex"), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	return assert_eq(active_name, "铁臂膀ex", "铁臂膀ex 应优先上前场")


func test_setup_mew_ex_active_for_raikou_opening() -> String:
	## 指定开局：梦幻ex 站前，雷公V/密勒顿ex 落后
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("梦幻ex", "Basic", "P", 180, "", "ex",
		[{"name": "再起动"}], [], 0), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex",
		[{"name": "串联装置"}], [{"name": "光子冲击", "cost": "LLC", "damage": "220"}]), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0))
	var s := _new_strategy()
	var choice: Dictionary = s.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	var bench_names: Array[String] = []
	for hand_index: int in choice.get("bench_hand_indices", []):
		bench_names.append(str(player.hand[hand_index].card_data.name))
	return run_checks([
		assert_eq(active_name, "梦幻ex", "梦幻ex 应优先作为前场起手"),
		assert_true("雷公V" in bench_names, "雷公V 应在开局一起落到后场"),
		assert_true("密勒顿ex" in bench_names, "密勒顿ex 应保留在后场准备开特性"),
	])


# ============================================================
#  动作评分测试
# ============================================================

func test_score_electric_generator_high() -> String:
	## 电气发生器 >= 500（牌库有雷能量时）
	var gs := _make_game_state()
	# 牌库放入雷能量（电气发生器的翻牌目标）
	for i: int in 5:
		gs.players[0].deck.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("电气发生器"), 0)},
		gs, 0
	)
	return assert_true(score >= 500.0, "电气发生器绝对分应 >= 500 (got %f)" % score)


func test_score_attach_lightning_attacker() -> String:
	## 雷能贴给差1能攻击手最高
	var gs := _make_game_state(3)
	var iron_hands_cd := _make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4)
	var iron_slot := _make_slot(iron_hands_cd, 0)
	# 已有2能量，差1能攻击（LLC=3能）
	iron_slot.attached_energy.append(CardInstance.create(_make_energy_cd("雷能量", "L"), 0))
	iron_slot.attached_energy.append(CardInstance.create(_make_energy_cd("雷能量", "L"), 0))
	gs.players[0].bench.append(iron_slot)
	var s := _new_strategy()
	var lightning := CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0)
	var score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": lightning, "target_slot": iron_slot},
		gs, 0
	)
	return assert_true(score >= 400.0, "差1能攻击手贴雷能应 >= 400 (got %f)" % score)


func test_score_tandem_unit_high() -> String:
	## 串联装置 >= 500（牌库有雷系基础宝可梦时）
	var gs := _make_game_state(2)
	var miraidon_cd := _make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex",
		[{"name": "串联装置", "text": "搜雷系基础宝可梦"}],
		[{"name": "光子冲击", "cost": "LLC", "damage": "220"}])
	var miraidon_slot := _make_slot(miraidon_cd, 0)
	gs.players[0].bench.append(miraidon_slot)
	# 牌库放入雷系基础宝可梦（串联装置的搜索目标）
	gs.players[0].deck.append(CardInstance.create(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex"), 0))
	gs.players[0].deck.append(CardInstance.create(_make_pokemon_cd("闪电鸟", "Basic", "L", 120), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": miraidon_slot, "ability_index": 0},
		gs, 0
	)
	return assert_true(score >= 500.0, "串联装置绝对分应 >= 500 (got %f)" % score)


func test_nest_ball_prefers_miraidon_before_engine_online() -> String:
	## 首个巢穴球先找密勒顿ex，而不是直接找铁臂膀ex
	var gs := _make_game_state(2)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("梦幻ex", "Basic", "P", 180, "", "ex",
		[{"name": "再起动"}], [], 0), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0))
	var miraidon := CardInstance.create(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex",
		[{"name": "串联装置"}], [{"name": "光子冲击", "cost": "LLC", "damage": "220"}]), 0)
	var iron_hands := CardInstance.create(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0)
	var step := {"id": "basic_pokemon", "title": "选择 1 张基础宝可梦放入备战区"}
	var s := _new_strategy()
	var miraidon_score: float = s.score_interaction_target(miraidon, step, _ctx(gs))
	var iron_hands_score: float = s.score_interaction_target(iron_hands, step, _ctx(gs))
	return assert_true(
		miraidon_score > iron_hands_score,
		"首个巢穴球应优先找密勒顿ex（miraidon=%f iron_hands=%f）" % [miraidon_score, iron_hands_score]
	)


func test_tandem_unit_prefers_iron_hands_after_miraidon_lands() -> String:
	## 密勒顿特性展开时优先补铁臂膀ex
	var gs := _make_game_state(2)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("梦幻ex", "Basic", "P", 180, "", "ex",
		[{"name": "再起动"}], [], 0), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0))
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex",
		[{"name": "串联装置"}], [{"name": "光子冲击", "cost": "LLC", "damage": "220"}]), 0))
	var iron_hands := CardInstance.create(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0)
	var zapdos := CardInstance.create(_make_pokemon_cd("闪电鸟", "Basic", "L", 120), 0)
	var step := {"id": "bench_pokemon", "title": "选择最多2只放入备战区的宝可梦"}
	var s := _new_strategy()
	var iron_hands_score: float = s.score_interaction_target(iron_hands, step, _ctx(gs))
	var zapdos_score: float = s.score_interaction_target(zapdos, step, _ctx(gs))
	return assert_true(
		iron_hands_score > zapdos_score,
		"串联装置应优先补铁臂膀ex（iron_hands=%f zapdos=%f）" % [iron_hands_score, zapdos_score]
	)


func test_nest_ball_prefers_squawk_after_core_shell_is_online() -> String:
	## 在雷公/密勒顿/铁臂膀都到位后，第二个巢穴球转而补怒鹦哥ex
	var gs := _make_game_state(2)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("梦幻ex", "Basic", "P", 180, "", "ex",
		[{"name": "再起动"}], [], 0), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0))
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex",
		[{"name": "串联装置"}], [{"name": "光子冲击", "cost": "LLC", "damage": "220"}]), 0))
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0))
	var squawk := CardInstance.create(_make_pokemon_cd("怒鹦哥ex", "Basic", "C", 160, "", "ex",
		[{"name": "Squawk and Seize"}]), 0)
	var zapdos := CardInstance.create(_make_pokemon_cd("闪电鸟", "Basic", "L", 120), 0)
	var step := {"id": "basic_pokemon", "title": "选择 1 张基础宝可梦放入备战区"}
	var s := _new_strategy()
	var squawk_score: float = s.score_interaction_target(squawk, step, _ctx(gs))
	var zapdos_score: float = s.score_interaction_target(zapdos, step, _ctx(gs))
	return assert_true(
		squawk_score > zapdos_score,
		"第二个巢穴球应优先补怒鹦哥ex（squawk=%f zapdos=%f）" % [squawk_score, zapdos_score]
	)


func test_opening_prefers_nest_ball_over_generator_before_miraidon() -> String:
	## 开局没落下密勒顿之前，应先铺板再开电枪
	var gs := _make_game_state(2)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("梦幻ex", "Basic", "P", 180, "", "ex",
		[{"name": "再起动"}], [], 0), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0))
	for i: int in 5:
		gs.players[0].deck.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	var s := _new_strategy()
	var nest_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("巢穴球"), 0)},
		gs, 0
	)
	var generator_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("电气发生器"), 0)},
		gs, 0
	)
	return assert_true(
		nest_score > generator_score,
		"开局没密勒顿时，巢穴球应先于电枪（nest=%f generator=%f）" % [nest_score, generator_score]
	)


func test_opening_dte_on_raichu_stays_negative_before_engine_online() -> String:
	## 引擎还没落地时，不应把双重涡轮先塞给前场雷丘
	var gs := _make_game_state(1)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("雷丘V", "Basic", "L", 200, "", "V", [],
		[{"name": "雷电突袭", "cost": "LL", "damage": "60"}], 1), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0))
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("闪电鸟", "Basic", "L", 120, "", "", [],
		[{"name": "雷鸣翼击", "cost": "LLC", "damage": "110"}], 1), 0))
	var s := _new_strategy()
	var dte_score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("双重涡轮能量", "C"), 0),
			"target_slot": gs.players[0].active_pokemon
		},
		gs, 0
	)
	return assert_true(
		dte_score < 0.0,
		"引擎未落地时，前场雷丘的 DTE 不应是正分（dte=%f）" % dte_score
	)


func test_late_nest_ball_stays_low_when_no_searchable_attacker_remains() -> String:
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("双重涡轮能量", "C"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex"), 0))
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_pokemon_cd("梦幻ex", "Basic", "P", 180, "", "ex",
		[{"name": "Restart"}], [], 0), 0))
	var s := _new_strategy()
	var nest_ball_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("巢穴球"), 0)},
		gs, 0
	)
	return assert_true(
		nest_ball_score < 100.0,
		"Late Nest Ball should stay low when only support targets remain in deck (nest_ball=%f)" % nest_ball_score
	)


func test_late_forest_seal_stone_on_mew_stays_low_with_ready_attacker() -> String:
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("双重涡轮能量", "C"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex"), 0))
	var mew := _make_slot(_make_pokemon_cd("梦幻ex", "Basic", "P", 180, "", "ex",
		[{"name": "Restart"}], [], 0), 0)
	player.bench.append(mew)
	var s := _new_strategy()
	var stone_score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_tool_cd("森林封印石"), 0),
			"target_slot": mew
		},
		gs, 0
	)
	return assert_true(
		stone_score < 120.0,
		"Late Forest Seal Stone on Mew ex should stay low once a ready attacker exists (stone=%f)" % stone_score
	)


func test_retreat_mew_into_ready_raikou_before_squawk() -> String:
	## 雷公已经就绪时，梦幻应先撤到雷公，不该先开怒鹦哥
	var gs := _make_game_state(2)
	var mew := _make_slot(_make_pokemon_cd("梦幻ex", "Basic", "P", 180, "", "ex",
		[{"name": "再起动"}], [], 0), 0)
	var raikou := _make_slot(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0)
	raikou.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	raikou.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	var squawk := _make_slot(_make_pokemon_cd("怒鹦哥ex", "Basic", "C", 160, "", "ex",
		[{"name": "Squawk and Seize"}]), 0)
	gs.players[0].active_pokemon = mew
	gs.players[0].bench.append(raikou)
	gs.players[0].bench.append(squawk)
	var s := _new_strategy()
	var retreat_score: float = s.score_action_absolute(
		{"kind": "retreat", "bench_target": raikou},
		gs, 0
	)
	var squawk_score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": squawk, "ability_index": 0},
		gs, 0
	)
	return assert_true(
		retreat_score > squawk_score,
		"梦幻应先退到可攻击的雷公（retreat=%f squawk=%f）" % [retreat_score, squawk_score]
	)


func test_fleet_feet_scores_above_squawk_when_raikou_is_active() -> String:
	## 雷公上前后，Fleet Feet 应先于怒鹦哥
	var gs := _make_game_state(2)
	var raikou := _make_slot(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0)
	var squawk := _make_slot(_make_pokemon_cd("怒鹦哥ex", "Basic", "C", 160, "", "ex",
		[{"name": "Squawk and Seize"}]), 0)
	var iron_hands := _make_slot(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0)
	gs.players[0].active_pokemon = raikou
	gs.players[0].bench.append(squawk)
	gs.players[0].bench.append(iron_hands)
	var s := _new_strategy()
	var fleet_feet_score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": raikou, "ability_index": 0},
		gs, 0
	)
	var squawk_score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": squawk, "ability_index": 0},
		gs, 0
	)
	return assert_true(
		fleet_feet_score > squawk_score,
		"雷公上前后应先用 Fleet Feet（fleet=%f squawk=%f）" % [fleet_feet_score, squawk_score]
	)


func test_handoff_target_prefers_ready_raikou_for_send_out_over_unready_iron_hands() -> String:
	## send_out 应优先把已经能打的雷公送上前场，而不是把差 1 能的铁臂膀当成“贴能目标”
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Knocked Out Lead", "Basic", "C", 60), 0)
	player.bench.clear()
	var raikou := _make_slot(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0)
	raikou.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	raikou.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	var iron_hands := _make_slot(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0)
	iron_hands.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	iron_hands.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	player.bench.append(raikou)
	player.bench.append(iron_hands)
	var s := _new_strategy()
	var raikou_score: float = s.score_handoff_target(raikou, {"id": "send_out"}, _ctx(gs))
	var iron_hands_score: float = s.score_handoff_target(iron_hands, {"id": "send_out"}, _ctx(gs))
	return assert_true(
		raikou_score > iron_hands_score,
		"send_out 应优先 ready 雷公而不是差 1 能的铁臂膀（raikou=%f iron_hands=%f）" % [raikou_score, iron_hands_score]
	)


func test_handoff_target_prefers_ready_raikou_for_self_switch_over_unready_iron_hands() -> String:
	## self_switch_target 应把换前的所有权给 ready attacker，而不是延续“谁更适合贴能”
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("梦幻ex", "Basic", "P", 180, "", "ex",
		[{"name": "再起动"}], [], 0), 0)
	player.bench.clear()
	var raikou := _make_slot(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0)
	raikou.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	raikou.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	var iron_hands := _make_slot(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex", [],
		[{"name": "猛击", "cost": "LLC", "damage": "160"}], 4), 0)
	iron_hands.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	iron_hands.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	player.bench.append(raikou)
	player.bench.append(iron_hands)
	var s := _new_strategy()
	var raikou_score: float = s.score_handoff_target(raikou, {"id": "self_switch_target"}, _ctx(gs))
	var iron_hands_score: float = s.score_handoff_target(iron_hands, {"id": "self_switch_target"}, _ctx(gs))
	return assert_true(
		raikou_score > iron_hands_score,
		"self_switch_target 应优先 ready 雷公而不是差 1 能的铁臂膀（raikou=%f iron_hands=%f）" % [raikou_score, iron_hands_score]
	)


func test_retreat_unready_raichu_into_ready_raikou_before_building_zapdos() -> String:
	## 当前场是打不了的攻击手时，应先退到 ready 雷公，而不是继续手贴后排闪电鸟
	var gs := _make_game_state(5)
	var raichu := _make_slot(_make_pokemon_cd("雷丘V", "Basic", "L", 200, "", "V", [],
		[{"name": "雷电突袭", "cost": "LL", "damage": "60"}], 1), 0)
	raichu.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	var raikou := _make_slot(_make_pokemon_cd("雷公V", "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "雷鸣轰击", "cost": "LC", "damage": "20"}], 1), 0)
	raikou.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	raikou.attached_energy.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	var zapdos := _make_slot(_make_pokemon_cd("闪电鸟", "Basic", "L", 120, "", "", [],
		[{"name": "雷鸣翼击", "cost": "LLC", "damage": "110"}], 1), 0)
	gs.players[0].active_pokemon = raichu
	gs.players[0].bench.append(raikou)
	gs.players[0].bench.append(zapdos)
	var s := _new_strategy()
	var retreat_score: float = s.score_action_absolute(
		{"kind": "retreat", "bench_target": raikou},
		gs, 0
	)
	var attach_score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0),
			"target_slot": zapdos
		},
		gs, 0
	)
	return assert_true(
		retreat_score > attach_score,
		"打不了的雷丘应先退到 ready 雷公，而不是继续养闪电鸟（retreat=%f attach=%f）" % [retreat_score, attach_score]
	)


func test_evaluate_board_engine_active() -> String:
	## 密勒顿ex 在场得分高
	var gs := _make_game_state(3)
	var miraidon_cd := _make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex")
	gs.players[0].bench.append(_make_slot(miraidon_cd, 0))
	var s := _new_strategy()
	var score_with: float = s.evaluate_board(gs, 0)
	# 移除密勒顿
	gs.players[0].bench.clear()
	var score_without: float = s.evaluate_board(gs, 0)
	return assert_true(score_with > score_without,
		"有密勒顿ex 时评分 (%f) 应高于无密勒顿 (%f)" % [score_with, score_without])


# ============================================================
#  编码器测试
# ============================================================

func test_encode_returns_100_dim() -> String:
	## 输出 100 维
	var gs := _make_game_state()
	var features: Array[float] = MiraidonStateEncoderScript.encode(gs, 0)
	return assert_eq(features.size(), 100, "编码器应输出 100 维 (got %d)" % features.size())


func test_encode_all_in_range() -> String:
	## 全部 [0,1]
	var gs := _make_game_state(3)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "", "ex"), 0))
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("铁臂膀ex", "Basic", "L", 230, "", "ex"), 0))
	gs.players[0].hand.append(CardInstance.create(_make_trainer_cd("电气发生器"), 0))
	gs.players[0].hand.append(CardInstance.create(_make_energy_cd("基本雷能量", "L"), 0))
	var features: Array[float] = MiraidonStateEncoderScript.encode(gs, 0)
	var all_ok: bool = true
	var bad_idx: int = -1
	var bad_val: float = 0.0
	for i: int in features.size():
		if features[i] < 0.0 or features[i] > 1.0:
			all_ok = false
			bad_idx = i
			bad_val = features[i]
			break
	return assert_true(all_ok, "所有特征应在 [0,1] 范围 (idx=%d val=%f)" % [bad_idx, bad_val])


func test_encode_null_graceful() -> String:
	## null 不崩
	var features: Array[float] = MiraidonStateEncoderScript.encode(null, 0)
	return assert_eq(features.size(), 100, "null game_state 应返回 100 维零向量")


# ============================================================
#  Value Net 测试
# ============================================================

func test_miraidon_exporter_keeps_loser_samples_by_default() -> String:
	var exporter = load("res://scripts/ai/MiraidonSelfPlayDataExporter.gd").new()
	exporter.start_game()
	var gs := _make_game_state(3)
	exporter.record_state(gs, 0)
	exporter.record_state(gs, 1)
	exporter.end_game(0)
	var records: Array[Dictionary] = exporter.get_records()
	var winners := 0
	var losers := 0
	for record: Dictionary in records:
		var player: int = int(record.get("player", -1))
		var result: float = float(record.get("result", -1.0))
		if player == 0 and result > 0.0:
			winners += 1
		elif player == 1 and is_equal_approx(result, 0.0):
			losers += 1
	return run_checks([
		assert_eq(records.size(), 2, "默认导出应保留胜负双方状态"),
		assert_eq(winners, 1, "赢家视角应保留正标签"),
		assert_eq(losers, 1, "输家视角应保留负标签"),
	])


func test_value_net_roundtrip() -> String:
	## 权重加载 + 推理 [0,1]
	var s := _new_strategy()
	# 构造一个最小权重文件
	var weights := {
		"input_dim": 100,
		"layers": [
			{"weights": [], "biases": []},
		]
	}
	# 构造简单权重：1层，100→1
	var layer_weights: Array = []
	for i: int in 100:
		layer_weights.append([0.01])
	weights["layers"][0]["weights"] = layer_weights
	weights["layers"][0]["biases"] = [0.5]

	var dir_path := "user://test_miraidon_vnet"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var path := dir_path.path_join("test_weights.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return assert_true(false, "无法创建测试权重文件")
	file.store_string(JSON.stringify(weights))
	file.close()

	var loaded: bool = s.load_miraidon_value_net(path)
	if not loaded:
		return assert_true(false, "加载权重失败")

	var gs := _make_game_state()
	var features: Array[float] = MiraidonStateEncoderScript.encode(gs, 0)
	var prediction: float = s.miraidon_value_net.predict(features)
	return run_checks([
		assert_true(s.has_miraidon_value_net(), "应有 value net"),
		assert_true(prediction >= 0.0 and prediction <= 1.0,
			"推理结果应在 [0,1] (got %f)" % prediction),
	])


func test_load_missing_graceful() -> String:
	## 缺失文件 → false
	var s := _new_strategy()
	var loaded: bool = s.load_miraidon_value_net("user://nonexistent_miraidon_weights.json")
	return run_checks([
		assert_true(not loaded, "缺失文件应返回 false"),
		assert_true(not s.has_miraidon_value_net(), "缺失文件后不应有 value net"),
	])


func test_live_opening_forced_active_raichu_prefers_energy_over_baton_bridge() -> String:
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	var raichu := _make_slot(_make_pokemon_cd(DeckStrategyMiraidonScript.RAICHU_V, "Basic", "L", 200, "", "V", [],
		[
			{"name": "Quick Charge", "cost": "L", "damage": ""},
			{"name": "Dynamic Spark", "cost": "LL", "damage": "60"}
		], 1), 0)
	var iron_hands := _make_slot(_make_pokemon_cd(DeckStrategyMiraidonScript.IRON_HANDS_EX, "Basic", "L", 230, "", "ex", [],
		[{"name": "Amp You Very Much", "cost": "LLC", "damage": "160"}], 4), 0)
	player.active_pokemon = raichu
	player.bench.append(iron_hands)
	var s := _new_strategy()
	var launch_plan := {
		"intent": "launch_shell",
		"flags": {
			"ready_attacker_on_board": false,
			"close_out_window": false,
			"need_energy_bridge": false,
			"need_pivot_enabler": false,
			"raikou_bridge_window": false,
		},
	}
	var attach_raichu: float = s.score_action(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("L1", "L"), 0),
			"target_slot": raichu
		},
		{
			"game_state": gs,
			"player_index": 0,
			"turn_plan": launch_plan,
		}
	)
	var attach_iron_hands: float = s.score_action(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("L2", "L"), 0),
			"target_slot": iron_hands
		},
		{
			"game_state": gs,
			"player_index": 0,
			"turn_plan": launch_plan,
		}
	)
	var baton_iron_hands: float = s.score_action(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_tool_cd(DeckStrategyMiraidonScript.HEAVY_BATON), 0),
			"target_slot": iron_hands
		},
		{
			"game_state": gs,
			"player_index": 0,
			"turn_plan": launch_plan,
		}
	)
	return assert_true(
		attach_raichu > attach_iron_hands and attach_raichu > baton_iron_hands,
		"live launch-shell scoring should prefer active Raichu energy over backline Iron Hands bridge setup in forced Raichu openings (raichu=%f iron_hands=%f baton=%f)" % [attach_raichu, attach_iron_hands, baton_iron_hands]
	)


func test_early_emergency_board_prefers_active_shell_for_raikou_pivot() -> String:
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var miraidon := _make_slot(_make_pokemon_cd(DeckStrategyMiraidonScript.MIRAIDON_EX, "Basic", "L", 220, "", "ex",
		[{"name": "Tandem Unit"}], [{"name": "Photon Blaster", "cost": "LLC", "damage": "220"}], 1), 0)
	var raikou := _make_slot(_make_pokemon_cd(DeckStrategyMiraidonScript.RAIKOU_V, "Basic", "L", 200, "", "V",
		[{"name": "Fleet Feet"}], [{"name": "Lightning Rondo", "cost": "LC", "damage": "20"}], 1), 0)
	raikou.attached_energy.append(CardInstance.create(_make_energy_cd("L1", "L"), 0))
	player.active_pokemon = miraidon
	player.bench.append(raikou)
	var s := _new_strategy()
	var board_on_active: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_tool_cd(DeckStrategyMiraidonScript.EMERGENCY_BOARD), 0),
			"target_slot": miraidon
		},
		gs,
		0
	)
	var board_on_iron_hands: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_tool_cd(DeckStrategyMiraidonScript.EMERGENCY_BOARD), 0),
			"target_slot": raikou
		},
		gs,
		0
	)
	return assert_true(
		board_on_active > board_on_iron_hands,
		"early bridge turns should prefer Emergency Board on the active shell when it unlocks a Raikou pivot attack (active=%f raikou=%f)" % [board_on_active, board_on_iron_hands]
	)


func test_miraidon_baseline_backup_script_loads_and_keeps_contract() -> String:
	var script: GDScript = load(MIRAIDON_BASELINE_SCRIPT_PATH)
	if script == null:
		return "DeckStrategyMiraidonBaseline.gd should exist before shared-layer hardening changes start"
	var strategy = script.new()
	return run_checks([
		assert_true(strategy != null, "Miraidon baseline strategy should instantiate"),
		assert_true(strategy.has_method("get_strategy_id"), "Baseline strategy should expose strategy id"),
		assert_true(strategy.has_method("get_signature_names"), "Baseline strategy should expose signatures"),
		assert_true(strategy.has_method("score_action_absolute"), "Baseline strategy should expose absolute scoring"),
		assert_true(strategy.has_method("score_action"), "Baseline strategy should expose heuristic scoring"),
		assert_true(strategy.has_method("evaluate_board"), "Baseline strategy should expose board evaluation"),
	])


func test_registry_keeps_live_miraidon_strategy_not_baseline_copy() -> String:
	var registry = DeckStrategyRegistryScript.new()
	var strategy = registry.create_strategy_by_id("miraidon")
	if strategy == null:
		return "Registry should create the live Miraidon strategy before baseline regression behavior can be checked"
	var script: GDScript = strategy.get_script()
	var path: String = script.resource_path if script != null else ""
	return assert_eq(path, "res://scripts/ai/DeckStrategyMiraidon.gd",
		"Production registry should still resolve the live Miraidon strategy, not the baseline backup")
