class_name AIDecisionSampleExporter
extends RefCounted

const TrainingExportPathScript = preload("res://scripts/ai/TrainingExportPath.gd")

var base_dir: String = "user://training_data/action_decisions"

var _records: Array[Dictionary] = []
var _interaction_records: Array[Dictionary] = []
var _winner_index: int = -1
var _meta: Dictionary = {}
var _total_turns: int = 0
var _failure_reason: String = ""
var _terminated_by_cap: bool = false
var _stalled: bool = false
var _match_quality_weight: float = 1.0
var max_turn_for_shaping: int = 30
var speed_penalty: float = 0.3


func start_game(meta: Dictionary = {}) -> void:
	_records.clear()
	_interaction_records.clear()
	_winner_index = -1
	_meta = meta.duplicate(true)
	_total_turns = 0
	_failure_reason = ""
	_terminated_by_cap = false
	_stalled = false
	_match_quality_weight = 1.0


func record_trace(trace, extra_context: Dictionary = {}) -> void:
	if trace == null:
		return
	var trace_dict: Dictionary = trace.to_dictionary() if trace.has_method("to_dictionary") else {}
	if trace_dict.is_empty():
		return
	var record := {
		"run_id": str(_meta.get("run_id", "")),
		"match_id": str(_meta.get("match_id", "")),
		"decision_id": _records.size(),
		"turn_number": int(trace_dict.get("turn_number", -1)),
		"phase": str(trace_dict.get("phase", "")),
		"player_index": int(trace_dict.get("player_index", -1)),
		"pipeline_name": str(_meta.get("pipeline_name", "")),
		"deck_identity": str(_meta.get("deck_identity", "")),
		"opponent_deck_identity": str(_meta.get("opponent_deck_identity", "")),
		"state_features": _to_float_array(trace_dict.get("state_features", [])),
		"legal_actions": _build_legal_action_entries(trace_dict),
		"chosen_action": _build_chosen_action_entry(trace_dict.get("chosen_action", {})),
		"reason_tags": (trace_dict.get("reason_tags", []) as Array).duplicate(true),
		"used_mcts": bool(trace_dict.get("used_mcts", false)),
		"result": 0.5,
	}
	_total_turns = maxi(_total_turns, int(record.get("turn_number", 0)))
	for key: Variant in extra_context.keys():
		record[str(key)] = extra_context[key]
	_records.append(record)


func record_interaction_decision(record: Dictionary) -> void:
	if record.is_empty():
		return
	var entry: Dictionary = record.duplicate(true)
	entry["interaction_id"] = _interaction_records.size()
	entry["run_id"] = str(_meta.get("run_id", ""))
	entry["match_id"] = str(_meta.get("match_id", ""))
	entry["pipeline_name"] = str(_meta.get("pipeline_name", ""))
	entry["deck_identity"] = str(_meta.get("deck_identity", ""))
	entry["opponent_deck_identity"] = str(_meta.get("opponent_deck_identity", ""))
	entry["state_features"] = _to_float_array(entry.get("state_features", []))
	var candidates_variant: Variant = entry.get("candidates", [])
	var candidates: Array[Dictionary] = []
	if candidates_variant is Array:
		for candidate_variant: Variant in candidates_variant:
			if not (candidate_variant is Dictionary):
				continue
			var candidate: Dictionary = (candidate_variant as Dictionary).duplicate(true)
			if candidate.has("interaction_vector"):
				candidate["interaction_vector"] = _to_float_array(candidate.get("interaction_vector", []))
			candidates.append(candidate)
	entry["candidates"] = candidates
	_interaction_records.append(entry)


func end_game(result_variant: Variant) -> void:
	var winner_index: int = -1
	if result_variant is Dictionary:
		var result: Dictionary = result_variant
		winner_index = int(result.get("winner_index", -1))
		_failure_reason = str(result.get("failure_reason", ""))
		_terminated_by_cap = bool(result.get("terminated_by_cap", false))
		_stalled = bool(result.get("stalled", false))
		_total_turns = maxi(_total_turns, int(result.get("turn_count", 0)))
	else:
		winner_index = int(result_variant)
	_failure_reason = _failure_reason.strip_edges()
	_match_quality_weight = _compute_match_quality_weight()
	_winner_index = winner_index
	var shaped_reward: float = 1.0
	if winner_index >= 0 and _total_turns > 0:
		var turn_ratio: float = clampf(float(_total_turns) / float(max_turn_for_shaping), 0.0, 1.0)
		shaped_reward = clampf(1.0 - turn_ratio * speed_penalty, 0.5, 1.0)
	for record: Dictionary in _records:
		var player_index: int = int(record.get("player_index", -1))
		if player_index == winner_index:
			record["result"] = shaped_reward
		elif winner_index >= 0:
			record["result"] = 0.0
		else:
			record["result"] = 0.5
		record["failure_reason"] = _failure_reason
		record["terminated_by_cap"] = _terminated_by_cap
		record["stalled"] = _stalled
		record["match_quality_weight"] = _match_quality_weight
	for record: Dictionary in _interaction_records:
		var player_index: int = int(record.get("player_index", -1))
		if player_index == winner_index:
			record["result"] = shaped_reward
		elif winner_index >= 0:
			record["result"] = 0.0
		else:
			record["result"] = 0.5
		record["failure_reason"] = _failure_reason
		record["terminated_by_cap"] = _terminated_by_cap
		record["stalled"] = _stalled
		record["match_quality_weight"] = _match_quality_weight


