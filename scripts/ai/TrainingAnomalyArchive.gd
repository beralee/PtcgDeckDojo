class_name TrainingAnomalyArchive
extends RefCounted

const DEFAULT_SAMPLE_LIMIT := 3
const SCHEMA_VERSION := 3
const NORMAL_TERMINAL_REASONS := {
	"normal_game_end": true,
	"deck_out": true,
}
const DECK_ID_TO_KEY := {
	575720: "miraidon",
	578647: "gardevoir",
	575716: "charizard_ex",
}

var sample_limit_per_group: int = DEFAULT_SAMPLE_LIMIT
var _summary: Dictionary = _make_empty_summary()


func record_matches(phase: String, matches: Array, metadata: Dictionary = {}) -> void:
	for match_variant: Variant in matches:
		if not match_variant is Dictionary:
			continue
		var match: Dictionary = match_variant
		var pairing_name := _resolve_pairing_name(match, metadata)
		_record_mcts_failure_details(match, pairing_name)
		var failure_reason: String = str(match.get("failure_reason", ""))
		if failure_reason == "" or NORMAL_TERMINAL_REASONS.has(failure_reason):
			continue
		var lane_id := str(metadata.get("lane_id", match.get("lane_id", "")))
		var generation_raw: Variant = metadata.get("generation", match.get("generation", -1))
		var generation_value: int = int(generation_raw)
		var run_id := str(metadata.get("run_id", match.get("run_id", "")))

		_increment_counter(_summary["phase_counts"], phase)
		_increment_counter(_summary["failure_reason_counts"], failure_reason)
		if lane_id != "":
			_increment_counter(_summary["lane_counts"], lane_id)
		if generation_value >= 0:
			_increment_counter(_summary["generation_counts"], str(generation_value))

		var pairing_counts: Dictionary = _summary.get("pairing_counts", {})
		var pairing_summary: Dictionary = pairing_counts.get(pairing_name, {
			"total": 0,
			"failure_reason_counts": {},
		})
		pairing_summary["total"] = int(pairing_summary.get("total", 0)) + 1
		_increment_counter(pairing_summary["failure_reason_counts"], failure_reason)
		pairing_counts[pairing_name] = pairing_summary
		_summary["pairing_counts"] = pairing_counts

		_append_sample(failure_reason, pairing_name, {
			"phase": phase,
			"run_id": run_id,
			"lane_id": lane_id,
			"generation": generation_value,
			"pairing": pairing_name,
			"deck_a_id": int(match.get("deck_a_id", _deck_id_from_side(match, "deck_a"))),
			"deck_b_id": int(match.get("deck_b_id", _deck_id_from_side(match, "deck_b"))),
			"seed": int(match.get("seed", -1)),
			"winner_index": int(match.get("winner_index", -1)),
			"failure_reason": failure_reason,
			"terminated_by_cap": bool(match.get("terminated_by_cap", false)),
			"stalled": bool(match.get("stalled", false)),
			"baseline_source": str(metadata.get("baseline_source", "")),
			"candidate_agent_config_path": str(metadata.get("candidate_agent_config_path", "")),
			"candidate_value_net_path": str(metadata.get("candidate_value_net_path", "")),
			"baseline_agent_config_path": str(metadata.get("baseline_agent_config_path", "")),
			"baseline_value_net_path": str(metadata.get("baseline_value_net_path", "")),
		})
		_summary["total_anomalies"] = int(_summary.get("total_anomalies", 0)) + 1


func build_summary() -> Dictionary:
	var summary := _summary.duplicate(true)
	summary["schema_version"] = SCHEMA_VERSION
	summary["sample_limit_per_group"] = sample_limit_per_group
	summary["updated_at"] = Time.get_datetime_string_from_system(false, true)
	return summary


func write_summary(path: String) -> bool:
	if path == "":
		return false
	return write_summary_to_path(path, build_summary())


