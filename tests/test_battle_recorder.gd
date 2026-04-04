class_name TestBattleRecorder
extends TestBase

const BattleRecorderPath := "res://scripts/engine/BattleRecorder.gd"
const BattleEventBuilderPath := "res://scripts/engine/BattleEventBuilder.gd"
const TEST_ROOT := "user://test_battle_recorder"


func _load_recorder_script() -> Variant:
	if not ResourceLoader.exists(BattleRecorderPath):
		return null
	return load(BattleRecorderPath)


func _load_event_builder_script() -> Variant:
	if not ResourceLoader.exists(BattleEventBuilderPath):
		return null
	return load(BattleEventBuilderPath)


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


func _new_recorder() -> Variant:
	var script: Variant = _load_recorder_script()
	if script == null:
		return {"ok": false, "error": "BattleRecorder script is missing"}

	var recorder = (script as GDScript).new()
	if recorder == null:
		return {"ok": false, "error": "BattleRecorder could not be instantiated"}

	if not _configure_root(recorder, TEST_ROOT):
		return {"ok": false, "error": "BattleRecorder root could not be configured"}
	return {"ok": true, "value": recorder}


func _configure_root(recorder: Object, root_path: String) -> bool:
	for method_name in ["set_output_root", "configure_output_root", "set_base_dir"]:
		if recorder.has_method(method_name):
			recorder.call(method_name, root_path)
			return true

	for property_name in ["base_dir", "output_root", "root_dir", "record_root"]:
		for prop_variant: Variant in recorder.get_property_list():
			if not prop_variant is Dictionary:
				continue
			var prop: Dictionary = prop_variant
			if str(prop.get("name", "")) == property_name:
				recorder.set(property_name, root_path)
				return true

	return false


func _make_match_meta() -> Dictionary:
	return {
		"mode": "local_human_vs_human",
		"player_labels": ["player_1", "player_2"],
		"first_player_index": 0,
	}


func _make_event(event_index: int, event_type: String, extra: Dictionary = {}) -> Dictionary:
	var event := {
		"match_id": "match_test",
		"event_index": event_index,
		"timestamp": "2026-03-29T00:00:00Z",
		"turn_number": 1,
		"phase": "main",
		"player_index": 0,
		"event_type": event_type,
	}
	for key_variant: Variant in extra.keys():
		event[str(key_variant)] = extra[key_variant]
	return event


func _open_first_match_dir() -> String:
	var root_path := ProjectSettings.globalize_path(TEST_ROOT)
	var dir := DirAccess.open(root_path)
	if dir == null:
		return ""

	var child_dirs: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != ".." and dir.current_is_dir():
			child_dirs.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	child_dirs.sort()
	return root_path.path_join(child_dirs[0]) if not child_dirs.is_empty() else ""


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _read_json_lines(path: String) -> Array[Dictionary]:
	var parsed_lines: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return parsed_lines

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			parsed_lines.append(parsed)
	file.close()
	return parsed_lines


func _read_non_empty_lines(path: String) -> Array[String]:
	var lines: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return lines

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		lines.append(line)
	file.close()
	return lines


func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _write_json_lines(path: String, lines: Array[Dictionary]) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	for line: Dictionary in lines:
		file.store_line(JSON.stringify(line))
	file.close()
	return true


func _contains_subsequence(values: Array, expected: Array) -> bool:
	if values.size() != expected.size():
		return false
	for index in expected.size():
		if values[index] != expected[index]:
			return false
	return true


