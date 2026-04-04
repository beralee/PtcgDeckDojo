class_name BattleRecordExporter
extends RefCounted


func export_match(match_dir: String, meta: Dictionary, initial_state: Dictionary, events: Array, result: Dictionary) -> bool:
	if match_dir.strip_edges().is_empty():
		return false

	var global_dir := ProjectSettings.globalize_path(match_dir)
	var parent_dir := global_dir.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		var parent_error := DirAccess.make_dir_recursive_absolute(parent_dir)
		if parent_error != OK:
			return false

	if not DirAccess.dir_exists_absolute(global_dir):
		var create_error := DirAccess.make_dir_recursive_absolute(global_dir)
		if create_error != OK:
			return false

	var normalized_events := _duplicate_events(events)
	var turns_payload := _build_turns_payload(normalized_events)
	var llm_digest := _build_llm_digest(meta, initial_state, turns_payload, result)
	var turn_count: int = int(turns_payload.get("turns", []).size())

	if not _write_json(match_dir.path_join("turns.json"), turns_payload):
		return false
	if not _write_json(match_dir.path_join("llm_digest.json"), llm_digest):
		return false
	return _write_json(match_dir.path_join("match.json"), {
		"meta": meta.duplicate(true),
		"initial_state": initial_state.duplicate(true),
		"result": result.duplicate(true),
		"event_count": normalized_events.size(),
		"turn_count": turn_count,
		"turns_path": "turns.json",
		"llm_digest_path": "llm_digest.json",
	})


func _build_turns_payload(events: Array) -> Dictionary:
	var turns: Array[Dictionary] = []
	var turns_by_number: Dictionary = {}

	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = (event_variant as Dictionary).duplicate(true)
		var turn_number: int = int(event.get("turn_number", 0))
		if turn_number <= 0:
			continue

		if not turns_by_number.has(turn_number):
			var turn_entry := {
				"turn_number": turn_number,
				"phase_sequence": [],
				"snapshot_reasons": [],
				"key_choices": [],
				"key_actions": [],
				"event_count": 0,
			}
			turns_by_number[turn_number] = turn_entry
			turns.append(turn_entry)

		var turn_data: Dictionary = turns_by_number[turn_number]
		turn_data["event_count"] = int(turn_data.get("event_count", 0)) + 1
		var phase := str(event.get("phase", ""))
		if phase != "":
			var phase_sequence: Array = turn_data.get("phase_sequence", [])
			if phase_sequence.is_empty() or str(phase_sequence.back()) != phase:
				phase_sequence.append(phase)
				turn_data["phase_sequence"] = phase_sequence

		match str(event.get("event_type", "")):
			"state_snapshot":
				var snapshot_reason := str(event.get("snapshot_reason", ""))
				if snapshot_reason != "":
					var snapshot_reasons: Array = turn_data.get("snapshot_reasons", [])
					if not snapshot_reasons.has(snapshot_reason):
						snapshot_reasons.append(snapshot_reason)
						turn_data["snapshot_reasons"] = snapshot_reasons
			"choice_context":
				var key_choices: Array = turn_data.get("key_choices", [])
				key_choices.append(_summarize_choice_event(event))
				turn_data["key_choices"] = key_choices
			"action_selected":
				var existing_choices: Array = turn_data.get("key_choices", [])
				var summarized_choice := _summarize_choice_event(event)
				if not existing_choices.is_empty():
					var last_choice_variant: Variant = existing_choices.back()
					if last_choice_variant is Dictionary and _choice_events_match(last_choice_variant, summarized_choice):
						var last_choice: Dictionary = (last_choice_variant as Dictionary).duplicate(true)
						last_choice["selected_index"] = summarized_choice.get("selected_index", -1)
						last_choice["selected_count"] = summarized_choice.get("selected_count", 0)
						var selected_labels: Array = summarized_choice.get("selected_labels", [])
						if selected_labels.is_empty():
							selected_labels = _labels_from_options(
								last_choice.get("option_labels", []),
								summarized_choice.get("selected_indices", [])
							)
						last_choice["selected_labels"] = selected_labels
						last_choice["selected_indices"] = summarized_choice.get("selected_indices", [])
						existing_choices[existing_choices.size() - 1] = last_choice
						turn_data["key_choices"] = existing_choices
					else:
						existing_choices.append(summarized_choice)
						turn_data["key_choices"] = existing_choices
				else:
					existing_choices.append(summarized_choice)
					turn_data["key_choices"] = existing_choices
			"action_resolved":
				var key_actions: Array = turn_data.get("key_actions", [])
				key_actions.append(_summarize_action_event(event))
				turn_data["key_actions"] = key_actions

	return {"turns": turns}


