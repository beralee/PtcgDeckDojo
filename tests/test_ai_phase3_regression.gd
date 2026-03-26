## Phase 3 AI 回归门测试
## 测试 BenchmarkEvaluator.compare_summaries 的各项回归规则
class_name TestAIPhase3Regression
extends TestBase

const BenchmarkEvaluatorScript = preload("res://scripts/ai/BenchmarkEvaluator.gd")


## 构造最小化的汇总字典，用于测试回归门
## 不运行实际比赛，直接构造汇总结构
func _make_summary(
	stall_rate: float,
	cap_rate: float,
	win_rate_a: float,
	win_rate_b: float,
	identity_hit_rate: float
) -> Dictionary:
	var evaluator := BenchmarkEvaluatorScript.new()
	var summary: Dictionary = evaluator.summarize_pairing([], "miraidon_vs_gardevoir")
	summary["total_matches"] = 8
	summary["wins_a"] = int(round(win_rate_a * 8.0))
	summary["wins_b"] = int(round(win_rate_b * 8.0))
	summary["win_rate_a"] = win_rate_a
	summary["win_rate_b"] = win_rate_b
	summary["average_turn_count"] = 20.0
	summary["avg_turn_count"] = 20.0
	summary["stall_rate"] = stall_rate
	summary["cap_termination_rate"] = cap_rate
	summary["failure_breakdown"] = {}
	var identity_breakdown: Dictionary = summary.get("identity_event_breakdown", {})
	for event_key: Variant in identity_breakdown.keys():
		var event_summary: Dictionary = identity_breakdown.get(event_key, {})
		event_summary["applicable_matches"] = 8
		event_summary["hit_matches"] = int(round(identity_hit_rate * 8.0))
		event_summary["hit_rate"] = identity_hit_rate
		identity_breakdown[event_key] = event_summary
	summary["identity_event_breakdown"] = identity_breakdown
	return summary


## 当候选与基线指标相同时，回归门应通过
func test_compare_summaries_passes_when_candidate_equals_baseline() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	var reasons: Array = result.get("reasons", [])
	return run_checks([
		assert_true(bool(result.get("passed", false)), "指标完全相同时回归门应通过"),
		assert_eq(reasons.size(), 0, "无回归时原因列表应为空"),
	])


## 当候选改善了胜率时，回归门应通过
func test_compare_summaries_passes_when_candidate_improves_win_rate() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.4, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.0, 0.6, 0.5, 0.75)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	return run_checks([
		assert_true(bool(result.get("passed", false)), "候选胜率提升时回归门应通过"),
	])


## 当候选停滞率高于基线时，回归门应失败
func test_compare_summaries_fails_when_candidate_increases_stall_rate() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.125, 0.0, 0.5, 0.5, 0.75)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	var reasons: Array = result.get("reasons", [])
	return run_checks([
		assert_false(bool(result.get("passed", false)), "候选停滞率升高时回归门应失败"),
		assert_true(reasons.size() > 0, "应包含停滞率回归原因"),
	])


## 当候选上限终止率高于基线时，回归门应失败
func test_compare_summaries_fails_when_candidate_increases_cap_rate() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.25, 0.5, 0.5, 0.75)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	var reasons: Array = result.get("reasons", [])
	return run_checks([
		assert_false(bool(result.get("passed", false)), "候选上限终止率升高时回归门应失败"),
		assert_true(reasons.size() > 0, "应包含上限终止率回归原因"),
	])


## 当候选胜率全面下降时，回归门应失败
func test_compare_summaries_fails_when_candidate_win_rate_drops_across_all_sides() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.0, 0.3, 0.3, 0.75)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	var reasons: Array = result.get("reasons", [])
	return run_checks([
		assert_false(bool(result.get("passed", false)), "候选胜率全面下降时回归门应失败"),
		assert_true(reasons.size() > 0, "应包含胜率下降原因"),
	])


## 只要有一侧胜率不低于基线，胜率门就应通过
func test_compare_summaries_passes_when_one_side_win_rate_stays_equal() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.0, 0.3, 0.5, 0.75)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	return run_checks([
		assert_true(bool(result.get("passed", false)), "只要一侧胜率 >= 基线，回归门应通过"),
	])


