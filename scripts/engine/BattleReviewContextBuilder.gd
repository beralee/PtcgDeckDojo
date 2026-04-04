class_name BattleReviewContextBuilder
extends RefCounted

const BattleReviewHeuristicsScript = preload("res://scripts/engine/BattleReviewHeuristics.gd")

var _heuristics = BattleReviewHeuristicsScript.new()


func build_turn_packet(turn_slice: Dictionary) -> Dictionary:
	var turn_number := int(turn_slice.get("turn_number", 0))
	var events: Array = turn_slice.get("events", [])
	var before_snapshot: Dictionary = turn_slice.get("before_snapshot", {})
	var match_meta: Dictionary = turn_slice.get("match_meta", {})
	var match_result: Dictionary = turn_slice.get("match_result", {})
	var player_index := _acting_player_index(events)
	var acting_archetype := _player_archetype(match_meta, player_index)
	var opponent_index := _opponent_index(before_snapshot, player_index)
	var opponent_archetype := _player_archetype(match_meta, opponent_index)
	return {
		"turn_number": turn_number,
		"player_index": player_index,
		"player_role": _player_role(player_index, match_result),
		"board_before_turn": _board_before_turn(before_snapshot),
		"zones_before_turn": _zones_before_turn(before_snapshot),
		"actions_and_choices": _actions_and_choices(events),
		"legal_choice_contexts": _legal_choice_contexts(events),
		"strategic_context": {
			"prior_turn_summaries": _prior_turn_summaries(turn_slice),
			"previous_turn_summary": turn_slice.get("previous_turn_summary", {}),
			"current_turn_summary": turn_slice.get("current_turn_summary", {}),
			"match_result": match_result,
		},
		"deck_context": {
			"player_labels": match_meta.get("player_labels", []),
			"player_archetypes": match_meta.get("player_archetypes", {}),
			"acting_player_archetype": acting_archetype,
			"opponent_archetype": opponent_archetype,
			"first_player_index": int(match_meta.get("first_player_index", -1)),
		},
		"matchup_context": {
			"pairing": _matchup_pairing(acting_archetype, opponent_archetype),
			"acting_player_archetype": acting_archetype,
			"opponent_archetype": opponent_archetype,
		},
		"heuristic_tags": _heuristics.build_turn_tags(turn_slice),
	}


func _acting_player_index(events: Array) -> int:
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		var player_index := int((event_variant as Dictionary).get("player_index", -1))
		if player_index >= 0:
			return player_index
	return -1


func _player_role(player_index: int, match_result: Dictionary) -> String:
	if player_index < 0:
		return "unknown"
	if int(match_result.get("winner_index", -1)) == player_index:
		return "winner_candidate"
	return "loser_candidate"


func _board_before_turn(before_snapshot: Dictionary) -> Dictionary:
	var state_variant: Variant = before_snapshot.get("state", {})
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	var players: Array = state.get("players", [])
	var board := {
		"current_player_index": int(state.get("current_player_index", -1)),
		"players": [],
	}
	for player_variant: Variant in players:
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = player_variant
		board["players"].append({
			"player_index": int(player.get("player_index", -1)),
			"active": _summarize_slot(player.get("active", {})),
			"bench": _summarize_slots(player.get("bench", [])),
		})
	return board


func _zones_before_turn(before_snapshot: Dictionary) -> Dictionary:
	var state_variant: Variant = before_snapshot.get("state", {})
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	var players: Array = state.get("players", [])
	var zones := {"players": []}
	for player_variant: Variant in players:
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = player_variant
		zones["players"].append({
			"player_index": int(player.get("player_index", -1)),
			"hand": _summarize_cards(player.get("hand", [])),
			"hand_count": _zone_count(player, "hand"),
			"discard": _summarize_cards(player.get("discard", [])),
			"discard_count": _zone_count(player, "discard"),
			"prize_count": int(player.get("prize_count", 0)),
			"deck_count": int(player.get("deck_count", 0)),
		})
	return zones


