class_name TestEvolutionEngine
extends TestBase

const EvolutionEngineScript = preload("res://scripts/ai/EvolutionEngine.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")


class FakeStore extends RefCounted:
	var load_latest_calls := 0
	var latest_record := {}
	var saved_versions: Array[Dictionary] = []

	func load_latest() -> Dictionary:
		load_latest_calls += 1
		return latest_record.duplicate(true)

	func save_version(config: Dictionary, metadata: Dictionary = {}) -> String:
		saved_versions.append({
			"config": config.duplicate(true),
			"metadata": metadata.duplicate(true),
		})
		return "user://ai_agents/fake_saved_agent.json"


class FakeRunner extends RefCounted:
	func run_batch(_mutant_config: Dictionary, _current_best: Dictionary, _deck_pairings: Array, _seed_set: Array, _max_steps: int, _export_data: bool) -> Dictionary:
		return {
			"agent_a_win_rate": 0.0,
			"total_matches": 0,
			"agent_a_wins": 0,
			"agent_b_wins": 0,
			"match_results": [],
		}


class FakeWinningRunner extends RefCounted:
	func run_batch(_mutant_config: Dictionary, _current_best: Dictionary, _deck_pairings: Array, _seed_set: Array, _max_steps: int, _export_data: bool) -> Dictionary:
		return {
			"agent_a_win_rate": 0.625,
			"total_matches": 24,
			"agent_a_wins": 15,
			"agent_b_wins": 9,
			"match_results": [],
		}


class FakeAnomalyRunner extends RefCounted:
	func run_batch(_mutant_config: Dictionary, _current_best: Dictionary, _deck_pairings: Array, _seed_set: Array, _max_steps: int, _export_data: bool) -> Dictionary:
		return {
			"agent_a_win_rate": 0.625,
			"total_matches": 4,
			"agent_a_wins": 2,
			"agent_b_wins": 1,
			"match_results": [
				{
					"winner_index": -1,
					"turn_count": 19,
					"steps": 42,
					"seed": 11,
					"deck_a_id": 575720,
					"deck_b_id": 578647,
					"agent_a_player_index": 0,
					"failure_reason": "action_cap_reached",
					"terminated_by_cap": true,
					"stalled": false,
				},
				{
					"winner_index": -1,
					"turn_count": 23,
					"steps": 51,
					"seed": 29,
					"deck_a_id": 575720,
					"deck_b_id": 578647,
					"agent_a_player_index": 1,
					"failure_reason": "stalled_no_progress",
					"terminated_by_cap": false,
					"stalled": true,
				},
			],
		}


class FakeProgressiveAnomalyRunner extends RefCounted:
	var anomaly_output_path: String = ""
	var saw_summary_before_second_generation: bool = false
	var _call_count: int = 0

	func run_batch(_mutant_config: Dictionary, _current_best: Dictionary, _deck_pairings: Array, _seed_set: Array, _max_steps: int, _export_data: bool) -> Dictionary:
		_call_count += 1
		if _call_count == 2 and anomaly_output_path != "":
			saw_summary_before_second_generation = FileAccess.file_exists(anomaly_output_path)
		return {
			"agent_a_win_rate": 0.0,
			"total_matches": 2,
			"agent_a_wins": 0,
			"agent_b_wins": 1,
			"match_results": [
				{
					"winner_index": -1,
					"turn_count": 11,
					"steps": 27,
					"seed": 11 + _call_count,
					"deck_a_id": 575720,
					"deck_b_id": 578647,
					"agent_a_player_index": 0,
					"failure_reason": "stalled_no_progress",
					"terminated_by_cap": false,
					"stalled": true,
				},
			],
		}


func test_run_writes_phase1_progress_status_json() -> String:
	var engine := EvolutionEngineScript.new()
	var fake_store := FakeStore.new()
	engine._store = fake_store
	engine._runner = FakeWinningRunner.new()
	engine.generations = 1
	engine.progress_output_path = "user://evolution_progress_status_test.json"
	var absolute_path := ProjectSettings.globalize_path(engine.progress_output_path)
	if FileAccess.file_exists(engine.progress_output_path):
		DirAccess.remove_absolute(absolute_path)

	engine.run(EvolutionEngineScript.get_default_config())

	if not FileAccess.file_exists(engine.progress_output_path):
		return "phase1 progress status should be written to the configured output path"

	var file := FileAccess.open(engine.progress_output_path, FileAccess.READ)
	if file == null:
		return "phase1 progress status should be readable after the run"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return "phase1 progress status should be valid JSON object"
	var progress: Dictionary = parsed
	DirAccess.remove_absolute(absolute_path)
	return run_checks([
		assert_eq(str(progress.get("phase", "")), "complete", "progress status should mark the phase complete after the evolution run"),
		assert_eq(int(progress.get("generation_current", 0)), 1, "progress status should record the completed generation count"),
		assert_eq(int(progress.get("generation_total", 0)), 1, "progress status should record the configured generation count"),
		assert_eq(int(progress.get("total_matches_completed", 0)), 24, "progress status should accumulate completed matches across generations"),
		assert_eq(int(progress.get("cumulative_agent_a_wins", 0)), 15, "progress status should accumulate agent_a wins"),
		assert_eq(int(progress.get("cumulative_agent_b_wins", 0)), 9, "progress status should accumulate agent_b wins"),
		assert_eq(float(progress.get("last_generation_win_rate", 0.0)), 0.625, "progress status should record the latest generation win rate"),
		assert_eq(int(progress.get("accepted_generations", 0)), 1, "progress status should record accepted generation count"),
	])