func _build_llm_digest(meta: Dictionary, initial_state: Dictionary, turns_payload: Dictionary, result: Dictionary) -> Dictionary:
	var turns: Array = turns_payload.get("turns", [])
	var inflection_points := _build_inflection_points(turns, result)
	return {
		"meta": {
			"match_id": str(meta.get("match_id", "")),
			"mode": str(meta.get("mode", "")),
			"winner_index": int(result.get("winner_index", -1)),
			"win_reason": str(result.get("reason", "")),
			"total_turns": int(result.get("turn_count", turns.size())),
			"player_labels": meta.get("player_labels", []),
			"player_archetypes": meta.get("player_archetypes", {}),
			"first_player_index": int(meta.get("first_player_index", -1)),
		},
		"opening": _build_opening_summary(meta, initial_state),
		"turn_summaries": _build_turn_summaries(turns),
		"critical_sequences": _build_critical_sequences(turns, inflection_points),
		"inflection_points": inflection_points,
		"review_prompts": [
			"analyze_winner_plan",
			"analyze_loser_mistakes",
			"evaluate_prize_map_management",
		],
	}


func _build_opening_summary(meta: Dictionary, initial_state: Dictionary) -> Dictionary:
	var opening := {
		"first_player": int(meta.get("first_player_index", -1)),
		"mulligans": {},
		"opening_tags": {},
		"starting_active": {},
	}
	var players: Array = initial_state.get("players", [])
	for player_index_int: int in players.size():
		var player_variant: Variant = players[player_index_int]
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = player_variant
		var player_index := str(int(player.get("player_index", player_index_int)))
		var hand: Array = player.get("hand", [])
		var tags: Array[String] = []
		for card_variant: Variant in hand:
			if not (card_variant is Dictionary):
				continue
			var card: Dictionary = card_variant
			var card_name := str(card.get("card_name", "")).strip_edges()
			if card_name != "":
				tags.append(card_name)
				if tags.size() >= 5:
					break
		opening["opening_tags"][player_index] = tags
		opening["starting_active"][player_index] = player.get("active", {})
	return opening


func _build_turn_summaries(turns: Array) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for turn_variant: Variant in turns:
		if not (turn_variant is Dictionary):
			continue
		var turn: Dictionary = turn_variant
		summaries.append({
			"turn_number": int(turn.get("turn_number", 0)),
			"phase_sequence": turn.get("phase_sequence", []).duplicate(true),
			"snapshot_reasons": turn.get("snapshot_reasons", []).duplicate(true),
			"key_choices": turn.get("key_choices", []).duplicate(true),
			"key_actions": turn.get("key_actions", []).duplicate(true),
			"missed_opportunities": [],
		})
	return summaries


