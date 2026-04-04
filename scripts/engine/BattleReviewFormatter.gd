class_name BattleReviewFormatter
extends RefCounted


func format_review(review: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]状态[/b] %s" % _status_text(str(review.get("status", ""))))
	var selected_turns: Array = review.get("selected_turns", [])
	var turn_reviews_by_number: Dictionary = {}
	for turn_review_variant: Variant in review.get("turn_reviews", []):
		if not (turn_review_variant is Dictionary):
			continue
		var turn_review: Dictionary = turn_review_variant
		turn_reviews_by_number[int(turn_review.get("turn_number", 0))] = turn_review
	lines.append("")
	lines.append("[b]获胜方关键回合[/b]")
	_append_review_side(lines, selected_turns, "winner", turn_reviews_by_number)
	lines.append("")
	lines.append("[b]失败方关键回合[/b]")
	_append_review_side(lines, selected_turns, "loser", turn_reviews_by_number)
	var errors: Array = review.get("errors", [])
	if not errors.is_empty():
		lines.append("")
		lines.append("[b]错误[/b]")
		for error_variant: Variant in errors:
			if not (error_variant is Dictionary):
				continue
			lines.append("- %s" % _error_message_text(error_variant as Dictionary))
	return "\n".join(lines)


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
		lines.append("第 %d 回合: %s" % [turn_number, str(turn.get("reason", ""))])
		var review_variant: Variant = turn_reviews_by_number.get(turn_number, {})
		var turn_review: Dictionary = review_variant if review_variant is Dictionary else {}
		var turn_goal := str(turn_review.get("turn_goal", ""))
		if turn_goal != "":
			lines.append("本回合目标: %s" % turn_goal)
		var timing_window_variant: Variant = turn_review.get("timing_window", {})
		var timing_window: Dictionary = timing_window_variant if timing_window_variant is Dictionary else {}
		var timing_assessment := str(timing_window.get("assessment", ""))
		if timing_assessment != "":
			lines.append("轮次判断: %s" % timing_assessment)
		_append_review_short_list(lines, "当前线路问题", turn_review.get("why_current_line_falls_short", []))
		_append_review_best_line(lines, turn_review.get("best_line", {}))
		var coach_takeaway := str(turn_review.get("coach_takeaway", ""))
		if coach_takeaway != "":
			lines.append("教练总结: %s" % coach_takeaway)
		lines.append("")
	if not wrote_any:
		lines.append("暂无")


func _append_review_short_list(lines: Array[String], title: String, values_variant: Variant) -> void:
	if not (values_variant is Array):
		return
	var values: Array = values_variant
	if values.is_empty():
		return
	lines.append("%s:" % title)
	for item_variant: Variant in values:
		lines.append("- %s" % str(item_variant))


func _append_review_best_line(lines: Array[String], block_variant: Variant) -> void:
	if not (block_variant is Dictionary):
		return
	var block: Dictionary = block_variant
	var summary := str(block.get("summary", ""))
	if summary != "":
		lines.append("更优路线: %s" % summary)
	var steps: Array = block.get("steps", [])
	for step_index: int in steps.size():
		lines.append("%d. %s" % [step_index + 1, str(steps[step_index])])


func _status_text(status: String) -> String:
	match status:
		"completed":
			return "已完成"
		"partial_success":
			return "部分成功"
		"failed":
			return "失败"
		"running":
			return "生成中"
		_:
			return status


func _error_message_text(error: Dictionary) -> String:
	var message := str(error.get("message", "")).strip_edges()
	match message:
		"Stage 1 did not return any key turns":
			return "第一阶段没有返回任何关键回合"
		"Stage 1 selected an unknown turn":
			return "第一阶段选择了不存在的回合"
		"ZenMux request could not be started":
			return "ZenMux 请求启动失败"
		"ZenMux turn analysis request could not be started":
			return "ZenMux 回合分析请求启动失败"
		"Selected turn entry was not a dictionary":
			return "关键回合数据格式无效"
		_:
			return message