func test_marks_recording_degraded_when_post_start_detail_write_fails() -> String:
	_cleanup_root()
	var recorder_result: Variant = _new_recorder()
	if recorder_result is Dictionary and not bool((recorder_result as Dictionary).get("ok", false)):
		return str((recorder_result as Dictionary).get("error", "Recorder setup failed"))

	var recorder: Object = (recorder_result as Dictionary).get("value") as Object
	recorder.call("start_match", _make_match_meta())
	recorder.call("record_event", _make_event(0, "match_started"))

	var match_dir := _open_first_match_dir()
	var detail_path := match_dir.path_join("detail.jsonl")
	var summary_path := match_dir.path_join("summary.log")
	var initial_detail_lines := _read_json_lines(detail_path)
	var initial_summary_lines := _read_non_empty_lines(summary_path)
	if FileAccess.file_exists(detail_path):
		DirAccess.remove_absolute(detail_path)
	DirAccess.make_dir_recursive_absolute(detail_path)

	recorder.call("record_event", _make_event(1, "action_resolved"))
	DirAccess.remove_absolute(detail_path)
	_write_json_lines(detail_path, initial_detail_lines)
	recorder.call("record_event", _make_event(2, "action_selected"))
	recorder.call("finalize_match", {"winner_index": 0, "reason": "prize_out"})

	var detail_lines := _read_json_lines(detail_path)
	var summary_lines := _read_non_empty_lines(summary_path)
	var result := run_checks([
		assert_eq(detail_lines.size(), initial_detail_lines.size(), "Recorder should stop appending detail.jsonl after a post-start detail write failure"),
		assert_eq(summary_lines.size(), initial_summary_lines.size(), "Recorder should stop appending summary.log after a post-start detail write failure"),
		assert_false(FileAccess.file_exists(match_dir.path_join("match.json")), "Recorder should not export match.json after a post-start detail write failure"),
	])
	_cleanup_root()
	return result


func test_unknown_numeric_action_type_uses_explicit_event_type_fallback() -> String:
	var script: Variant = _load_event_builder_script()
	if script == null:
		return "BattleEventBuilder script is missing"

	var builder = (script as GDScript).new()
	var event: Dictionary = builder.call("build_event", {"action_type": 999}, "match_test", 0)
	return run_checks([
		assert_true(String(event.get("event_type", "")) != "", "Unknown numeric action_type should still produce a stable event_type"),
		assert_eq(String(event.get("event_type", "")), "action_type_999", "Unknown numeric action_type should use an explicit fallback name"),
	])


func test_creates_per_match_directory() -> String:
	_cleanup_root()
	var recorder_result: Variant = _new_recorder()
	if recorder_result is Dictionary and not bool((recorder_result as Dictionary).get("ok", false)):
		return str((recorder_result as Dictionary).get("error", "Recorder setup failed"))

	var recorder: Object = (recorder_result as Dictionary).get("value") as Object
	recorder.call("start_match", _make_match_meta())

	var root_path := ProjectSettings.globalize_path(TEST_ROOT)
	var child_dir := _open_first_match_dir()
	var child_name := child_dir.get_file() if child_dir != "" else ""
	var result := run_checks([
		assert_true(DirAccess.dir_exists_absolute(root_path), "Recorder should create the base output root"),
		assert_true(child_name != "", "Recorder should create a per-match directory"),
		assert_true(DirAccess.dir_exists_absolute(child_dir), "Per-match directory should exist on disk"),
	])
	_cleanup_root()
	return result


func test_writes_summary_log() -> String:
	_cleanup_root()
	var recorder_result: Variant = _new_recorder()
	if recorder_result is Dictionary and not bool((recorder_result as Dictionary).get("ok", false)):
		return str((recorder_result as Dictionary).get("error", "Recorder setup failed"))

	var recorder: Object = (recorder_result as Dictionary).get("value") as Object
	recorder.call("start_match", _make_match_meta())
	recorder.call("record_event", _make_event(0, "match_started"))
	recorder.call("record_event", _make_event(1, "action_resolved", {"summary_tag": "attack_30"}))
	recorder.call("finalize_match", {"winner_index": 0, "reason": "prize_out"})

	var match_dir := _open_first_match_dir()
	var summary_path := match_dir.path_join("summary.log")
	var summary_text := _read_text(summary_path)
	var result := run_checks([
		assert_true(FileAccess.file_exists(summary_path), "Recorder should write summary.log"),
		assert_true(summary_text.strip_edges() != "", "summary.log should not be empty after recording events"),
	])
	_cleanup_root()
	return result


func test_appends_detail_jsonl_in_stable_event_order() -> String:
	_cleanup_root()
	var recorder_result: Variant = _new_recorder()
	if recorder_result is Dictionary and not bool((recorder_result as Dictionary).get("ok", false)):
		return str((recorder_result as Dictionary).get("error", "Recorder setup failed"))

	var recorder: Object = (recorder_result as Dictionary).get("value") as Object
	recorder.call("start_match", _make_match_meta())
	recorder.call("record_event", _make_event(0, "state_snapshot"))
	recorder.call("record_event", _make_event(1, "action_selected"))
	recorder.call("record_event", _make_event(2, "action_resolved"))
	recorder.call("finalize_match", {"winner_index": 0, "reason": "prize_out"})

	var match_dir := _open_first_match_dir()
	var detail_path := match_dir.path_join("detail.jsonl")
	var event_lines := _read_json_lines(detail_path)
	var event_types: Array = []
	for line in event_lines:
		event_types.append(line.get("event_type", ""))
	var result := run_checks([
		assert_true(FileAccess.file_exists(detail_path), "Recorder should append detail.jsonl"),
		assert_true(_contains_subsequence(event_types, ["state_snapshot", "action_selected", "action_resolved"]), "detail.jsonl should preserve the order of recorded events"),
	])
	_cleanup_root()
	return result