func test_run_writes_phase1_anomaly_summary_json() -> String:
	var engine := EvolutionEngineScript.new()
	var fake_store := FakeStore.new()
	engine._store = fake_store
	engine._runner = FakeAnomalyRunner.new()
	engine.generations = 1
	engine.anomaly_output_path = "user://evolution_phase1_anomalies_test.json"
	var absolute_path := ProjectSettings.globalize_path(engine.anomaly_output_path)
	if FileAccess.file_exists(engine.anomaly_output_path):
		DirAccess.remove_absolute(absolute_path)

	engine.run(EvolutionEngineScript.get_default_config())

	if not FileAccess.file_exists(engine.anomaly_output_path):
		return "phase1 anomaly summary should be written to the configured output path"

	var file := FileAccess.open(engine.anomaly_output_path, FileAccess.READ)
	if file == null:
		return "phase1 anomaly summary should be readable after the run"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	DirAccess.remove_absolute(absolute_path)
	if not parsed is Dictionary:
		return "phase1 anomaly summary should be valid JSON object"
	var summary: Dictionary = parsed
	var failure_counts: Dictionary = summary.get("failure_reason_counts", {})
	return run_checks([
		assert_eq(int(summary.get("total_anomalies", 0)), 2, "phase1 anomaly summary should count anomalous matches"),
		assert_eq(int(failure_counts.get("action_cap_reached", 0)), 1, "phase1 anomaly summary should count capped matches"),
		assert_eq(int(failure_counts.get("stalled_no_progress", 0)), 1, "phase1 anomaly summary should count stalled matches"),
		assert_eq(int((summary.get("phase_counts", {}) as Dictionary).get("phase1_self_play", 0)), 2, "phase1 anomaly summary should tag anomalies with the phase"),
	])


func test_run_flushes_phase1_anomaly_summary_after_each_generation() -> String:
	var engine := EvolutionEngineScript.new()
	var fake_store := FakeStore.new()
	var fake_runner := FakeProgressiveAnomalyRunner.new()
	engine._store = fake_store
	engine._runner = fake_runner
	engine.generations = 2
	engine.anomaly_output_path = "user://evolution_phase1_anomalies_progressive_test.json"
	fake_runner.anomaly_output_path = engine.anomaly_output_path
	var absolute_path := ProjectSettings.globalize_path(engine.anomaly_output_path)
	if FileAccess.file_exists(engine.anomaly_output_path):
		DirAccess.remove_absolute(absolute_path)

	engine.run(EvolutionEngineScript.get_default_config())

	if FileAccess.file_exists(engine.anomaly_output_path):
		DirAccess.remove_absolute(absolute_path)
	return run_checks([
		assert_true(fake_runner.saw_summary_before_second_generation, "phase1 anomaly summary should be flushed before the next generation starts"),
	])


func test_run_with_explicit_initial_config_bypasses_latest_store_lookup() -> String:
	var engine := EvolutionEngineScript.new()
	var fake_store := FakeStore.new()
	fake_store.latest_record = {
		"heuristic_weights": {"attack_base": 999.0},
		"mcts_config": {"branch_factor": 5, "rollouts_per_sequence": 50, "rollout_max_steps": 200, "time_budget_ms": 9999},
	}
	engine._store = fake_store
	engine._runner = FakeRunner.new()
	engine.generations = 0
	var explicit_config := {
		"heuristic_weights": {"attack_base": 123.0},
		"mcts_config": {"branch_factor": 2, "rollouts_per_sequence": 9, "rollout_max_steps": 111, "time_budget_ms": 3001},
	}
	var result: Dictionary = engine.run(explicit_config)
	return run_checks([
		assert_eq(fake_store.load_latest_calls, 0, "explicit initial_config should not trigger load_latest"),
		assert_eq(float(result.get("best_config", {}).get("heuristic_weights", {}).get("attack_base", 0.0)), 123.0, "explicit config should remain the best config when no generations run"),
	])


func test_run_without_initial_config_loads_latest_store_once() -> String:
	var engine := EvolutionEngineScript.new()
	var fake_store := FakeStore.new()
	fake_store.latest_record = {
		"heuristic_weights": {"attack_base": 456.0},
		"mcts_config": {"branch_factor": 4, "rollouts_per_sequence": 10, "rollout_max_steps": 88, "time_budget_ms": 3002},
	}
	engine._store = fake_store
	engine._runner = FakeRunner.new()
	engine.generations = 0
	var result: Dictionary = engine.run({})
	return run_checks([
		assert_eq(fake_store.load_latest_calls, 1, "empty initial_config should trigger exactly one latest-store lookup"),
		assert_eq(float(result.get("best_config", {}).get("heuristic_weights", {}).get("attack_base", 0.0)), 456.0, "latest-store heuristic config should seed the run"),
	])