func _summarize_choice_event(event: Dictionary) -> Dictionary:
	var summary := {
		"event_type": str(event.get("event_type", "")),
		"player_index": int(event.get("player_index", -1)),
		"prompt_type": str(event.get("prompt_type", "")),
		"prompt_source": str(event.get("prompt_source", event.get("selection_source", ""))),
		"title": str(event.get("title", "")),
		"selected_index": int(event.get("selected_index", -1)),
		"selected_count": int(event.get("selected_count", 0)),
	}
	var selected_labels_variant: Variant = event.get("selected_labels", [])
	if selected_labels_variant is Array:
		summary["selected_labels"] = (selected_labels_variant as Array).duplicate(true)
	var selected_indices_variant: Variant = event.get("selected_indices", [])
	if selected_indices_variant is Array:
		summary["selected_indices"] = (selected_indices_variant as Array).duplicate(true)
	elif int(summary.get("selected_index", -1)) >= 0:
		summary["selected_indices"] = [int(summary.get("selected_index", -1))]
	var items_variant: Variant = event.get("items", [])
	if items_variant is Array:
		summary["option_labels"] = _option_labels_from_items(items_variant as Array)
	var assignments_variant: Variant = event.get("assignments", [])
	if assignments_variant is Array and not (assignments_variant as Array).is_empty():
		summary["selected_labels"] = _summarize_assignments(assignments_variant as Array)
		summary["selected_count"] = (assignments_variant as Array).size()
	return summary


func _option_labels_from_items(items: Array) -> Array[String]:
	var labels: Array[String] = []
	for item: Variant in items:
		labels.append(_selection_label(item))
	return labels


func _labels_from_options(option_labels_variant: Variant, selected_indices_variant: Variant) -> Array:
	var labels: Array = []
	if not (option_labels_variant is Array) or not (selected_indices_variant is Array):
		return labels
	var option_labels: Array = option_labels_variant
	var selected_indices: Array = selected_indices_variant
	for index_variant: Variant in selected_indices:
		var idx: int = int(index_variant)
		if idx < 0 or idx >= option_labels.size():
			continue
		labels.append(option_labels[idx])
	return labels


func _summarize_assignments(assignments: Array) -> Array[String]:
	var labels: Array[String] = []
	for assignment_variant: Variant in assignments:
		if not (assignment_variant is Dictionary):
			continue
		var assignment: Dictionary = assignment_variant
		var source_label := _selection_label(assignment.get("source"))
		var target_label := _selection_label(assignment.get("target"))
		if source_label != "" and target_label != "":
			labels.append("%s -> %s" % [source_label, target_label])
		elif source_label != "":
			labels.append(source_label)
		elif target_label != "":
			labels.append(target_label)
	return labels


func _selection_label(value: Variant) -> String:
	if value is Dictionary:
		var entry: Dictionary = value
		for key: String in ["pokemon_name", "card_name", "name", "title"]:
			var text := str(entry.get(key, "")).strip_edges()
			if text != "":
				return text
		return ""
	return str(value).strip_edges()


func _summarize_action_event(event: Dictionary) -> Dictionary:
	var summary := {
		"event_type": str(event.get("event_type", "")),
		"player_index": int(event.get("player_index", -1)),
		"description": str(event.get("description", "")),
	}
	var data_variant: Variant = event.get("data", {})
	if data_variant is Dictionary:
		var data: Dictionary = data_variant
		if data.has("attack_name"):
			summary["attack_name"] = str(data.get("attack_name", ""))
		if data.has("damage"):
			summary["damage"] = int(data.get("damage", 0))
		if data.has("target_pokemon_name"):
			summary["target_pokemon_name"] = str(data.get("target_pokemon_name", ""))
		if data.has("prize_count"):
			summary["prize_count"] = int(data.get("prize_count", 0))
		if data.has("reason"):
			summary["reason"] = str(data.get("reason", ""))
	return summary


func _choice_events_match(existing_choice: Variant, selected_choice: Dictionary) -> bool:
	if not (existing_choice is Dictionary):
		return false
	var existing: Dictionary = existing_choice
	var selected_prompt_type := str(selected_choice.get("prompt_type", ""))
	var selected_title := str(selected_choice.get("title", ""))
	if selected_prompt_type == "" and selected_title == "":
		return true
	return (
		str(existing.get("prompt_type", "")) == selected_prompt_type
		and str(existing.get("title", "")) == selected_title
	)


func _duplicate_events(events: Array) -> Array:
	var copied: Array = []
	for event: Variant in events:
		if event is Dictionary:
			copied.append((event as Dictionary).duplicate(true))
		else:
			copied.append(event)
	return copied


