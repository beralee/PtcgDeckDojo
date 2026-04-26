class_name ZenMuxClient
extends RefCounted

const PYTHON_FALLBACK_RESOURCE_PATH := "res://scripts/tools/zenmux_request.py"
const PYTHON_FALLBACK_USER_DIR := "user://tmp/zenmux"
const PYTHON_FALLBACK_USER_SCRIPT := PYTHON_FALLBACK_USER_DIR + "/zenmux_request.py"

class PythonFallbackRequest:
	extends Node

	var client: RefCounted = null
	var process_id: int = -1
	var input_path: String = ""
	var output_path: String = ""
	var callback: Callable = Callable()
	var started_msec: int = 0
	var timeout_seconds: float = 30.0

	func configure(
		p_client: RefCounted,
		p_process_id: int,
		p_input_path: String,
		p_output_path: String,
		p_callback: Callable,
		p_timeout_seconds: float
	) -> void:
		client = p_client
		process_id = p_process_id
		input_path = p_input_path
		output_path = p_output_path
		callback = p_callback
		timeout_seconds = maxf(p_timeout_seconds, 0.1)
		started_msec = Time.get_ticks_msec()
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(true)

	func _process(_delta: float) -> void:
		var elapsed := float(Time.get_ticks_msec() - started_msec) / 1000.0
		if FileAccess.file_exists(output_path):
			_finish_from_output()
			return
		if process_id > 0 and OS.is_process_running(process_id):
			if elapsed < timeout_seconds + 2.0:
				return
			OS.kill(process_id)
			_finish_with_error("python_fallback_timeout", "ZenMux Python fallback timed out")
			return
		_finish_with_error("python_fallback_failed", "ZenMux Python fallback process exited without output")

	func _finish_from_output() -> void:
		var output_file := FileAccess.open(output_path, FileAccess.READ)
		if output_file == null:
			_finish_with_error("python_fallback_read_failed", "ZenMux Python fallback response could not be read")
			return
		var output_text := output_file.get_as_text()
		output_file.close()
		_cleanup_files()
		var normalized: Dictionary = {}
		if client != null and client.has_method("_normalize_python_fallback_output"):
			normalized = client.call("_normalize_python_fallback_output", output_text)
		else:
			normalized = {
				"status": "error",
				"error_type": "python_fallback_missing_client",
				"message": "ZenMux Python fallback client was missing",
				"transport": "python_fallback",
			}
		_emit_callback(normalized)

	func _finish_with_error(error_type: String, message: String) -> void:
		_cleanup_files()
		_emit_callback({
			"status": "error",
			"error_type": error_type,
			"message": message,
			"transport": "python_fallback",
		})

	func _cleanup_files() -> void:
		if input_path != "":
			DirAccess.remove_absolute(input_path)
		if output_path != "":
			DirAccess.remove_absolute(output_path)

	func _emit_callback(response: Dictionary) -> void:
		set_process(false)
		if callback.is_valid():
			callback.call_deferred(response)
		queue_free()

var _timeout_seconds: float = 30.0
var _allow_unsafe_tls: bool = true
var _allow_python_fallback: bool = true
var _proxy_host: String = ""
var _proxy_port: int = -1
var _proxy_loaded_from_environment: bool = false


func set_timeout_seconds(timeout_seconds: float) -> void:
	_timeout_seconds = max(timeout_seconds, 0.0)


func set_allow_unsafe_tls(allow_unsafe_tls: bool) -> void:
	_allow_unsafe_tls = allow_unsafe_tls


func set_allow_python_fallback(allow_python_fallback: bool) -> void:
	_allow_python_fallback = allow_python_fallback


func set_proxy(proxy_host: String, proxy_port: int) -> void:
	_proxy_host = proxy_host.strip_edges()
	_proxy_port = proxy_port
	_proxy_loaded_from_environment = true


func clear_proxy() -> void:
	_proxy_host = ""
	_proxy_port = -1
	_proxy_loaded_from_environment = true


