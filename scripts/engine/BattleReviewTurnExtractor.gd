class_name BattleReviewTurnExtractor
extends RefCounted


func extract_turn(match_dir: String, turn_number: int) -> Dictionary:
	var normalized_dir := match_dir.trim_suffix("/").trim_suffix("\\")
	var match_data := _read_json_file(normalized_dir.path_join("match.json"))
	var turns_payload := _read_json_file(normalized_dir.path_join("turns.json"))
	var events := _read_detail_events(normalized_dir)
	var turn_events := _filter_turn_events(events, turn_number)
	return {
		"match_dir": normalized_dir,
		"turn_number": turn_number,
		"events": turn_events,
		"before_snapshot": _nearest_snapshot_before(events, turn_number),
		"after_snapshot": _nearest_snapshot_after(events, turn_number),
		"previous_turn_summary": _load_turn_summary(turns_payload, turn_number - 1),
		"prior_turn_summaries": _load_prior_turn_summaries(turns_payload, turn_number, 2),
		"current_turn_summary": _load_turn_summary(turns_payload, turn_number),
		"match_meta": match_data.get("meta", {}),
		"match_result": match_data.get("result", {}),
	}


func _read_detail_events(match_dir: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var detail_path := match_dir.path_join("detail.jsonl")
	var file := FileAccess.open(detail_path, FileAccess.READ)
	if file == null:
		return events

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			events.append(parsed)
	file.close()
	return events


func _filter_turn_events(events: Array[Dictionary], turn_number: int) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event: Dictionary in events:
		if int(event.get("turn_number", 0)) == turn_number:
			filtered.append(event.duplicate(true))
	return filtered


func _nearest_snapshot_before(events: Array[Dictionary], turn_number: int) -> Dictionary:
	var latest: Dictionary = {}
	for event: Dictionary in events:
		if str(event.get("event_type", "")) != "state_snapshot":
			continue
		if int(event.get("turn_number", 0)) >= turn_number:
			continue
		latest = event.duplicate(true)
	return latest


func _nearest_snapshot_after(events: Array[Dictionary], turn_number: int) -> Dictionary:
	var latest_in_turn: Dictionary = {}
	for event: Dictionary in events:
		if str(event.get("event_type", "")) != "state_snapshot":
			continue
		if int(event.get("turn_number", 0)) == turn_number:
			latest_in_turn = event.duplicate(true)
	if not latest_in_turn.is_empty():
		return latest_in_turn

	for event: Dictionary in events:
		if str(event.get("event_type", "")) != "state_snapshot":
			continue
		if int(event.get("turn_number", 0)) > turn_number:
			return event.duplicate(true)
	return {}


func _load_turn_summary(turns_payload: Dictionary, turn_number: int) -> Dictionary:
	var turns: Array = turns_payload.get("turns", [])
	for turn_variant: Variant in turns:
		if not (turn_variant is Dictionary):
			continue
		var turn: Dictionary = turn_variant
		if int(turn.get("turn_number", 0)) == turn_number:
			return turn.duplicate(true)
	return {}


func _load_prior_turn_summaries(turns_payload: Dictionary, turn_number: int, max_items: int) -> Array[Dictionary]:
	var prior: Array[Dictionary] = []
	if max_items <= 0:
		return prior
	var turns: Array = turns_payload.get("turns", [])
	for turn_variant: Variant in turns:
		if not (turn_variant is Dictionary):
			continue
		var turn: Dictionary = turn_variant
		var summary_turn := int(turn.get("turn_number", 0))
		if summary_turn <= 0 or summary_turn >= turn_number:
			continue
		prior.append(turn.duplicate(true))
	if prior.size() <= max_items:
		return prior
	return prior.slice(prior.size() - max_items, prior.size())


func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
