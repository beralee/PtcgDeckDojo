class_name EvolutionEngine
extends RefCounted

## 进化搜索引擎：联合调优 heuristic 权重 + MCTS 参数。
## 用 hill-climbing + 高斯扰动 + 自适应 sigma 搜索更优 agent config。

const SelfPlayRunnerScript = preload("res://scripts/ai/SelfPlayRunner.gd")
const AgentVersionStoreScript = preload("res://scripts/ai/AgentVersionStore.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")

## 进化配置
var generations: int = 50
var sigma_weights: float = 0.15
var sigma_mcts: float = 0.10
var max_steps_per_match: int = 200
var seed_set: Array[int] = [11, 29, 47, 83]
var deck_pairings: Array[Array] = [
	[575720, 578647],   # miraidon vs gardevoir
	[575720, 575716],   # miraidon vs charizard_ex
	[578647, 575716],   # gardevoir vs charizard_ex
]
var value_net_path: String = ""
var export_training_data: bool = false

## 自适应 sigma 参数
const SIGMA_MIN: float = 0.05
const SIGMA_MAX: float = 0.40
const SIGMA_INCREASE_FACTOR: float = 1.20
const SIGMA_DECREASE_FACTOR: float = 0.90
const CONSECUTIVE_THRESHOLD: int = 3

## MCTS 参数 clamp 范围
const MCTS_CLAMP := {
	"branch_factor": {"min": 2, "max": 5},
	"rollouts_per_sequence": {"min": 5, "max": 50},
	"rollout_max_steps": {"min": 30, "max": 200},
	"time_budget_ms": {"min": 1000, "max": 10000},
}

## 内部状态
var _rng := RandomNumberGenerator.new()
var _consecutive_accepts: int = 0
var _consecutive_rejects: int = 0

## 外部组件（可覆盖用于测试）
var _runner: RefCounted = null
var _store: RefCounted = null


static func get_default_config() -> Dictionary:
	return {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
		"mcts_config": {
			"branch_factor": 3,
			"rollouts_per_sequence": 20,
			"rollout_max_steps": 80,
			"time_budget_ms": 3000,
		},
		"value_net_path": "",
	}


func run(initial_config: Dictionary = {}) -> Dictionary:
	_rng.randomize()
	if _runner == null:
		_runner = SelfPlayRunnerScript.new()
	if _store == null:
		_store = AgentVersionStoreScript.new()

	var current_best: Dictionary = initial_config.duplicate(true)
	if current_best.is_empty():
		var latest: Dictionary = _store.load_latest()
		if latest.is_empty():
			current_best = get_default_config()
		else:
			current_best = {
				"heuristic_weights": latest.get("heuristic_weights", {}),
				"mcts_config": latest.get("mcts_config", {}),
			}

	var generation_log: Array[Dictionary] = []
	var versions_saved: Array[String] = []
	var parent_version: String = str(current_best.get("_version_id", ""))

	print("[Evolution] 启动进化: %d 代, sigma_w=%.3f, sigma_m=%.3f" % [generations, sigma_weights, sigma_mcts])

	for gen: int in generations:
		var mutant_config: Dictionary = mutate(current_best)
		if value_net_path != "":
			mutant_config["value_net_path"] = value_net_path
			current_best["value_net_path"] = value_net_path
		var result: Dictionary = _runner.run_batch(
			mutant_config,
			current_best,
			deck_pairings,
			seed_set,
			max_steps_per_match,
			export_training_data,
		)
		var mutant_wr: float = float(result.get("agent_a_win_rate", 0.0))
		var accepted: bool = mutant_wr > 0.5

		var gen_entry := {
			"generation": gen,
			"mutant_win_rate": mutant_wr,
			"accepted": accepted,
			"total_matches": int(result.get("total_matches", 0)),
			"agent_a_wins": int(result.get("agent_a_wins", 0)),
			"sigma_weights": sigma_weights,
			"sigma_mcts": sigma_mcts,
		}
		generation_log.append(gen_entry)

		if accepted:
			current_best = mutant_config.duplicate(true)
			var save_path: String = _store.save_version(current_best, {
				"generation": gen,
				"parent_version": parent_version,
				"win_rate_vs_parent": mutant_wr,
			})
			if save_path != "":
				versions_saved.append(save_path)
				parent_version = save_path
			adjust_sigma("accept")
			print("[Evolution] 第 %d 代: 接受 (胜率 %.1f%%) sigma_w=%.3f sigma_m=%.3f" % [gen, mutant_wr * 100.0, sigma_weights, sigma_mcts])
		else:
			adjust_sigma("reject")
			print("[Evolution] 第 %d 代: 拒绝 (胜率 %.1f%%) sigma_w=%.3f sigma_m=%.3f" % [gen, mutant_wr * 100.0, sigma_weights, sigma_mcts])

	print("[Evolution] 完成! %d 代, 保存了 %d 个版本" % [generations, versions_saved.size()])

	return {
		"best_config": current_best,
		"generations_run": generations,
		"generation_log": generation_log,
		"versions_saved": versions_saved,
	}


func mutate(base_config: Dictionary) -> Dictionary:
	var mutant := {}

	## 扰动 heuristic 权重
	var base_weights: Dictionary = base_config.get("heuristic_weights", {})
	var mutant_weights: Dictionary = base_weights.duplicate(true)
	for key: String in mutant_weights.keys():
		var value: float = float(mutant_weights[key])
		var noise: float = _rng.randfn(0.0, sigma_weights)
		mutant_weights[key] = value * (1.0 + noise)
	mutant["heuristic_weights"] = mutant_weights

	## 扰动 MCTS 参数
	var base_mcts: Dictionary = base_config.get("mcts_config", {})
	var mutant_mcts: Dictionary = base_mcts.duplicate(true)
	for key: String in mutant_mcts.keys():
		var value: float = float(mutant_mcts[key])
		var noise: float = _rng.randfn(0.0, sigma_mcts)
		var new_value: float = value * (1.0 + noise)
		## clamp 到合理范围
		if MCTS_CLAMP.has(key):
			var bounds: Dictionary = MCTS_CLAMP[key]
			new_value = clampf(new_value, float(bounds["min"]), float(bounds["max"]))
		mutant_mcts[key] = int(roundi(new_value))
	mutant["mcts_config"] = mutant_mcts

	return mutant


func adjust_sigma(outcome: String) -> void:
	if outcome == "accept":
		_consecutive_accepts += 1
		_consecutive_rejects = 0
		if _consecutive_accepts >= CONSECUTIVE_THRESHOLD:
			sigma_weights = clampf(sigma_weights * SIGMA_DECREASE_FACTOR, SIGMA_MIN, SIGMA_MAX)
			sigma_mcts = clampf(sigma_mcts * SIGMA_DECREASE_FACTOR, SIGMA_MIN, SIGMA_MAX)
			_consecutive_accepts = 0
	elif outcome == "reject":
		_consecutive_rejects += 1
		_consecutive_accepts = 0
		if _consecutive_rejects >= CONSECUTIVE_THRESHOLD:
			sigma_weights = clampf(sigma_weights * SIGMA_INCREASE_FACTOR, SIGMA_MIN, SIGMA_MAX)
			sigma_mcts = clampf(sigma_mcts * SIGMA_INCREASE_FACTOR, SIGMA_MIN, SIGMA_MAX)
			_consecutive_rejects = 0
