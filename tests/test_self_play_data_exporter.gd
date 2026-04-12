class_name TestSelfPlayDataExporter
extends TestBase

const SelfPlayDataExporterScript = preload("res://scripts/ai/SelfPlayDataExporter.gd")
const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")


func _make_minimal_game_state() -> GameState:
	var gs := GameState.new()
	gs.turn_number = 1
	gs.first_player_index = 0
	gs.current_player_index = 0
	for i: int in 2:
		var ps := PlayerState.new()
		ps.player_index = i
		var cd := CardData.new()
		cd.name = "Test Pokemon"
		cd.card_type = "Pokemon"
		cd.stage = "Basic"
		cd.hp = 100
		cd.energy_type = "C"
		cd.attacks = []
		var card := CardInstance.create(cd, i)
		var slot := PokemonSlot.new()
		slot.pokemon_stack = [card]
		ps.active_pokemon = slot
		for _p: int in 6:
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

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	return run_checks([
		assert_true(path != "", "Exporter should return a non-empty output path"),
		assert_true(parse_ok, "Exporter output should be valid JSON"),
		assert_eq(data.get("version", ""), "1.0", "Version should stay at 1.0"),
		assert_eq(int(data.get("winner_index", -1)), 0, "Winner index should be recorded"),
		assert_true(data.has("meta"), "Exporter should persist match metadata"),
		assert_eq((data.get("records", []) as Array).size(), 2, "Exporter should write both player views"),
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
		assert_eq(features.size(), StateEncoderScript.FEATURE_DIM, "Feature length should match StateEncoder feature dim"),
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
		assert_true(absf(float(r0.get("result", -1.0)) - 1.0) < 0.01, "Winner-side result should be 1.0"),
		assert_true(absf(float(r1.get("result", -1.0)) - 0.0) < 0.01, "Loser-side result should be 0.0"),
	])


func test_export_game_uses_match_metadata_and_avoids_filename_collisions() -> String:
	var exporter_a := SelfPlayDataExporterScript.new()
	exporter_a.base_dir = "user://test_training_data"
	var exporter_b := SelfPlayDataExporterScript.new()
	exporter_b.base_dir = "user://test_training_data"
	var gs := _make_minimal_game_state()

	exporter_a.start_game({"match_id": "self_play_578647_vs_575720_s1276720_a0"})
	exporter_a.record_state(gs, 0)
	exporter_a.end_game(0)
	var path_a: String = exporter_a.export_game()

	exporter_b.start_game({"match_id": "self_play_578647_vs_575720_s1276720_a0"})
	exporter_b.record_state(gs, 0)
	exporter_b.end_game(0)
	var path_b: String = exporter_b.export_game()

	var name_a := path_a.get_file()
	var name_b := path_b.get_file()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_a))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_b))

	return run_checks([
		assert_true(name_a.find("game_self_play_578647_vs_575720_s1276720_a0") >= 0, "Value export filename should preserve the match id"),
		assert_true(path_a != path_b, "Repeated match ids should not overwrite the first export"),
		assert_true(name_b.find("_01.json") >= 0, "Repeated match ids should get a deterministic numeric suffix"),
	])


func test_end_game_accepts_result_dictionary_and_persists_match_quality() -> String:
	var exporter := SelfPlayDataExporterScript.new()
	exporter.base_dir = "user://test_training_data"
	var gs := _make_minimal_game_state()

	exporter.start_game({"match_id": "quality_test_match"})
	exporter.record_state(gs, 0)
	exporter.record_state(gs, 1)
	exporter.end_game({
		"winner_index": 0,
		"failure_reason": "deck_out",
		"turn_count": 19,
		"terminated_by_cap": false,
		"stalled": false,
	})

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

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	return run_checks([
		assert_eq(str(data.get("failure_reason", "")), "deck_out", "Exporter should persist match failure reason"),
		assert_true(absf(float(data.get("match_quality_weight", 0.0)) - 0.9) < 0.01, "Deck-out matches should use reduced quality weight"),
		assert_eq(int(data.get("total_turns", 0)), 19, "Result dictionary should be allowed to backfill total turns"),
		assert_true(absf(float(first_record.get("match_quality_weight", 0.0)) - 0.9) < 0.01, "Per-record quality weight should be written"),
	])
