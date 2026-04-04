class_name BattleAdviceContextBuilder
extends RefCounted

const MAX_SUMMARY_LINES := 24
const MAX_DETAIL_EVENTS := 48
const MAX_ZONE_CARD_NAMES := 18
const MAX_DECKLIST_ENTRIES := 60
const MAX_OPTION_LABELS := 8


func build_request_context(live_snapshot: Dictionary, initial_snapshot: Dictionary, match_dir: String, view_player: int, session: Dictionary) -> Dictionary:
	return {
		"session": {
			"session_id": str(session.get("session_id", "")),
			"request_index": int(session.get("request_index", session.get("next_request_index", 1))),
			"last_advice_summary": str(session.get("last_advice_summary", "")),
			"current_player_index": view_player,
		},
		"visibility_rules": _visibility_rules(),
		"current_position": _current_position(live_snapshot, initial_snapshot, view_player),
		"delta_since_last_advice": _build_delta(match_dir, int(session.get("last_synced_event_index", 0))),
	}


func _visibility_rules() -> Dictionary:
	return {
		"known": [
			"current_player_hand",
			"public_board_state",
			"public_discard_piles",
			"public_prize_counts",
			"both_decklists",
			"historical_public_actions",
		],
		"unknown": [
			"opponent_hand_contents",
			"prize_identities",
			"deck_order",
		],
	}


func _current_position(live_snapshot: Dictionary, initial_snapshot: Dictionary, view_player: int) -> Dictionary:
	var position := {
		"turn_number": int(live_snapshot.get("turn_number", 0)),
		"phase": str(live_snapshot.get("phase", "")),
		"current_player_index": int(live_snapshot.get("current_player_index", -1)),
		"first_player_index": int(live_snapshot.get("first_player_index", -1)),
		"winner_index": int(live_snapshot.get("winner_index", -1)),
		"win_reason": str(live_snapshot.get("win_reason", "")),
		"energy_attached_this_turn": bool(live_snapshot.get("energy_attached_this_turn", false)),
		"supporter_used_this_turn": bool(live_snapshot.get("supporter_used_this_turn", false)),
		"stadium_played_this_turn": bool(live_snapshot.get("stadium_played_this_turn", false)),
		"retreat_used_this_turn": bool(live_snapshot.get("retreat_used_this_turn", false)),
		"stadium_card": _summarize_card_entry(live_snapshot.get("stadium_card", {})),
		"stadium_owner_index": int(live_snapshot.get("stadium_owner_index", -1)),
	}
	position["players"] = _filtered_players(live_snapshot.get("players", []), view_player)
	position["decklists"] = _decklists_from_initial_snapshot(initial_snapshot)
	return position


func _filtered_players(players_variant: Variant, view_player: int) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	if not (players_variant is Array):
		return filtered
	for player_variant: Variant in players_variant:
		if not (player_variant is Dictionary):
			continue
		filtered.append(_summarize_player_position(player_variant as Dictionary, view_player))
	return filtered


func _decklists_from_initial_snapshot(initial_snapshot: Dictionary) -> Array[Dictionary]:
	var decklists: Array[Dictionary] = []
	var players: Array = initial_snapshot.get("players", [])
	for player_variant: Variant in players:
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = player_variant
		var compact_decklist: Array[Dictionary] = []
		var decklist_variant: Variant = player.get("decklist", [])
		if decklist_variant is Array:
			for entry_variant: Variant in decklist_variant:
				if not (entry_variant is Dictionary):
					continue
				compact_decklist.append({
					"card_name": str((entry_variant as Dictionary).get("card_name", "")),
					"count": int((entry_variant as Dictionary).get("count", 0)),
				})
				if compact_decklist.size() >= MAX_DECKLIST_ENTRIES:
					break
		decklists.append({
			"player_index": int(player.get("player_index", -1)),
			"decklist": compact_decklist,
		})
	return decklists


