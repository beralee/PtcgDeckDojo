class_name EvolutionEngine
extends RefCounted

## 进化搜索引擎：联合调优 heuristic 权重 + MCTS 参数。
## 用 hill-climbing + 高斯扰动 + 自适应 sigma 搜索更优 agent config。

const SelfPlayRunnerScript = preload("res://scripts/ai/SelfPlayRunner.gd")
const AgentVersionStoreScript = preload("res://scripts/ai/AgentVersionStore.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const TrainingAnomalyArchiveScript = preload("res://scripts/ai/TrainingAnomalyArchive.gd")

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
var action_scorer_path: String = ""
var interaction_scorer_path: String = ""
var progress_output_path: String = ""
var anomaly_output_path: String = ""
var export_training_data: bool = false
var export_action_training_data: bool = false

## 自适应 sigma 参数
const SIGMA_MIN: float = 0.05
const SIGMA_MAX: float = 0.40
const SIGMA_INCREASE_FACTOR: float = 1.20
const SIGMA_DECREASE_FACTOR: float = 0.90
const CONSECUTIVE_THRESHOLD: int = 3

## 卡组中文名映射
const DECK_NAMES := {
	575720: "密勒顿",
	578647: "沙奈朵",
	575716: "喷火龙ex",
}

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
		"action_scorer_path": "",
		"interaction_scorer_path": "",
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
				"value_net_path": str(latest.get("value_net_path", "")),
				"action_scorer_path": str(latest.get("action_scorer_path", "")),
				"interaction_scorer_path": str(latest.get("interaction_scorer_path", "")),
			}

	var generation_log: Array[Dictionary] = []
	var versions_saved: Array[String] = []
	var parent_version: String = str(current_best.get("_version_id", ""))
	var cumulative_matches: int = 0
	var cumulative_agent_a_wins: int = 0
	var cumulative_agent_b_wins: int = 0
	var accepted_generations: int = 0
	var anomaly_archive = TrainingAnomalyArchiveScript.new()

	print("[Evolution] 启动进化: %d 代, sigma_w=%.3f, sigma_m=%.3f" % [generations, sigma_weights, sigma_mcts])

	_write_progress_status({
		"phase": "phase1",
		"generation_current": 0,
		"generation_total": generations,
		"total_matches_completed": 0,
		"cumulative_agent_a_wins": 0,
		"cumulative_agent_b_wins": 0,
		"cumulative_agent_a_win_rate": 0.0,
		"last_generation_matches": 0,
		"last_generation_agent_a_wins": 0,
		"last_generation_agent_b_wins": 0,
		"last_generation_win_rate": 0.0,
		"accepted_generations": 0,
		"sigma_weights": sigma_weights,
		"sigma_mcts": sigma_mcts,
	})

	for gen: int in generations:
		var mutant_config: Dictionary = mutate(current_best)
		if value_net_path != "":
			mutant_config["value_net_path"] = value_net_path
			current_best["value_net_path"] = value_net_path
		if action_scorer_path != "":
			mutant_config["action_scorer_path"] = action_scorer_path
			current_best["action_scorer_path"] = action_scorer_path
		if interaction_scorer_path != "":
			mutant_config["interaction_scorer_path"] = interaction_scorer_path
			current_best["interaction_scorer_path"] = interaction_scorer_path
		## 导出训练数据时使用更大的步数上限确保对局能完成
		var effective_max_steps: int = 500 if export_training_data else max_steps_per_match
		var result: Dictionary = _runner.run_batch(
			mutant_config,
			current_best,
			deck_pairings,
			seed_set,
			effective_max_steps,
			export_training_data,
			export_action_training_data,
		)
		var mutant_wr: float = float(result.get("agent_a_win_rate", 0.0))
		var accepted: bool = mutant_wr > 0.5
		var total_matches: int = int(result.get("total_matches", 0))
		var agent_a_wins: int = int(result.get("agent_a_wins", 0))
		var agent_b_wins: int = int(result.get("agent_b_wins", 0))
		cumulative_matches += total_matches
		cumulative_agent_a_wins += agent_a_wins
		cumulative_agent_b_wins += agent_b_wins

		var gen_entry := {
			"generation": gen,
			"mutant_win_rate": mutant_wr,
			"accepted": accepted,
			"total_matches": total_matches,
			"agent_a_wins": agent_a_wins,
			"sigma_weights": sigma_weights,
			"sigma_mcts": sigma_mcts,
		}
		generation_log.append(gen_entry)

		if accepted:
			accepted_generations += 1
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
			print("[进化] 第 %d 代: 接受 (胜率 %.1f%%) sigma_w=%.3f sigma_m=%.3f" % [gen, mutant_wr * 100.0, sigma_weights, sigma_mcts])
		else:
			adjust_sigma("reject")
			print("[进化] 第 %d 代: 拒绝 (胜率 %.1f%%) sigma_w=%.3f sigma_m=%.3f" % [gen, mutant_wr * 100.0, sigma_weights, sigma_mcts])

		anomaly_archive.record_matches("phase1_self_play", result.get("match_results", []), {
			"generation": gen,
		})
		if anomaly_output_path != "":
			anomaly_archive.write_summary(anomaly_output_path)
		_print_generation_detail(result, gen)
		_write_progress_status({
			"phase": "phase1",
			"generation_current": gen + 1,
			"generation_total": generations,
			"total_matches_completed": cumulative_matches,
			"cumulative_agent_a_wins": cumulative_agent_a_wins,
			"cumulative_agent_b_wins": cumulative_agent_b_wins,
			"cumulative_agent_a_win_rate": 0.0 if cumulative_matches <= 0 else float(cumulative_agent_a_wins) / float(cumulative_matches),
			"last_generation_matches": total_matches,
			"last_generation_agent_a_wins": agent_a_wins,
			"last_generation_agent_b_wins": agent_b_wins,
			"last_generation_win_rate": mutant_wr,
			"accepted_generations": accepted_generations,
			"sigma_weights": sigma_weights,
			"sigma_mcts": sigma_mcts,
		})

	print("[进化] 完成! %d 代, 保存了 %d 个版本" % [generations, versions_saved.size()])
	_print_trend_summary(generation_log)
	if anomaly_output_path != "":
		anomaly_archive.write_summary(anomaly_output_path)
	_write_progress_status({
		"phase": "complete",
		"generation_current": generations,
		"generation_total": generations,
		"total_matches_completed": cumulative_matches,
		"cumulative_agent_a_wins": cumulative_agent_a_wins,
		"cumulative_agent_b_wins": cumulative_agent_b_wins,
		"cumulative_agent_a_win_rate": 0.0 if cumulative_matches <= 0 else float(cumulative_agent_a_wins) / float(cumulative_matches),
		"last_generation_matches": 0 if generation_log.is_empty() else int(generation_log[-1].get("total_matches", 0)),
		"last_generation_agent_a_wins": 0 if generation_log.is_empty() else int(generation_log[-1].get("agent_a_wins", 0)),
		"last_generation_agent_b_wins": 0 if generation_log.is_empty() else int(generation_log[-1].get("total_matches", 0)) - int(generation_log[-1].get("agent_a_wins", 0)),
		"last_generation_win_rate": 0.0 if generation_log.is_empty() else float(generation_log[-1].get("mutant_win_rate", 0.0)),
		"accepted_generations": accepted_generations,
		"sigma_weights": sigma_weights,
		"sigma_mcts": sigma_mcts,
	})

	return {
		"best_config": current_best,
		"generations_run": generations,
		"generation_log": generation_log,
		"versions_saved": versions_saved,
	}


