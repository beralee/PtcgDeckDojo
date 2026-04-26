extends SceneTree

const DuelToolScript = preload("res://scripts/ai/LLMRagingBoltDuelTool.gd")

const DEFAULT_MODE := "miraidon"
const DEFAULT_GAMES := 1
const DEFAULT_JSON_OUTPUT := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var mode := str(args.get("mode", DEFAULT_MODE)).strip_edges().to_lower()
	var games: int = maxi(int(args.get("games", DEFAULT_GAMES)), 1)
	var tool: Node = DuelToolScript.new()
	root.add_child(tool)
	var options := {}
	if args.has("seed"):
		options["seed"] = int(args.get("seed"))
	if args.has("max-steps"):
		options["max_steps"] = int(args.get("max-steps"))
	if args.has("first-player"):
		options["first_player_index"] = int(args.get("first-player"))
	if args.has("llm-timeout"):
		options["llm_wait_timeout_seconds"] = float(args.get("llm-timeout"))
	if args.has("output-root"):
		options["output_root"] = str(args.get("output-root"))
	if args.has("llm-wait-timeout-seconds"):
		options["llm_wait_timeout_seconds"] = float(args.get("llm-wait-timeout-seconds"))
	if args.has("llm-wait-poll-seconds"):
		options["llm_wait_poll_seconds"] = float(args.get("llm-wait-poll-seconds"))
	if args.has("llm-max-failures"):
		options["llm_max_failures_per_strategy"] = int(args.get("llm-max-failures"))

	var report: Dictionary
	match mode:
		"self_play", "self-play", "mirror":
			report = await tool.call("run_llm_raging_bolt_self_play", games, options)
			report["mode"] = "self_play"
		"miraidon", "rule_miraidon", "vs_miraidon":
			report = await tool.call("run_rule_miraidon_vs_llm_raging_bolt", games, options)
			report["mode"] = "miraidon"
		_:
			report = {
				"mode": mode,
				"error": "unsupported mode",
				"supported_modes": ["self_play", "miraidon"],
			}

	var json_text := JSON.stringify(report, "\t")
	var json_output := str(args.get("json-output", DEFAULT_JSON_OUTPUT))
	if json_output != "":
		_write_text(json_output, json_text)
	print(json_text)
	if is_instance_valid(tool):
		tool.queue_free()
	quit(1 if report.has("error") else 0)


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for raw_arg: String in raw_args:
		if not raw_arg.begins_with("--"):
			continue
		var eq_index := raw_arg.find("=")
		if eq_index <= 2:
			continue
		var key := raw_arg.substr(2, eq_index - 2)
		var value := raw_arg.substr(eq_index + 1)
		parsed[key] = value
	return parsed


func _write_text(path: String, text: String) -> void:
	var normalized_path := path.strip_edges()
	if normalized_path == "":
		return
	var absolute_path := normalized_path
	if normalized_path.begins_with("res://") or normalized_path.begins_with("user://"):
		absolute_path = ProjectSettings.globalize_path(normalized_path)
	var dir := absolute_path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write JSON output: %s" % normalized_path)
		return
	file.store_string(text)
	file.close()
