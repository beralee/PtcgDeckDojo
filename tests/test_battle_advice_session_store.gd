class_name TestBattleAdviceSessionStore
extends TestBase

const StorePath := "res://scripts/engine/BattleAdviceSessionStore.gd"
const TEST_ROOT := "user://test_battle_advice"


func _cleanup_root() -> void:
	var root_path := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(root_path):
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


func _new_store() -> Variant:
	if not ResourceLoader.exists(StorePath):
		return {"ok": false, "error": "BattleAdviceSessionStore script is missing"}
	var script: GDScript = load(StorePath)
	var store = script.new()
	if store == null:
		return {"ok": false, "error": "BattleAdviceSessionStore could not be instantiated"}
	return {"ok": true, "value": store}


func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func test_create_session_starts_with_next_request_index_one() -> String:
	_cleanup_root()
	var store_result: Variant = _new_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "BattleAdviceSessionStore setup failed"))

	var store: Object = (store_result as Dictionary).get("value") as Object
	if not store.has_method("create_or_load_session"):
		return "BattleAdviceSessionStore is missing create_or_load_session"

	var session: Variant = store.call("create_or_load_session", TEST_ROOT.path_join("session_a"), 0)
	if not session is Dictionary:
		return "create_or_load_session should return a Dictionary"

	return run_checks([
		assert_eq(int((session as Dictionary).get("next_request_index", 0)), 1, "Session should start with request index 1"),
		assert_eq(String((session as Dictionary).get("latest_attempt_status", "")), "idle", "New session should start idle"),
	])


func test_failed_attempt_does_not_overwrite_latest_success() -> String:
	_cleanup_root()
	var store_result: Variant = _new_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "BattleAdviceSessionStore setup failed"))

	var store: Object = (store_result as Dictionary).get("value") as Object
	if not store.has_method("write_latest_success") or not store.has_method("write_latest_attempt") or not store.has_method("read_latest_success"):
		return "BattleAdviceSessionStore is missing persistence helpers"

	var match_dir := TEST_ROOT.path_join("session_b")
	store.call("write_latest_success", match_dir, {"status": "completed", "request_index": 1, "advice": {"strategic_thesis": "keep pressure"}})
	store.call("write_latest_attempt", match_dir, {"status": "failed", "request_index": 2, "errors": [{"message": "timeout"}]})
	var latest_success: Variant = store.call("read_latest_success", match_dir)
	if not latest_success is Dictionary:
		return "read_latest_success should return a Dictionary"
	var latest_advice_path := ProjectSettings.globalize_path(match_dir.path_join("advice/latest_advice.json"))
	var latest_advice_exists := FileAccess.file_exists(latest_advice_path)
	var latest_advice: Dictionary = {}
	if latest_advice_exists:
		var file := FileAccess.open(latest_advice_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			latest_advice = parsed if parsed is Dictionary else {}
			file.close()

	return run_checks([
		assert_eq(int((latest_success as Dictionary).get("request_index", 0)), 1, "Failed attempt must not overwrite latest_success"),
		assert_true(latest_advice_exists, "Failed attempt should persist latest_advice.json"),
		assert_eq(int(latest_advice.get("request_index", 0)), 2, "Latest advice artifact should capture the failed request index"),
	])


func test_success_write_updates_latest_advice() -> String:
	_cleanup_root()
	var store_result: Variant = _new_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "BattleAdviceSessionStore setup failed"))

	var store: Object = (store_result as Dictionary).get("value") as Object
	if not store.has_method("write_latest_success"):
		return "BattleAdviceSessionStore is missing write_latest_success"

	var match_dir := TEST_ROOT.path_join("session_c")
	store.call("write_latest_success", match_dir, {"status": "completed", "request_index": 3, "advice": {"strategic_thesis": "close out"}})
	var latest_advice_path := ProjectSettings.globalize_path(match_dir.path_join("advice/latest_advice.json"))
	var latest_advice := _read_json_file(latest_advice_path)
	return run_checks([
		assert_eq(int(latest_advice.get("request_index", 0)), 3, "Successful attempt should persist latest_advice.json"),
		assert_eq(String(latest_advice.get("status", "")), "completed", "Successful attempt should mirror status into latest_advice.json"),
	])


func test_request_debug_artifacts_use_fixed_filenames_under_advice() -> String:
	_cleanup_root()
	var store_result: Variant = _new_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "BattleAdviceSessionStore setup failed"))

	var store: Object = (store_result as Dictionary).get("value") as Object
	if not store.has_method("write_request_debug_artifact") or not store.has_method("read_request_debug_artifact"):
		return "BattleAdviceSessionStore is missing debug artifact helpers"

	var match_dir := TEST_ROOT.path_join("session_d")
	store.call("write_request_debug_artifact", match_dir, 4, "request", {"kind": "request", "request_index": 4})
	store.call("write_request_debug_artifact", match_dir, 4, "response", {"kind": "response", "request_index": 4})

	var request_path := ProjectSettings.globalize_path(match_dir.path_join("advice/advice_request_4.json"))
	var response_path := ProjectSettings.globalize_path(match_dir.path_join("advice/advice_response_4.json"))
	var request_payload: Dictionary = store.call("read_request_debug_artifact", match_dir, 4, "request")
	var response_payload: Dictionary = store.call("read_request_debug_artifact", match_dir, 4, "response")

	return run_checks([
		assert_true(FileAccess.file_exists(request_path), "Request debug artifact should use advice/advice_request_<n>.json"),
		assert_true(FileAccess.file_exists(response_path), "Response debug artifact should use advice/advice_response_<n>.json"),
		assert_eq(String(request_payload.get("kind", "")), "request", "Request debug artifact payload should be readable from the fixed filename"),
		assert_eq(String(response_payload.get("kind", "")), "response", "Response debug artifact payload should be readable from the fixed filename"),
	])
