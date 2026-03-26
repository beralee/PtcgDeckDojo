class_name BenchmarkEvaluator
extends RefCounted

const EVENT_TO_DECK_KEY: Dictionary = {
	"miraidon_bench_developed": "miraidon",
	"electric_generator_resolved": "miraidon",
	"miraidon_attack_ready": "miraidon",
	"gardevoir_stage2_online": "gardevoir",
	"psychic_embrace_resolved": "gardevoir",
	"gardevoir_energy_loop_online": "gardevoir",
	"charizard_stage2_online": "charizard_ex",
	"charizard_evolution_support_used": "charizard_ex",
	"charizard_attack_ready": "charizard_ex",
}

const EVENT_ORDER: Array[String] = [
	"miraidon_bench_developed",
	"electric_generator_resolved",
	"miraidon_attack_ready",
	"gardevoir_stage2_online",
	"psychic_embrace_resolved",
	"gardevoir_energy_loop_online",
	"charizard_stage2_online",
	"charizard_evolution_support_used",
	"charizard_attack_ready",
]

const PASS_THRESHOLD := 0.30


func summarize_pairing(matches: Array[Dictionary], pairing_name: String) -> Dictionary:
	var summary := _make_empty_summary(pairing_name)
	var total_matches: int = matches.size()
	summary["total_matches"] = total_matches

	var pairing_deck_keys := _collect_pairing_deck_keys(matches)
	var deck_a_id := _get_pairing_deck_id(matches, "deck_a")
	var deck_b_id := _get_pairing_deck_id(matches, "deck_b")
	var wins_a: int = 0
	var wins_b: int = 0
	var turn_total: int = 0
	var stall_count: int = 0
	var cap_count: int = 0
	var failure_breakdown: Dictionary = {}
	var identity_breakdown: Dictionary = summary["identity_event_breakdown"]

	for event_key: String in EVENT_ORDER:
		var event_summary: Dictionary = identity_breakdown.get(event_key, {})
		var applicable_matches: int = 0
		var event_deck_key: String = str(EVENT_TO_DECK_KEY.get(event_key, ""))
		if pairing_deck_keys.has(event_deck_key):
			applicable_matches = total_matches
		event_summary["applicable_matches"] = applicable_matches
		event_summary["hit_matches"] = 0
		event_summary["hit_rate"] = 0.0
		identity_breakdown[event_key] = event_summary

	for match_variant: Variant in matches:
		if not match_variant is Dictionary:
			continue
		var match: Dictionary = match_variant
		turn_total += int(match.get("turn_count", 0))

		var failure_reason: String = str(match.get("failure_reason", ""))
		if failure_reason == "stalled_no_progress":
			stall_count += 1
		if failure_reason == "action_cap_reached":
			cap_count += 1
		if failure_reason != "" and failure_reason != "normal_game_end":
			failure_breakdown[failure_reason] = int(failure_breakdown.get(failure_reason, 0)) + 1

		var winner_index: int = int(match.get("winner_index", -1))
		var player_0_deck_id: int = int(match.get("player_0_deck_id", -1))
		var player_1_deck_id: int = int(match.get("player_1_deck_id", -1))
		if winner_index == 0:
			if player_0_deck_id == deck_a_id:
				wins_a += 1
			elif player_0_deck_id == deck_b_id:
				wins_b += 1
		elif winner_index == 1:
			if player_1_deck_id == deck_a_id:
				wins_a += 1
			elif player_1_deck_id == deck_b_id:
				wins_b += 1

		var identity_hits: Dictionary = _get_identity_hits(match)
		for event_key: String in EVENT_ORDER:
			var event_summary: Dictionary = identity_breakdown.get(event_key, {})
			if int(event_summary.get("applicable_matches", 0)) <= 0:
				continue
			if _get_identity_hit_value(identity_hits, event_key):
				event_summary["hit_matches"] = int(event_summary.get("hit_matches", 0)) + 1
			identity_breakdown[event_key] = event_summary

	for event_key: String in EVENT_ORDER:
		var event_summary: Dictionary = identity_breakdown.get(event_key, {})
		var applicable_matches: int = int(event_summary.get("applicable_matches", 0))
		var hit_matches: int = int(event_summary.get("hit_matches", 0))
		event_summary["hit_rate"] = 0.0 if applicable_matches <= 0 else float(hit_matches) / float(applicable_matches)
		identity_breakdown[event_key] = event_summary

	var applicable_event_count: int = 0
	var passed_event_count: int = 0
	for event_key: String in EVENT_ORDER:
		var event_summary: Dictionary = identity_breakdown.get(event_key, {})
		var applicable_matches: int = int(event_summary.get("applicable_matches", 0))
		if applicable_matches <= 0:
			continue
		applicable_event_count += 1
		if float(event_summary.get("hit_rate", 0.0)) >= PASS_THRESHOLD:
			passed_event_count += 1

	summary["wins_a"] = wins_a
	summary["wins_b"] = wins_b
	summary["win_rate_a"] = 0.0 if total_matches <= 0 else float(wins_a) / float(total_matches)
	summary["win_rate_b"] = 0.0 if total_matches <= 0 else float(wins_b) / float(total_matches)
	summary["average_turn_count"] = 0.0 if total_matches <= 0 else float(turn_total) / float(total_matches)
	summary["avg_turn_count"] = summary["average_turn_count"]
	summary["stall_rate"] = 0.0 if total_matches <= 0 else float(stall_count) / float(total_matches)
	summary["cap_termination_rate"] = 0.0 if total_matches <= 0 else float(cap_count) / float(total_matches)
	summary["failure_breakdown"] = failure_breakdown
	summary["identity_event_breakdown"] = identity_breakdown
	summary["identity_check_pass_rate"] = 0.0 if applicable_event_count <= 0 else float(passed_event_count) / float(applicable_event_count)

	# 版本回归模式: 按 version_a / version_b 拆分胜场
	_apply_version_regression_fields(summary, matches, total_matches)

	return summary


