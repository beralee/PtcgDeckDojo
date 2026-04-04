class_name TestBattleAdviceService
extends TestBase

const ServicePath := "res://scripts/engine/BattleAdviceService.gd"
const StorePath := "res://scripts/engine/BattleAdviceSessionStore.gd"
const TEST_ROOT := "user://test_battle_advice_service"


class FakeZenMuxClient:
	extends RefCounted

	var response: Dictionary = {}
	var recorded_payloads: Array[Dictionary] = []
	var timeout_seconds: float = 0.0

	func set_timeout_seconds(value: float) -> void:
		timeout_seconds = value

	func request_json(_parent: Node, _endpoint: String, _api_key: String, payload: Dictionary, callback: Callable) -> int:
		recorded_payloads.append(payload.duplicate(true))
		callback.call(response.duplicate(true))
		return OK


class FakeAdviceContextBuilder:
	extends RefCounted

	var last_session: Dictionary = {}

	func build_request_context(live_snapshot: Dictionary, _initial_snapshot: Dictionary, _match_dir: String, view_player: int, session: Dictionary) -> Dictionary:
		last_session = session.duplicate(true)
		return {
			"session": {
				"session_id": str(session.get("session_id", "")),
				"request_index": int(session.get("request_index", session.get("next_request_index", 1))),
				"last_advice_summary": str(session.get("last_advice_summary", "")),
				"current_player_index": view_player,
			},
			"visibility_rules": {
				"known": ["board"],
				"unknown": ["opponent_hand"],
			},
			"current_position": {
				"turn_number": int(live_snapshot.get("turn_number", 0)),
				"players": [],
				"decklists": [],
			},
			"delta_since_last_advice": {
				"summary_lines": [],
				"detail_events": [
					{"event_index": int(live_snapshot.get("event_index", 0))},
				],
			},
		}


class FakeAdvicePromptBuilder:
	extends RefCounted

	func build_request_payload(session_block: Dictionary, visibility_rules: Dictionary, current_position: Dictionary, delta_block: Dictionary) -> Dictionary:
		return {
			"schema_version": "battle_advice_v1",
			"system_prompt_version": "battle_advice_v1",
			"instructions": PackedStringArray(["Return JSON only."]),
			"response_format": {
				"type": "object",
				"properties": {
					"strategic_thesis": {"type": "string"},
				},
			},
			"session": session_block.duplicate(true),
			"visibility_rules": visibility_rules.duplicate(true),
			"current_position": current_position.duplicate(true),
			"delta_since_last_advice": delta_block.duplicate(true),
		}


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


func _new_store() -> Variant:
	if not ResourceLoader.exists(StorePath):
		return {"ok": false, "error": "BattleAdviceSessionStore script is missing"}
	var script: GDScript = load(StorePath)
	var store = script.new()
	if store == null:
		return {"ok": false, "error": "BattleAdviceSessionStore could not be instantiated"}
	return {"ok": true, "value": store}


func _new_service(store: Object, client: RefCounted, context_builder: RefCounted, prompt_builder: RefCounted) -> Variant:
	if not ResourceLoader.exists(ServicePath):
		return {"ok": false, "error": "BattleAdviceService script is missing"}
	var script: GDScript = load(ServicePath)
	var service = script.new()
	if service == null:
		return {"ok": false, "error": "BattleAdviceService could not be instantiated"}
	if not service.has_method("configure_dependencies"):
		return {"ok": false, "error": "BattleAdviceService is missing configure_dependencies"}
	service.call("configure_dependencies", client, context_builder, store, prompt_builder)
	return {"ok": true, "value": service}


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func test_generate_advice_ignores_new_request_while_running() -> String:
	var store_result: Variant = _new_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "BattleAdviceSessionStore setup failed"))

	var client := FakeZenMuxClient.new()
	var context_builder := FakeAdviceContextBuilder.new()
	var prompt_builder := FakeAdvicePromptBuilder.new()
	var service_result: Variant = _new_service((store_result as Dictionary).get("value") as Object, client, context_builder, prompt_builder)
	if service_result is Dictionary and not bool((service_result as Dictionary).get("ok", false)):
		return str((service_result as Dictionary).get("error", "BattleAdviceService setup failed"))

	var service: Object = (service_result as Dictionary).get("value") as Object
	if not service.has_method("set_busy_for_test"):
		return "BattleAdviceService is missing set_busy_for_test"
	service.call("set_busy_for_test", true)
	var host := Node.new()
	var result: Variant = service.call("generate_advice", host, TEST_ROOT.path_join("service_busy"), {}, {"players": []}, {"endpoint": "", "api_key": "", "model": ""}, 0)
	host.free()
	if not result is Dictionary:
		return "generate_advice should return a Dictionary"
	return run_checks([
		assert_eq(String((result as Dictionary).get("status", "")), "ignored", "Busy service should ignore concurrent requests"),
	])