func test_writes_match_json_on_finalize() -> String:
	_cleanup_root()
	var recorder_result: Variant = _new_recorder()
	if recorder_result is Dictionary and not bool((recorder_result as Dictionary).get("ok", false)):
		return str((recorder_result as Dictionary).get("error", "Recorder setup failed"))

	var recorder: Object = (recorder_result as Dictionary).get("value") as Object
	recorder.call("start_match", _make_match_meta())
	recorder.call("record_event", _make_event(0, "match_started"))
	recorder.call("record_event", _make_event(1, "state_snapshot"))
	recorder.call("finalize_match", {
		"winner_index": 1,
		"reason": "prize_out",
		"turn_count": 12,
	})

	var match_dir := _open_first_match_dir()
	var match_path := match_dir.path_join("match.json")
	var data := _read_json_file(match_path)
	var result := run_checks([
		assert_true(FileAccess.file_exists(match_path), "Recorder should write match.json on finalize"),
		assert_true(data.has("meta"), "match.json should include meta"),
		assert_true(data.has("initial_state"), "match.json should include initial_state"),
		assert_true(data.has("event_count"), "match.json should keep a lightweight event_count instead of duplicating full events"),
		assert_true(data.has("turn_count"), "match.json should include turn_count for quick navigation"),
		assert_true(data.has("turns_path"), "match.json should point to turns.json"),
		assert_true(data.has("llm_digest_path"), "match.json should point to llm_digest.json"),
		assert_true(data.has("result"), "match.json should include result"),
	])
	_cleanup_root()
	return result


func test_refreshes_match_context_after_recording_start() -> String:
	_cleanup_root()
	var recorder_result: Variant = _new_recorder()
	if recorder_result is Dictionary and not bool((recorder_result as Dictionary).get("ok", false)):
		return str((recorder_result as Dictionary).get("error", "Recorder setup failed"))

	var recorder: Object = (recorder_result as Dictionary).get("value") as Object
	recorder.call("start_match", {
		"mode": "two_player",
		"player_labels": [],
		"first_player_index": -1,
	}, {
		"players": [{}, {}],
	})
	recorder.call("update_match_context", {
		"mode": "two_player",
		"player_labels": ["winner", "loser"],
		"first_player_index": 1,
	}, {
		"players": [
			{"player_index": 0, "hand": [{"card_name": "Regidrago V"}], "active": {"pokemon_name": "Regidrago V"}},
			{"player_index": 1, "hand": [{"card_name": "Iron Hands ex"}], "active": {"pokemon_name": "Iron Hands ex"}},
		],
	})
	recorder.call("record_event", _make_event(0, "match_started"))
	recorder.call("finalize_match", {"winner_index": 0, "reason": "prize_out", "turn_count": 1})

	var match_dir := _open_first_match_dir()
	var match_json := _read_json_file(match_dir.path_join("match.json"))
	var llm_digest := _read_json_file(match_dir.path_join("llm_digest.json"))
	var meta: Dictionary = match_json.get("meta", {})
	var initial_state: Dictionary = match_json.get("initial_state", {})
	var players: Array = initial_state.get("players", [])
	var opening: Dictionary = llm_digest.get("opening", {})
	var opening_tags: Dictionary = opening.get("opening_tags", {})
	var result := run_checks([
		assert_eq(meta.get("player_labels", []), ["winner", "loser"], "Recorder should allow updating player labels after recording starts"),
		assert_eq(int(meta.get("first_player_index", -1)), 1, "Recorder should allow updating first player after recording starts"),
		assert_eq(str(players[0].get("active", {}).get("pokemon_name", "")) if players.size() > 0 and players[0] is Dictionary else "", "Regidrago V", "Recorder should replace placeholder initial state with the real opening board"),
		assert_eq(opening_tags.get("0", []), ["Regidrago V"], "Updated opening state should flow through to llm digest"),
	])
	_cleanup_root()
	return result


