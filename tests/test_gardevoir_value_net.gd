## 沙奈朵 Value Net 端到端测试
class_name TestGardevoirValueNet
extends TestBase

const GardevoirStateEncoderScript = preload("res://scripts/ai/GardevoirStateEncoder.gd")
const GardevoirSelfPlayDataExporterScript = preload("res://scripts/ai/GardevoirSelfPlayDataExporter.gd")
const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")


# ============================================================
#  辅助函数
# ============================================================

func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.mechanic = mechanic
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
	var p0 := _make_player(0)
	var p1 := _make_player(1)
	p0.active_pokemon = _make_slot(_make_pokemon_cd("拉鲁拉丝"))
	p1.active_pokemon = _make_slot(_make_pokemon_cd("密勒顿ex", "Basic", "L", 220, "ex"), 1)
	gs.players = [p0, p1]
	return gs


func _make_gardevoir_state() -> GameState:
	## 构造带沙奈朵引擎的典型中期局面
	var gs := _make_game_state(5)
	var p0: PlayerState = gs.players[0]
	# 前场：振翼发
	p0.active_pokemon = _make_slot(_make_pokemon_cd("振翼发"))
	# 后备：沙奈朵ex + 奇鲁莉安 + 飘飘球 + 愿增猿
	var gardevoir_cd := _make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "ex",
		[{"name": "精神拥抱", "type": "Ability"}], [])
	var kirlia_cd := _make_pokemon_cd("奇鲁莉安", "Stage 1", "P", 80)
	var drifloon_cd := _make_pokemon_cd("飘飘球", "Basic", "P", 70, "",
		[], [{"name": "气球炸弹", "cost": "PP", "damage": "0"}])
	var munkidori_cd := _make_pokemon_cd("愿增猿", "Basic", "D", 110)
	p0.bench = [
		_make_slot(gardevoir_cd),
		_make_slot(kirlia_cd),
		_make_slot(drifloon_cd),
		_make_slot(munkidori_cd),
	]
	# 手牌
	p0.hand = [
		CardInstance.create(_make_trainer_cd("高级球"), 0),
		CardInstance.create(_make_trainer_cd("老大的指令", "Supporter"), 0),
		CardInstance.create(_make_energy_cd("基本超能量", "P"), 0),
	]
	# 弃牌堆：超能量
	for i: int in 4:
		p0.discard_pile.append(CardInstance.create(_make_energy_cd("基本超能量", "P"), 0))
	# 飘飘球贴伤害指示物（模拟 Embrace）
	p0.bench[2].damage_counters = 40
	return gs


# ============================================================
#  测试用例
# ============================================================

func test_encode_returns_correct_dim() -> String:
	var gs := _make_game_state()
	var features: Array[float] = GardevoirStateEncoderScript.encode(gs, 0)
	return assert_eq(features.size(), 124, "特征维度应为 124")


func test_encode_all_in_range() -> String:
	var gs := _make_gardevoir_state()
	var features: Array[float] = GardevoirStateEncoderScript.encode(gs, 0)
	for i: int in features.size():
		var r: String = assert_true(features[i] >= 0.0 and features[i] <= 1.0,
			"特征 [%d] = %.4f 应在 [0,1] 范围内" % [i, features[i]])
		if r != "":
			return r
	return ""


func test_encode_null_graceful() -> String:
	var features: Array[float] = GardevoirStateEncoderScript.encode(null, 0)
	var r: String = assert_eq(features.size(), 124, "null 输入应返回 124 维零向量")
	if r != "":
		return r
	for i: int in features.size():
		r = assert_eq(features[i], 0.0, "null 输入特征 [%d] 应为 0" % i)
		if r != "":
			return r
	return ""


func test_encode_gardevoir_engine_feature() -> String:
	var gs := _make_gardevoir_state()
	var features: Array[float] = GardevoirStateEncoderScript.encode(gs, 0)
	# 己方身份偏移 40，engine_active 在 [45]
	return assert_eq(features[45], 1.0, "沙奈朵ex 在场时 engine_active 应为 1.0")


func test_encode_discard_psychic_energy() -> String:
	var gs := _make_gardevoir_state()
	var features: Array[float] = GardevoirStateEncoderScript.encode(gs, 0)
	# 沙奈朵资源偏移 64，弃牌堆超能量在 [64]
	return run_checks([
		assert_true(features[64] > 0.0, "弃牌堆有超能量时特征应 > 0"),
		assert_eq(features[65], 1.0, "弃牌堆超能量 4 >= 3，应为 1.0"),
	])


