extends SceneTree


const ScenarioReviewQueueHydratorScript = preload("res://scripts/tools/scenario_review/ScenarioReviewQueueHydrator.gd")


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var review_queue_dir: String = str(args.get("review-queue-dir", ""))
	var scenarios_root: String = str(args.get("scenarios-root", ""))
	if review_queue_dir == "" or scenarios_root == "":
		print("Missing --review-queue-dir or --scenarios-root")
		quit(2)
		return

	var hydrator = ScenarioReviewQueueHydratorScript.new()
	var result: Dictionary = hydrator.hydrate_review_queue(
		review_queue_dir,
		scenarios_root,
		str(args.get("runtime-mode", "rules_only")),
		bool(args.get("overwrite", false))
	)
	print(JSON.stringify(result, "\t"))
	quit(0 if int(result.get("error_count", 0)) == 0 else 1)


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {
		"runtime-mode": "rules_only",
	}
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
