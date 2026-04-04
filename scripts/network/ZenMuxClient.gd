class_name ZenMuxClient
extends RefCounted

var _timeout_seconds: float = 30.0


func set_timeout_seconds(timeout_seconds: float) -> void:
	_timeout_seconds = max(timeout_seconds, 0.0)


func request_json(parent: Node, endpoint: String, api_key: String, payload: Dictionary, callback: Callable) -> int:
	var request := HTTPRequest.new()
	request.timeout = _timeout_seconds
	parent.add_child(request)
	request.request_completed.connect(_on_request_completed.bind(request, callback), CONNECT_ONE_SHOT)
	var request_url := _normalize_endpoint(endpoint)
	var request_payload := _build_request_payload(payload)
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
		return payload.duplicate(true)

	var request_payload := {}
	request_payload["model"] = str(payload.get("model", ""))
	request_payload["messages"] = _build_messages(payload)
	request_payload["temperature"] = 0

	var schema: Dictionary = payload.get("response_format", {})
	if not schema.is_empty():
		request_payload["response_format"] = {
			"type": "json_schema",
			"json_schema": {
				"name": str(payload.get("system_prompt_version", "battle_review_response")).strip_edges(),
				"strict": true,
				"schema": schema.duplicate(true),
			},
		}
	return request_payload


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
			if key_str in ["model", "instructions", "response_format", "system_prompt_version"]:
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
		normalized = _parse_error_response(response_code, result, response_text)
	elif normalized.has("status") and String(normalized.get("status", "")) == "error":
		normalized["request_result"] = result
	else:
		normalized["http_code"] = response_code
		normalized["request_result"] = result

	if is_instance_valid(request):
		request.queue_free()

	if callback.is_valid():
		callback.call(normalized)


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
	var content := String(message.get("content", "")).strip_edges()
	if content == "":
		return {
			"status": "error",
			"http_code": response_code,
			"error_type": "missing_content",
			"message": "ZenMux response did not include message content",
			"raw_body": response_text,
		}

	var content_json := JSON.new()
	if content_json.parse(content) != OK:
		return {
			"status": "error",
			"http_code": response_code,
			"error_type": "invalid_content_json",
			"message": "ZenMux message content was not valid JSON",
			"raw_body": content,
		}

	var content_parsed: Variant = content_json.data
	if content_parsed is Dictionary:
		return content_parsed

	return {
		"status": "error",
		"http_code": response_code,
		"error_type": "invalid_content_json",
		"message": "ZenMux message content must decode to a JSON object",
		"raw_body": content,
	}


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
		_:
			return "ZenMux request failed (result=%d)" % request_result