func request_json(parent: Node, endpoint: String, api_key: String, payload: Dictionary, callback: Callable) -> int:
	var request_url := _normalize_endpoint(endpoint)
	var request_payload := _build_request_payload(payload)
	if _should_prefer_python_transport():
		var async_error := _request_json_payload_via_python_fallback_async(parent, request_url, api_key, request_payload, callback)
		if async_error == OK:
			return OK

	var request := HTTPRequest.new()
	request.timeout = _timeout_seconds
	_configure_tls(request)
	_configure_proxy(request, request_url)
	request.set_meta("zenmux_request_url", request_url)
	request.set_meta("zenmux_api_key", api_key)
	parent.add_child(request)
	request.request_completed.connect(_on_request_completed.bind(request, callback), CONNECT_ONE_SHOT)
	request.set_meta("zenmux_request_payload", request_payload)
	var request_error := request.request(
		request_url,
		PackedStringArray([
			"Content-Type: application/json",
			"Authorization: Bearer %s" % api_key,
		]),
		HTTPClient.METHOD_POST,
		JSON.stringify(request_payload)
	)
	if request_error != OK and is_instance_valid(request):
		request.queue_free()
	return request_error


func _configure_tls(request: HTTPRequest) -> void:
	if request == null or not _allow_unsafe_tls:
		return
	if not request.has_method("set_tls_options"):
		return
	# Headless Godot on Windows can fail to load the system root store, which
	# makes otherwise valid ZenMux HTTPS calls fail before the response layer.
	request.call("set_tls_options", TLSOptions.client_unsafe())


func _configure_proxy(request: HTTPRequest, request_url: String) -> void:
	if request == null:
		return
	_ensure_proxy_loaded_from_environment()
	if _proxy_host == "" or _proxy_port <= 0:
		return
	var lower_url := request_url.strip_edges().to_lower()
	if lower_url.begins_with("https://"):
		if request.has_method("set_https_proxy"):
			request.call("set_https_proxy", _proxy_host, _proxy_port)
	elif lower_url.begins_with("http://"):
		if request.has_method("set_http_proxy"):
			request.call("set_http_proxy", _proxy_host, _proxy_port)
	else:
		if request.has_method("set_https_proxy"):
			request.call("set_https_proxy", _proxy_host, _proxy_port)
		if request.has_method("set_http_proxy"):
			request.call("set_http_proxy", _proxy_host, _proxy_port)


func _ensure_proxy_loaded_from_environment() -> void:
	if _proxy_loaded_from_environment:
		return
	_proxy_loaded_from_environment = true
	for env_name: String in ["HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy", "ALL_PROXY", "all_proxy"]:
		var proxy_url := OS.get_environment(env_name).strip_edges()
		if proxy_url == "":
			continue
		var parsed := _parse_proxy_url(proxy_url)
		if parsed.is_empty():
			continue
		_proxy_host = str(parsed.get("host", ""))
		_proxy_port = int(parsed.get("port", -1))
		return


func _parse_proxy_url(proxy_url: String) -> Dictionary:
	var trimmed := proxy_url.strip_edges()
	if trimmed == "":
		return {}
	var default_port := 80
	var scheme_index := trimmed.find("://")
	if scheme_index >= 0:
		var scheme := trimmed.substr(0, scheme_index).to_lower()
		default_port = 443 if scheme == "https" else 80
		trimmed = trimmed.substr(scheme_index + 3)
	var at_index := trimmed.rfind("@")
	if at_index >= 0:
		trimmed = trimmed.substr(at_index + 1)
	var slash_index := trimmed.find("/")
	if slash_index >= 0:
		trimmed = trimmed.substr(0, slash_index)
	trimmed = trimmed.strip_edges()
	if trimmed == "":
		return {}
	if trimmed.begins_with("["):
		var close_index := trimmed.find("]")
		if close_index <= 1:
			return {}
		var host := trimmed.substr(1, close_index - 1)
		var port := default_port
		if close_index + 1 < trimmed.length() and trimmed[close_index + 1] == ":":
			port = int(trimmed.substr(close_index + 2))
		if host == "" or port <= 0:
			return {}
		return {"host": host, "port": port}
	var colon_index := trimmed.rfind(":")
	var host := trimmed
	var port := default_port
	if colon_index > 0:
		host = trimmed.substr(0, colon_index)
		port = int(trimmed.substr(colon_index + 1))
	if host.strip_edges() == "" or port <= 0:
		return {}
	return {"host": host.strip_edges(), "port": port}


