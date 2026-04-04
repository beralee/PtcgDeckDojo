## Self-play evolution entry point.
extends Control

const EvolutionEngineScript = preload("res://scripts/ai/EvolutionEngine.gd")
const AgentVersionStoreScript = preload("res://scripts/ai/AgentVersionStore.gd")
const DeckBenchmarkCaseScript = preload("res://scripts/ai/DeckBenchmarkCase.gd")


func _ready() -> void:
	print("===== Self-Play Evolution Runner =====")

	var engine := EvolutionEngineScript.new()
	var options := parse_args(OS.get_cmdline_user_args())
	_apply_engine_options(engine, options)

	print("[TunerRunner] Config: generations=%d sigma_w=%.3f sigma_m=%.3f" % [
		engine.generations, engine.sigma_weights, engine.sigma_mcts
	])
	print("[TunerRunner] Pipeline: %s" % str(options.get("pipeline_name", DeckBenchmarkCaseScript.PIPELINE_FIXED_THREE_DECK)))

	var initial_config := build_initial_config(options)
	if str(options.get("agent_config_path", "")) != "":
		print("[TunerRunner] Loading explicit agent config: %s" % str(options.get("agent_config_path", "")))
	elif bool(options.get("from_latest", false)):
		print("[TunerRunner] Loading latest agent config from store")
	else:
		print("[TunerRunner] Using default config baseline")

	var result: Dictionary = engine.run(initial_config)

	print("\n===== Evolution Result =====")
	print("Generations run: %d" % int(result.get("generations_run", 0)))
	print("Versions saved: %d" % (result.get("versions_saved", []) as Array).size())

	var best_config: Dictionary = result.get("best_config", {})
	print("Final heuristic weights:")
	print(JSON.stringify(best_config.get("heuristic_weights", {}), "  "))
	print("Final MCTS config:")
	print(JSON.stringify(best_config.get("mcts_config", {}), "  "))

	var log_entries: Array = result.get("generation_log", [])
	var accepted_count: int = 0
	for entry: Variant in log_entries:
		if entry is Dictionary and bool((entry as Dictionary).get("accepted", false)):
			accepted_count += 1
	print("Accepted mutants: %d / %d" % [accepted_count, log_entries.size()])

	if DisplayServer.get_name() == "headless":
		call_deferred("_quit_after_run")


func parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {
		"generations": 50,
		"sigma_weights": 0.15,
		"sigma_mcts": 0.10,
		"max_steps": 200,
		"from_latest": false,
		"agent_config_path": "",
		"value_net_path": "",
		"action_scorer_path": "",
		"progress_output_path": "",
		"anomaly_output_path": "",
		"pipeline_name": DeckBenchmarkCaseScript.PIPELINE_FIXED_THREE_DECK,
		"export_data": false,
		"export_action_data": false,
	}
	for arg: String in args:
		if arg.begins_with("--generations="):
			parsed["generations"] = int(arg.split("=")[1])
		elif arg.begins_with("--sigma-w="):
			parsed["sigma_weights"] = float(arg.split("=")[1])
		elif arg.begins_with("--sigma-m="):
			parsed["sigma_mcts"] = float(arg.split("=")[1])
		elif arg.begins_with("--max-steps="):
			parsed["max_steps"] = int(arg.split("=")[1])
		elif arg == "--from-latest":
			parsed["from_latest"] = true
		elif arg.begins_with("--agent-config="):
			parsed["agent_config_path"] = arg.split("=")[1]
		elif arg.begins_with("--value-net="):
			parsed["value_net_path"] = arg.split("=")[1]
		elif arg.begins_with("--action-scorer="):
			parsed["action_scorer_path"] = arg.split("=")[1]
		elif arg.begins_with("--progress-output="):
			parsed["progress_output_path"] = arg.split("=")[1]
		elif arg.begins_with("--anomaly-output="):
			parsed["anomaly_output_path"] = arg.split("=")[1]
		elif arg.begins_with("--pipeline-name="):
			parsed["pipeline_name"] = arg.split("=")[1]
		elif arg == "--export-data":
			parsed["export_data"] = true
		elif arg == "--export-action-data":
			parsed["export_action_data"] = true
	return parsed


func build_initial_config(options: Dictionary, store_override: RefCounted = null) -> Dictionary:
	var initial_config := EvolutionEngineScript.get_default_config().duplicate(true)
	var store := store_override if store_override != null else AgentVersionStoreScript.new()
	var agent_config_path := str(options.get("agent_config_path", ""))
	if agent_config_path != "":
		var loaded: Dictionary = store.load_version(agent_config_path)
		if not loaded.is_empty():
			return _extract_agent_config(loaded, initial_config)
		return initial_config
	if bool(options.get("from_latest", false)):
		var latest: Dictionary = store.load_latest()
		if not latest.is_empty():
			return _extract_agent_config(latest, initial_config)
	return initial_config


func _apply_engine_options(engine: EvolutionEngine, options: Dictionary) -> void:
	engine.generations = int(options.get("generations", engine.generations))
	engine.sigma_weights = float(options.get("sigma_weights", engine.sigma_weights))
	engine.sigma_mcts = float(options.get("sigma_mcts", engine.sigma_mcts))
	engine.max_steps_per_match = int(options.get("max_steps", engine.max_steps_per_match))
	engine.value_net_path = str(options.get("value_net_path", ""))
	engine.action_scorer_path = str(options.get("action_scorer_path", ""))
	engine.progress_output_path = str(options.get("progress_output_path", ""))
	engine.anomaly_output_path = str(options.get("anomaly_output_path", ""))
	engine.deck_pairings = DeckBenchmarkCaseScript.get_training_deck_pairings(str(options.get("pipeline_name", DeckBenchmarkCaseScript.PIPELINE_FIXED_THREE_DECK)))
	engine.export_training_data = bool(options.get("export_data", false))
	engine.export_action_training_data = bool(options.get("export_action_data", false))


func _extract_agent_config(source: Dictionary, fallback: Dictionary) -> Dictionary:
	return {
		"heuristic_weights": (source.get("heuristic_weights", fallback.get("heuristic_weights", {})) as Dictionary).duplicate(true),
		"mcts_config": (source.get("mcts_config", fallback.get("mcts_config", {})) as Dictionary).duplicate(true),
	}


func _quit_after_run() -> void:
	get_tree().quit(0)