func _actions_and_choices(events: Array) -> Array[Dictionary]:
	var timeline: Array[Dictionary] = []
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		var event_type := str(event.get("event_type", ""))
		if event_type in ["choice_context", "action_selected", "action_resolved"]:
			timeline.append(_summarize_event(event))
	return timeline


func _legal_choice_contexts(events: Array) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		if str(event.get("event_type", "")) == "choice_context":
			choices.append(_summarize_event(event))
	return choices


func _summarize_event(event: Dictionary) -> Dictionary:
	var summary := {
		"event_type": str(event.get("event_type", "")),
		"event_index": int(event.get("event_index", -1)),
		"player_index": int(event.get("player_index", -1)),
		"turn_number": int(event.get("turn_number", 0)),
		"phase": str(event.get("phase", "")),
	}
	var event_type := str(event.get("event_type", ""))
	match event_type:
		"choice_context":
			summary["prompt_source"] = str(event.get("prompt_source", ""))
			summary["prompt_type"] = str(event.get("prompt_type", ""))
			summary["title"] = str(event.get("title", ""))
			summary["option_labels"] = _extract_option_labels(event)
			var extra_summary := _summarize_extra_data(event.get("extra_data", {}))
			if not extra_summary.is_empty():
				summary["context"] = extra_summary
		"action_selected":
			summary["selection_source"] = str(event.get("selection_source", ""))
			summary["prompt_type"] = str(event.get("prompt_type", ""))
			summary["title"] = str(event.get("title", ""))
			summary["selected_index"] = int(event.get("selected_index", -1))
			summary["selected_indices"] = _int_array(event.get("selected_indices", []))
			summary["selected_labels"] = _string_array(event.get("selected_labels", []))
			var assignments := _summarize_assignments(event.get("assignments", []))
			if not assignments.is_empty():
				summary["assignments"] = assignments
		"action_resolved":
			summary["action_type"] = int(event.get("action_type", -1))
			summary["description"] = str(event.get("description", ""))
			var data_summary := _summarize_scalar_dict(event.get("data", {}))
			if not data_summary.is_empty():
				summary["data"] = data_summary
	return summary