func _normalize_endpoint(endpoint: String) -> String:
	var trimmed := endpoint.strip_edges()
	if trimmed == "":
		return trimmed
	var suffix := "/chat/completions"
	if trimmed.ends_with(suffix):
		return trimmed
	return trimmed.trim_suffix("/").trim_suffix("\\") + suffix


func _build_request_payload(payload: Dictionary) -> Dictionary:
	if payload.has("messages"):
		return _make_chat_payload_compatible(payload.duplicate(true))

	var request_payload := {}
	request_payload["model"] = str(payload.get("model", ""))
	request_payload["messages"] = _build_messages(payload)
	request_payload["temperature"] = _temperature_for_model(request_payload["model"], payload)
	if payload.has("reasoning"):
		request_payload["reasoning"] = payload.get("reasoning")
	if payload.has("reasoning_effort"):
		request_payload["reasoning_effort"] = str(payload.get("reasoning_effort", ""))
	if payload.has("thinking"):
		request_payload["thinking"] = payload.get("thinking")
	if payload.has("max_tokens"):
		request_payload["max_tokens"] = int(payload.get("max_tokens", 0))
	if payload.has("max_completion_tokens"):
		request_payload["max_completion_tokens"] = int(payload.get("max_completion_tokens", 0))

	var schema: Dictionary = payload.get("response_format", {})
	if not schema.is_empty():
		_append_schema_contract(
			request_payload,
			schema,
			str(payload.get("system_prompt_version", "battle_review_response")).strip_edges()
		)
	return _make_chat_payload_compatible(request_payload)


func _make_chat_payload_compatible(request_payload: Dictionary) -> Dictionary:
	request_payload["temperature"] = _temperature_for_model(str(request_payload.get("model", "")), request_payload)
	var response_format_variant: Variant = request_payload.get("response_format", {})
	request_payload.erase("response_format")
	if response_format_variant is Dictionary:
		var schema := _schema_from_response_format(response_format_variant as Dictionary)
		if not schema.is_empty():
			var schema_name := _schema_name_from_response_format(response_format_variant as Dictionary)
			_append_schema_contract(request_payload, schema, schema_name)
	_apply_default_reasoning_policy(request_payload)
	return request_payload


func _apply_default_reasoning_policy(request_payload: Dictionary) -> void:
	if _has_reasoning_opt_in(request_payload):
		return
	if not request_payload.has("reasoning"):
		request_payload["reasoning"] = {"enabled": false}
	if not request_payload.has("thinking"):
		request_payload["thinking"] = {"type": "disabled"}
	if _is_qwen_model(str(request_payload.get("model", ""))):
		_apply_qwen_no_think_policy(request_payload)


func _has_reasoning_opt_in(request_payload: Dictionary) -> bool:
	if request_payload.has("reasoning_effort"):
		return true

	var reasoning_variant: Variant = request_payload.get("reasoning", {})
	if reasoning_variant is Dictionary:
		var reasoning := reasoning_variant as Dictionary
		if bool(reasoning.get("enabled", false)):
			return true
		if str(reasoning.get("effort", "")).strip_edges() != "":
			return true

	var thinking_variant: Variant = request_payload.get("thinking", {})
	if thinking_variant is Dictionary:
		var thinking_type := str((thinking_variant as Dictionary).get("type", "")).strip_edges().to_lower()
		return thinking_type in ["enabled", "auto", "on"]
	return false


func _is_qwen_model(model: String) -> bool:
	return model.strip_edges().to_lower().contains("qwen")


func _is_kimi_k26_model(model: String) -> bool:
	var normalized := model.strip_edges().to_lower()
	return normalized.contains("kimi") and (normalized.contains("k2.6") or normalized.contains("k2-6"))


