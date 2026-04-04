class_name BattleAdviceService
extends RefCounted

signal status_changed(status: String, context: Dictionary)
signal advice_completed(result: Dictionary)

const BattleAdviceSessionStoreScript = preload("res://scripts/engine/BattleAdviceSessionStore.gd")
const BattleAdviceContextBuilderScript = preload("res://scripts/engine/BattleAdviceContextBuilder.gd")
const BattleAdvicePromptBuilderScript = preload("res://scripts/engine/BattleAdvicePromptBuilder.gd")
const ZenMuxClientScript = preload("res://scripts/network/ZenMuxClient.gd")

var _client = ZenMuxClientScript.new()
var _context_builder = BattleAdviceContextBuilderScript.new()
var _store = BattleAdviceSessionStoreScript.new()
var _prompt_builder = BattleAdvicePromptBuilderScript.new()
var _busy := false


func configure_dependencies(client: Variant, context_builder: Variant, store: Variant, prompt_builder: Variant) -> void:
	if client != null:
		_client = client
	if context_builder != null:
		_context_builder = context_builder
	if store != null:
		_store = store
	if prompt_builder != null:
		_prompt_builder = prompt_builder


func set_busy_for_test(value: bool) -> void:
	_busy = value


func generate_advice(parent: Node, match_dir: String, live_snapshot: Dictionary, initial_snapshot: Dictionary, api_config: Dictionary, view_player: int) -> Dictionary:
	if _busy:
		return {"status": "ignored"}

	_busy = true
	_set_status("running", {"match_dir": match_dir})
	if _client != null and _client.has_method("set_timeout_seconds"):
		_client.call("set_timeout_seconds", float(api_config.get("timeout_seconds", 30.0)))

	var session: Dictionary = _store.create_or_load_session(match_dir, view_player)
	var request_index := int(session.get("next_request_index", 1))
	session = _prepare_running_session(session, request_index, view_player)
	_store.write_session(match_dir, session)

	var request_session: Dictionary = session.duplicate(true)
	request_session["request_index"] = request_index
	var request_context: Dictionary = _context_builder.build_request_context(live_snapshot, initial_snapshot, match_dir, view_player, request_session)
	var payload: Dictionary = _prompt_builder.build_request_payload(
		request_context.get("session", {}),
		request_context.get("visibility_rules", {}),
		request_context.get("current_position", {}),
		request_context.get("delta_since_last_advice", {})
	)
	payload["model"] = str(api_config.get("model", ""))
	_store.write_request_debug_artifact(match_dir, request_index, "request", payload)

	var request_error: int = _client.request_json(
		parent,
		str(api_config.get("endpoint", "")),
		str(api_config.get("api_key", "")),
		payload,
		_on_response.bind(match_dir, live_snapshot, view_player, request_index, request_context)
	)
	if request_error != OK:
		var failed: Dictionary = _build_failed_result({
			"message": "ZenMux request could not be started",
			"request_error": request_error,
		}, match_dir, live_snapshot, view_player, request_index, session)
		_finalize_failed_request(match_dir, view_player, request_index, failed)
		return failed

	return {
		"status": "running",
		"session_id": str(session.get("session_id", "")),
		"request_index": request_index,
	}


func _on_response(
	response: Dictionary,
	match_dir: String,
	live_snapshot: Dictionary,
	view_player: int,
	request_index: int,
	request_context: Dictionary
) -> void:
	if String(response.get("status", "")) == "error":
		var failed: Dictionary = _build_failed_result(response, match_dir, live_snapshot, view_player, request_index, _store.read_session(match_dir))
		_finalize_failed_request(match_dir, view_player, request_index, failed)
		return

	var completed: Dictionary = _build_completed_result(response, match_dir, live_snapshot, view_player, request_index)
	var detail_events: Array = (request_context.get("delta_since_last_advice", {}) as Dictionary).get("detail_events", [])
	var latest_event_index := _last_event_index(detail_events)
	_finalize_successful_request(match_dir, view_player, request_index, completed, latest_event_index, int(live_snapshot.get("turn_number", 0)))


