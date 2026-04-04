class_name BattleReviewService
extends RefCounted

signal status_changed(status: String, context: Dictionary)
signal review_completed(review: Dictionary)

enum Status {
	IDLE,
	SELECTING_TURNS,
	ANALYZING_TURN,
	WRITING_REVIEW,
	COMPLETED,
	FAILED,
}

const BattleReviewArtifactStoreScript = preload("res://scripts/engine/BattleReviewArtifactStore.gd")
const BattleReviewDataBuilderScript = preload("res://scripts/engine/BattleReviewDataBuilder.gd")
const BattleReviewPromptBuilderScript = preload("res://scripts/engine/BattleReviewPromptBuilder.gd")
const ZenMuxClientScript = preload("res://scripts/network/ZenMuxClient.gd")

var _client = ZenMuxClientScript.new()
var _data_builder = BattleReviewDataBuilderScript.new()
var _artifact_store = BattleReviewArtifactStoreScript.new()
var _prompt_builder = BattleReviewPromptBuilderScript.new()
var _status: Status = Status.IDLE
var _latest_review: Dictionary = {}


func configure_dependencies(client: Variant, data_builder: Variant, artifact_store: Variant, prompt_builder: Variant = null) -> void:
	if client != null:
		_client = client
	if data_builder != null:
		_data_builder = data_builder
	if artifact_store != null:
		_artifact_store = artifact_store
	if prompt_builder != null:
		_prompt_builder = prompt_builder


func generate_review(parent: Node, match_dir: String, api_config: Dictionary) -> Dictionary:
	_latest_review = {}
	_set_status(Status.SELECTING_TURNS, {"match_dir": match_dir})
	if _client != null and _client.has_method("set_timeout_seconds"):
		_client.call("set_timeout_seconds", float(api_config.get("timeout_seconds", 30.0)))

	var stage1_request: Dictionary = _prompt_builder.build_stage1_payload(_data_builder.build_stage1_payload(match_dir))
	stage1_request["model"] = str(api_config.get("model", ""))
	_artifact_store.write_stage_debug(match_dir, "stage1_request.json", stage1_request)

	var request_error: int = _client.request_json(
		parent,
		str(api_config.get("endpoint", "")),
		str(api_config.get("api_key", "")),
		stage1_request,
		_on_stage1_response.bind(parent, match_dir, api_config, stage1_request)
	)
	if request_error != OK:
		_latest_review = _finalize_failure(match_dir, api_config, [{
			"stage": "stage1",
			"message": "ZenMux request could not be started",
			"request_error": request_error,
		}])
	return _latest_review


func get_status_name() -> String:
	return _status_name(_status)


func _on_stage1_response(
	response: Dictionary,
	parent: Node,
	match_dir: String,
	api_config: Dictionary,
	stage1_request: Dictionary
) -> void:
	_artifact_store.write_stage_debug(match_dir, "stage1_response.json", response)
	if _is_error_response(response):
		_latest_review = _finalize_failure(match_dir, api_config, [_normalize_error("stage1", response)])
		return

	var selected_turns := _selected_turns_from_stage1(response)
	if selected_turns.is_empty():
		_latest_review = _finalize_failure(match_dir, api_config, [{
			"stage": "stage1",
			"message": "Stage 1 did not return any key turns",
		}])
		return
	var invalid_turn_errors := _validate_selected_turns(selected_turns, stage1_request)
	if not invalid_turn_errors.is_empty():
		_latest_review = _finalize_failure(match_dir, api_config, invalid_turn_errors)
		return

	var review := {
		"status": "running",
		"generated_at": Time.get_datetime_string_from_system(),
		"model_id": str(api_config.get("model", "")),
		"prompt_versions": {
			"stage1": String(stage1_request.get("system_prompt_version", "")),
			"stage2": String(_prompt_builder.build_stage2_payload({}).get("system_prompt_version", "")),
		},
		"selected_turns": selected_turns,
		"turn_reviews": [],
		"errors": [],
	}
	_analyze_turn(parent, match_dir, api_config, review, 0)


func _analyze_turn(parent: Node, match_dir: String, api_config: Dictionary, review: Dictionary, turn_index: int) -> void:
	var selected_turns: Array = review.get("selected_turns", [])
	if turn_index >= selected_turns.size():
		_latest_review = _finalize_review(match_dir, review)
		return

	var turn_entry_variant: Variant = selected_turns[turn_index]
	if not (turn_entry_variant is Dictionary):
		var invalid_review := review.duplicate(true)
		var invalid_errors: Array = invalid_review.get("errors", [])
		invalid_errors.append({"stage": "stage2", "message": "Selected turn entry was not a dictionary"})
		invalid_review["errors"] = invalid_errors
		_analyze_turn(parent, match_dir, api_config, invalid_review, turn_index + 1)
		return

	var turn_entry: Dictionary = turn_entry_variant
	var turn_number := int(turn_entry.get("turn_number", 0))
	_set_status(Status.ANALYZING_TURN, {"turn_number": turn_number, "turn_index": turn_index, "total": selected_turns.size()})

	var turn_packet: Dictionary = _data_builder.build_turn_packet(match_dir, turn_number)
	var stage2_request: Dictionary = _prompt_builder.build_stage2_payload(turn_packet)
	stage2_request["model"] = str(api_config.get("model", ""))
	_artifact_store.write_stage_debug(match_dir, "turn_%d_request.json" % turn_number, stage2_request)

	var request_error: int = _client.request_json(
		parent,
		str(api_config.get("endpoint", "")),
		str(api_config.get("api_key", "")),
		stage2_request,
		_on_stage2_response.bind(parent, match_dir, api_config, review, turn_index, turn_number)
	)
	if request_error != OK:
		var errored_review := review.duplicate(true)
		var request_errors: Array = errored_review.get("errors", [])
		request_errors.append({
			"stage": "stage2",
			"turn_number": turn_number,
			"message": "ZenMux turn analysis request could not be started",
			"request_error": request_error,
		})
		errored_review["errors"] = request_errors
		_analyze_turn(parent, match_dir, api_config, errored_review, turn_index + 1)