func _write_progress_status(payload: Dictionary) -> void:
	if progress_output_path == "":
		return
	var path: String = progress_output_path
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir_path := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var enriched := payload.duplicate(true)
	enriched["updated_at"] = Time.get_datetime_string_from_system(false, true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("EvolutionEngine: failed to write progress status to %s" % path)
		return
	file.store_string(JSON.stringify(enriched, "  "))
	file.close()


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


func _print_generation_detail(result: Dictionary, gen: int) -> void:
	var matches: Array = result.get("match_results", [])
	if matches.is_empty():
		return

	## 按卡组对聚合
	var pair_stats := {}  # "deckA_id:deckB_id" -> {mutant_wins, baseline_wins, turns, timeouts, failures}
	for m: Variant in matches:
		if not m is Dictionary:
			continue
		var md: Dictionary = m as Dictionary
		var da: int = int(md.get("deck_a_id", 0))
		var db: int = int(md.get("deck_b_id", 0))
		var pair_key: String = "%d:%d" % [da, db]
		if not pair_stats.has(pair_key):
			pair_stats[pair_key] = {
				"deck_a_id": da, "deck_b_id": db,
				"mutant_wins": 0, "baseline_wins": 0, "draws": 0,
				"total_turns": 0, "match_count": 0,
				"timeouts": 0, "failures": 0,
			}
		var ps: Dictionary = pair_stats[pair_key]
		ps["match_count"] += 1
		ps["total_turns"] += int(md.get("turn_count", 0))
		if bool(md.get("terminated_by_cap", false)):
			ps["timeouts"] += 1
		var fr: String = str(md.get("failure_reason", ""))
		if fr != "":
			ps["failures"] += 1

		## 判断突变体是否获胜
		var winner: int = int(md.get("winner_index", -1))
		var agent_a_pi: int = int(md.get("agent_a_player_index", 0))
		if winner == agent_a_pi:
			ps["mutant_wins"] += 1
		elif winner >= 0:
			ps["baseline_wins"] += 1
		else:
			ps["draws"] += 1

	print("[进化] 第 %d 代 详情 (%d场):" % [gen, matches.size()])
	for key: String in pair_stats.keys():
		var ps: Dictionary = pair_stats[key]
		var name_a: String = DECK_NAMES.get(ps["deck_a_id"], str(ps["deck_a_id"]))
		var name_b: String = DECK_NAMES.get(ps["deck_b_id"], str(ps["deck_b_id"]))
		var avg_turns: float = 0.0 if ps["match_count"] == 0 else float(ps["total_turns"]) / float(ps["match_count"])
		print("  %s vs %s | 突变 %d:%d 基准 | 平均 %.1f 回合 | 超时 %d | 失败 %d" % [
			name_a, name_b,
			ps["mutant_wins"], ps["baseline_wins"],
			avg_turns, ps["timeouts"], ps["failures"],
		])

	var total_mw: int = int(result.get("agent_a_wins", 0))
	var total_bw: int = int(result.get("agent_b_wins", 0))
	var wr: float = float(result.get("agent_a_win_rate", 0.0))
	var outcome_str: String = "接受" if wr > 0.5 else "拒绝"
	print("  总计: 突变 %d:%d 基准 (%.1f%%) -> %s" % [total_mw, total_bw, wr * 100.0, outcome_str])


func _print_trend_summary(generation_log: Array[Dictionary]) -> void:
	if generation_log.is_empty():
		return

	print("\n===== 训练趋势 =====")
	print("  代  | 突变胜率 | 结果 | 累计接受 | sigma_w | sigma_m")
	var cumulative_accepts: int = 0
	var best_wr: float = 0.0
	var best_gen: int = 0

	for entry: Dictionary in generation_log:
		var gen: int = int(entry.get("generation", 0))
		var wr: float = float(entry.get("mutant_win_rate", 0.0))
		var accepted: bool = bool(entry.get("accepted", false))
		if accepted:
			cumulative_accepts += 1
		var sw: float = float(entry.get("sigma_weights", 0.0))
		var sm: float = float(entry.get("sigma_mcts", 0.0))
		var outcome_str: String = "接受" if accepted else "拒绝"
		print("  %3d |  %5.1f%%  | %s |   %3d   | %.3f  | %.3f" % [
			gen, wr * 100.0, outcome_str, cumulative_accepts, sw, sm,
		])
		if wr > best_wr:
			best_wr = wr
			best_gen = gen

	print("最佳突变胜率: %.1f%% (第 %d 代)" % [best_wr * 100.0, best_gen])
	print("接受率: %d/%d (%.1f%%)" % [
		cumulative_accepts, generation_log.size(),
		0.0 if generation_log.is_empty() else float(cumulative_accepts) / float(generation_log.size()) * 100.0,
	])