func _prepare_running_session(session: Dictionary, request_index: int, view_player: int) -> Dictionary:
	var next_session := session.duplicate(true)
	next_session["updated_at"] = Time.get_datetime_string_from_system()
	next_session["request_count"] = int(next_session.get("request_count", 0)) + 1
	next_session["latest_attempt_status"] = "running"
	next_session["latest_attempt_request_index"] = request_index
	next_session["next_request_index"] = request_index + 1
	next_session["last_player_view_index"] = view_player
	return next_session


func _build_completed_result(response: Dictionary, match_dir: String, live_snapshot: Dictionary, view_player: int, request_index: int) -> Dictionary:
	var normalized := response.duplicate(true)
	normalized["status"] = "completed"
	normalized["generated_at"] = Time.get_datetime_string_from_system()
	normalized["session_id"] = str(_store.read_session(match_dir).get("session_id", ""))
	normalized["request_index"] = request_index
	normalized["turn_number"] = int(live_snapshot.get("turn_number", 0))
	normalized["player_index"] = view_player
	return normalized


func _build_failed_result(response: Dictionary, match_dir: String, live_snapshot: Dictionary, view_player: int, request_index: int, session: Dictionary) -> Dictionary:
	return {
		"status": "failed",
		"generated_at": Time.get_datetime_string_from_system(),
		"session_id": str(session.get("session_id", "")),
		"request_index": request_index,
		"turn_number": int(live_snapshot.get("turn_number", 0)),
		"player_index": view_player,
		"errors": [{
			"message": str(response.get("message", "Unknown error")),
			"error_type": str(response.get("error_type", "")),
			"http_code": int(response.get("http_code", 0)),
			"request_error": int(response.get("request_error", 0)),
		}],
		"raw_provider_response": response.duplicate(true),
	}


func _finalize_successful_request(match_dir: String, view_player: int, request_index: int, completed: Dictionary, latest_event_index: int, turn_number: int) -> void:
	_store.write_request_debug_artifact(match_dir, request_index, "response", completed)
	_store.write_latest_success(match_dir, completed)

	var session: Dictionary = _store.read_session(match_dir)
	if session.is_empty():
		session = _store.create_or_load_session(match_dir, view_player)
	session["updated_at"] = Time.get_datetime_string_from_system()
	session["latest_attempt_status"] = "completed"
	session["latest_attempt_request_index"] = request_index
	session["latest_success_request_index"] = request_index
	session["last_synced_event_index"] = latest_event_index
	session["last_synced_turn_number"] = turn_number
	session["last_advice_summary"] = str(completed.get("summary_for_next_request", ""))
	session["last_player_view_index"] = view_player
	_store.write_session(match_dir, session)

	_busy = false
	_set_status("completed", {"match_dir": match_dir, "request_index": request_index})
	advice_completed.emit(completed)


func _finalize_failed_request(match_dir: String, view_player: int, request_index: int, failed: Dictionary) -> void:
	_store.write_request_debug_artifact(match_dir, request_index, "response", failed)
	_store.write_latest_attempt(match_dir, failed)

	var session: Dictionary = _store.read_session(match_dir)
	if session.is_empty():
		session = _store.create_or_load_session(match_dir, view_player)
	session["updated_at"] = Time.get_datetime_string_from_system()
	session["latest_attempt_status"] = "failed"
	session["latest_attempt_request_index"] = request_index
	session["last_player_view_index"] = view_player
	_store.write_session(match_dir, session)

	_busy = false
	_set_status("failed", {"match_dir": match_dir, "request_index": request_index})
	advice_completed.emit(failed)


func _last_event_index(detail_events: Array) -> int:
	var latest := 0
	for event_variant: Variant in detail_events:
		if not (event_variant is Dictionary):
			continue
		latest = maxi(latest, int((event_variant as Dictionary).get("event_index", 0)))
	return latest


func _set_status(status: String, context: Dictionary) -> void:
	status_changed.emit(status, context)