func _apply_qwen_no_think_policy(request_payload: Dictionary) -> void:
	if not request_payload.has("enable_thinking"):
		request_payload["enable_thinking"] = false
	_prepend_qwen_no_think_instruction(request_payload)


func _prepend_qwen_no_think_instruction(request_payload: Dictionary) -> void:
	var messages_variant: Variant = request_payload.get("messages", [])
	if not messages_variant is Array:
		return
	var messages: Array = messages_variant as Array
	for i: int in messages.size():
		var message_variant: Variant = messages[i]
		if not message_variant is Dictionary:
			continue
		var message := message_variant as Dictionary
		if str(message.get("role", "")) != "system":
			continue
		var content := str(message.get("content", ""))
		if not content.contains("/no_think"):
			message["content"] = "/no_think\n" + content
			messages[i] = message
			request_payload["messages"] = messages
		return
	messages.insert(0, {
		"role": "system",
		"content": "/no_think",
	})
	request_payload["messages"] = messages


func _temperature_for_model(model: String, payload: Dictionary) -> Variant:
	if _is_kimi_k26_model(model):
		return 0.6
	if payload.has("temperature"):
		return payload.get("temperature", 0)
	return 0


func _schema_from_response_format(response_format: Dictionary) -> Dictionary:
	if response_format.has("json_schema"):
		var json_schema_variant: Variant = response_format.get("json_schema", {})
		if json_schema_variant is Dictionary:
			var schema_variant: Variant = (json_schema_variant as Dictionary).get("schema", {})
			if schema_variant is Dictionary:
				return (schema_variant as Dictionary).duplicate(true)
	if String(response_format.get("type", "")) == "object" or response_format.has("properties"):
		return response_format.duplicate(true)
	return {}


func _schema_name_from_response_format(response_format: Dictionary) -> String:
	var json_schema_variant: Variant = response_format.get("json_schema", {})
	if json_schema_variant is Dictionary:
		return str((json_schema_variant as Dictionary).get("name", "json_response")).strip_edges()
	return "json_response"


func _append_schema_contract(request_payload: Dictionary, schema: Dictionary, schema_name: String) -> void:
	if schema.is_empty():
		return
	var name := schema_name if schema_name.strip_edges() != "" else "json_response"
	var contract := "\n\nReturn exactly one JSON object and nothing else. Do not wrap it in Markdown code fences. It must match this JSON schema named '%s':\n%s" % [
		name,
		JSON.stringify(schema, "\t"),
	]
	var messages_variant: Variant = request_payload.get("messages", [])
	if not messages_variant is Array:
		request_payload["messages"] = [{
			"role": "system",
			"content": contract.strip_edges(),
		}]
		return
	var messages: Array = messages_variant as Array
	for i: int in messages.size():
		var message_variant: Variant = messages[i]
		if not message_variant is Dictionary:
			continue
		var message := message_variant as Dictionary
		if str(message.get("role", "")) != "system":
			continue
		message["content"] = str(message.get("content", "")).strip_edges() + contract
		messages[i] = message
		request_payload["messages"] = messages
		return
	messages.insert(0, {
		"role": "system",
		"content": contract.strip_edges(),
	})
	request_payload["messages"] = messages


func _build_messages(payload: Dictionary) -> Array[Dictionary]:
	var system_lines: PackedStringArray = payload.get("instructions", PackedStringArray())
	var system_content := "\n".join(system_lines)
	if system_content.strip_edges() == "":
		system_content = "Return JSON only."

	var user_payload := {}
	if payload.has("match"):
		user_payload["match"] = payload.get("match", {}).duplicate(true)
	if payload.has("turn_packet"):
		user_payload["turn_packet"] = payload.get("turn_packet", {}).duplicate(true)
	if user_payload.is_empty():
		for key: Variant in payload.keys():
			var key_str := str(key)
			if key_str in ["model", "instructions", "response_format", "system_prompt_version", "reasoning", "reasoning_effort", "thinking"]:
				continue
			user_payload[key_str] = payload.get(key)

	return [
		{
			"role": "system",
			"content": system_content,
		},
		{
			"role": "user",
			"content": JSON.stringify(user_payload),
		},
	]


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	request: HTTPRequest,
	callback: Callable
) -> void:
	var response_text := body.get_string_from_utf8()
	var normalized := _parse_chat_response(response_code, response_text)
	if result != HTTPRequest.RESULT_SUCCESS:
		if _try_start_python_fallback_from_failed_request(request, callback):
			if is_instance_valid(request):
				request.queue_free()
			return
		normalized = _parse_error_response(response_code, result, response_text)
	elif normalized.has("status") and String(normalized.get("status", "")) == "error":
		normalized["request_result"] = result
	else:
		normalized["http_code"] = response_code
		normalized["request_result"] = result
	if normalized.has("status") and String(normalized.get("status", "")) == "error":
		normalized["proxy"] = _proxy_description()
		normalized["unsafe_tls"] = _allow_unsafe_tls

	if is_instance_valid(request):
		request.queue_free()

	if callback.is_valid():
		callback.call(normalized)


