class_name TestZenMuxClient
extends TestBase

const ZenMuxClientPath := "res://scripts/network/ZenMuxClient.gd"


func _load_client_script() -> Variant:
	if not ResourceLoader.exists(ZenMuxClientPath):
		return null
	return load(ZenMuxClientPath)


func _new_client() -> Variant:
	var script: Variant = _load_client_script()
	if script == null:
		return {"ok": false, "error": "ZenMuxClient script is missing"}

	var client = (script as GDScript).new()
	if client == null:
		return {"ok": false, "error": "ZenMuxClient could not be instantiated"}

	return {"ok": true, "value": client}


func test_parse_success_response_returns_content_json() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	if not client.has_method("_parse_chat_response"):
		return "ZenMuxClient is missing _parse_chat_response"

	var response: Variant = client.call(
		"_parse_chat_response",
		200,
		"{\"choices\":[{\"message\":{\"content\":\"{\\\"ok\\\":true}\"}}]}"
	)
	if not response is Dictionary:
		return "ZenMuxClient should return a Dictionary for successful chat responses"

	return run_checks([
		assert_true(bool((response as Dictionary).get("ok", false)), "Parsed content JSON should expose ok=true"),
	])


func test_parse_http_failure_returns_error_status() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	if not client.has_method("_parse_error_response"):
		return "ZenMuxClient is missing _parse_error_response"

	var response: Variant = client.call("_parse_error_response", 401, HTTPRequest.RESULT_SUCCESS, "unauthorized")
	if not response is Dictionary:
		return "ZenMuxClient should return a Dictionary for error responses"

	return run_checks([
		assert_eq(String((response as Dictionary).get("status", "")), "error", "HTTP failures should be normalized as error status"),
		assert_eq(int((response as Dictionary).get("http_code", 0)), 401, "HTTP failures should preserve the response code"),
	])


func test_parse_success_response_rejects_non_json_message_content() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	var response: Variant = client.call(
		"_parse_chat_response",
		200,
		"{\"choices\":[{\"message\":{\"content\":\"not valid json\"}}]}"
	)
	if not response is Dictionary:
		return "ZenMuxClient should return a Dictionary for invalid content JSON"

	return run_checks([
		assert_eq(String((response as Dictionary).get("status", "")), "error", "Non-JSON message content should be normalized as an error"),
		assert_eq(String((response as Dictionary).get("error_type", "")), "invalid_content_json", "Non-JSON message content should expose a stable error type"),
	])


func test_normalize_endpoint_appends_chat_completions_for_base_api_path() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	if not client.has_method("_normalize_endpoint"):
		return "ZenMuxClient is missing _normalize_endpoint"

	return run_checks([
		assert_eq(
			String(client.call("_normalize_endpoint", "https://zenmux.ai/api/v1")),
			"https://zenmux.ai/api/v1/chat/completions",
			"Base API endpoint should expand to chat/completions"
		),
		assert_eq(
			String(client.call("_normalize_endpoint", "https://zenmux.ai/api/v1/chat/completions")),
			"https://zenmux.ai/api/v1/chat/completions",
			"Fully qualified chat/completions endpoint should stay unchanged"
		),
	])


func test_build_request_payload_wraps_prompt_contract_into_chat_completions_shape() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	if not client.has_method("_build_request_payload"):
		return "ZenMuxClient is missing _build_request_payload"

	var payload: Variant = client.call("_build_request_payload", {
		"model": "openai/gpt-5.4",
		"system_prompt_version": "battle_review_stage1_v1",
		"instructions": PackedStringArray([
			"Use only the provided match data.",
			"Return JSON only with the agreed keys.",
		]),
		"response_format": {
			"type": "object",
			"properties": {"winner_index": {"type": "integer"}},
		},
		"match": {"winner_index": 0, "turn_summaries": [{"turn_number": 5}]},
	})
	if not payload is Dictionary:
		return "_build_request_payload should return a Dictionary"

	var messages: Array = (payload as Dictionary).get("messages", [])
	var response_format: Dictionary = (payload as Dictionary).get("response_format", {})
	var json_schema: Dictionary = response_format.get("json_schema", {})
	var user_content := str(((messages[1] as Dictionary).get("content", ""))) if messages.size() > 1 and messages[1] is Dictionary else ""
	return run_checks([
		assert_eq(String((payload as Dictionary).get("model", "")), "openai/gpt-5.4", "Request payload should preserve the model"),
		assert_eq(messages.size(), 2, "Prompt payload should be converted into system and user chat messages"),
		assert_eq(String(response_format.get("type", "")), "json_schema", "Prompt payload should request a json_schema response"),
		assert_eq(String(json_schema.get("name", "")), "battle_review_stage1_v1", "json_schema should use the prompt version as the schema name"),
		assert_true(bool(json_schema.get("strict", false)), "json_schema responses should be strict"),
		assert_true(user_content.contains("\"match\""), "User message should carry the match payload"),
		assert_true(user_content.contains("\"turn_summaries\""), "User message should preserve compact turn summaries"),
	])