func test_failed_response_writes_latest_attempt_but_preserves_latest_success() -> String:
	_cleanup_root()
	var store_result: Variant = _new_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "BattleAdviceSessionStore setup failed"))

	var store: Object = (store_result as Dictionary).get("value") as Object
	var match_dir := TEST_ROOT.path_join("service_failure")
	store.call("write_latest_success", match_dir, {"status": "completed", "request_index": 1, "session_id": "session_a", "advice": {"strategic_thesis": "keep pressure"}})

	var client := FakeZenMuxClient.new()
	client.response = {"status": "error", "message": "timeout", "error_type": "request_error"}
	var service_result: Variant = _new_service(store, client, FakeAdviceContextBuilder.new(), FakeAdvicePromptBuilder.new())
	if service_result is Dictionary and not bool((service_result as Dictionary).get("ok", false)):
		return str((service_result as Dictionary).get("error", "BattleAdviceService setup failed"))

	var service: Object = (service_result as Dictionary).get("value") as Object
	var completions: Array[Dictionary] = []
	service.call("connect", "advice_completed", Callable(self, "_capture_advice_completion").bind(completions))
	var host := Node.new()
	var result: Variant = service.call("generate_advice", host, match_dir, {"turn_number": 5, "event_index": 5}, {"players": []}, {"endpoint": "", "api_key": "", "model": "test-model"}, 0)
	host.free()
	if not result is Dictionary:
		return "generate_advice should return a Dictionary"

	var latest_success: Dictionary = store.call("read_latest_success", match_dir)
	var latest_advice := _read_json(match_dir.path_join("advice/latest_advice.json"))
	return run_checks([
		assert_eq(completions.size(), 1, "Failure path should emit exactly one completion"),
		assert_eq(String((completions[0] as Dictionary).get("status", "")) if not completions.is_empty() else "", "failed", "Failure path should emit a failed completion"),
		assert_eq(int(latest_success.get("request_index", 0)), 1, "Failure path should preserve the previous latest_success artifact"),
		assert_eq(String(latest_advice.get("status", "")), "failed", "Failure path should write latest_advice as failed"),
	])


func test_success_response_writes_latest_success_and_response_artifact() -> String:
	_cleanup_root()
	var store_result: Variant = _new_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "BattleAdviceSessionStore setup failed"))

	var store: Object = (store_result as Dictionary).get("value") as Object
	var client := FakeZenMuxClient.new()
	client.response = {
		"strategic_thesis": "Take two prizes safely",
		"current_turn_main_line": [{"step": 1, "action": "Attack", "why": "Secure knockout"}],
		"conditional_branches": [],
		"prize_plan": [{"horizon": "next_turn", "goal": "Stay ahead on prizes"}],
		"why_this_line": ["It pressures the active attacker."],
		"risk_watchouts": [{"risk": "Counter gust", "mitigation": "Keep bench small"}],
		"confidence": "medium",
		"summary_for_next_request": "Took the safest prize line.",
	}
	var service_result: Variant = _new_service(store, client, FakeAdviceContextBuilder.new(), FakeAdvicePromptBuilder.new())
	if service_result is Dictionary and not bool((service_result as Dictionary).get("ok", false)):
		return str((service_result as Dictionary).get("error", "BattleAdviceService setup failed"))

	var service: Object = (service_result as Dictionary).get("value") as Object
	var match_dir := TEST_ROOT.path_join("service_success")
	var host := Node.new()
	service.call("generate_advice", host, match_dir, {"turn_number": 5, "event_index": 6}, {"players": []}, {"endpoint": "", "api_key": "", "model": "test-model"}, 0)
	host.free()

	var latest_success: Dictionary = store.call("read_latest_success", match_dir)
	var response_artifact := _read_json(match_dir.path_join("advice/advice_response_1.json"))
	return run_checks([
		assert_eq(String(latest_success.get("status", "")), "completed", "Success path should write latest_success.json"),
		assert_eq(String(latest_success.get("strategic_thesis", "")), "Take two prizes safely", "Success path should persist the normalized advice"),
		assert_eq(String(response_artifact.get("status", "")), "completed", "Success path should write a completed response artifact"),
	])