func test_exports_turns_json_grouped_by_turn() -> String:
	_cleanup_root()
	var recorder_result: Variant = _new_recorder()
	if recorder_result is Dictionary and not bool((recorder_result as Dictionary).get("ok", false)):
		return str((recorder_result as Dictionary).get("error", "Recorder setup failed"))

	var recorder: Object = (recorder_result as Dictionary).get("value") as Object
	recorder.call("start_match", _make_match_meta(), {
		"players": [
			{"hand": [{"card_name": "Dreepy"}]},
			{"hand": [{"card_name": "Entei V"}]},
		],
	})
	recorder.call("record_event", _make_event(0, "match_started"))
	recorder.call("record_event", _make_event(1, "state_snapshot", {"snapshot_reason": "match_start"}))
	recorder.call("record_event", _make_event(2, "choice_context", {
		"title": "Choose action",
		"prompt_type": "pokemon_action",
		"items": ["Attack", "Retreat"],
	}))
	recorder.call("record_event", _make_event(3, "action_selected", {
		"selection_source": "dialog",
		"selected_index": 0,
		"selected_labels": ["Attack"],
	}))
	recorder.call("record_event", _make_event(4, "action_resolved", {"description": "Player 1 used Test Slash"}))
	recorder.call("record_event", _make_event(5, "state_snapshot", {"snapshot_reason": "after_action_resolved"}))
	recorder.call("record_event", _make_event(6, "match_ended", {"winner_index": 0}))
	recorder.call("finalize_match", {"winner_index": 0, "reason": "prize_out", "turn_count": 1})

	var match_dir := _open_first_match_dir()
	var turns_path := match_dir.path_join("turns.json")
	var turns_json := _read_json_file(turns_path)
	var turns: Array = turns_json.get("turns", [])
	var first_turn: Dictionary = turns[0] if not turns.is_empty() and turns[0] is Dictionary else {}
	var key_actions: Array = first_turn.get("key_actions", [])
	var key_choices: Array = first_turn.get("key_choices", [])
	var snapshot_reasons: Array = first_turn.get("snapshot_reasons", [])
	var first_choice: Dictionary = key_choices[0] if not key_choices.is_empty() and key_choices[0] is Dictionary else {}
	var selected_labels: Array = first_choice.get("selected_labels", [])
	var result := run_checks([
		assert_true(FileAccess.file_exists(turns_path), "Recorder should export turns.json"),
		assert_eq(turns.size(), 1, "turns.json should group events into one turn bucket here"),
		assert_eq(int(first_turn.get("turn_number", -1)), 1, "turn bucket should preserve turn number"),
		assert_contains(snapshot_reasons, "match_start", "turn bucket should include snapshot reasons"),
		assert_contains(snapshot_reasons, "after_action_resolved", "turn bucket should keep post-action snapshots"),
		assert_eq(key_choices.size(), 1, "turn bucket should keep compact key choice summaries"),
		assert_eq(selected_labels, ["Attack"], "turn bucket should preserve selected option labels for fast review"),
		assert_eq(key_actions.size(), 1, "turn bucket should keep compact key action summaries"),
	])
	_cleanup_root()
	return result


