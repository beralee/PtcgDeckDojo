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