func _build_inflection_points(turns: Array, result: Dictionary) -> Array[Dictionary]:
	var inflection_points: Array[Dictionary] = []
	for turn_variant: Variant in turns:
		if not (turn_variant is Dictionary):
			continue
		var turn: Dictionary = turn_variant
		var turn_number: int = int(turn.get("turn_number", 0))
		var key_actions: Array = turn.get("key_actions", [])
		for action_variant: Variant in key_actions:
			if not (action_variant is Dictionary):
				continue
			var action: Dictionary = action_variant
			var description := str(action.get("description", ""))
			var player_index: int = int(action.get("player_index", -1))
			var damage: int = int(action.get("damage", 0))
			var prize_count: int = int(action.get("prize_count", 0))
			var reason := str(action.get("reason", ""))
			if damage >= 200:
				inflection_points.append({
					"turn_number": turn_number,
					"player_index": player_index,
					"kind": "big_damage",
					"summary": description,
				})
			if prize_count >= 2:
				inflection_points.append({
					"turn_number": turn_number,
					"player_index": player_index,
					"kind": "multi_prize_knockout",
					"summary": description,
				})
			if prize_count > 0:
				inflection_points.append({
					"turn_number": turn_number,
					"player_index": player_index,
					"kind": "knockout",
					"summary": description,
				})
			if reason != "":
				inflection_points.append({
					"turn_number": turn_number,
					"player_index": player_index,
					"kind": "game_end",
					"summary": description if description != "" else reason,
				})
		var key_choices: Array = turn.get("key_choices", [])
		for choice_variant: Variant in key_choices:
			if not (choice_variant is Dictionary):
				continue
			var choice: Dictionary = choice_variant
			if str(choice.get("prompt_source", "")) == "field_slot":
				inflection_points.append({
					"turn_number": turn_number,
					"player_index": int(choice.get("player_index", -1)),
					"kind": "field_slot_choice",
					"summary": str(choice.get("title", "")),
				})
	inflection_points = _dedupe_inflection_points(inflection_points)
	if inflection_points.is_empty():
		inflection_points.append({
			"turn_number": int(result.get("turn_count", 0)),
			"player_index": int(result.get("winner_index", -1)),
			"kind": "result",
			"summary": str(result.get("reason", "")),
		})
	return inflection_points


func _dedupe_inflection_points(points: Array[Dictionary]) -> Array[Dictionary]:
	var deduped: Array[Dictionary] = []
	var seen: Dictionary = {}
	for point: Dictionary in points:
		var key := "%d|%d|%s|%s" % [
			int(point.get("turn_number", 0)),
			int(point.get("player_index", -1)),
			str(point.get("kind", "")),
			str(point.get("summary", "")),
		]
		if seen.has(key):
			continue
		seen[key] = true
		deduped.append(point)
	return deduped


func _build_critical_sequences(turns: Array, inflection_points: Array[Dictionary]) -> Array[Dictionary]:
	var turn_map: Dictionary = {}
	for turn_variant: Variant in turns:
		if not (turn_variant is Dictionary):
			continue
		var turn: Dictionary = turn_variant
		turn_map[int(turn.get("turn_number", 0))] = turn
	var sequences: Array[Dictionary] = []
	var covered_turns: Dictionary = {}
	for point: Dictionary in inflection_points:
		var turn_number: int = int(point.get("turn_number", 0))
		if covered_turns.has(turn_number) or not turn_map.has(turn_number):
			continue
		covered_turns[turn_number] = true
		var turn: Dictionary = turn_map.get(turn_number, {})
		var action_descriptions: Array[String] = []
		for action_variant: Variant in turn.get("key_actions", []):
			if not (action_variant is Dictionary):
				continue
			var description := str((action_variant as Dictionary).get("description", "")).strip_edges()
			if description != "":
				action_descriptions.append(description)
			if action_descriptions.size() >= 4:
				break
		sequences.append({
			"turn_number": turn_number,
			"player_index": int(point.get("player_index", -1)),
			"reason": str(point.get("summary", "")),
			"actions": action_descriptions,
		})
		if sequences.size() >= 3:
			break
	return sequences


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true
