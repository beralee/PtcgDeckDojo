class_name BattleReviewHeuristics
extends RefCounted


func build_turn_tags(turn_slice: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	var events: Array = turn_slice.get("events", [])
	if _has_choice_density(events):
		tags.append("choice_heavy")
	if _has_prize_swing(events):
		tags.append("prize_swing")
	if _has_gust_like_action(events):
		tags.append("gust_pressure")
	return tags


func _has_choice_density(events: Array) -> bool:
	var count := 0
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		if str((event_variant as Dictionary).get("event_type", "")) == "action_selected":
			count += 1
	return count >= 2


func _has_prize_swing(events: Array) -> bool:
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		var data_variant: Variant = event.get("data", {})
		var data: Dictionary = data_variant if data_variant is Dictionary else {}
		if int(data.get("prize_count", 0)) > 0:
			return true
	return false


func _has_gust_like_action(events: Array) -> bool:
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		var description := str((event_variant as Dictionary).get("description", "")).to_lower()
		if description.contains("gust") or description.contains("switch"):
			return true
	return false