func _try_start_python_fallback_from_failed_request(request: HTTPRequest, callback: Callable) -> bool:
	if not _allow_python_fallback or request == null or not is_instance_valid(request):
		return false
	var parent := request.get_parent()
	if parent == null or not is_instance_valid(parent):
		return false
	var payload_variant: Variant = request.get_meta("zenmux_request_payload", {})
	var request_payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
	var async_error := _request_json_payload_via_python_fallback_async(
		parent,
		str(request.get_meta("zenmux_request_url", "")),
		str(request.get_meta("zenmux_api_key", "")),
		request_payload,
		_on_async_python_fallback_completed.bind(callback)
	)
	return async_error == OK


func _on_async_python_fallback_completed(response: Dictionary, callback: Callable) -> void:
	var normalized := response.duplicate(true)
	if normalized.has("status") and String(normalized.get("status", "")) == "error":
		normalized["proxy"] = _proxy_description()
		normalized["unsafe_tls"] = _allow_unsafe_tls
	if callback.is_valid():
		callback.call_deferred(normalized)


func _parse_chat_response(response_code: int, response_text: String) -> Dictionary:
	if response_code < 200 or response_code >= 300:
		return _parse_error_response(response_code, HTTPRequest.RESULT_SUCCESS, response_text)

	var parsed: Variant = JSON.parse_string(response_text)
	if not parsed is Dictionary:
		return {
			"status": "error",
			"http_code": response_code,
			"error_type": "invalid_response_json",
			"message": "ZenMux response was not valid JSON",
			"raw_body": response_text,
		}

	var parsed_dict := parsed as Dictionary
	var responses_content := _extract_responses_api_content(parsed_dict)
	if responses_content.strip_edges() != "":
		return _parse_json_content(response_code, responses_content, response_text)

	var choices_variant: Variant = parsed_dict.get("choices", [])
	if not choices_variant is Array or (choices_variant as Array).is_empty():
		return {
			"status": "error",
			"http_code": response_code,
			"error_type": "missing_choices",
			"message": "ZenMux response did not include choices",
			"raw_body": response_text,
		}

	var first_choice: Variant = (choices_variant as Array)[0]
	if not first_choice is Dictionary:
		return {
			"status": "error",
			"http_code": response_code,
			"error_type": "invalid_choice",
			"message": "ZenMux response choice was not an object",
			"raw_body": response_text,
		}

	var message_variant: Variant = (first_choice as Dictionary).get("message", {})
	var message: Dictionary = message_variant if message_variant is Dictionary else {}
	var content := _message_content_to_text(message.get("content", "")).strip_edges()
	if content == "":
		return {
			"status": "error",
			"http_code": response_code,
			"error_type": "missing_content",
			"message": "ZenMux response did not include message content",
			"raw_body": response_text,
		}

	return _parse_json_content(response_code, content, response_text)