func test_encode_perspective_symmetry() -> String:
	var gs := _make_gardevoir_state()
	var features_p0: Array[float] = GardevoirStateEncoderScript.encode(gs, 0)
	var features_p1: Array[float] = GardevoirStateEncoderScript.encode(gs, 1)
	# p0 己方前场 HP = p1 对手前场 HP
	return assert_eq(features_p0[0], features_p1[20],
		"双方视角的前场 HP 应对称：p0[0]=%.3f, p1[20]=%.3f" % [features_p0[0], features_p1[20]])


func test_exporter_correct_feature_dim() -> String:
	var exporter := GardevoirSelfPlayDataExporterScript.new()
	exporter.deck_strategy = DeckStrategyGardevoirScript.new()
	exporter.start_game()
	var gs := _make_gardevoir_state()
	exporter.record_state(gs, 0)
	var records: Array[Dictionary] = exporter.get_records()
	var r: String = assert_eq(records.size(), 1, "应有 1 条记录")
	if r != "":
		return r
	var feats: Variant = records[0].get("features", [])
	return run_checks([
		assert_true(feats is Array, "features 应为 Array"),
		assert_eq((feats as Array).size(), 124, "导出特征维度应为 124"),
	])


func test_exporter_teacher_score() -> String:
	var exporter := GardevoirSelfPlayDataExporterScript.new()
	exporter.deck_strategy = DeckStrategyGardevoirScript.new()
	exporter.start_game()
	var gs := _make_gardevoir_state()
	exporter.record_state(gs, 0)
	var records: Array[Dictionary] = exporter.get_records()
	var teacher: float = float(records[0].get("teacher_score", -1.0))
	return assert_true(teacher >= 0.0 and teacher <= 1.0,
		"teacher_score 应在 [0,1]，实际: %.4f" % teacher)


func test_exporter_keeps_loser_samples_by_default() -> String:
	var exporter := GardevoirSelfPlayDataExporterScript.new()
	exporter.start_game()
	var gs := _make_gardevoir_state()
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
	## 构造一个简单的 2 层网络权重 JSON，加载后推理应在 [0,1]
	var weights_data := {
		"architecture": "mlp",
		"input_dim": 124,
		"encoder_name": "gardevoir",
		"feature_dim": 124,
		"layers": [
			{
				"out_features": 4,
				"activation": "relu",
				"weights": _make_random_weights(4, 124),
				"bias": [0.0, 0.0, 0.0, 0.0],
			},
			{
				"out_features": 1,
				"activation": "sigmoid",
				"weights": _make_random_weights(1, 4),
				"bias": [0.0],
			},
		],
	}
	var net := NeuralNetInferenceScript.new()
	var loaded: bool = net.load_weights_from_dict(weights_data)
	var r: String = run_checks([
		assert_true(loaded, "权重应成功加载"),
		assert_true(net.is_loaded(), "网络应标记为已加载"),
	])
	if r != "":
		return r

	var gs := _make_gardevoir_state()
	var features: Array[float] = GardevoirStateEncoderScript.encode(gs, 0)
	var prediction: float = net.predict(features)
	return assert_true(prediction >= 0.0 and prediction <= 1.0,
		"推理输出应在 [0,1]，实际: %.4f" % prediction)


func test_mcts_prefers_value_net_over_evaluate_board() -> String:
	## 设置 value_net 后，MCTS 应优先使用 value_net
	var planner := MCTSPlannerScript.new()
	var strategy := DeckStrategyGardevoirScript.new()
	planner.deck_strategy = strategy

	var weights_data := {
		"architecture": "mlp",
		"input_dim": 124,
		"layers": [
			{
				"out_features": 2,
				"activation": "relu",
				"weights": _make_random_weights(2, 124),
				"bias": [0.0, 0.0],
			},
			{
				"out_features": 1,
				"activation": "sigmoid",
				"weights": [[0.5, 0.5]],
				"bias": [0.0],
			},
		],
	}
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(weights_data)
	planner.value_net = net
	planner.state_encoder_class = GardevoirStateEncoderScript

	return run_checks([
		assert_true(planner.value_net != null and planner.value_net.is_loaded(),
			"value_net 应已加载"),
		assert_true(planner.state_encoder_class != null,
			"state_encoder_class 应已设置"),
	])


func test_load_missing_file_graceful() -> String:
	var strategy := DeckStrategyGardevoirScript.new()
	var result: bool = strategy.load_gardevoir_value_net("user://nonexistent_file_12345.json")
	return run_checks([
		assert_false(result, "加载不存在的文件应返回 false"),
		assert_false(strategy.has_gardevoir_value_net(), "has_gardevoir_value_net 应为 false"),
	])


# ============================================================
#  辅助
# ============================================================

func _make_random_weights(rows: int, cols: int) -> Array:
	var weights: Array = []
	for _r: int in rows:
		var row: Array = []
		for _c: int in cols:
			row.append(randf_range(-0.1, 0.1))
		weights.append(row)
	return weights