func test_mutate_produces_different_weights() -> String:
	var engine := EvolutionEngineScript.new()
	var base_config := {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
		"mcts_config": {"branch_factor": 3, "rollouts_per_sequence": 20, "rollout_max_steps": 80, "time_budget_ms": 3000},
	}
	var mutant: Dictionary = engine.mutate(base_config)
	var base_w: Dictionary = base_config.get("heuristic_weights", {})
	var mutant_w: Dictionary = mutant.get("heuristic_weights", {})
	var any_different: bool = false
	for key: String in base_w.keys():
		if abs(float(mutant_w.get(key, 0.0)) - float(base_w[key])) > 0.001:
			any_different = true
			break
	return run_checks([
		assert_true(mutant.has("heuristic_weights"), "mutant 应包含 heuristic_weights"),
		assert_true(mutant.has("mcts_config"), "mutant 应包含 mcts_config"),
		assert_true(any_different, "突变后至少一个权重应不同"),
	])


func test_mutate_clamps_mcts_params() -> String:
	var engine := EvolutionEngineScript.new()
	engine.sigma_mcts = 10.0  # 极端扰动
	var base_config := {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
		"mcts_config": {"branch_factor": 3, "rollouts_per_sequence": 20, "rollout_max_steps": 80, "time_budget_ms": 3000},
	}
	var mutant: Dictionary = engine.mutate(base_config)
	var mcts: Dictionary = mutant.get("mcts_config", {})
	return run_checks([
		assert_true(int(mcts.get("branch_factor", 0)) >= 2, "branch_factor 应 >= 2"),
		assert_true(int(mcts.get("branch_factor", 999)) <= 5, "branch_factor 应 <= 5"),
		assert_true(int(mcts.get("rollouts_per_sequence", 0)) >= 5, "rollouts 应 >= 5"),
		assert_true(int(mcts.get("rollouts_per_sequence", 999)) <= 50, "rollouts 应 <= 50"),
		assert_true(int(mcts.get("rollout_max_steps", 0)) >= 30, "rollout_steps 应 >= 30"),
		assert_true(int(mcts.get("rollout_max_steps", 999)) <= 200, "rollout_steps 应 <= 200"),
		assert_true(int(mcts.get("time_budget_ms", 0)) >= 1000, "time_budget 应 >= 1000"),
		assert_true(int(mcts.get("time_budget_ms", 99999)) <= 10000, "time_budget 应 <= 10000"),
	])


func test_adjust_sigma_increases_on_consecutive_rejects() -> String:
	var engine := EvolutionEngineScript.new()
	engine.sigma_weights = 0.15
	engine.sigma_mcts = 0.10
	engine.adjust_sigma("reject")
	engine.adjust_sigma("reject")
	engine.adjust_sigma("reject")
	return run_checks([
		assert_true(engine.sigma_weights > 0.15, "连续拒绝后 sigma_weights 应增大"),
		assert_true(engine.sigma_mcts > 0.10, "连续拒绝后 sigma_mcts 应增大"),
	])


func test_adjust_sigma_decreases_on_consecutive_accepts() -> String:
	var engine := EvolutionEngineScript.new()
	engine.sigma_weights = 0.15
	engine.sigma_mcts = 0.10
	engine.adjust_sigma("accept")
	engine.adjust_sigma("accept")
	engine.adjust_sigma("accept")
	return run_checks([
		assert_true(engine.sigma_weights < 0.15, "连续接受后 sigma_weights 应缩小"),
		assert_true(engine.sigma_mcts < 0.10, "连续接受后 sigma_mcts 应缩小"),
	])


func test_sigma_clamp_bounds() -> String:
	var engine := EvolutionEngineScript.new()
	engine.sigma_weights = 0.05
	engine.sigma_mcts = 0.05
	## 连续接受应不会低于下界
	for _i in 20:
		engine.adjust_sigma("accept")
	var below_min_w: bool = engine.sigma_weights < 0.05
	engine.sigma_weights = 0.40
	engine.sigma_mcts = 0.40
	## 连续拒绝应不会高于上界
	for _i in 20:
		engine.adjust_sigma("reject")
	var above_max_w: bool = engine.sigma_weights > 0.40
	return run_checks([
		assert_false(below_min_w, "sigma_weights 不应低于 0.05"),
		assert_false(above_max_w, "sigma_weights 不应高于 0.40"),
	])


func test_get_default_config_returns_valid_structure() -> String:
	var config: Dictionary = EvolutionEngineScript.get_default_config()
	return run_checks([
		assert_true(config.has("heuristic_weights"), "默认 config 应包含 heuristic_weights"),
		assert_true(config.has("mcts_config"), "默认 config 应包含 mcts_config"),
		assert_true(not config.get("heuristic_weights", {}).is_empty(), "权重不应为空"),
		assert_true(config.get("mcts_config", {}).has("branch_factor"), "MCTS config 应包含 branch_factor"),
	])
