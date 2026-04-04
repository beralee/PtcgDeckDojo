class_name TestBattleReviewFormatter
extends TestBase

const BattleReviewFormatterScript = preload("res://scripts/engine/BattleReviewFormatter.gd")


func _new_formatter() -> RefCounted:
	return BattleReviewFormatterScript.new()


func test_formatter_includes_compact_v3_fields_in_chinese() -> String:
	var formatter := _new_formatter()
	var review_text: String = formatter.call("format_review", {
		"status": "completed",
		"selected_turns": [
			{"turn_number": 5, "reason": "winner swing", "side": "winner"},
		],
		"turn_reviews": [
			{
				"turn_number": 5,
				"player_index": 0,
				"judgment": "suboptimal",
				"turn_goal": "Take a clean two-prize lead without exposing Pidgeot",
				"why_current_line_falls_short": ["winner issue"],
				"timing_window": {"earliest_opponent_pressure_turn": 7, "assessment": "Opponent cannot punish the slower line before turn 7."},
				"best_line": {"summary": "Search Charizard first", "steps": ["Search Charizard ex", "Then bench support attacker"]},
				"coach_takeaway": "Search the irreplaceable evolution piece before optional value cards.",
			},
		],
	})

	return run_checks([
		assert_true(review_text.contains("状态"), "Formatter should include the Chinese status label"),
		assert_true(review_text.contains("已完成"), "Formatter should translate completed status"),
		assert_true(review_text.contains("获胜方关键回合"), "Formatter should include the Chinese winner heading"),
		assert_true(review_text.contains("Take a clean two-prize lead without exposing Pidgeot"), "Formatter should keep model-authored body text intact"),
		assert_true(review_text.contains("Opponent cannot punish the slower line before turn 7."), "Formatter should keep model-authored timing analysis intact"),
		assert_true(review_text.contains("Search Charizard first"), "Formatter should keep the compact best-line summary"),
		assert_true(review_text.contains("Search the irreplaceable evolution piece before optional value cards."), "Formatter should keep the coach takeaway"),
		assert_false(review_text.contains("Status"), "Formatter should no longer expose English status labels"),
		assert_false(review_text.contains("Winner Key Turn"), "Formatter should no longer expose English winner headings"),
	])


func test_formatter_drops_legacy_better_line_fields() -> String:
	var formatter := _new_formatter()
	var review_text: String = formatter.call("format_review", {
		"status": "completed",
		"selected_turns": [
			{"turn_number": 5, "reason": "winner swing", "side": "winner"},
		],
		"turn_reviews": [
			{
				"turn_number": 5,
				"player_index": 0,
				"judgment": "suboptimal",
				"why_current_line_falls_short": ["winner issue"],
				"better_line": {"goal": "win cleaner", "steps": ["take prize", "hold gust"]},
				"why_better": ["safer map"],
			},
		],
	})

	return run_checks([
		assert_true(review_text.contains("winner issue"), "Formatter should keep why_current_line_falls_short visible"),
		assert_false(review_text.contains("take prize"), "Formatter should stop rendering removed legacy better_line steps"),
		assert_false(review_text.contains("safer map"), "Formatter should stop rendering removed legacy why_better copy"),
	])


func test_formatter_uses_chinese_labels_without_english_shell_text() -> String:
	var formatter := _new_formatter()
	var review_text: String = formatter.call("format_review", {
		"status": "partial_success",
		"selected_turns": [
			{"turn_number": 2, "reason": "winner swing", "side": "winner"},
		],
		"turn_reviews": [{
			"turn_number": 2,
			"player_index": 1,
			"judgment": "close_to_optimal",
			"turn_goal": "Take the first prize without over-investing",
			"timing_window": {"earliest_opponent_pressure_turn": 5, "assessment": "Opponent cannot threaten a clean return KO until turn 5."},
			"why_current_line_falls_short": ["You spent too many resources for the same prize outcome."],
			"best_line": {"summary": "Keep the pressure simple", "steps": ["Take the KO", "Preserve the gust card"]},
			"coach_takeaway": "Value timing over cosmetic efficiency.",
		}],
	})

	return run_checks([
		assert_true(review_text.contains("状态"), "Formatter should use a Chinese status label"),
		assert_true(review_text.contains("部分成功"), "Formatter should translate partial_success"),
		assert_true(review_text.contains("获胜方关键回合"), "Formatter should use a Chinese winner heading"),
		assert_true(review_text.contains("第 2 回合"), "Formatter should use a Chinese turn heading"),
		assert_true(review_text.contains("本回合目标"), "Formatter should use a Chinese goal label"),
		assert_true(review_text.contains("轮次判断"), "Formatter should use a Chinese timing label"),
		assert_true(review_text.contains("当前线路问题"), "Formatter should use a Chinese issue label"),
		assert_true(review_text.contains("更优路线"), "Formatter should use a Chinese best-line label"),
		assert_true(review_text.contains("教练总结"), "Formatter should use a Chinese takeaway label"),
		assert_false(review_text.contains("Status"), "Formatter should not render English status labels"),
		assert_false(review_text.contains("Turn 2"), "Formatter should not render English turn headings"),
		assert_false(review_text.contains("Goal:"), "Formatter should not render English goal labels"),
		assert_false(review_text.contains("Timing:"), "Formatter should not render English timing labels"),
		assert_false(review_text.contains("Current line issues"), "Formatter should not render English issue labels"),
		assert_false(review_text.contains("Best line:"), "Formatter should not render English best-line labels"),
		assert_false(review_text.contains("Takeaway:"), "Formatter should not render English takeaway labels"),
		assert_false(review_text.contains("閻樿埖"), "Formatter should not render garbled legacy labels"),
		assert_false(review_text.contains("鑾疯儨"), "Formatter should not render garbled legacy labels"),
	])
