extends SceneTree


const ScenarioCatalogScript = preload("res://tests/scenarios/ScenarioCatalog.gd")
const ScenarioRunnerScript = preload("res://tests/scenarios/ScenarioRunner.gd")
const ScenarioStateRestorerScript = preload("res://scripts/engine/scenario/ScenarioStateRestorer.gd")
const ScenarioEquivalenceRegistryScript = preload("res://scripts/ai/scenario_comparator/ScenarioEquivalenceRegistry.gd")


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var scenarios_dir: String = str(args.get("scenarios-dir", ""))
	if scenarios_dir == "":
		print("Missing --scenarios-dir")
		quit(2)
		return
	var overwrite: bool = bool(args.get("overwrite", false))
	var report: Dictionary = _populate_expected_states(scenarios_dir, overwrite)
	print(JSON.stringify(report, "\t"))
	quit(0 if int(report.get("error_count", 0)) == 0 else 1)


func _populate_expected_states(scenarios_dir: String, overwrite: bool) -> Dictionary:
	var updated: Array[Dictionary] = []
	var skipped: Array[Dictionary] = []
	var errors: Array[Dictionary] = []

	for scenario_path: String in ScenarioCatalogScript.list_scenario_files(scenarios_dir):
		var scenario: Dictionary = ScenarioCatalogScript.load_scenario(scenario_path)
		var expected: Dictionary = scenario.get("expected_end_state", {})
		if not overwrite and _expected_end_state_present(expected):
			skipped.append({
				"scenario_path": scenario_path,
				"reason": "expected_end_state_already_present",
			})
			continue

		var built: Dictionary = _build_expected_end_state(scenario)
		if built.is_empty():
			errors.append({
				"scenario_path": scenario_path,
				"reason": "unable_to_build_expected_end_state",
			})
			continue

		scenario["expected_end_state"] = built
		var file := FileAccess.open(scenario_path, FileAccess.WRITE)
		if file == null:
			errors.append({
				"scenario_path": scenario_path,
				"reason": "unable_to_open_for_write",
			})
			continue
		file.store_string(JSON.stringify(scenario, "\t") + "\n")
		updated.append({
			"scenario_path": scenario_path,
			"scenario_id": str(scenario.get("scenario_id", "")),
		})

	return {
		"scenarios_dir": scenarios_dir,
		"updated": updated,
		"skipped": skipped,
		"errors": errors,
		"updated_count": updated.size(),
		"skipped_count": skipped.size(),
		"error_count": errors.size(),
	}


func _build_expected_end_state(scenario: Dictionary) -> Dictionary:
	var source: Dictionary = scenario.get("expected_end_state_source", {})
	var source_state: Variant = source.get("state", {})
	if not (source_state is Dictionary):
		return {}

	var runner = ScenarioRunnerScript.new()
	var normalized_snapshot: Dictionary = runner.normalize_snapshot_for_restore(source_state)
	var restore_result: Dictionary = ScenarioStateRestorerScript.restore(normalized_snapshot)
	var errors: Array = restore_result.get("errors", [])
	if not errors.is_empty():
		return {}
	var gsm: GameStateMachine = restore_result.get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return {}
	var tracked_player_index: int = int(scenario.get("tracked_player_index", -1))
	return {
		"scenario_id": str(scenario.get("scenario_id", "")),
		"primary": ScenarioEquivalenceRegistryScript.extract_primary(gsm.game_state, tracked_player_index),
		"secondary": ScenarioEquivalenceRegistryScript.extract_secondary(gsm.game_state, tracked_player_index),
	}


func _expected_end_state_present(expected_end_state: Dictionary) -> bool:
	if expected_end_state.is_empty():
		return false
	var primary: Dictionary = expected_end_state.get("primary", {})
	var secondary: Dictionary = expected_end_state.get("secondary", {})
	return not primary.is_empty() or not secondary.is_empty()


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for raw_arg: String in raw_args:
		if raw_arg == "--overwrite":
			parsed["overwrite"] = true
			continue
		if not raw_arg.begins_with("--"):
			continue
		var eq_index: int = raw_arg.find("=")
		if eq_index <= 2:
			continue
		var key: String = raw_arg.substr(2, eq_index - 2)
		var value: String = raw_arg.substr(eq_index + 1)
		parsed[key] = value
	return parsed
