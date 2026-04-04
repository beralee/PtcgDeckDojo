class_name BattleReviewDataBuilder
extends RefCounted

const BattleReviewTurnExtractorScript = preload("res://scripts/engine/BattleReviewTurnExtractor.gd")
const BattleReviewContextBuilderScript = preload("res://scripts/engine/BattleReviewContextBuilder.gd")

var _extractor = BattleReviewTurnExtractorScript.new()
var _context_builder = BattleReviewContextBuilderScript.new()


func build_stage1_payload(match_dir: String) -> Dictionary:
	var llm_digest := _read_json_file(match_dir.path_join("llm_digest.json"))
	var turns_payload := _read_json_file(match_dir.path_join("turns.json"))
	var match_payload := _read_json_file(match_dir.path_join("match.json"))
	return {
		"meta": llm_digest.get("meta", match_payload.get("meta", {})),
		"opening": llm_digest.get("opening", {}),
		"turn_summaries": _compact_stage1_turn_summaries(llm_digest.get("turn_summaries", turns_payload.get("turns", []))),
		"inflection_points": _compact_inflection_points(llm_digest.get("inflection_points", [])),
		"result": match_payload.get("result", {}),
	}


func build_turn_packet(match_dir: String, turn_number: int) -> Dictionary:
	var turn_slice := _extractor.extract_turn(match_dir, turn_number)
	return _context_builder.build_turn_packet(turn_slice)


func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _compact_stage1_turn_summaries(turn_summaries_variant: Variant) -> Array[Dictionary]:
	var compact: Array[Dictionary] = []
	if not (turn_summaries_variant is Array):
		return compact
	for summary_variant: Variant in turn_summaries_variant:
		if not (summary_variant is Dictionary):
			continue
		var summary: Dictionary = summary_variant
		var compact_summary := {
			"turn_number": int(summary.get("turn_number", 0)),
			"key_actions": _compact_stage1_key_actions(summary.get("key_actions", [])),
			"key_choices": _compact_stage1_key_choices(summary.get("key_choices", [])),
		}
		compact.append(compact_summary)
	return compact


func _compact_stage1_key_actions(key_actions_variant: Variant) -> Array[String]:
	var compact: Array[String] = []
	if not (key_actions_variant is Array):
		return compact
	for action_variant: Variant in key_actions_variant:
		if not (action_variant is Dictionary):
			continue
		var description := str((action_variant as Dictionary).get("description", "")).strip_edges()
		if description == "":
			continue
		compact.append(description)
		if compact.size() >= 4:
			break
	return compact


func _compact_stage1_key_choices(key_choices_variant: Variant) -> Array[Dictionary]:
	var compact: Array[Dictionary] = []
	if not (key_choices_variant is Array):
		return compact
	for choice_variant: Variant in key_choices_variant:
		if not (choice_variant is Dictionary):
			continue
		var choice: Dictionary = choice_variant
		compact.append({
			"title": str(choice.get("title", "")),
			"selected_labels": choice.get("selected_labels", []),
		})
		if compact.size() >= 2:
			break
	return compact


func _compact_inflection_points(inflection_points_variant: Variant) -> Array[Dictionary]:
	var compact: Array[Dictionary] = []
	if not (inflection_points_variant is Array):
		return compact
	for point_variant: Variant in inflection_points_variant:
		if not (point_variant is Dictionary):
			continue
		var point: Dictionary = point_variant
		compact.append({
			"turn_number": int(point.get("turn_number", 0)),
			"kind": str(point.get("kind", "")),
			"summary": str(point.get("summary", "")),
		})
		if compact.size() >= 6:
			break
	return compact