func _parse_json_content(response_code: int, content: String, raw_body: String = "") -> Dictionary:
	var normalized_content := _normalize_json_content(content)
	var content_json := JSON.new()
	if content_json.parse(normalized_content) != OK:
		return {
			"status": "error",
			"http_code": response_code,
			"error_type": "invalid_content_json",
			"message": "ZenMux message content was not valid JSON",
			"raw_body": content if raw_body == "" else raw_body,
			"raw_content": content,
		}

	var content_parsed: Variant = content_json.data
	if content_parsed is Dictionary:
		return content_parsed

	return {
		"status": "error",
		"http_code": response_code,
		"error_type": "invalid_content_json",
		"message": "ZenMux message content must decode to a JSON object",
		"raw_body": content if raw_body == "" else raw_body,
		"raw_content": content,
	}


func _normalize_json_content(content: String) -> String:
	var trimmed := content.strip_edges()
	if trimmed.begins_with("```"):
		var first_newline := trimmed.find("\n")
		var last_fence := trimmed.rfind("```")
		if first_newline >= 0 and last_fence > first_newline:
			trimmed = trimmed.substr(first_newline + 1, last_fence - first_newline - 1).strip_edges()
	if trimmed.begins_with("{") and trimmed.ends_with("}"):
		return trimmed
	var first_brace := trimmed.find("{")
	var last_brace := trimmed.rfind("}")
	if first_brace >= 0 and last_brace > first_brace:
		return trimmed.substr(first_brace, last_brace - first_brace + 1).strip_edges()
	return trimmed


func _message_content_to_text(content_variant: Variant) -> String:
	if content_variant is String:
		return content_variant
	if content_variant is Array:
		var parts: PackedStringArray = []
		for part_variant: Variant in content_variant:
			if part_variant is Dictionary:
				var part := part_variant as Dictionary
				if part.has("text"):
					parts.append(str(part.get("text", "")))
				elif part.has("content"):
					parts.append(str(part.get("content", "")))
			else:
				parts.append(str(part_variant))
		return "\n".join(parts)
	return str(content_variant)


func _extract_responses_api_content(parsed_dict: Dictionary) -> String:
	var output_text := str(parsed_dict.get("output_text", "")).strip_edges()
	if output_text != "":
		return output_text
	var output_variant: Variant = parsed_dict.get("output", [])
	if not output_variant is Array:
		return ""
	var parts: PackedStringArray = []
	for item_variant: Variant in output_variant as Array:
		if not item_variant is Dictionary:
			continue
		var item := item_variant as Dictionary
		var content_variant: Variant = item.get("content", [])
		if content_variant is Array:
			for content_item_variant: Variant in content_variant as Array:
				if content_item_variant is Dictionary:
					var content_item := content_item_variant as Dictionary
					if content_item.has("text"):
						parts.append(str(content_item.get("text", "")))
		elif content_variant is String:
			parts.append(str(content_variant))
	return "\n".join(parts)


func _parse_error_response(response_code: int, request_result: int, response_text: String) -> Dictionary:
	var message := response_text.strip_edges()
	var error_type := "http_error"
	if request_result != HTTPRequest.RESULT_SUCCESS:
		error_type = "request_error"
		if message == "":
			message = _request_result_to_message(request_result)

	return {
		"status": "error",
		"http_code": response_code,
		"request_result": request_result,
		"error_type": error_type,
		"message": message,
		"raw_body": response_text,
	}


func _request_result_to_message(request_result: int) -> String:
	match request_result:
		HTTPRequest.RESULT_TIMEOUT:
			return "ZenMux request timed out"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "ZenMux request could not connect"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "ZenMux request could not resolve host"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "ZenMux connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "ZenMux TLS handshake failed"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "ZenMux request got no response"
		_:
			return "ZenMux request failed (result=%d)" % request_result


func _request_json_payload_via_python_fallback_async(
	parent: Node,
	request_url: String,
	api_key: String,
	request_payload: Dictionary,
	callback: Callable
) -> int:
	if not _allow_python_fallback or parent == null or not is_instance_valid(parent):
		return ERR_UNAVAILABLE
	var request_paths := _write_python_fallback_request(request_url, api_key, request_payload)
	if request_paths.is_empty():
		return ERR_CANT_CREATE
	var input_path := str(request_paths.get("input_path", ""))
	var output_path := str(request_paths.get("output_path", ""))
	var script_path := str(request_paths.get("script_path", ""))
	var process_id := OS.create_process(_python_executable(), [script_path, input_path, output_path], false)
	if process_id <= 0:
		DirAccess.remove_absolute(input_path)
		DirAccess.remove_absolute(output_path)
		return ERR_CANT_CREATE
	var poller := PythonFallbackRequest.new()
	poller.configure(self, process_id, input_path, output_path, callback, _timeout_seconds)
	parent.add_child(poller)
	return OK