func build_text_summary(summary: Dictionary) -> String:
	var pairing := str(summary.get("pairing", ""))
	var total_matches: int = int(summary.get("total_matches", 0))
	var wins_a: int = int(summary.get("wins_a", 0))
	var wins_b: int = int(summary.get("wins_b", 0))
	var win_rate_a: float = float(summary.get("win_rate_a", 0.0))
	var win_rate_b: float = float(summary.get("win_rate_b", 0.0))
	var average_turn_count: float = float(summary.get("average_turn_count", summary.get("avg_turn_count", 0.0)))
	var stall_count: int = _rate_to_count(float(summary.get("stall_rate", 0.0)), total_matches)
	var cap_count: int = _rate_to_count(float(summary.get("cap_termination_rate", 0.0)), total_matches)
	var pass_rate: float = float(summary.get("identity_check_pass_rate", 0.0))
	var base_line := "%s | matches=%d | wins_a=%d (win_rate_a=%.1f%%) | wins_b=%d (win_rate_b=%.1f%%) | average_turn_count=%.2f | stalls=%d | caps=%d | identity_check_pass_rate=%.1f%%" % [
		pairing,
		total_matches,
		wins_a,
		win_rate_a * 100.0,
		wins_b,
		win_rate_b * 100.0,
		average_turn_count,
		stall_count,
		cap_count,
		pass_rate * 100.0,
	]

	# 版本回归模式追加版本对比行
	if summary.has("version_a_label"):
		var va_label := str(summary.get("version_a_label", ""))
		var vb_label := str(summary.get("version_b_label", ""))
		var va_wins: int = int(summary.get("version_a_wins", 0))
		var vb_wins: int = int(summary.get("version_b_wins", 0))
		var va_rate: float = float(summary.get("version_a_win_rate", 0.0))
		var vb_rate: float = float(summary.get("version_b_win_rate", 0.0))
		base_line += " | version_a=%s wins=%d (version_a_win_rate=%.1f%%) | version_b=%s wins=%d (version_b_win_rate=%.1f%%)" % [
			va_label, va_wins, va_rate * 100.0,
			vb_label, vb_wins, vb_rate * 100.0,
		]

	return base_line