func test_second_request_reuses_session_id_and_increments_request_count() -> String:
	_cleanup_root()
	var store_result: Variant = _new_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "BattleAdviceSessionStore setup failed"))

	var store: Object = (store_result as Dictionary).get("value") as Object
	var client := FakeZenMuxClient.new()
	client.response = {
		"strategic_thesis": "Keep pressure",
		"current_turn_main_line": [{"step": 1, "action": "Attack", "why": "Keep tempo"}],
		"conditional_branches": [],
		"prize_plan": [{"horizon": "next_turn", "goal": "Stay ahead"}],
		"why_this_line": ["It preserves the board."],
		"risk_watchouts": [{"risk": "Brick", "mitigation": "Hold draw support"}],
		"confidence": "high",
		"summary_for_next_request": "Stayed ahead.",
	}
	var service_result: Variant = _new_service(store, client, FakeAdviceContextBuilder.new(), FakeAdvicePromptBuilder.new())
	if service_result is Dictionary and not bool((service_result as Dictionary).get("ok", false)):
		return str((service_result as Dictionary).get("error", "BattleAdviceService setup failed"))

	var service: Object = (service_result as Dictionary).get("value") as Object
	var match_dir := TEST_ROOT.path_join("service_session_reuse")
	var host_a := Node.new()
	service.call("generate_advice", host_a, match_dir, {"turn_number": 5, "event_index": 5}, {"players": []}, {"endpoint": "", "api_key": "", "model": "test-model"}, 0)
	host_a.free()
	var first_session: Dictionary = store.call("read_session", match_dir)
	var host_b := Node.new()
	service.call("generate_advice", host_b, match_dir, {"turn_number": 6, "event_index": 8}, {"players": []}, {"endpoint": "", "api_key": "", "model": "test-model"}, 0)
	host_b.free()
	var second_session: Dictionary = store.call("read_session", match_dir)
	return run_checks([
		assert_eq(int(second_session.get("request_count", 0)), 2, "Repeated requests should increment request_count"),
		assert_eq(String(second_session.get("session_id", "")), String(first_session.get("session_id", "")), "Repeated requests should reuse the same session_id"),
	])


func test_missing_or_corrupted_session_is_rebuilt_non_fatally() -> String:
	_cleanup_root()
	var store_result: Variant = _new_store()
	if store_result is Dictionary and not bool((store_result as Dictionary).get("ok", false)):
		return str((store_result as Dictionary).get("error", "BattleAdviceSessionStore setup failed"))

	var store: Object = (store_result as Dictionary).get("value") as Object
	if not store.has_method("write_raw_session_for_test") or not store.has_method("read_session"):
		return "BattleAdviceSessionStore is missing test session helpers"
	var match_dir := TEST_ROOT.path_join("service_recover_session")
	store.call("write_raw_session_for_test", match_dir, "{not-json")
	var session: Dictionary = store.call("create_or_load_session", match_dir, 0)
	return run_checks([
		assert_eq(int(session.get("next_request_index", 0)), 1, "Corrupted session should be rebuilt with default counters"),
		assert_eq(String(session.get("latest_attempt_status", "")), "idle", "Rebuilt session should return to idle"),
		assert_true(not (store.call("read_session", match_dir) as Dictionary).is_empty(), "Recovered session should be readable after rebuild"),
	])


func _capture_advice_completion(result: Dictionary, completions: Array[Dictionary]) -> void:
	completions.append(result)
