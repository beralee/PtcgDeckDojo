class_name TestZenMuxClient
extends TestBase

const ZenMuxClientPath := "res://scripts/network/ZenMuxClient.gd"


class AsyncFallbackProbeClient extends ZenMuxClient:
	var async_fallback_called := false
	var captured_parent_valid := false
	var captured_url := ""
	var captured_api_key := ""
	var captured_payload: Dictionary = {}

	func _request_json_payload_via_python_fallback_async(
		parent: Node,
		request_url: String,
		api_key: String,
		request_payload: Dictionary,
		_callback: Callable
	) -> int:
		async_fallback_called = true
		captured_parent_valid = parent != null and is_instance_valid(parent)
		captured_url = request_url
		captured_api_key = api_key
		captured_payload = request_payload.duplicate(true)
		return OK


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


func test_parse_success_response_accepts_json_code_fence() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	var response: Variant = client.call(
		"_parse_chat_response",
		200,
		"{\"choices\":[{\"message\":{\"content\":\"```json\\n{\\\"ok\\\":true}\\n```\"}}]}"
	)
	if not response is Dictionary:
		return "ZenMuxClient should return a Dictionary for fenced JSON"

	return run_checks([
		assert_true(bool((response as Dictionary).get("ok", false)), "Fenced JSON should be extracted and parsed"),
	])