## 检测版本回归模式并附加 version_a / version_b 胜场字段
func _apply_version_regression_fields(summary: Dictionary, matches: Array[Dictionary], total_matches: int) -> void:
	var is_version_regression := false
	for match_variant: Variant in matches:
		if not match_variant is Dictionary:
			continue
		if str((match_variant as Dictionary).get("comparison_mode", "")) == "version_regression":
			is_version_regression = true
			break

	if not is_version_regression:
		return

	var version_a_wins: int = 0
	var version_b_wins: int = 0
	var version_a_label: String = ""
	var version_b_label: String = ""

	for match_variant: Variant in matches:
		if not match_variant is Dictionary:
			continue
		var m: Dictionary = match_variant

		# 从第一条有效记录提取版本标签（不依赖胜者）
		if version_a_label == "":
			var va_config: Variant = m.get("version_a_agent_config", {})
			if va_config is Dictionary:
				version_a_label = str((va_config as Dictionary).get("version_tag", ""))
		if version_b_label == "":
			var vb_config: Variant = m.get("version_b_agent_config", {})
			if vb_config is Dictionary:
				version_b_label = str((vb_config as Dictionary).get("version_tag", ""))

		var winner_index: int = int(m.get("winner_index", -1))
		if winner_index < 0:
			continue
		var va_player_index: int = int(m.get("version_a_player_index", -1))
		var vb_player_index: int = int(m.get("version_b_player_index", -1))
		if winner_index == va_player_index:
			version_a_wins += 1
		elif winner_index == vb_player_index:
			version_b_wins += 1

	summary["version_a_wins"] = version_a_wins
	summary["version_b_wins"] = version_b_wins
	summary["version_a_win_rate"] = 0.0 if total_matches <= 0 else float(version_a_wins) / float(total_matches)
	summary["version_b_win_rate"] = 0.0 if total_matches <= 0 else float(version_b_wins) / float(total_matches)
	summary["version_a_label"] = version_a_label
	summary["version_b_label"] = version_b_label


func _make_empty_summary(pairing_name: String) -> Dictionary:
	var identity_event_breakdown := {}
	for event_key: String in EVENT_ORDER:
		identity_event_breakdown[event_key] = {
			"applicable_matches": 0,
			"hit_matches": 0,
			"hit_rate": 0.0,
		}
	return {
		"pairing": pairing_name,
		"total_matches": 0,
		"wins_a": 0,
		"wins_b": 0,
		"win_rate_a": 0.0,
		"win_rate_b": 0.0,
		"avg_turn_count": 0.0,
		"stall_rate": 0.0,
		"cap_termination_rate": 0.0,
		"failure_breakdown": {},
		"identity_check_pass_rate": 0.0,
		"identity_event_breakdown": identity_event_breakdown,
	}


func _collect_pairing_deck_keys(matches: Array[Dictionary]) -> Dictionary:
	var deck_keys: Dictionary = {}
	for match_variant: Variant in matches:
		if not match_variant is Dictionary:
			continue
		var match: Dictionary = match_variant
		var deck_a_variant: Variant = match.get("deck_a", {})
		var deck_b_variant: Variant = match.get("deck_b", {})
		var deck_a: Dictionary = deck_a_variant if deck_a_variant is Dictionary else {}
		var deck_b: Dictionary = deck_b_variant if deck_b_variant is Dictionary else {}
		var deck_a_key: String = str(deck_a.get("deck_key", ""))
		var deck_b_key: String = str(deck_b.get("deck_key", ""))
		if deck_a_key != "":
			deck_keys[deck_a_key] = true
		if deck_b_key != "":
			deck_keys[deck_b_key] = true
	return deck_keys


func _get_pairing_deck_id(matches: Array[Dictionary], deck_label: String) -> int:
	for match_variant: Variant in matches:
		if not match_variant is Dictionary:
			continue
		var match: Dictionary = match_variant
		var deck_variant: Variant = match.get(deck_label, {})
		var deck: Dictionary = deck_variant if deck_variant is Dictionary else {}
		var deck_id: int = int(deck.get("deck_id", -1))
		if deck_id > 0:
			return deck_id
	return -1


func _get_identity_hits(match: Dictionary) -> Dictionary:
	var raw_identity_hits: Variant = match.get("identity_hits", {})
	if raw_identity_hits is Dictionary:
		return raw_identity_hits
	return {}


func _get_identity_hit_value(identity_hits: Dictionary, event_key: String) -> bool:
	if identity_hits.has(event_key):
		return bool(identity_hits.get(event_key, false))
	for key: Variant in identity_hits.keys():
		var nested: Variant = identity_hits.get(key)
		if nested is Dictionary and (nested as Dictionary).has(event_key):
			return bool((nested as Dictionary).get(event_key, false))
	return false


