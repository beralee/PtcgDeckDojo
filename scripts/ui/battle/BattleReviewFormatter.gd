extends RefCounted

const BattleI18nScript := preload("res://scripts/ui/battle/BattleI18n.gd")


func format_review(review: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b] %s" % [
		BattleI18nScript.t("battle.review.status_label"),
		_status_text(str(review.get("status", ""))),
	])

	var selected_turns: Array = review.get("selected_turns", [])
	var turn_reviews_by_number := _index_turn_reviews(review.get("turn_reviews", []))

	lines.append("")
	lines.append("[b]%s[/b]" % BattleI18nScript.t("battle.review.winner_heading"))
	_append_review_side(lines, selected_turns, "winner", turn_reviews_by_number)
	lines.append("")
	lines.append("[b]%s[/b]" % BattleI18nScript.t("battle.review.loser_heading"))
	_append_review_side(lines, selected_turns, "loser", turn_reviews_by_number)

	var errors: Array = review.get("errors", [])
	if not errors.is_empty():
		lines.append("")
		lines.append("[b]%s[/b]" % BattleI18nScript.t("battle.review.errors_label"))
		for error_variant: Variant in errors:
			if not (error_variant is Dictionary):
				continue
			lines.append("- %s" % _error_message_text(error_variant as Dictionary))

	return "\n".join(lines)


func _index_turn_reviews(turn_reviews_variant: Variant) -> Dictionary:
	var turn_reviews_by_number: Dictionary = {}
	if not (turn_reviews_variant is Array):
		return turn_reviews_by_number
	for turn_review_variant: Variant in turn_reviews_variant:
		if not (turn_review_variant is Dictionary):
			continue
		var turn_review: Dictionary = turn_review_variant
		turn_reviews_by_number[int(turn_review.get("turn_number", 0))] = turn_review
	return turn_reviews_by_number


func _append_review_side(lines: Array[String], selected_turns: Array, side: String, turn_reviews_by_number: Dictionary) -> void:
	var wrote_any := false
	for turn_variant: Variant in selected_turns:
		if not (turn_variant is Dictionary):
			continue
		var turn: Dictionary = turn_variant
		if str(turn.get("side", "")) != side:
			continue

		wrote_any = true
		var turn_number := int(turn.get("turn_number", 0))
		lines.append(BattleI18nScript.t("battle.review.turn_label", {
			"turn_number": turn_number,
			"reason": str(turn.get("reason", "")),
		}))

		var review_variant: Variant = turn_reviews_by_number.get(turn_number, {})
		var turn_review: Dictionary = review_variant if review_variant is Dictionary else {}
		var turn_goal := str(turn_review.get("turn_goal", ""))
		if turn_goal != "":
			lines.append("%s: %s" % [BattleI18nScript.t("battle.review.turn_goal_label"), turn_goal])

		var timing_window_variant: Variant = turn_review.get("timing_window", {})
		var timing_window: Dictionary = timing_window_variant if timing_window_variant is Dictionary else {}
		var timing_assessment := str(timing_window.get("assessment", ""))
		if timing_assessment != "":
			lines.append("%s: %s" % [BattleI18nScript.t("battle.review.timing_label"), timing_assessment])

		_append_string_list(lines, BattleI18nScript.t("battle.review.current_line_issues_label"), turn_review.get("why_current_line_falls_short", []))
		_append_best_line(lines, turn_review.get("best_line", {}))

		var coach_takeaway := str(turn_review.get("coach_takeaway", ""))
		if coach_takeaway != "":
			lines.append("%s: %s" % [BattleI18nScript.t("battle.review.takeaway_label"), coach_takeaway])
		lines.append("")

	if not wrote_any:
		lines.append(BattleI18nScript.t("battle.review.empty"))


func _append_string_list(lines: Array[String], title: String, values_variant: Variant) -> void:
	if not (values_variant is Array):
		return
	var values: Array = values_variant
	if values.is_empty():
		return
	lines.append("%s:" % title)
	for item_variant: Variant in values:
		lines.append("- %s" % str(item_variant))


func _append_best_line(lines: Array[String], block_variant: Variant) -> void:
	if not (block_variant is Dictionary):
		return
	var block: Dictionary = block_variant
	var summary := str(block.get("summary", ""))
	if summary != "":
		lines.append("%s: %s" % [BattleI18nScript.t("battle.review.best_line_label"), summary])
	var steps: Array = block.get("steps", [])
	for step_index: int in steps.size():
		lines.append("%d. %s" % [step_index + 1, str(steps[step_index])])


func _status_text(status: String) -> String:
	match status:
		"completed":
			return BattleI18nScript.t("battle.status.completed")
		"partial_success":
			return BattleI18nScript.t("battle.status.partial_success")
		"failed":
			return BattleI18nScript.t("battle.status.failed")
		"running":
			return BattleI18nScript.t("battle.status.running")
		_:
			return status


func _error_message_text(error: Dictionary) -> String:
	var message := str(error.get("message", "")).strip_edges()
	match message:
		"Stage 1 did not return any key turns":
			return BattleI18nScript.t("battle.review.error.stage1_no_turns")
		"Stage 1 selected an unknown turn":
			return BattleI18nScript.t("battle.review.error.unknown_turn")
		"ZenMux request could not be started":
			return BattleI18nScript.t("battle.review.error.request_start_failed")
		"ZenMux turn analysis request could not be started":
			return BattleI18nScript.t("battle.review.error.turn_request_start_failed")
		"Selected turn entry was not a dictionary":
			return BattleI18nScript.t("battle.review.error.invalid_selected_turn")
		_:
			return message
