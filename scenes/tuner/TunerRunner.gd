## Self-Play 进化调优入口场景脚本
##
## 用法:
##   Godot --headless --quit-after 3600 --path <project> "res://scenes/tuner/TunerRunner.tscn"
##
## 命令行参数:
##   --generations=100         代数（默认 50）
##   --sigma-w=0.15            heuristic 权重扰动幅度（默认 0.15）
##   --sigma-m=0.10            MCTS 参数扰动幅度（默认 0.10）
##   --max-steps=200           单局最大步数（默认 200）
##   --from-latest             从 AgentVersionStore 加载最新版本作为起点
##   --value-net=path          价值网络权重路径（user:// 格式）
##   --export-data             导出训练数据
extends Control

const EvolutionEngineScript = preload("res://scripts/ai/EvolutionEngine.gd")


func _ready() -> void:
	print("===== Self-Play Evolution Runner =====")

	var engine := EvolutionEngineScript.new()
	var from_latest: bool = false

	var export_data: bool = false
	var cmdline_args: PackedStringArray = OS.get_cmdline_args()
	for arg: String in cmdline_args:
		if arg.begins_with("--generations="):
			engine.generations = int(arg.split("=")[1])
		elif arg.begins_with("--sigma-w="):
			engine.sigma_weights = float(arg.split("=")[1])
		elif arg.begins_with("--sigma-m="):
			engine.sigma_mcts = float(arg.split("=")[1])
		elif arg.begins_with("--max-steps="):
			engine.max_steps_per_match = int(arg.split("=")[1])
		elif arg == "--from-latest":
			from_latest = true
		elif arg.begins_with("--value-net="):
			engine.value_net_path = arg.split("=")[1]
		elif arg == "--export-data":
			export_data = true

	engine.export_training_data = export_data
	print("[TunerRunner] 配置: 代数=%d, sigma_w=%.3f, sigma_m=%.3f" % [
		engine.generations, engine.sigma_weights, engine.sigma_mcts
	])

	var initial_config := {}
	if from_latest:
		print("[TunerRunner] 从 AgentVersionStore 加载最新版本...")

	var result: Dictionary = engine.run(initial_config)

	print("\n===== 进化结果 =====")
	print("运行代数: %d" % int(result.get("generations_run", 0)))
	print("保存版本数: %d" % (result.get("versions_saved", []) as Array).size())

	var best_config: Dictionary = result.get("best_config", {})
	print("最终最优权重 JSON:")
	print(JSON.stringify(best_config.get("heuristic_weights", {}), "  "))
	print("最终 MCTS 参数:")
	print(JSON.stringify(best_config.get("mcts_config", {}), "  "))

	var log_entries: Array = result.get("generation_log", [])
	var accepted_count: int = 0
	for entry: Variant in log_entries:
		if entry is Dictionary and bool((entry as Dictionary).get("accepted", false)):
			accepted_count += 1
	print("被接受的突变: %d / %d" % [accepted_count, log_entries.size()])

	if DisplayServer.get_name() == "headless":
		call_deferred("_quit_after_run")


func _quit_after_run() -> void:
	get_tree().quit(0)