func _rate_to_count(rate: float, total_matches: int) -> int:
	if total_matches <= 0:
		return 0
	return int(round(rate * float(total_matches)))


## Phase 3 回归门: 对比基线汇总与候选汇总，返回 { "passed": bool, "reasons": Array[String] }
## 规则:
##   - 候选停滞率不得高于基线
##   - 候选上限终止率不得高于基线
##   - 至少有一个配对的胜率不低于基线
##   - 身份事件命中率不得崩溃（可适用事件的命中率不得低于基线超过容差）
static func compare_summaries(baseline: Dictionary, candidate: Dictionary, identity_collapse_tolerance: float = 0.10) -> Dictionary:
	var reasons: Array[String] = []

	# 空汇总检查
	if baseline.is_empty():
		reasons.append("基线汇总为空")
	if candidate.is_empty():
		reasons.append("候选汇总为空")
	if not reasons.is_empty():
		return {"passed": false, "reasons": reasons}

	# 停滞率对比
	var baseline_stall_rate: float = float(baseline.get("stall_rate", 0.0))
	var candidate_stall_rate: float = float(candidate.get("stall_rate", 0.0))
	if candidate_stall_rate > baseline_stall_rate:
		reasons.append("候选停滞率 (%.2f) 高于基线 (%.2f)" % [candidate_stall_rate, baseline_stall_rate])

	# 上限终止率对比
	var baseline_cap_rate: float = float(baseline.get("cap_termination_rate", 0.0))
	var candidate_cap_rate: float = float(candidate.get("cap_termination_rate", 0.0))
	if candidate_cap_rate > baseline_cap_rate:
		reasons.append("候选上限终止率 (%.2f) 高于基线 (%.2f)" % [candidate_cap_rate, baseline_cap_rate])

	# 胜率对比: 候选至少有一个配对胜率 >= 基线
	var baseline_win_rate_a: float = float(baseline.get("win_rate_a", 0.0))
	var candidate_win_rate_a: float = float(candidate.get("win_rate_a", 0.0))
	var baseline_win_rate_b: float = float(baseline.get("win_rate_b", 0.0))
	var candidate_win_rate_b: float = float(candidate.get("win_rate_b", 0.0))
	var any_improved_or_equal := false
	if candidate_win_rate_a >= baseline_win_rate_a:
		any_improved_or_equal = true
	if candidate_win_rate_b >= baseline_win_rate_b:
		any_improved_or_equal = true
	if not any_improved_or_equal:
		reasons.append("候选胜率全面下降: win_rate_a %.2f->%.2f, win_rate_b %.2f->%.2f" % [
			baseline_win_rate_a, candidate_win_rate_a,
			baseline_win_rate_b, candidate_win_rate_b,
		])

	# 身份事件命中率崩溃检查
	var baseline_identity: Dictionary = baseline.get("identity_event_breakdown", {}) if baseline.get("identity_event_breakdown", {}) is Dictionary else {}
	var candidate_identity: Dictionary = candidate.get("identity_event_breakdown", {}) if candidate.get("identity_event_breakdown", {}) is Dictionary else {}
	for event_key: String in EVENT_ORDER:
		var b_event: Variant = baseline_identity.get(event_key, {})
		var c_event: Variant = candidate_identity.get(event_key, {})
		if not b_event is Dictionary or not c_event is Dictionary:
			continue
		var b_applicable: int = int((b_event as Dictionary).get("applicable_matches", 0))
		var c_applicable: int = int((c_event as Dictionary).get("applicable_matches", 0))
		if b_applicable <= 0 or c_applicable <= 0:
			continue
		var b_hit_rate: float = float((b_event as Dictionary).get("hit_rate", 0.0))
		var c_hit_rate: float = float((c_event as Dictionary).get("hit_rate", 0.0))
		if c_hit_rate < b_hit_rate - identity_collapse_tolerance:
			reasons.append("身份事件 %s 命中率崩溃: %.2f -> %.2f (容差 %.2f)" % [
				event_key, b_hit_rate, c_hit_rate, identity_collapse_tolerance,
			])

	return {"passed": reasons.is_empty(), "reasons": reasons}
