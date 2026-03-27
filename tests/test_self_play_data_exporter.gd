class_name TestSelfPlayDataExporter
extends TestBase

const SelfPlayDataExporterScript = preload("res://scripts/ai/SelfPlayDataExporter.gd")
const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")


func _make_minimal_game_state() -> GameState:
	var gs := GameState.new()
	gs.turn_number = 1
	gs.first_player_index = 0
	gs.current_player_index = 0
	for i in 2:
		var ps := PlayerState.new()
		ps.player_index = i
		var cd := CardData.new()
		cd.name = "测试宝可梦"
		cd.card_type = "Pokemon"
		cd.stage = "Basic"
		cd.hp = 100
		cd.energy_type = "C"
		cd.attacks = []
		var card := CardInstance.create(cd, i)
		var slot := PokemonSlot.new()
		slot.pokemon_stack = [card]
		ps.active_pokemon = slot
		for _p in 6:
			ps.prizes.append(CardInstance.create(CardData.new(), i))
		gs.players.append(ps)
	return gs


func test_record_and_export_produces_valid_json() -> String:
	var exporter := SelfPlayDataExporterScript.new()
	exporter.base_dir = "user://test_training_data"
	var gs := _make_minimal_game_state()

	exporter.start_game()
	exporter.record_state(gs, 0)
	exporter.record_state(gs, 1)
	exporter.end_game(0)

	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text() if file != null else ""
	if file != null:
		file.close()

	var json := JSON.new()
	var parse_ok: bool = json.parse(text) == OK
	var data: Dictionary = json.data if json.data is Dictionary else {}

	## 清理
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	return run_checks([
		assert_true(path != "", "导出路径应非空"),
		assert_true(parse_ok, "导出文件应是有效 JSON"),
		assert_eq(data.get("version", ""), "1.0", "版本应为 1.0"),
		assert_eq(int(data.get("winner_index", -1)), 0, "胜者应为 0"),
		assert_eq((data.get("records", []) as Array).size(), 2, "应有 2 条记录"),
	])


func test_records_have_correct_features_length() -> String:
	var exporter := SelfPlayDataExporterScript.new()
	exporter.base_dir = "user://test_training_data"
	var gs := _make_minimal_game_state()

	exporter.start_game()
	exporter.record_state(gs, 0)
	exporter.end_game(0)

	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text() if file != null else ""
	if file != null:
		file.close()

	var json := JSON.new()
	json.parse(text)
	var data: Dictionary = json.data if json.data is Dictionary else {}
	var records: Array = data.get("records", [])
	var first_record: Dictionary = records[0] if not records.is_empty() else {}
	var features: Array = first_record.get("features", [])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	return run_checks([
		assert_eq(features.size(), StateEncoderScript.FEATURE_DIM, "特征向量维度应为 %d" % StateEncoderScript.FEATURE_DIM),
	])


func test_result_backfill() -> String:
	var exporter := SelfPlayDataExporterScript.new()
	exporter.base_dir = "user://test_training_data"
	var gs := _make_minimal_game_state()

	exporter.start_game()
	exporter.record_state(gs, 0)
	exporter.record_state(gs, 1)
	exporter.end_game(0)

	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text() if file != null else ""
	if file != null:
		file.close()

	var json := JSON.new()
	json.parse(text)
	var data: Dictionary = json.data if json.data is Dictionary else {}
	var records: Array = data.get("records", [])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var r0: Dictionary = records[0] if records.size() > 0 else {}
	var r1: Dictionary = records[1] if records.size() > 1 else {}
	return run_checks([
		assert_true(absf(float(r0.get("result", -1.0)) - 1.0) < 0.01, "玩家 0 赢了，result 应为 1.0"),
		assert_true(absf(float(r1.get("result", -1.0)) - 0.0) < 0.01, "玩家 1 输了，result 应为 0.0"),
	])