func _write_python_fallback_request(request_url: String, api_key: String, request_payload: Dictionary) -> Dictionary:
	var script_path := _ensure_python_fallback_script()
	if script_path == "":
		return {}
	var temp_dir := ProjectSettings.globalize_path(PYTHON_FALLBACK_USER_DIR)
	if DirAccess.make_dir_recursive_absolute(temp_dir) != OK:
		return {}
	var token := "%d_%d" % [Time.get_ticks_msec(), randi()]
	var input_path := "%s/request_%s.json" % [temp_dir, token]
	var output_path := "%s/response_%s.json" % [temp_dir, token]
	var input := {
		"url": request_url,
		"api_key": api_key,
		"payload": request_payload,
		"timeout_seconds": _timeout_seconds,
		"allow_unsafe_tls": _allow_unsafe_tls,
	}
	var input_file := FileAccess.open(input_path, FileAccess.WRITE)
	if input_file == null:
		return {}
	input_file.store_string(JSON.stringify(input))
	input_file.close()
	return {
		"script_path": script_path,
		"input_path": input_path,
		"output_path": output_path,
	}


func _ensure_python_fallback_script() -> String:
	if not FileAccess.file_exists(PYTHON_FALLBACK_RESOURCE_PATH):
		return ""
	var temp_dir := ProjectSettings.globalize_path(PYTHON_FALLBACK_USER_DIR)
	if DirAccess.make_dir_recursive_absolute(temp_dir) != OK:
		return ""
	var source_file := FileAccess.open(PYTHON_FALLBACK_RESOURCE_PATH, FileAccess.READ)
	if source_file == null:
		return ""
	var script_text := source_file.get_as_text()
	source_file.close()
	if script_text.strip_edges() == "":
		return ""
	var target_file := FileAccess.open(PYTHON_FALLBACK_USER_SCRIPT, FileAccess.WRITE)
	if target_file == null:
		return ""
	target_file.store_string(script_text)
	target_file.close()
	return ProjectSettings.globalize_path(PYTHON_FALLBACK_USER_SCRIPT)


func _normalize_python_fallback_output(output_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(output_text)
	if not (parsed is Dictionary):
		return {
			"status": "error",
			"error_type": "python_fallback_invalid_output",
			"message": "ZenMux Python fallback output was not JSON",
			"raw_body": output_text,
			"transport": "python_fallback",
		}
	var response := parsed as Dictionary
	if not bool(response.get("ok", false)):
		response["status"] = "error"
		response["transport"] = "python_fallback"
		return response
	var normalized := _parse_chat_response(int(response.get("http_code", 0)), str(response.get("body", "")))
	normalized["transport"] = "python_fallback"
	normalized["http_code"] = int(response.get("http_code", 0))
	return normalized


func _should_prefer_python_transport() -> bool:
	if not _allow_python_fallback:
		return false
	if OS.get_environment("ZENMUX_DISABLE_PYTHON_FALLBACK").strip_edges() in ["1", "true", "TRUE", "yes", "YES"]:
		return false
	if OS.get_environment("ZENMUX_PREFER_PYTHON").strip_edges() in ["1", "true", "TRUE", "yes", "YES"]:
		return true
	if OS.get_name() == "Windows":
		return true
	_ensure_proxy_loaded_from_environment()
	return _proxy_host != "" and _proxy_port > 0


func _python_executable() -> String:
	var configured := OS.get_environment("PYTHON").strip_edges()
	if configured != "":
		return configured
	return "python"


func _proxy_description() -> String:
	_ensure_proxy_loaded_from_environment()
	if _proxy_host == "" or _proxy_port <= 0:
		return ""
	return "%s:%d" % [_proxy_host, _proxy_port]
