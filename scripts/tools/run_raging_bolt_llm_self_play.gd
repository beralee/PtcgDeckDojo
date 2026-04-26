extends SceneTree

const RagingBoltLLMSelfPlayToolScript = preload("res://scripts/tools/RagingBoltLLMSelfPlayTool.gd")

const DEFAULT_GAMES := 1
const DEFAULT_MAX_STEPS := 160
const DEFAULT_SEED_BASE := 260426
const DEFAULT_LLM_WAIT_SECONDS := 90.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var tool: RefCounted = RagingBoltLLMSelfPlayToolScript.new()
	var result: Dictionary = await tool.run(options, self)
	var log_path := str(result.get("log_path", ""))
	var global_log_path := ProjectSettings.globalize_path(log_path) if log_path.begins_with("user://") else log_path
	print("Raging Bolt LLM self-play finished")
	print("self_play_log=%s" % global_log_path)
	for path: Variant in result.get("llm_audit_paths", []):
		var path_str := str(path)
		var global_path := ProjectSettings.globalize_path(path_str) if path_str.begins_with("user://") else path_str
		print("llm_audit_log=%s" % global_path)
	var games: Array = result.get("games", [])
	for game: Variant in games:
		if not (game is Dictionary):
			continue
		print("game=%d seed=%d winner=%d turns=%d steps=%d failure=%s" % [
			int((game as Dictionary).get("game_index", -1)),
			int((game as Dictionary).get("seed", -1)),
			int((game as Dictionary).get("winner_index", -1)),
			int((game as Dictionary).get("turn_count", -1)),
			int((game as Dictionary).get("steps", -1)),
			str((game as Dictionary).get("failure_reason", "")),
		])
	var errors: Array = result.get("errors", [])
	if not errors.is_empty():
		for error: Variant in errors:
			push_error(str(error))
		quit(1)
		return
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"games": DEFAULT_GAMES,
		"seed_base": DEFAULT_SEED_BASE,
		"max_steps": DEFAULT_MAX_STEPS,
		"llm_wait_seconds": DEFAULT_LLM_WAIT_SECONDS,
		"log_path": "",
	}
	for raw_arg: String in args:
		if raw_arg.begins_with("--games="):
			options["games"] = max(1, int(raw_arg.trim_prefix("--games=")))
		elif raw_arg.begins_with("--seed-base="):
			options["seed_base"] = int(raw_arg.trim_prefix("--seed-base="))
		elif raw_arg.begins_with("--seed="):
			options["seed_base"] = int(raw_arg.trim_prefix("--seed="))
		elif raw_arg.begins_with("--max-steps="):
			options["max_steps"] = max(1, int(raw_arg.trim_prefix("--max-steps=")))
		elif raw_arg.begins_with("--llm-wait-seconds="):
			options["llm_wait_seconds"] = maxf(0.1, float(raw_arg.trim_prefix("--llm-wait-seconds=")))
		elif raw_arg.begins_with("--log-path="):
			options["log_path"] = raw_arg.trim_prefix("--log-path=")
	return options