func _build_delta(match_dir: String, last_synced_event_index: int) -> Dictionary:
	var detail_events: Array[Dictionary] = []
	for event: Dictionary in _read_json_lines(match_dir.path_join("detail.jsonl")):
		if int(event.get("event_index", -1)) > last_synced_event_index:
			detail_events.append(_summarize_detail_event(event))
	if detail_events.size() > MAX_DETAIL_EVENTS:
		detail_events = detail_events.slice(detail_events.size() - MAX_DETAIL_EVENTS, detail_events.size())

	return {
		"summary_lines": _tail_lines(_read_text_lines(match_dir.path_join("summary.log")), MAX_SUMMARY_LINES),
		"detail_events": detail_events,
	}


func _read_text_lines(path: String) -> Array[String]:
	var lines: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return lines
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges() != "":
			lines.append(line)
	file.close()
	return lines


func _read_json_lines(path: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return lines
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			lines.append(parsed)
	file.close()
	return lines


func _tail_lines(lines: Array[String], max_items: int) -> Array[String]:
	if lines.size() <= max_items:
		return lines
	return lines.slice(lines.size() - max_items, lines.size())


func _summarize_player_position(player: Dictionary, view_player: int) -> Dictionary:
	var player_index := int(player.get("player_index", -1))
	var summary := {
		"player_index": player_index,
		"hand_count": int(player.get("hand_count", 0)),
		"deck_count": int(player.get("deck_count", 0)),
		"discard_count": int(player.get("discard_count", 0)),
		"prize_count": int(player.get("prize_count", 0)),
		"active": _summarize_slot(player.get("active", {})),
		"bench": _summarize_slot_array(player.get("bench", [])),
		"discard_pile": _summarize_zone(player.get("discard_pile", []), MAX_ZONE_CARD_NAMES),
		"lost_zone": _summarize_zone(player.get("lost_zone", []), 8),
	}
	if player_index == view_player:
		summary["hand"] = _summarize_zone(player.get("hand", []), MAX_ZONE_CARD_NAMES)
	return summary


func _summarize_slot_array(slots_variant: Variant) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	if not (slots_variant is Array):
		return summaries
	for slot_variant: Variant in slots_variant:
		summaries.append(_summarize_slot(slot_variant))
	return summaries


func _summarize_slot(slot_variant: Variant) -> Dictionary:
	if not (slot_variant is Dictionary):
		return {}
	var slot: Dictionary = slot_variant
	var summary := {
		"pokemon_name": str(slot.get("pokemon_name", "")),
		"remaining_hp": int(slot.get("remaining_hp", 0)),
		"max_hp": int(slot.get("max_hp", 0)),
		"damage_counters": int(slot.get("damage_counters", 0)),
		"retreat_cost": int(slot.get("retreat_cost", 0)),
		"attached_energy": _summarize_zone(slot.get("attached_energy", []), MAX_ZONE_CARD_NAMES),
		"energy_count": _zone_count(slot.get("attached_energy", [])),
		"attached_tool": _summarize_card_entry(slot.get("attached_tool", {})),
		"pokemon_stack": _summarize_zone(slot.get("pokemon_stack", []), 4),
		"status_conditions": _active_statuses(slot.get("status_conditions", {})),
	}
	return _drop_empty_values(summary)


func _zone_count(zone_variant: Variant) -> int:
	return (zone_variant as Array).size() if zone_variant is Array else 0


func _summarize_zone(cards_variant: Variant, max_items: int) -> Array[String]:
	var summaries: Array[String] = []
	if not (cards_variant is Array):
		return summaries
	for card_variant: Variant in cards_variant:
		var label := _summarize_card_entry(card_variant)
		if label != "":
			summaries.append(label)
		if summaries.size() >= max_items:
			break
	return summaries


func _summarize_card_entry(card_variant: Variant) -> String:
	if card_variant is Dictionary:
		var card: Dictionary = card_variant
		for key: String in ["card_name", "pokemon_name", "name"]:
			var value := str(card.get(key, "")).strip_edges()
			if value != "":
				return value
	elif card_variant is String:
		return str(card_variant).strip_edges()
	return ""


func _active_statuses(status_variant: Variant) -> Array[String]:
	var statuses: Array[String] = []
	if not (status_variant is Dictionary):
		return statuses
	var status_dict: Dictionary = status_variant
	for key_variant: Variant in status_dict.keys():
		if bool(status_dict.get(key_variant, false)):
			statuses.append(str(key_variant))
	return statuses


func _drop_empty_values(source: Dictionary) -> Dictionary:
	var compact := {}
	for key_variant: Variant in source.keys():
		var key := str(key_variant)
		var value: Variant = source.get(key_variant)
		if value is String and str(value) == "":
			continue
		if value is Array and (value as Array).is_empty():
			continue
		if value is Dictionary and (value as Dictionary).is_empty():
			continue
		compact[key] = value
	return compact


func _summarize_detail_event(event: Dictionary) -> Dictionary:
	var summary := {
		"event_index": int(event.get("event_index", -1)),
		"event_type": str(event.get("event_type", "")),
		"turn_number": int(event.get("turn_number", 0)),
		"phase": str(event.get("phase", "")),
		"player_index": int(event.get("player_index", -1)),
	}
	match str(event.get("event_type", "")):
		"choice_context":
			summary["prompt_type"] = str(event.get("prompt_type", ""))
			summary["title"] = _compact_text(str(event.get("title", "")), 120)
			var option_labels := _extract_option_labels(event)
			if not option_labels.is_empty():
				summary["option_labels"] = option_labels
		"action_selected":
			summary["prompt_type"] = str(event.get("prompt_type", ""))
			summary["selection_source"] = str(event.get("selection_source", ""))
			summary["title"] = _compact_text(str(event.get("title", "")), 120)
			var selected_labels := _string_array(event.get("selected_labels", []), MAX_OPTION_LABELS)
			if not selected_labels.is_empty():
				summary["selected_labels"] = selected_labels
		"action_resolved":
			summary["description"] = _compact_text(str(event.get("description", "")), 140, true)
			summary["action_type"] = int(event.get("action_type", -1))
			var resolved_data := _summarize_scalar_dict(event.get("data", {}))
			if not resolved_data.is_empty():
				summary["data"] = resolved_data
		"state_snapshot":
			summary["snapshot_reason"] = str(event.get("snapshot_reason", ""))
	return _drop_empty_values(summary)


func _extract_option_labels(event: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	var items_variant: Variant = event.get("items", [])
	if items_variant is Array:
		for item_variant: Variant in items_variant:
			var label := _summarize_card_entry(item_variant)
			if label == "" and item_variant is String:
				label = str(item_variant).strip_edges()
			if label != "":
				labels.append(label)
			if labels.size() >= MAX_OPTION_LABELS:
				break
	if labels.is_empty():
		var choice_labels := _string_array(event.get("choice_labels", []), MAX_OPTION_LABELS)
		if not choice_labels.is_empty():
			return choice_labels
	return labels


func _string_array(values_variant: Variant, max_items: int) -> Array[String]:
	var values: Array[String] = []
	if not (values_variant is Array):
		return values
	for value: Variant in values_variant:
		var text := str(value).strip_edges()
		if text != "":
			values.append(text)
		if values.size() >= max_items:
			break
	return values


func _summarize_scalar_dict(source_variant: Variant) -> Dictionary:
	if not (source_variant is Dictionary):
		return {}
	var source: Dictionary = source_variant
	var summary := {}
	for key_variant: Variant in source.keys():
		var value: Variant = source.get(key_variant)
		if value is String or value is bool or value is int or value is float:
			summary[str(key_variant)] = _compact_text(str(value), 120, true) if value is String else value
	return summary


func _compact_text(value: String, max_length: int, replace_if_long: bool = false) -> String:
	var trimmed := value.strip_edges()
	if trimmed.length() <= max_length:
		return trimmed
	if replace_if_long:
		return "[long text omitted]"
	return trimmed.substr(0, max_length - 1) + "…"
