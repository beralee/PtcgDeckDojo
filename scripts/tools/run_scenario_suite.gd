extends SceneTree


const ScenarioRunnerScript = preload("res://tests/scenarios/ScenarioRunner.gd")


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var runner = ScenarioRunnerScript.new()
	var result: Dictionary = {}

	if args.has("scenario-path"):
		result = runner.run_scenario(str(args.get("scenario-path", "")), str(args.get("runtime-mode", "rules_only")))
	elif args.has("scenarios-dir"):
		result = runner.run_all(str(args.get("scenarios-dir", "")), str(args.get("runtime-mode", "rules_only")))
	else:
		print("Missing --scenario-path or --scenarios-dir")
		quit(2)
		return

	print(JSON.stringify(result, "\t"))
	quit(_exit_code_for_result(result))


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {
		"runtime-mode": "rules_only",
	}
	for raw_arg: String in raw_args:
		if not raw_arg.begins_with("--"):
			continue
		var eq_index: int = raw_arg.find("=")
		if eq_index <= 2:
			continue
		var key: String = raw_arg.substr(2, eq_index - 2)
		var value: String = raw_arg.substr(eq_index + 1)
		parsed[key] = value
	return parsed


func _exit_code_for_result(result: Dictionary) -> int:
	if result.has("status"):
		return 0 if str(result.get("status", "")) == "PASS" else 1
	var status_counts: Dictionary = result.get("status_counts", {})
	var failures: int = int(status_counts.get("FAIL", 0))
	var errors: int = int(status_counts.get("ERROR", 0))
	var diverges: int = int(status_counts.get("DIVERGE", 0))
	return 0 if failures == 0 and errors == 0 and diverges == 0 else 1