func _on_stage2_response(
	response: Dictionary,
	parent: Node,
	match_dir: String,
	api_config: Dictionary,
	review: Dictionary,
	turn_index: int,
	turn_number: int
) -> void:
	_artifact_store.write_stage_debug(match_dir, "turn_%d_response.json" % turn_number, response)

	var next_review := review.duplicate(true)
	if _is_error_response(response):
		var errors: Array = next_review.get("errors", [])
		var normalized := _normalize_error("stage2", response)
		normalized["turn_number"] = turn_number
		errors.append(normalized)
		next_review["errors"] = errors
	else:
		var turn_reviews: Array = next_review.get("turn_reviews", [])
		turn_reviews.append(response.duplicate(true))
		next_review["turn_reviews"] = turn_reviews

	_analyze_turn(parent, match_dir, api_config, next_review, turn_index + 1)


func _selected_turns_from_stage1(stage1_response: Dictionary) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	_append_selected_turns(selected, stage1_response.get("winner_turns", []), int(stage1_response.get("winner_index", -1)), "winner")
	_append_selected_turns(selected, stage1_response.get("loser_turns", []), int(stage1_response.get("loser_index", -1)), "loser")
	return selected


func _append_selected_turns(target: Array[Dictionary], turns_variant: Variant, player_index: int, side: String) -> void:
	if not (turns_variant is Array):
		return
	var appended := 0
	for turn_variant: Variant in turns_variant:
		if not (turn_variant is Dictionary):
			continue
		var turn: Dictionary = turn_variant
		target.append({
			"turn_number": int(turn.get("turn_number", 0)),
			"reason": str(turn.get("reason", "")),
			"player_index": player_index,
			"side": side,
		})
		appended += 1
		if appended >= 1:
			break


func _validate_selected_turns(selected_turns: Array[Dictionary], stage1_request: Dictionary) -> Array:
	var errors: Array = []
	var valid_turn_numbers := _valid_turn_numbers_from_stage1_request(stage1_request)
	for turn: Dictionary in selected_turns:
		var turn_number := int(turn.get("turn_number", 0))
		if turn_number <= 0 or not valid_turn_numbers.has(turn_number):
			errors.append({
				"stage": "stage1",
				"message": "Stage 1 selected an unknown turn",
				"turn_number": turn_number,
			})
	return errors


func _valid_turn_numbers_from_stage1_request(stage1_request: Dictionary) -> Array[int]:
	var valid_turn_numbers: Array[int] = []
	var match_payload_variant: Variant = stage1_request.get("match", {})
	var match_payload: Dictionary = match_payload_variant if match_payload_variant is Dictionary else {}
	var turn_summaries: Array = match_payload.get("turn_summaries", [])
	for summary_variant: Variant in turn_summaries:
		if not (summary_variant is Dictionary):
			continue
		var turn_number := int((summary_variant as Dictionary).get("turn_number", 0))
		if turn_number > 0 and not valid_turn_numbers.has(turn_number):
			valid_turn_numbers.append(turn_number)
	return valid_turn_numbers


func _finalize_review(match_dir: String, review: Dictionary) -> Dictionary:
	_set_status(Status.WRITING_REVIEW, {})
	var turn_reviews: Array = review.get("turn_reviews", [])
	var errors: Array = review.get("errors", [])
	var final_review := review.duplicate(true)
	if errors.is_empty():
		final_review["status"] = "completed"
		_set_status(Status.COMPLETED, {})
	elif turn_reviews.is_empty():
		final_review["status"] = "failed"
		_set_status(Status.FAILED, {})
	else:
		final_review["status"] = "partial_success"
		_set_status(Status.COMPLETED, {"partial": true})

	_artifact_store.write_review(match_dir, final_review)
	review_completed.emit(final_review)
	return final_review


func _finalize_failure(match_dir: String, api_config: Dictionary, errors: Array) -> Dictionary:
	_set_status(Status.WRITING_REVIEW, {})
	var review := {
		"status": "failed",
		"generated_at": Time.get_datetime_string_from_system(),
		"model_id": str(api_config.get("model", "")),
		"prompt_versions": {},
		"selected_turns": [],
		"turn_reviews": [],
		"errors": errors,
	}
	_artifact_store.write_review(match_dir, review)
	_set_status(Status.FAILED, {})
	review_completed.emit(review)
	return review


func _normalize_error(stage: String, response: Dictionary) -> Dictionary:
	return {
		"stage": stage,
		"message": str(response.get("message", "Unknown error")),
		"error_type": str(response.get("error_type", "")),
		"http_code": int(response.get("http_code", 0)),
	}


func _is_error_response(response: Dictionary) -> bool:
	return String(response.get("status", "")) == "error"


func _set_status(next_status: Status, context: Dictionary) -> void:
	_status = next_status
	status_changed.emit(_status_name(next_status), context)


func _status_name(value: Status) -> String:
	match value:
		Status.IDLE:
			return "idle"
		Status.SELECTING_TURNS:
			return "selecting_turns"
		Status.ANALYZING_TURN:
			return "analyzing_turn"
		Status.WRITING_REVIEW:
			return "writing_review"
		Status.COMPLETED:
			return "completed"
		Status.FAILED:
			return "failed"
	return "unknown"