func test_parse_success_response_accepts_responses_api_output_text() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	var response: Variant = client.call(
		"_parse_chat_response",
		200,
		"{\"output_text\":\"{\\\"ok\\\":true}\"}"
	)
	if not response is Dictionary:
		return "ZenMuxClient should return a Dictionary for Responses API output_text"

	return run_checks([
		assert_true(bool((response as Dictionary).get("ok", false)), "Responses API output_text should be parsed"),
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


func test_configure_tls_supports_headless_https_fallback() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	if not client.has_method("set_allow_unsafe_tls"):
		return "ZenMuxClient is missing set_allow_unsafe_tls"
	if not client.has_method("_configure_tls"):
		return "ZenMuxClient is missing _configure_tls"

	var request := HTTPRequest.new()
	client.call("set_allow_unsafe_tls", true)
	client.call("_configure_tls", request)
	client.call("set_allow_unsafe_tls", false)
	client.call("_configure_tls", request)
	request.free()
	return ""


func test_http_transport_failure_starts_python_fallback_asynchronously() -> String:
	var client := AsyncFallbackProbeClient.new()
	var parent := Node.new()
	var request := HTTPRequest.new()
	request.set_meta("zenmux_request_url", "https://zenmux.ai/api/v1/chat/completions")
	request.set_meta("zenmux_api_key", "test-key")
	request.set_meta("zenmux_request_payload", {"model": "test-model", "messages": []})
	parent.add_child(request)
	var callback_state := {"called": false}
	var callback := func(_response: Dictionary) -> void:
		callback_state["called"] = true

	client.call(
		"_on_request_completed",
		HTTPRequest.RESULT_CANT_CONNECT,
		0,
		PackedStringArray(),
		PackedByteArray(),
		request,
		callback
	)
	var result := run_checks([
		assert_true(client.async_fallback_called, "HTTP transport failure should start Python fallback"),
		assert_true(client.captured_parent_valid, "Async fallback should be attached to the same live parent node"),
		assert_eq(client.captured_url, "https://zenmux.ai/api/v1/chat/completions", "Async fallback should reuse the failed request URL"),
		assert_eq(client.captured_api_key, "test-key", "Async fallback should reuse the API key"),
		assert_eq(str(client.captured_payload.get("model", "")), "test-model", "Async fallback should reuse the built request payload"),
		assert_false(bool(callback_state.get("called", false)), "HTTP failure callback should not be called synchronously while fallback is pending"),
	])
	parent.free()
	return result


func test_parse_proxy_url_accepts_common_proxy_formats() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	if not client.has_method("_parse_proxy_url"):
		return "ZenMuxClient is missing _parse_proxy_url"

	var local_proxy: Dictionary = client.call("_parse_proxy_url", "http://127.0.0.1:7897")
	var auth_proxy: Dictionary = client.call("_parse_proxy_url", "https://user:pass@proxy.example.com:8443/path")
	var no_port_proxy: Dictionary = client.call("_parse_proxy_url", "proxy.example.com")
	return run_checks([
		assert_eq(str(local_proxy.get("host", "")), "127.0.0.1", "Proxy host should parse from localhost URL"),
		assert_eq(int(local_proxy.get("port", 0)), 7897, "Proxy port should parse from localhost URL"),
		assert_eq(str(auth_proxy.get("host", "")), "proxy.example.com", "Proxy parser should remove credentials"),
		assert_eq(int(auth_proxy.get("port", 0)), 8443, "Proxy parser should preserve explicit HTTPS proxy port"),
		assert_eq(str(no_port_proxy.get("host", "")), "proxy.example.com", "Proxy parser should accept bare host"),
		assert_eq(int(no_port_proxy.get("port", 0)), 80, "Proxy parser should default bare host to HTTP proxy port"),
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
		"max_tokens": 420,
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
	var user_content := str(((messages[1] as Dictionary).get("content", ""))) if messages.size() > 1 and messages[1] is Dictionary else ""
	var system_content := str(((messages[0] as Dictionary).get("content", ""))) if messages.size() > 0 and messages[0] is Dictionary else ""
	return run_checks([
		assert_eq(String((payload as Dictionary).get("model", "")), "openai/gpt-5.4", "Request payload should preserve the model"),
		assert_eq(int((payload as Dictionary).get("max_tokens", 0)), 420, "Request payload should preserve max_tokens for latency control"),
		assert_eq(((payload as Dictionary).get("reasoning", {}) as Dictionary).get("enabled", true), false, "ZenMux reasoning should be disabled by default"),
		assert_eq(((payload as Dictionary).get("thinking", {}) as Dictionary).get("type", ""), "disabled", "Provider thinking mode should be disabled by default"),
		assert_eq(messages.size(), 2, "Prompt payload should be converted into system and user chat messages"),
		assert_false((payload as Dictionary).has("response_format"), "ZenMux payload should avoid provider-specific structured output parameters"),
		assert_true(system_content.contains("battle_review_stage1_v1"), "System prompt should include the schema name"),
		assert_true(system_content.contains("\"winner_index\""), "System prompt should include the JSON schema contract"),
		assert_true(user_content.contains("\"match\""), "User message should carry the match payload"),
		assert_true(user_content.contains("\"turn_summaries\""), "User message should preserve compact turn summaries"),
	])


func test_build_request_payload_converts_openai_response_format_to_prompt_contract() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	var payload: Variant = client.call("_build_request_payload", {
		"model": "deepseek/deepseek-v4-pro",
		"messages": [{
			"role": "system",
			"content": "Return JSON only.",
		}, {
			"role": "user",
			"content": "hello",
		}],
		"response_format": {
			"type": "json_schema",
			"json_schema": {
				"name": "deck_discussion_v2",
				"strict": true,
				"schema": {
					"type": "object",
					"properties": {"answer_markdown": {"type": "string"}},
				},
			},
		},
	})
	if not payload is Dictionary:
		return "_build_request_payload should return a Dictionary"

	var messages: Array = (payload as Dictionary).get("messages", [])
	var system_content := str(((messages[0] as Dictionary).get("content", ""))) if messages.size() > 0 and messages[0] is Dictionary else ""
	return run_checks([
		assert_eq(String((payload as Dictionary).get("model", "")), "deepseek/deepseek-v4-pro", "Request payload should preserve arbitrary ZenMux model ids"),
		assert_eq(((payload as Dictionary).get("reasoning", {}) as Dictionary).get("enabled", true), false, "Chat payloads should disable ZenMux reasoning by default"),
		assert_eq(((payload as Dictionary).get("thinking", {}) as Dictionary).get("type", ""), "disabled", "Chat payloads should disable provider thinking mode by default"),
		assert_false((payload as Dictionary).has("response_format"), "OpenAI response_format should not be sent to arbitrary ZenMux models"),
		assert_true(system_content.contains("deck_discussion_v2"), "Schema name should be preserved in prompt contract"),
		assert_true(system_content.contains("answer_markdown"), "Schema body should be preserved in prompt contract"),
	])


func test_build_request_payload_preserves_explicit_reasoning_override() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	var payload: Variant = client.call("_build_request_payload", {
		"model": "openai/gpt-5.4",
		"messages": [{
			"role": "user",
			"content": "hello",
		}],
		"reasoning": {"effort": "low"},
	})
	if not payload is Dictionary:
		return "_build_request_payload should return a Dictionary"

	var reasoning: Dictionary = (payload as Dictionary).get("reasoning", {}) as Dictionary
	return run_checks([
		assert_eq(str(reasoning.get("effort", "")), "low", "Explicit reasoning config should be preserved for future opt-in use"),
		assert_false(reasoning.has("enabled"), "Explicit reasoning config should not be overwritten by the default disabled policy"),
		assert_false((payload as Dictionary).has("thinking"), "Explicit reasoning opt-in should not be contradicted by default thinking=disabled"),
	])


func test_build_request_payload_preserves_explicit_thinking_override() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	var payload: Variant = client.call("_build_request_payload", {
		"model": "z-ai/glm-5.1",
		"messages": [{
			"role": "user",
			"content": "hello",
		}],
		"thinking": {"type": "enabled"},
	})
	if not payload is Dictionary:
		return "_build_request_payload should return a Dictionary"

	var thinking: Dictionary = (payload as Dictionary).get("thinking", {}) as Dictionary
	return run_checks([
		assert_eq(str(thinking.get("type", "")), "enabled", "Explicit provider thinking config should be preserved"),
		assert_false((payload as Dictionary).has("reasoning"), "Explicit provider thinking opt-in should not receive default reasoning=disabled"),
	])


func test_build_request_payload_disables_qwen_thinking_with_provider_flag_and_prompt_switch() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	var payload: Variant = client.call("_build_request_payload", {
		"model": "qwen/qwen3.6-plus",
		"messages": [{
			"role": "system",
			"content": "Return JSON only.",
		}, {
			"role": "user",
			"content": "hello",
		}],
	})
	if not payload is Dictionary:
		return "_build_request_payload should return a Dictionary"

	var messages: Array = (payload as Dictionary).get("messages", [])
	var system_content := str(((messages[0] as Dictionary).get("content", ""))) if messages.size() > 0 and messages[0] is Dictionary else ""
	return run_checks([
		assert_eq((payload as Dictionary).get("enable_thinking", true), false, "Qwen payloads should use the official enable_thinking=false switch"),
		assert_true(system_content.begins_with("/no_think"), "Qwen payloads should include the documented soft no-thinking switch as a fallback"),
	])


func test_build_request_payload_defaults_kimi_k26_temperature_to_required_value() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	var payload: Variant = client.call("_build_request_payload", {
		"model": "kimi-k2.6",
		"messages": [{
			"role": "user",
			"content": "hello",
		}],
	})
	var explicit_payload: Variant = client.call("_build_request_payload", {
		"model": "kimi-k2.6",
		"messages": [{
			"role": "user",
			"content": "hello",
		}],
		"temperature": 0.9,
	})
	var explicit_non_kimi_payload: Variant = client.call("_build_request_payload", {
		"model": "test-model",
		"messages": [{
			"role": "user",
			"content": "hello",
		}],
		"temperature": 0.9,
	})
	if not payload is Dictionary or not explicit_payload is Dictionary or not explicit_non_kimi_payload is Dictionary:
		return "_build_request_payload should return dictionaries"

	return run_checks([
		assert_eq(float((payload as Dictionary).get("temperature", 0.0)), 0.6, "kimi-k2.6 should default to ZenMux-required temperature 0.6"),
		assert_eq(float((explicit_payload as Dictionary).get("temperature", 0.0)), 0.6, "kimi-k2.6 should force ZenMux-required temperature 0.6 even if an upstream prompt builder set another value"),
		assert_eq(float((explicit_non_kimi_payload as Dictionary).get("temperature", 0.0)), 0.9, "Explicit temperature should still be preserved for non-Kimi models"),
	])


func test_python_fallback_candidates_prefer_python3_on_macos() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	if not client.has_method("_python_executable_candidates_for_os"):
		return "ZenMuxClient is missing _python_executable_candidates_for_os"

	var candidates: Array = client.call("_python_executable_candidates_for_os", "macOS", "")
	return run_checks([
		assert_true(candidates.size() >= 3, "macOS fallback should have multiple Python 3 candidates"),
		assert_eq(str(candidates[0]), "/usr/bin/python3", "macOS app bundles should prefer absolute python3 before PATH lookup"),
		assert_true(candidates.has("python3"), "macOS fallback should still try PATH python3"),
		assert_true(candidates.has("python"), "macOS fallback should keep python as last-resort compatibility"),
	])


func test_python_fallback_candidates_preserve_configured_python_first() -> String:
	var client_result: Variant = _new_client()
	if client_result is Dictionary and not bool((client_result as Dictionary).get("ok", false)):
		return str((client_result as Dictionary).get("error", "ZenMuxClient setup failed"))

	var client: Object = (client_result as Dictionary).get("value") as Object
	var candidates: Array = client.call("_python_executable_candidates_for_os", "macOS", "/custom/python")
	return run_checks([
		assert_eq(str(candidates[0]), "/custom/python", "Explicit PYTHON environment override should stay first"),
		assert_eq(candidates.count("/custom/python"), 1, "Python candidates should not contain duplicates"),
	])
