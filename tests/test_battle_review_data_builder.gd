class_name TestBattleReviewDataBuilder
extends TestBase

const DataBuilderPath := "res://scripts/engine/BattleReviewDataBuilder.gd"
const TEST_ROOT := "user://test_battle_review_data_builder"


func _new_builder() -> Variant:
	if not ResourceLoader.exists(DataBuilderPath):
		return {"ok": false, "error": "BattleReviewDataBuilder script is missing"}
	var script: GDScript = load(DataBuilderPath)
	var builder = script.new()
	if builder == null:
		return {"ok": false, "error": "BattleReviewDataBuilder could not be instantiated"}
	return {"ok": true, "value": builder}


func _cleanup_root() -> void:
	var root_path := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(root_path):
		if FileAccess.file_exists(root_path):
			DirAccess.remove_absolute(root_path)
		return
	_remove_dir_recursive(root_path)
	DirAccess.remove_absolute(root_path)


func _remove_dir_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_remove_dir_recursive(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _write_json(path: String, payload: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func test_build_stage1_payload_drops_heavy_sections_and_keeps_compact_turn_context() -> String:
	_cleanup_root()
	var builder_result: Variant = _new_builder()
	if builder_result is Dictionary and not bool((builder_result as Dictionary).get("ok", false)):
		return str((builder_result as Dictionary).get("error", "BattleReviewDataBuilder setup failed"))

	var match_dir := TEST_ROOT.path_join("fixture_match")
	_write_json(match_dir.path_join("match.json"), {
		"meta": {"winner_index": 1},
		"initial_state": {"players": [{"hand": [{"card_name": "Huge Hand Card", "description": "very long text"}]}]},
		"result": {"winner_index": 1, "reason": "prize_out"},
	})
	_write_json(match_dir.path_join("turns.json"), {
		"turns": [
			{
				"turn_number": 2,
				"key_actions": [
					{"description": "Action A"},
					{"description": "Action B"},
					{"description": "Action C"},
					{"description": "Action D"},
					{"description": "Action E"},
				],
				"key_choices": [
					{"title": "Ultra Ball", "selected_labels": ["Pidgeot ex"], "selected_indices": [1]},
					{"title": "Arven", "selected_labels": ["Rare Candy", "Forest Seal Stone"], "selected_indices": [0, 1]},
					{"title": "Extra Choice", "selected_labels": ["Too Much"]},
				],
			},
		],
	})
	_write_json(match_dir.path_join("llm_digest.json"), {
		"meta": {"winner_index": 1},
		"opening": {"first_player": 0},
		"turn_summaries": [
			{
				"turn_number": 2,
				"key_actions": [
					{"description": "Action A"},
					{"description": "Action B"},
					{"description": "Action C"},
					{"description": "Action D"},
					{"description": "Action E"},
				],
				"key_choices": [
					{"title": "Ultra Ball", "selected_labels": ["Pidgeot ex"], "selected_indices": [1]},
					{"title": "Arven", "selected_labels": ["Rare Candy", "Forest Seal Stone"], "selected_indices": [0, 1]},
					{"title": "Extra Choice", "selected_labels": ["Too Much"]},
				],
			},
		],
		"critical_sequences": [{"turn_number": 2, "actions": ["too much detail"]}],
		"inflection_points": [{"turn_number": 2, "kind": "knockout", "summary": "Prize swing"}],
	})

	var builder: Object = (builder_result as Dictionary).get("value") as Object
	var payload: Variant = builder.call("build_stage1_payload", ProjectSettings.globalize_path(match_dir))
	if not payload is Dictionary:
		return "build_stage1_payload should return a Dictionary"

	var turn_summaries: Array = (payload as Dictionary).get("turn_summaries", [])
	var first_turn: Dictionary = turn_summaries[0] if turn_summaries.size() > 0 and turn_summaries[0] is Dictionary else {}
	var key_actions: Array = first_turn.get("key_actions", [])
	var key_choices: Array = first_turn.get("key_choices", [])
	var first_choice: Dictionary = key_choices[0] if key_choices.size() > 0 and key_choices[0] is Dictionary else {}
	var serialized_size := JSON.stringify(payload).length()

	_cleanup_root()
	return run_checks([
		assert_false((payload as Dictionary).has("initial_state"), "Stage 1 payload should drop heavy initial_state data"),
		assert_false((payload as Dictionary).has("critical_sequences"), "Stage 1 payload should drop verbose critical_sequences"),
		assert_eq(key_actions.size(), 4, "Stage 1 turn summaries should cap key actions at four"),
		assert_eq(key_choices.size(), 2, "Stage 1 turn summaries should cap key choices at two"),
		assert_eq(String(first_choice.get("title", "")), "Ultra Ball", "Stage 1 turn summaries should keep the choice title"),
		assert_eq(first_choice.get("selected_labels", []), ["Pidgeot ex"], "Stage 1 turn summaries should keep selected labels"),
		assert_false(first_choice.has("selected_indices"), "Stage 1 turn summaries should drop low-signal index data"),
		assert_true(serialized_size < 1200, "Stage 1 payload should stay compact for the key-turn selector"),
	])