func _extract_option_labels(event: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	var items_variant: Variant = event.get("items", [])
	if items_variant is Array:
		for item: Variant in items_variant:
			var label := _label_from_value(item)
			if label != "":
				labels.append(label)
	var extra_data_variant: Variant = event.get("extra_data", {})
	if labels.is_empty() and extra_data_variant is Dictionary:
		var extra_data: Dictionary = extra_data_variant
		var choice_labels_variant: Variant = extra_data.get("choice_labels", [])
		if choice_labels_variant is Array:
			for label_variant: Variant in choice_labels_variant:
				var text := str(label_variant).strip_edges()
				if text != "":
					labels.append(text)
		var actions_variant: Variant = extra_data.get("actions", [])
		if labels.is_empty() and actions_variant is Array:
			for action_variant: Variant in actions_variant:
				if not (action_variant is Dictionary):
					continue
				var action: Dictionary = action_variant
				var text := str(action.get("label", action.get("name", ""))).strip_edges()
				if text != "":
					labels.append(text)
	return labels


func _summarize_extra_data(extra_data_variant: Variant) -> Dictionary:
	if not (extra_data_variant is Dictionary):
		return {}
	var extra_data: Dictionary = extra_data_variant
	var summary := _summarize_scalar_dict(extra_data, ["player", "min_select", "max_select", "allow_cancel", "ui_mode", "presentation"])
	var actions_variant: Variant = extra_data.get("actions", [])
	if actions_variant is Array:
		var action_labels: Array[String] = []
		for action_variant: Variant in actions_variant:
			if not (action_variant is Dictionary):
				continue
			var action: Dictionary = action_variant
			var label := str(action.get("label", action.get("name", ""))).strip_edges()
			if label != "":
				action_labels.append(label)
		if not action_labels.is_empty():
			summary["action_labels"] = action_labels
	return summary


func _summarize_scalar_dict(source_variant: Variant, allowed_keys: Array[String] = []) -> Dictionary:
	if not (source_variant is Dictionary):
		return {}
	var source: Dictionary = source_variant
	var summary := {}
	for key_variant: Variant in source.keys():
		var key := str(key_variant)
		if not allowed_keys.is_empty() and not allowed_keys.has(key):
			continue
		var value: Variant = source.get(key_variant)
		if value is String or value is bool or value is int or value is float:
			summary[key] = value
	return summary


func _summarize_assignments(assignments_variant: Variant) -> Array[String]:
	var labels: Array[String] = []
	if not (assignments_variant is Array):
		return labels
	for assignment_variant: Variant in assignments_variant:
		if not (assignment_variant is Dictionary):
			continue
		var assignment: Dictionary = assignment_variant
		var source := _label_from_value(assignment.get("source"))
		var target := _label_from_value(assignment.get("target"))
		if source != "" and target != "":
			labels.append("%s -> %s" % [source, target])
		elif source != "":
			labels.append(source)
		elif target != "":
			labels.append(target)
	return labels


func _label_from_value(value: Variant) -> String:
	if value is String:
		return str(value).strip_edges()
	if value is Dictionary:
		var entry: Dictionary = value
		for key: String in ["pokemon_name", "card_name", "name", "title", "label"]:
			var text := str(entry.get(key, "")).strip_edges()
			if text != "":
				return text
	return ""


func _string_array(values_variant: Variant) -> Array[String]:
	var values: Array[String] = []
	if not (values_variant is Array):
		return values
	for value: Variant in values_variant:
		values.append(str(value))
	return values


func _int_array(values_variant: Variant) -> Array[int]:
	var values: Array[int] = []
	if not (values_variant is Array):
		return values
	for value: Variant in values_variant:
		values.append(int(value))
	return values


func _prior_turn_summaries(turn_slice: Dictionary) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	var prior_variant: Variant = turn_slice.get("prior_turn_summaries", [])
	if prior_variant is Array:
		for summary_variant: Variant in prior_variant:
			if summary_variant is Dictionary:
				summaries.append(_summarize_turn_summary(summary_variant as Dictionary))
	if summaries.is_empty():
		var previous_variant: Variant = turn_slice.get("previous_turn_summary", {})
		if previous_variant is Dictionary and not (previous_variant as Dictionary).is_empty():
			summaries.append(_summarize_turn_summary(previous_variant as Dictionary))
	return summaries


func _opponent_index(before_snapshot: Dictionary, player_index: int) -> int:
	var state_variant: Variant = before_snapshot.get("state", {})
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	var players: Array = state.get("players", [])
	for player_variant: Variant in players:
		if not (player_variant is Dictionary):
			continue
		var other_index := int((player_variant as Dictionary).get("player_index", -1))
		if other_index >= 0 and other_index != player_index:
			return other_index
	return -1


func _player_archetype(match_meta: Dictionary, player_index: int) -> String:
	if player_index < 0:
		return ""
	var archetypes_variant: Variant = match_meta.get("player_archetypes", {})
	if not (archetypes_variant is Dictionary):
		return ""
	var archetypes: Dictionary = archetypes_variant
	for key_variant: Variant in archetypes.keys():
		var key_text := str(key_variant)
		if key_text == str(player_index):
			return str(archetypes.get(key_variant, ""))
	return ""


func _matchup_pairing(acting_archetype: String, opponent_archetype: String) -> String:
	if acting_archetype == "" and opponent_archetype == "":
		return ""
	if opponent_archetype == "":
		return acting_archetype
	if acting_archetype == "":
		return opponent_archetype
	return "%s vs %s" % [acting_archetype, opponent_archetype]


func _summarize_slots(slots_variant: Variant) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	if not (slots_variant is Array):
		return summaries
	for slot_variant: Variant in slots_variant:
		var summary := _summarize_slot(slot_variant)
		if not summary.is_empty():
			summaries.append(summary)
	return summaries


func _summarize_slot(slot_variant: Variant) -> Dictionary:
	if not (slot_variant is Dictionary):
		return {}
	var slot: Dictionary = slot_variant
	var summary := {}
	var pokemon_name := str(slot.get("pokemon_name", "")).strip_edges()
	if pokemon_name == "":
		pokemon_name = _top_card_name(slot.get("pokemon_stack", []))
	if pokemon_name != "":
		summary["pokemon_name"] = pokemon_name
	var stack_names := _summarize_cards(slot.get("pokemon_stack", []))
	if not stack_names.is_empty():
		summary["stack"] = stack_names
	var attached_energy := _summarize_cards(slot.get("attached_energy", []))
	if not attached_energy.is_empty():
		summary["attached_energy"] = attached_energy
		summary["energy_count"] = attached_energy.size()
	var attached_tool := _label_from_value(slot.get("attached_tool", {}))
	if attached_tool != "":
		summary["attached_tool"] = attached_tool
	var remaining_hp := int(slot.get("remaining_hp", 0))
	if remaining_hp > 0:
		summary["remaining_hp"] = remaining_hp
	var max_hp := int(slot.get("max_hp", 0))
	if max_hp > 0:
		summary["max_hp"] = max_hp
	var damage_counters := int(slot.get("damage_counters", 0))
	if damage_counters > 0:
		summary["damage_counters"] = damage_counters
	var status_conditions := _active_statuses(slot.get("status_conditions", {}))
	if not status_conditions.is_empty():
		summary["status_conditions"] = status_conditions
	return summary


func _summarize_cards(cards_variant: Variant) -> Array[String]:
	var summaries: Array[String] = []
	if not (cards_variant is Array):
		return summaries
	for card_variant: Variant in cards_variant:
		var label := _label_from_value(card_variant)
		if label != "":
			summaries.append(label)
	return summaries


func _zone_count(player: Dictionary, key: String) -> int:
	var explicit_count_key := "%s_count" % key
	var explicit_count := int(player.get(explicit_count_key, -1))
	if explicit_count >= 0:
		return explicit_count
	var zone_variant: Variant = player.get(key, [])
	return (zone_variant as Array).size() if zone_variant is Array else 0


func _top_card_name(cards_variant: Variant) -> String:
	if not (cards_variant is Array) or (cards_variant as Array).is_empty():
		return ""
	return _label_from_value((cards_variant as Array)[-1])


func _active_statuses(status_variant: Variant) -> Array[String]:
	var statuses: Array[String] = []
	if not (status_variant is Dictionary):
		return statuses
	var status_dict: Dictionary = status_variant
	for key_variant: Variant in status_dict.keys():
		var key := str(key_variant)
		if bool(status_dict.get(key_variant, false)):
			statuses.append(key)
	return statuses


func _summarize_turn_summary(summary: Dictionary) -> Dictionary:
	var compact := {
		"turn_number": int(summary.get("turn_number", 0)),
		"event_count": int(summary.get("event_count", 0)),
		"key_actions": [],
		"key_choices": [],
	}
	var key_actions_variant: Variant = summary.get("key_actions", [])
	if key_actions_variant is Array:
		for action_variant: Variant in key_actions_variant:
			if not (action_variant is Dictionary):
				continue
			var action: Dictionary = action_variant
			compact["key_actions"].append({
				"description": str(action.get("description", "")),
			})
			if (compact["key_actions"] as Array).size() >= 6:
				break
	var key_choices_variant: Variant = summary.get("key_choices", [])
	if key_choices_variant is Array:
		for choice_variant: Variant in key_choices_variant:
			if not (choice_variant is Dictionary):
				continue
			var choice: Dictionary = choice_variant
			compact["key_choices"].append({
				"title": str(choice.get("title", "")),
				"selected_labels": _string_array(choice.get("selected_labels", [])),
			})
			if (compact["key_choices"] as Array).size() >= 3:
				break
	return compact
