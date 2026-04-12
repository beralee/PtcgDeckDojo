## 锦标赛评估器：新 net vs 旧 net/greedy，输出胜率。
## 用法：
## godot --headless --path . res://scenes/tuner/TournamentRunner.tscn -- \
##   --games=50 --challenger=user://ai_agents/gardevoir_value_net_new.json \
##   --champion=user://ai_agents/gardevoir_value_net.json
##
## 省略 --champion 则对手为纯 greedy（无 value net）。
extends Control

const SelfPlayRunnerScript = preload("res://scripts/ai/SelfPlayRunner.gd")
const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")

const GARDEVOIR := 578647


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var games: int = int(options.get("games", 50))
	var challenger_path: String = str(options.get("challenger", ""))
	var champion_path: String = str(options.get("champion", ""))
	var result_path: String = str(options.get("result", ""))

	print("===== Tournament Runner =====")
	print("[Tournament] games=%d" % games)
	print("[Tournament] challenger=%s" % (challenger_path if challenger_path != "" else "(greedy)"))
	print("[Tournament] champion=%s" % (champion_path if champion_path != "" else "(greedy)"))

	var strategy := DeckStrategyGardevoirScript.new()
	var mcts_cfg: Dictionary = strategy.get_mcts_config()

	var challenger_config := {
		"heuristic_weights": {},
		"mcts_config": mcts_cfg,
	}
	if challenger_path != "":
		challenger_config["value_net_path"] = challenger_path

	var champion_config := {
		"heuristic_weights": {},
		"mcts_config": mcts_cfg,
	}
	if champion_path != "":
		champion_config["value_net_path"] = champion_path

	var deck_pairings: Array = [[GARDEVOIR, GARDEVOIR]]
	var seeds: Array = []
	for i: int in games:
		seeds.append(i + 5000)

	var runner := SelfPlayRunnerScript.new()
	var result: Dictionary = runner.run_batch(
		challenger_config, champion_config,
		deck_pairings, seeds,
		200,    # max_steps
		false,  # export_training_data
		false,  # export_action_training_data
		false,  # gardevoir_exporter
	)

	var total: int = int(result.get("total_matches", 0))
	var challenger_wins: int = int(result.get("agent_a_wins", 0))
	var champion_wins: int = int(result.get("agent_b_wins", 0))
	var draws: int = int(result.get("draws", 0))
	var win_rate: float = float(result.get("agent_a_win_rate", 0))

	print("\n===== Tournament Result =====")
	print("Total: %d | Challenger wins: %d | Champion wins: %d | Draws: %d" % [total, challenger_wins, champion_wins, draws])
	print("Challenger win rate: %.1f%%" % (win_rate * 100.0))
	if win_rate > 0.55:
		print(">>> CHALLENGER WINS (%.1f%% > 55%%)" % (win_rate * 100.0))
	else:
		print(">>> CHAMPION HOLDS (%.1f%% <= 55%%)" % (win_rate * 100.0))

	# 输出结果到文件（供脚本读取）
	if result_path != "":
		var rfile := FileAccess.open(result_path, FileAccess.WRITE)
		if rfile != null:
			rfile.store_string(JSON.stringify({
				"total": total,
				"challenger_wins": challenger_wins,
				"champion_wins": champion_wins,
				"draws": draws,
				"challenger_win_rate": win_rate,
				"promoted": win_rate > 0.55,
			}))
			rfile.close()

	if DisplayServer.get_name() == "headless":
		call_deferred("_quit_after_run")


func _quit_after_run() -> void:
	get_tree().quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {
		"games": 50,
		"challenger": "",
		"champion": "",
		"result": "",
	}
	for arg: String in args:
		if arg.begins_with("--games="):
			parsed["games"] = int(arg.split("=")[1])
		elif arg.begins_with("--challenger="):
			parsed["challenger"] = arg.split("=")[1]
		elif arg.begins_with("--champion="):
			parsed["champion"] = arg.split("=")[1]
		elif arg.begins_with("--result="):
			parsed["result"] = arg.split("=")[1]
	return parsed