func test_exports_llm_digest_without_full_event_duplication() -> String:
	_cleanup_root()
	var recorder_result: Variant = _new_recorder()
	if recorder_result is Dictionary and not bool((recorder_result as Dictionary).get("ok", false)):
		return str((recorder_result as Dictionary).get("error", "Recorder setup failed"))

	var recorder: Object = (recorder_result as Dictionary).get("value") as Object
	recorder.call("start_match", {
		"mode": "local_human_vs_human",
		"player_labels": ["player_0", "player_1"],
		"player_archetypes": {"0": "dragapult", "1": "pokeflame"},
		"first_player_index": 0,
	}, {
		"players": [
			{"hand": [{"card_name": "Dreepy"}], "active": {"pokemon_name": "Dreepy"}},
			{"hand": [{"card_name": "Entei V"}], "active": {"pokemon_name": "Entei V"}},
		],
	})
	recorder.call("record_event", _make_event(0, "match_started"))
	recorder.call("record_event", _make_event(1, "state_snapshot", {"snapshot_reason": "match_start"}))
	recorder.call("record_event", _make_event(2, "choice_context", {
		"title": "Choose attack",
		"prompt_type": "pokemon_action",
	}))
	recorder.call("record_event", _make_event(3, "action_selected", {
		"selection_source": "dialog",
		"selected_index": 0,
		"selected_labels": ["Burning Rondo"],
		"title": "Choose attack",
		"prompt_type": "pokemon_action",
	}))
	recorder.call("record_event", _make_event(4, "action_resolved", {
		"description": "Player 1 used Burning Rondo",
		"data": {"attack_name": "Burning Rondo", "damage": 120},
	}))
	recorder.call("record_event", _make_event(3, "match_ended", {"winner_index": 1}))
	recorder.call("finalize_match", {"winner_index": 1, "reason": "prize_out", "turn_count": 1})

	var match_dir := _open_first_match_dir()
	var digest_path := match_dir.path_join("llm_digest.json")
	var digest := _read_json_file(digest_path)
	var meta: Dictionary = digest.get("meta", {})
	var turn_summaries: Array = digest.get("turn_summaries", [])
	var first_turn: Dictionary = turn_summaries[0] if not turn_summaries.is_empty() and turn_summaries[0] is Dictionary else {}
	var opening: Dictionary = digest.get("opening", {})
	var opening_tags: Dictionary = opening.get("opening_tags", {})
	var critical_sequences: Array = digest.get("critical_sequences", [])
	var inflection_points: Array = digest.get("inflection_points", [])
	var key_choices: Array = first_turn.get("key_choices", [])
	var first_choice: Dictionary = key_choices[0] if not key_choices.is_empty() and key_choices[0] is Dictionary else {}
	var result := run_checks([
		assert_true(FileAccess.file_exists(digest_path), "Recorder should export llm_digest.json"),
		assert_eq(int(meta.get("winner_index", -1)), 1, "llm digest meta should preserve winner"),
		assert_true(not digest.has("events"), "llm digest should not duplicate the full event stream"),
		assert_true(digest.has("opening"), "llm digest should include opening summary"),
		assert_true(digest.has("turn_summaries"), "llm digest should include turn summaries"),
		assert_eq(turn_summaries.size(), 1, "llm digest should compress this fixture into one turn summary"),
		assert_eq(int(first_turn.get("turn_number", -1)), 1, "turn summary should preserve turn number"),
		assert_eq(meta.get("player_labels", []), ["player_0", "player_1"], "llm digest meta should preserve player labels"),
		assert_eq(opening_tags.get("0", []), ["Dreepy"], "llm digest opening should preserve compact opening tags"),
		assert_eq(first_choice.get("selected_labels", []), ["Burning Rondo"], "llm digest should preserve selected labels in key choices"),
		assert_true(not critical_sequences.is_empty(), "llm digest should extract at least one critical sequence"),
		assert_true(not inflection_points.is_empty(), "llm digest should extract at least one inflection point"),
		assert_true(first_turn.has("key_actions"), "turn summary should keep compact key actions"),
	])
	_cleanup_root()
	return result


func test_survives_write_failure_without_raising_gameplay_breaking_errors() -> String:
	_cleanup_root()
	var root_dir := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(root_dir)
	var blocked_root := root_dir.path_join("blocked_root")
	var blocked_file := FileAccess.open(blocked_root, FileAccess.WRITE)
	if blocked_file != null:
		blocked_file.store_string("blocked")
		blocked_file.close()

	var script: Variant = _load_recorder_script()
	if script == null:
		_cleanup_root()
		return "BattleRecorder script is missing"

	var recorder = (script as GDScript).new()
	if not _configure_root(recorder, blocked_root):
		_cleanup_root()
		return "BattleRecorder root could not be configured"
	recorder.call("start_match", _make_match_meta())
	recorder.call("record_event", _make_event(0, "match_started"))
	recorder.call("finalize_match", {"winner_index": 0, "reason": "prize_out"})

	var blocked_exists := FileAccess.file_exists(blocked_root)
	var blocked_is_dir := DirAccess.dir_exists_absolute(blocked_root)
	_cleanup_root()
	return run_checks([
		assert_true(blocked_exists, "Failure fixture should remain a file"),
		assert_false(blocked_is_dir, "Failure fixture should not turn into a directory"),
	])
