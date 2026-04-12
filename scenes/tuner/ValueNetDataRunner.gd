## Value Net 数据采集入口（headless）。
## 用法：
## godot --headless --path . res://scenes/tuner/ValueNetDataRunner.tscn -- \
##   --games=200 --deck-a=578647 --deck-b=578647
extends Control

const SelfPlayRunnerScript = preload("res://scripts/ai/SelfPlayRunner.gd")
const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const DeckStrategyMiraidonScript = preload("res://scripts/ai/DeckStrategyMiraidon.gd")
const DeckStrategyArceusGiratinaScript = preload("res://scripts/ai/DeckStrategyArceusGiratina.gd")
const DeckStrategyDragapultDusknoirScript = preload("res://scripts/ai/DeckStrategyDragapultDusknoir.gd")
const DeckStrategyDragapultCharizardScript = preload("res://scripts/ai/DeckStrategyDragapultCharizard.gd")


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var games: int = int(options.get("games", 200))
	var deck_a: int = int(options.get("deck_a", 578647))
	var deck_b: int = int(options.get("deck_b", 578647))
	var max_steps: int = int(options.get("max_steps", 200))
	var value_net_path: String = str(options.get("value_net", ""))
	var action_scorer_path: String = str(options.get("action_scorer", ""))
	var interaction_scorer_path: String = str(options.get("interaction_scorer", ""))
	var export_action_data: bool = bool(options.get("export_action_data", false))
	var training_data_dir: String = str(options.get("data_dir", ""))
	var action_data_dir: String = str(options.get("action_data_dir", ""))

	print("===== Value Net Data Runner =====")
	print("[ValueNetDataRunner] games=%d deck_a=%d deck_b=%d" % [games, deck_a, deck_b])
	if value_net_path != "":
		print("[ValueNetDataRunner] value_net=%s" % value_net_path)
	if action_scorer_path != "":
		print("[ValueNetDataRunner] action_scorer=%s" % action_scorer_path)
	if interaction_scorer_path != "":
		print("[ValueNetDataRunner] interaction_scorer=%s" % interaction_scorer_path)
	if export_action_data:
		print("[ValueNetDataRunner] export_action_data=true")
	if training_data_dir != "":
		print("[ValueNetDataRunner] data_dir=%s" % training_data_dir)
	if action_data_dir != "":
		print("[ValueNetDataRunner] action_data_dir=%s" % action_data_dir)

	var encoder: String = str(options.get("encoder", "gardevoir"))
	var pipeline_name: String = str(options.get("pipeline_name", encoder))
	var strategy: RefCounted = _create_strategy(encoder)
	var agent_config := {
		"heuristic_weights": {},
		"mcts_config": strategy.get_mcts_config(),
	}
	if value_net_path != "":
		agent_config["value_net_path"] = value_net_path
	if action_scorer_path != "":
		agent_config["action_scorer_path"] = action_scorer_path
	if interaction_scorer_path != "":
		agent_config["interaction_scorer_path"] = interaction_scorer_path

	var seed_offset: int = int(options.get("seed_offset", 0))
	print("[ValueNetDataRunner] encoder=%s" % encoder)

	var deck_pairings: Array = [[deck_a, deck_b]]
	var seeds: Array = []
	for i: int in games:
		seeds.append(i + 1000 + seed_offset)

	var runner := SelfPlayRunnerScript.new()

	var result: Dictionary = runner.run_batch(
		agent_config, agent_config,
		deck_pairings, seeds,
		max_steps,
		true,   # export_training_data
		export_action_data,  # export_action_training_data
		false,  # gardevoir_exporter (legacy)
		false,  # miraidon_exporter (legacy)
		encoder,  # encoder_id
		training_data_dir,
		action_data_dir,
		pipeline_name
	)

	print("\n===== Collection Done =====")
	print("Total matches: %d" % int(result.get("total_matches", 0)))
	print("A wins: %d  B wins: %d  Draws: %d" % [
		int(result.get("agent_a_wins", 0)),
		int(result.get("agent_b_wins", 0)),
		int(result.get("draws", 0)),
	])
	print("A win rate: %.1f%%" % (float(result.get("agent_a_win_rate", 0)) * 100.0))

	if DisplayServer.get_name() == "headless":
		call_deferred("_quit_after_run")


func _quit_after_run() -> void:
	get_tree().quit(0)


func _create_strategy(encoder: String) -> RefCounted:
	match encoder:
		"miraidon":
			return DeckStrategyMiraidonScript.new()
		"arceus_giratina":
			return DeckStrategyArceusGiratinaScript.new()
		"dragapult_dusknoir":
			return DeckStrategyDragapultDusknoirScript.new()
		"dragapult_charizard":
			return DeckStrategyDragapultCharizardScript.new()
	return DeckStrategyGardevoirScript.new()


func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {
		"games": 200,
		"deck_a": 578647,
		"deck_b": 578647,
		"max_steps": 200,
		"value_net": "",
		"action_scorer": "",
		"interaction_scorer": "",
		"seed_offset": 0,
		"encoder": "gardevoir",
		"export_action_data": false,
		"data_dir": "",
		"action_data_dir": "",
		"pipeline_name": "",
	}
	for arg: String in args:
		if arg.begins_with("--games="):
			parsed["games"] = int(arg.split("=")[1])
		elif arg.begins_with("--deck-a="):
			parsed["deck_a"] = int(arg.split("=")[1])
		elif arg.begins_with("--deck-b="):
			parsed["deck_b"] = int(arg.split("=")[1])
		elif arg.begins_with("--max-steps="):
			parsed["max_steps"] = int(arg.split("=")[1])
		elif arg.begins_with("--value-net="):
			parsed["value_net"] = arg.split("=")[1]
		elif arg.begins_with("--action-scorer="):
			parsed["action_scorer"] = arg.split("=")[1]
		elif arg.begins_with("--interaction-scorer="):
			parsed["interaction_scorer"] = arg.split("=")[1]
		elif arg.begins_with("--seed-offset="):
			parsed["seed_offset"] = int(arg.split("=")[1])
		elif arg.begins_with("--encoder="):
			parsed["encoder"] = arg.split("=")[1]
		elif arg == "--export-action-data":
			parsed["export_action_data"] = true
		elif arg.begins_with("--data-dir="):
			parsed["data_dir"] = arg.split("=")[1]
		elif arg.begins_with("--action-data-dir="):
			parsed["action_data_dir"] = arg.split("=")[1]
		elif arg.begins_with("--pipeline-name="):
			parsed["pipeline_name"] = arg.split("=")[1]
	return parsed