static func merge_summaries(summaries: Array, sample_limit: int = DEFAULT_SAMPLE_LIMIT) -> Dictionary:
	var archive_script = load("res://scripts/ai/TrainingAnomalyArchive.gd")
	var archive = archive_script.new()
	archive.sample_limit_per_group = sample_limit
	for summary_variant: Variant in summaries:
		if not summary_variant is Dictionary:
			continue
		archive._merge_summary(summary_variant)
	return archive.build_summary()


static func read_summary(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


static func write_summary_to_path(path: String, summary: Dictionary) -> bool:
	if path == "":
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir_path := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(dir_path)
		if mkdir_error != OK:
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	return true


func _merge_summary(summary: Dictionary) -> void:
	_merge_simple_counts(_summary["phase_counts"], summary.get("phase_counts", {}))
	_merge_simple_counts(_summary["failure_reason_counts"], summary.get("failure_reason_counts", {}))
	_merge_simple_counts(_summary["lane_counts"], summary.get("lane_counts", {}))
	_merge_simple_counts(_summary["generation_counts"], summary.get("generation_counts", {}))
	_merge_simple_counts(_summary["mcts_failure_category_counts"], summary.get("mcts_failure_category_counts", {}))
	_merge_simple_counts(_summary["mcts_failure_kind_counts"], summary.get("mcts_failure_kind_counts", {}))
	_summary["total_anomalies"] = int(_summary.get("total_anomalies", 0)) + int(summary.get("total_anomalies", 0))

	var source_pairing_counts: Dictionary = summary.get("pairing_counts", {})
	for pairing_name_variant: Variant in source_pairing_counts.keys():
		var pairing_name: String = str(pairing_name_variant)
		var source_pairing: Dictionary = source_pairing_counts.get(pairing_name, {})
		var target_pairing: Dictionary = (_summary["pairing_counts"] as Dictionary).get(pairing_name, {
			"total": 0,
			"failure_reason_counts": {},
		})
		target_pairing["total"] = int(target_pairing.get("total", 0)) + int(source_pairing.get("total", 0))
		_merge_simple_counts(target_pairing["failure_reason_counts"], source_pairing.get("failure_reason_counts", {}))
		(_summary["pairing_counts"] as Dictionary)[pairing_name] = target_pairing

	var source_samples: Dictionary = summary.get("samples", {})
	for failure_reason_variant: Variant in source_samples.keys():
		var failure_reason: String = str(failure_reason_variant)
		var pairing_map_variant: Variant = source_samples.get(failure_reason, {})
		if not pairing_map_variant is Dictionary:
			continue
		for pairing_name_variant: Variant in (pairing_map_variant as Dictionary).keys():
			var pairing_name: String = str(pairing_name_variant)
			var sample_list_variant: Variant = (pairing_map_variant as Dictionary).get(pairing_name, [])
			if not sample_list_variant is Array:
				continue
			for sample_variant: Variant in sample_list_variant:
				if sample_variant is Dictionary:
					_append_sample(failure_reason, pairing_name, sample_variant)

	var source_mcts_samples: Dictionary = summary.get("mcts_failure_samples", {})
	for category_variant: Variant in source_mcts_samples.keys():
		var category: String = str(category_variant)
		var pairing_map_variant: Variant = source_mcts_samples.get(category, {})
		if not pairing_map_variant is Dictionary:
			continue
		for pairing_name_variant: Variant in (pairing_map_variant as Dictionary).keys():
			var pairing_name: String = str(pairing_name_variant)
			var sample_list_variant: Variant = (pairing_map_variant as Dictionary).get(pairing_name, [])
			if not sample_list_variant is Array:
				continue
			for sample_variant: Variant in sample_list_variant:
				if sample_variant is Dictionary:
					_append_mcts_failure_sample(category, pairing_name, sample_variant)


func _append_sample(failure_reason: String, pairing_name: String, sample: Dictionary) -> void:
	var samples: Dictionary = _summary.get("samples", {})
	var reason_bucket: Dictionary = samples.get(failure_reason, {})
	var pairing_samples_variant: Variant = reason_bucket.get(pairing_name, [])
	var pairing_samples: Array = pairing_samples_variant if pairing_samples_variant is Array else []
	if pairing_samples.size() >= sample_limit_per_group:
		reason_bucket[pairing_name] = pairing_samples
		samples[failure_reason] = reason_bucket
		_summary["samples"] = samples
		return
	pairing_samples.append(sample.duplicate(true))
	reason_bucket[pairing_name] = pairing_samples
	samples[failure_reason] = reason_bucket
	_summary["samples"] = samples


func _record_mcts_failure_details(match: Dictionary, pairing_name: String) -> void:
	var event_counters_variant: Variant = match.get("event_counters", {})
	if not event_counters_variant is Dictionary:
		return
	var event_counters: Dictionary = event_counters_variant
	_merge_simple_counts(_summary["mcts_failure_category_counts"], event_counters.get("mcts_failure_category_counts", {}))
	_merge_simple_counts(_summary["mcts_failure_kind_counts"], event_counters.get("mcts_failure_kind_counts", {}))
	var samples_variant: Variant = event_counters.get("mcts_failure_samples", [])
	if not samples_variant is Array:
		return
	for sample_variant: Variant in samples_variant:
		if not sample_variant is Dictionary:
			continue
		var sample: Dictionary = sample_variant
		var category: String = str(sample.get("category", "system_execution_error"))
		_append_mcts_failure_sample(category, pairing_name, sample)


func _append_mcts_failure_sample(category: String, pairing_name: String, sample: Dictionary) -> void:
	var samples: Dictionary = _summary.get("mcts_failure_samples", {})
	var category_bucket: Dictionary = samples.get(category, {})
	var pairing_samples_variant: Variant = category_bucket.get(pairing_name, [])
	var pairing_samples: Array = pairing_samples_variant if pairing_samples_variant is Array else []
	if pairing_samples.size() >= sample_limit_per_group:
		category_bucket[pairing_name] = pairing_samples
		samples[category] = category_bucket
		_summary["mcts_failure_samples"] = samples
		return
	pairing_samples.append(sample.duplicate(true))
	category_bucket[pairing_name] = pairing_samples
	samples[category] = category_bucket
	_summary["mcts_failure_samples"] = samples


func _resolve_pairing_name(match: Dictionary, metadata: Dictionary) -> String:
	var explicit_pairing: String = str(metadata.get("pairing", match.get("pairing_name", "")))
	if explicit_pairing != "":
		return explicit_pairing
	var deck_a_id: int = int(match.get("deck_a_id", _deck_id_from_side(match, "deck_a")))
	var deck_b_id: int = int(match.get("deck_b_id", _deck_id_from_side(match, "deck_b")))
	var deck_a_key: String = str(DECK_ID_TO_KEY.get(deck_a_id, str(deck_a_id)))
	var deck_b_key: String = str(DECK_ID_TO_KEY.get(deck_b_id, str(deck_b_id)))
	return "%s_vs_%s" % [deck_a_key, deck_b_key]


func _deck_id_from_side(match: Dictionary, side: String) -> int:
	var side_variant: Variant = match.get(side, {})
	if side_variant is Dictionary:
		return int((side_variant as Dictionary).get("deck_id", -1))
	return -1


func _increment_counter(target: Variant, key: String) -> void:
	if not target is Dictionary:
		return
	var dictionary := target as Dictionary
	dictionary[key] = int(dictionary.get(key, 0)) + 1


func _merge_simple_counts(target: Variant, source: Variant) -> void:
	if not target is Dictionary or not source is Dictionary:
		return
	var target_dict := target as Dictionary
	var source_dict := source as Dictionary
	for key_variant: Variant in source_dict.keys():
		var key: String = str(key_variant)
		target_dict[key] = int(target_dict.get(key, 0)) + int(source_dict.get(key, 0))


func _make_empty_summary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"total_anomalies": 0,
		"phase_counts": {},
		"failure_reason_counts": {},
		"mcts_failure_category_counts": {},
		"mcts_failure_kind_counts": {},
		"pairing_counts": {},
		"lane_counts": {},
		"generation_counts": {},
		"samples": {},
		"mcts_failure_samples": {},
	}
