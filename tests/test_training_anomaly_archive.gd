class_name TestTrainingAnomalyArchive
extends TestBase

const ArchiveScriptPath := "res://scripts/ai/TrainingAnomalyArchive.gd"


func _load_archive_script():
	return load(ArchiveScriptPath)


func _make_match(
	failure_reason: String,
	seed: int,
	deck_a_id: int,
	deck_b_id: int,
	generation: int = 0,
	lane_id: String = "lane_01"
) -> Dictionary:
	return {
		"winner_index": -1 if failure_reason != "" else 0,
		"turn_count": 17,
		"steps": 41,
		"seed": seed,
		"deck_a_id": deck_a_id,
		"deck_b_id": deck_b_id,
		"agent_a_player_index": 0,
		"failure_reason": failure_reason,
		"terminated_by_cap": failure_reason == "action_cap_reached",
		"stalled": failure_reason == "stalled_no_progress",
		"generation": generation,
		"lane_id": lane_id,
	}


func test_archive_summarizes_failures_by_reason_and_pairing() -> String:
	var archive_script = _load_archive_script()
	if archive_script == null:
		return "TrainingAnomalyArchive helper should exist"
	var archive = archive_script.new()
	archive.record_matches("phase1_self_play", [
		_make_match("action_cap_reached", 11, 575720, 578647, 1, "lane_01"),
		_make_match("action_cap_reached", 29, 575720, 578647, 1, "lane_01"),
		_make_match("stalled_no_progress", 47, 575720, 575716, 2, "lane_02"),
		_make_match("normal_game_end", 83, 575720, 575716, 2, "lane_02"),
	], {
		"run_id": "run_01",
	})
	var summary: Dictionary = archive.build_summary()
	var failure_counts: Dictionary = summary.get("failure_reason_counts", {})
	var phase_counts: Dictionary = summary.get("phase_counts", {})
	var pairing_counts: Dictionary = summary.get("pairing_counts", {})
	var samples: Dictionary = summary.get("samples", {})
	var cap_samples_for_pairing: Array = (samples.get("action_cap_reached", {}) as Dictionary).get("miraidon_vs_gardevoir", [])
	return run_checks([
		assert_eq(int(summary.get("total_anomalies", 0)), 3, "summary should count only anomalous matches"),
		assert_eq(int(failure_counts.get("action_cap_reached", 0)), 2, "summary should count capped matches"),
		assert_eq(int(failure_counts.get("stalled_no_progress", 0)), 1, "summary should count stalled matches"),
		assert_eq(int(phase_counts.get("phase1_self_play", 0)), 3, "summary should attribute anomalies to the correct phase"),
		assert_eq(int((pairing_counts.get("miraidon_vs_gardevoir", {}) as Dictionary).get("total", 0)), 2, "pairing totals should accumulate anomalies"),
		assert_eq(int((pairing_counts.get("miraidon_vs_charizard_ex", {}) as Dictionary).get("total", 0)), 1, "pairing totals should stay separated"),
		assert_eq(cap_samples_for_pairing.size(), 2, "summary should retain representative samples per failure reason and pairing"),
		assert_eq(str((cap_samples_for_pairing[0] as Dictionary).get("lane_id", "")), "lane_01", "samples should preserve lane context"),
	])


func test_archive_caps_samples_per_reason_and_pairing_and_merges_summaries() -> String:
	var archive_script = _load_archive_script()
	if archive_script == null:
		return "TrainingAnomalyArchive helper should exist"
	var first = archive_script.new()
	first.record_matches("phase1_self_play", [
		_make_match("action_cap_reached", 11, 575720, 578647, 1, "lane_01"),
		_make_match("action_cap_reached", 29, 575720, 578647, 1, "lane_01"),
		_make_match("action_cap_reached", 47, 575720, 578647, 2, "lane_01"),
	], {"run_id": "run_01"})
	var second = archive_script.new()
	second.record_matches("phase3_benchmark", [
		_make_match("action_cap_reached", 83, 575720, 578647, 0, "lane_09"),
		_make_match("stalled_no_progress", 101, 578647, 575716, 0, "lane_09"),
	], {"run_id": "run_01"})
	var merged: Dictionary = archive_script.merge_summaries([
		first.build_summary(),
		second.build_summary(),
	])
	var samples: Dictionary = merged.get("samples", {})
	var cap_samples_for_pairing: Array = (samples.get("action_cap_reached", {}) as Dictionary).get("miraidon_vs_gardevoir", [])
	var phase_counts: Dictionary = merged.get("phase_counts", {})
	return run_checks([
		assert_eq(int(merged.get("total_anomalies", 0)), 5, "merged summary should add anomaly totals across phases"),
		assert_eq(int((merged.get("failure_reason_counts", {}) as Dictionary).get("action_cap_reached", 0)), 4, "merged summary should add failure counts"),
		assert_eq(int((merged.get("failure_reason_counts", {}) as Dictionary).get("stalled_no_progress", 0)), 1, "merged summary should preserve distinct failure reasons"),
		assert_eq(int(phase_counts.get("phase1_self_play", 0)), 3, "merged summary should keep phase1 totals"),
		assert_eq(int(phase_counts.get("phase3_benchmark", 0)), 2, "merged summary should keep phase3 totals"),
		assert_eq(cap_samples_for_pairing.size(), 3, "merged summary should cap retained samples at three per failure reason and pairing"),
		assert_eq(str((cap_samples_for_pairing[2] as Dictionary).get("seed", "")), "47", "merged summary should keep the first three encountered samples"),
	])