## 当身份事件命中率崩溃时，回归门应失败
func test_compare_summaries_fails_when_identity_hit_rate_collapses() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.0, 0.5, 0.5, 0.50)
	# 默认容差为 0.10，0.75 -> 0.50 超出容差
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	var reasons: Array = result.get("reasons", [])
	return run_checks([
		assert_false(bool(result.get("passed", false)), "身份事件命中率崩溃时回归门应失败"),
		assert_true(reasons.size() > 0, "应包含身份事件崩溃原因"),
	])


## 身份事件命中率在容差范围内的轻微下降不应触发失败
func test_compare_summaries_passes_when_identity_drop_within_tolerance() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.0, 0.5, 0.5, 0.70)
	# 下降 0.05，在默认容差 0.10 内
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	return run_checks([
		assert_true(bool(result.get("passed", false)), "身份命中率在容差内轻微下降时回归门应通过"),
	])


## 空基线汇总应导致回归门失败
func test_compare_summaries_fails_on_empty_baseline() -> String:
	var candidate := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries({}, candidate)
	return run_checks([
		assert_false(bool(result.get("passed", false)), "空基线应失败"),
	])


## 空候选汇总应导致回归门失败
func test_compare_summaries_fails_on_empty_candidate() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, {})
	return run_checks([
		assert_false(bool(result.get("passed", false)), "空候选应失败"),
	])


## 多重回归应在原因列表中一并报告
func test_compare_summaries_reports_multiple_failures() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	# 候选: 停滞率升高 + 上限终止率升高 + 胜率全面下降 + 身份崩溃
	var candidate := _make_summary(0.125, 0.25, 0.3, 0.3, 0.50)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	var reasons: Array = result.get("reasons", [])
	return run_checks([
		assert_false(bool(result.get("passed", false)), "多重回归时应失败"),
		assert_true(reasons.size() >= 4, "应报告至少 4 条回归原因 (停滞、上限、胜率、身份): 实际 %d" % reasons.size()),
	])


## 返回结果的结构应包含 passed 和 reasons 两个键
func test_compare_summaries_returns_correct_structure() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	return run_checks([
		assert_true(result.has("passed"), "返回结果应包含 passed 键"),
		assert_true(result.has("reasons"), "返回结果应包含 reasons 键"),
		assert_true(result.get("reasons") is Array, "reasons 应为 Array 类型"),
	])


## 自定义容差应生效
func test_compare_summaries_respects_custom_tolerance() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.0, 0.5, 0.5, 0.50)
	# 使用宽松容差 0.30，0.75 -> 0.50 在容差内
	var result_loose: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate, 0.30)
	# 使用严格容差 0.05，0.75 -> 0.50 超出容差
	var result_strict: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate, 0.05)
	return run_checks([
		assert_true(bool(result_loose.get("passed", false)), "宽松容差下身份下降不应失败"),
		assert_false(bool(result_strict.get("passed", false)), "严格容差下身份下降应失败"),
	])


## 不适用的身份事件不应影响对比结果
func test_compare_summaries_ignores_non_applicable_identity_events() -> String:
	var baseline := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	var candidate := _make_summary(0.0, 0.0, 0.5, 0.5, 0.75)
	# 将候选的 charizard_attack_ready 设为不适用但命中率为 0
	var c_identity: Dictionary = candidate.get("identity_event_breakdown", {})
	var charizard_event: Dictionary = c_identity.get("charizard_attack_ready", {})
	charizard_event["applicable_matches"] = 0
	charizard_event["hit_matches"] = 0
	charizard_event["hit_rate"] = 0.0
	c_identity["charizard_attack_ready"] = charizard_event
	# 基线也设为不适用
	var b_identity: Dictionary = baseline.get("identity_event_breakdown", {})
	var b_charizard: Dictionary = b_identity.get("charizard_attack_ready", {})
	b_charizard["applicable_matches"] = 0
	b_charizard["hit_matches"] = 0
	b_charizard["hit_rate"] = 0.0
	b_identity["charizard_attack_ready"] = b_charizard
	var result: Dictionary = BenchmarkEvaluatorScript.compare_summaries(baseline, candidate)
	return run_checks([
		assert_true(bool(result.get("passed", false)), "不适用的身份事件不应阻止回归门通过"),
	])