func export_game() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var match_id: String = str(_meta.get("match_id", ""))
	var path := TrainingExportPathScript.build_unique_user_json_path(base_dir, match_id, "decision_match")
	var payload := {
		"version": "1.0",
		"winner_index": _winner_index,
		"total_turns": _total_turns,
		"failure_reason": _failure_reason,
		"terminated_by_cap": _terminated_by_cap,
		"stalled": _stalled,
		"match_quality_weight": _match_quality_weight,
		"meta": _meta.duplicate(true),
		"records": _records.duplicate(true),
		"interaction_records": _interaction_records.duplicate(true),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[AIDecisionSampleExporter] Unable to write: %s" % path)
		return ""
	file.store_string(JSON.stringify(payload))
	file.close()
	return path


func _compute_match_quality_weight() -> float:
	if _terminated_by_cap or _stalled:
		return 0.0
	match _failure_reason:
		"", "normal_game_end":
			return 1.0
		"deck_out":
			return 0.9
		"action_cap_reached", "stalled_no_progress", "unsupported_prompt", "unsupported_interaction_step", "invalid_state_transition":
			return 0.0
	return 0.0


func _build_legal_action_entries(trace_dict: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var scored_actions_variant: Variant = trace_dict.get("scored_actions", [])
	if not scored_actions_variant is Array:
		return entries
	var chosen_action: Dictionary = trace_dict.get("chosen_action", {})
	for scored_variant: Variant in scored_actions_variant:
		if not (scored_variant is Dictionary):
			continue
		var scored_action: Dictionary = (scored_variant as Dictionary).duplicate(true)
		entries.append({
			"action_index": entries.size(),
			"kind": str(scored_action.get("kind", "")),
			"score": float(scored_action.get("score", 0.0)),
			"features": _sanitize_features(scored_action.get("features", {})),
			"chosen": _actions_match(scored_action, chosen_action),
			"requires_interaction": bool(scored_action.get("requires_interaction", false)),
			"ability_index": int(scored_action.get("ability_index", -1)),
			"attack_index": int(scored_action.get("attack_index", -1)),
			"card_name": _extract_card_name(scored_action.get("card", null)),
			"target_name": _extract_target_name(scored_action.get("target_slot", null)),
			"teacher_available": bool(scored_action.get("teacher_available", false)),
			"teacher_baseline_value": float(scored_action.get("teacher_baseline_value", 0.5)),
			"teacher_post_value": float(scored_action.get("teacher_post_value", 0.5)),
			"teacher_value_delta": float(scored_action.get("teacher_value_delta", 0.0)),
			"teacher_reason": str(scored_action.get("teacher_reason", "")),
		})
	return entries


func _build_chosen_action_entry(chosen_variant: Variant) -> Dictionary:
	if not (chosen_variant is Dictionary):
		return {}
	var chosen_action: Dictionary = (chosen_variant as Dictionary).duplicate(true)
	return {
		"kind": str(chosen_action.get("kind", "")),
		"score": float(chosen_action.get("score", 0.0)),
		"features": _sanitize_features(chosen_action.get("features", {})),
		"ability_index": int(chosen_action.get("ability_index", -1)),
		"attack_index": int(chosen_action.get("attack_index", -1)),
		"card_name": _extract_card_name(chosen_action.get("card", null)),
		"target_name": _extract_target_name(chosen_action.get("target_slot", null)),
		"teacher_available": bool(chosen_action.get("teacher_available", false)),
		"teacher_baseline_value": float(chosen_action.get("teacher_baseline_value", 0.5)),
		"teacher_post_value": float(chosen_action.get("teacher_post_value", 0.5)),
		"teacher_value_delta": float(chosen_action.get("teacher_value_delta", 0.0)),
		"teacher_reason": str(chosen_action.get("teacher_reason", "")),
	}


func _sanitize_features(features_variant: Variant) -> Dictionary:
	if not (features_variant is Dictionary):
		return {}
	var features: Dictionary = (features_variant as Dictionary).duplicate(true)
	if features.has("action_vector"):
		features["action_vector"] = _to_float_array(features.get("action_vector", []))
	return features


func _to_float_array(values_variant: Variant) -> Array[float]:
	var floats: Array[float] = []
	if not (values_variant is Array):
		return floats
	for value: Variant in values_variant:
		floats.append(float(value))
	return floats


func _actions_match(lhs: Dictionary, rhs: Dictionary) -> bool:
	if lhs.is_empty() or rhs.is_empty():
		return false
	if str(lhs.get("kind", "")) != str(rhs.get("kind", "")):
		return false
	if int(lhs.get("attack_index", -1)) != int(rhs.get("attack_index", -1)):
		return false
	if int(lhs.get("ability_index", -1)) != int(rhs.get("ability_index", -1)):
		return false
	var lhs_card_name: String = _extract_card_name(lhs.get("card", null))
	var rhs_card_name: String = _extract_card_name(rhs.get("card", null))
	if lhs_card_name != rhs_card_name:
		return false
	var lhs_target_name: String = _extract_target_name(lhs.get("target_slot", null))
	var rhs_target_name: String = _extract_target_name(rhs.get("target_slot", null))
	return lhs_target_name == rhs_target_name


func _extract_card_name(card_variant: Variant) -> String:
	if card_variant is CardInstance and (card_variant as CardInstance).card_data != null:
		return str((card_variant as CardInstance).card_data.name)
	return ""


func _extract_target_name(target_variant: Variant) -> String:
	if target_variant is PokemonSlot:
		return (target_variant as PokemonSlot).get_pokemon_name()
	return ""
