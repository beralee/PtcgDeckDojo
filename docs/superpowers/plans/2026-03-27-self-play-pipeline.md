# Self-Play Pipeline Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 self-play 自动进化 pipeline，让 AI 通过自博弈联合调优 heuristic 权重 + MCTS 参数，每轮产出比上一轮更强的 agent。

**Architecture:** 三个新模块（AgentVersionStore / SelfPlayRunner / EvolutionEngine）+ 改造现有 TunerRunner 场景。SelfPlayRunner 复用 AIBenchmarkRunner.run_headless_duel() 核心。EvolutionEngine 用 hill-climbing + 高斯扰动 + 自适应 sigma 做联合参数搜索。AgentVersionStore 将最优 agent config 持久化为 JSON。

**Tech Stack:** Godot 4.6, GDScript, 现有 headless benchmark 基础设施, TestRunner.tscn 测试套件。

---

## File Map

### Create

- `scripts/ai/AgentVersionStore.gd`
  - Agent config 序列化/反序列化为 JSON，管理版本谱系，保存到 `user://ai_agents/`。
- `scripts/ai/SelfPlayRunner.gd`
  - 接收两个 agent config，在多组卡组对上跑批量 headless 对战，输出结构化胜负统计。
- `scripts/ai/EvolutionEngine.gd`
  - 进化搜索引擎：联合调优 heuristic 权重 + MCTS 参数，通过 SelfPlayRunner 评估，通过 AgentVersionStore 持久化。
- `tests/test_agent_version_store.gd`
  - AgentVersionStore 单元测试。
- `tests/test_self_play_runner.gd`
  - SelfPlayRunner 单元测试。
- `tests/test_evolution_engine.gd`
  - EvolutionEngine 单元测试。

### Modify

- `scenes/tuner/TunerRunner.gd`
  - 从 HeuristicTuner 切换到 EvolutionEngine，支持新的命令行参数。
- `tests/TestRunner.gd`
  - 注册三个新测试文件。

### Deprecate

- `scripts/ai/HeuristicTuner.gd`
  - 逻辑迁移到 EvolutionEngine 后删除。

### Reference

- `docs/superpowers/specs/2026-03-27-self-play-pipeline-design.md`
- `scripts/ai/AIBenchmarkRunner.gd` — `run_headless_duel()` 接口
- `scripts/ai/AIOpponent.gd` — `configure()`, `heuristic_weights`, `use_mcts`, `mcts_config`
- `scripts/ai/AIHeuristics.gd` — `get_default_weights()`

---

## Task 1: Add AgentVersionStore

**Files:**
- Create: `scripts/ai/AgentVersionStore.gd`
- Create: `tests/test_agent_version_store.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/test_agent_version_store.gd`:

```gdscript
class_name TestAgentVersionStore
extends TestBase

const AgentVersionStoreScript = preload("res://scripts/ai/AgentVersionStore.gd")


func _make_test_config() -> Dictionary:
	return {
		"heuristic_weights": {
			"attack_knockout": 1000.0,
			"attack_base": 500.0,
		},
		"mcts_config": {
			"branch_factor": 3,
			"rollouts_per_sequence": 20,
		},
	}


func _cleanup_test_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("ai_agents_test"):
		dir.change_dir("ai_agents_test")
		var files := dir.get_files()
		for file_name: String in files:
			dir.remove(file_name)
		dir.change_dir("..")
		dir.remove("ai_agents_test")


func test_save_and_load_roundtrip() -> String:
	_cleanup_test_dir()
	var store := AgentVersionStoreScript.new()
	store.base_dir = "user://ai_agents_test"
	var config := _make_test_config()
	var metadata := {"generation": 5, "parent_version": "", "win_rate_vs_parent": 0.583}
	var path: String = store.save_version(config, metadata)
	var loaded: Dictionary = store.load_version(path)
	_cleanup_test_dir()
	return run_checks([
		assert_true(path != "", "save_version 应返回非空路径"),
		assert_eq(loaded.get("generation"), 5, "应保留 generation"),
		assert_true(abs(float(loaded.get("win_rate_vs_parent", 0.0)) - 0.583) < 0.001, "应保留 win_rate_vs_parent"),
		assert_true(loaded.has("heuristic_weights"), "应包含 heuristic_weights"),
		assert_eq(loaded.get("heuristic_weights", {}).get("attack_knockout"), 1000.0, "权重值应完整保留"),
		assert_true(loaded.has("mcts_config"), "应包含 mcts_config"),
		assert_eq(loaded.get("mcts_config", {}).get("branch_factor"), 3, "MCTS 参数应完整保留"),
		assert_true(loaded.has("version"), "应包含 version 字段"),
		assert_true(loaded.has("timestamp"), "应包含 timestamp 字段"),
	])


func test_load_latest_returns_most_recent() -> String:
	_cleanup_test_dir()
	var store := AgentVersionStoreScript.new()
	store.base_dir = "user://ai_agents_test"
	var config_a := _make_test_config()
	store.save_version(config_a, {"generation": 1, "parent_version": "", "win_rate_vs_parent": 0.52})
	var config_b := _make_test_config()
	config_b["heuristic_weights"]["attack_knockout"] = 9999.0
	store.save_version(config_b, {"generation": 2, "parent_version": "", "win_rate_vs_parent": 0.55})
	var latest: Dictionary = store.load_latest()
	_cleanup_test_dir()
	return run_checks([
		assert_eq(latest.get("generation"), 2, "load_latest 应返回最新一代"),
		assert_eq(latest.get("heuristic_weights", {}).get("attack_knockout"), 9999.0, "应返回最新权重"),
	])


func test_list_versions_returns_sorted() -> String:
	_cleanup_test_dir()
	var store := AgentVersionStoreScript.new()
	store.base_dir = "user://ai_agents_test"
	store.save_version(_make_test_config(), {"generation": 1, "parent_version": "", "win_rate_vs_parent": 0.51})
	store.save_version(_make_test_config(), {"generation": 2, "parent_version": "", "win_rate_vs_parent": 0.53})
	store.save_version(_make_test_config(), {"generation": 3, "parent_version": "", "win_rate_vs_parent": 0.56})
	var versions: Array[Dictionary] = store.list_versions()
	_cleanup_test_dir()
	return run_checks([
		assert_eq(versions.size(), 3, "应列出 3 个版本"),
		assert_eq(versions[0].get("generation"), 1, "第一个应是最早的版本"),
		assert_eq(versions[2].get("generation"), 3, "最后一个应是最新的版本"),
	])


func test_load_latest_returns_empty_when_no_versions() -> String:
	_cleanup_test_dir()
	var store := AgentVersionStoreScript.new()
	store.base_dir = "user://ai_agents_test"
	var latest: Dictionary = store.load_latest()
	_cleanup_test_dir()
	return run_checks([
		assert_true(latest.is_empty(), "无版本时 load_latest 应返回空字典"),
	])
```

- [ ] **Step 2: Register test in TestRunner**

In `tests/TestRunner.gd`, add at the top const area (after `TestMCTSPlanner`):

```gdscript
const TestAgentVersionStore = preload("res://tests/test_agent_version_store.gd")
```

In `_ready()`, add after the MCTSPlanner line and before CardCatalogAudit:

```gdscript
_run_test_suite("AgentVersionStore", TestAgentVersionStore.new())
```

- [ ] **Step 3: Run tests to verify failure**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: AgentVersionStore tests fail because the script doesn't exist.

- [ ] **Step 4: Implement AgentVersionStore**

Create `scripts/ai/AgentVersionStore.gd`:

```gdscript
class_name AgentVersionStore
extends RefCounted

## Agent 版本持久化：将 agent config 序列化为 JSON，管理版本谱系。

var base_dir: String = "user://ai_agents"


func save_version(config: Dictionary, metadata: Dictionary) -> String:
	_ensure_dir_exists()
	var generation: int = int(metadata.get("generation", 0))
	var timestamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var version_id := "v%03d_%s" % [generation, timestamp]
	var file_name := "agent_%s.json" % version_id

	var data := {
		"version": version_id,
		"generation": generation,
		"parent_version": str(metadata.get("parent_version", "")),
		"win_rate_vs_parent": float(metadata.get("win_rate_vs_parent", 0.0)),
		"timestamp": Time.get_datetime_string_from_system(),
		"heuristic_weights": config.get("heuristic_weights", {}),
		"mcts_config": config.get("mcts_config", {}),
	}

	var full_path := base_dir.path_join(file_name)
	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		print("[AgentVersionStore] 无法写入: %s" % full_path)
		return ""
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("[AgentVersionStore] 已保存: %s" % full_path)
	return full_path


func load_version(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	return data if data is Dictionary else {}


func load_latest() -> Dictionary:
	var versions := list_versions()
	if versions.is_empty():
		return {}
	return versions[versions.size() - 1]


func list_versions() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and file_name.begins_with("agent_"):
			var full_path := base_dir.path_join(file_name)
			var data := load_version(full_path)
			if not data.is_empty():
				results.append(data)
		file_name = dir.get_next()
	dir.list_dir_end()
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("generation", 0)) < int(b.get("generation", 0))
	)
	return results


func _ensure_dir_exists() -> void:
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
```

- [ ] **Step 5: Run tests**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: All AgentVersionStore tests pass, no regressions.

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/AgentVersionStore.gd tests/test_agent_version_store.gd tests/TestRunner.gd
git commit -m "feat: add AgentVersionStore for agent config persistence"
```

---

## Task 2: Add SelfPlayRunner

**Files:**
- Create: `scripts/ai/SelfPlayRunner.gd`
- Create: `tests/test_self_play_runner.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/test_self_play_runner.gd`:

```gdscript
class_name TestSelfPlayRunner
extends TestBase

const SelfPlayRunnerScript = preload("res://scripts/ai/SelfPlayRunner.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")


func _make_default_agent_config() -> Dictionary:
	return {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
	}


func test_same_config_produces_near_even_win_rate() -> String:
	var runner := SelfPlayRunnerScript.new()
	var config := _make_default_agent_config()
	var result: Dictionary = runner.run_batch(
		config,
		config,
		[[575720, 578647]],
		[11, 29],
		200
	)
	var total: int = int(result.get("total_matches", 0))
	var a_wr: float = float(result.get("agent_a_win_rate", 0.0))
	return run_checks([
		assert_true(total > 0, "应至少完成一局对战"),
		assert_eq(total, 4, "1 组卡组对 x 2 seed x 双边 = 4 局"),
		assert_true(a_wr >= 0.0 and a_wr <= 1.0, "胜率应在 0-1 之间"),
	])


func test_result_structure_is_complete() -> String:
	var runner := SelfPlayRunnerScript.new()
	var config := _make_default_agent_config()
	var result: Dictionary = runner.run_batch(
		config,
		config,
		[[575720, 578647]],
		[11],
		200
	)
	return run_checks([
		assert_true(result.has("total_matches"), "结果应包含 total_matches"),
		assert_true(result.has("agent_a_wins"), "结果应包含 agent_a_wins"),
		assert_true(result.has("agent_b_wins"), "结果应包含 agent_b_wins"),
		assert_true(result.has("draws"), "结果应包含 draws"),
		assert_true(result.has("agent_a_win_rate"), "结果应包含 agent_a_win_rate"),
		assert_true(result.has("match_results"), "结果应包含 match_results"),
	])


func test_match_results_contain_per_match_details() -> String:
	var runner := SelfPlayRunnerScript.new()
	var config := _make_default_agent_config()
	var result: Dictionary = runner.run_batch(
		config,
		config,
		[[575720, 578647]],
		[11],
		200
	)
	var match_results: Array = result.get("match_results", [])
	if match_results.is_empty():
		return "match_results 不应为空"
	var first_match: Dictionary = match_results[0]
	return run_checks([
		assert_true(first_match.has("winner_index"), "单局结果应包含 winner_index"),
		assert_true(first_match.has("seed"), "单局结果应包含 seed"),
		assert_true(first_match.has("deck_a_id"), "单局结果应包含 deck_a_id"),
	])


func test_mcts_config_applied_when_present() -> String:
	## 只验证不崩溃——MCTS 模式下能完成对战
	var runner := SelfPlayRunnerScript.new()
	var config := {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
		"mcts_config": {
			"branch_factor": 2,
			"rollouts_per_sequence": 3,
			"rollout_max_steps": 20,
			"time_budget_ms": 1000,
		},
	}
	var result: Dictionary = runner.run_batch(
		config,
		_make_default_agent_config(),
		[[575720, 578647]],
		[11],
		200
	)
	return run_checks([
		assert_true(int(result.get("total_matches", 0)) > 0, "MCTS 模式下应能完成对战"),
	])
```

- [ ] **Step 2: Register test in TestRunner**

In `tests/TestRunner.gd`, add at the top const area (after `TestAgentVersionStore`):

```gdscript
const TestSelfPlayRunner = preload("res://tests/test_self_play_runner.gd")
```

In `_ready()`, add after the AgentVersionStore line:

```gdscript
_run_test_suite("SelfPlayRunner", TestSelfPlayRunner.new())
```

- [ ] **Step 3: Run tests to verify failure**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: SelfPlayRunner tests fail because the script doesn't exist.

- [ ] **Step 4: Implement SelfPlayRunner**

Create `scripts/ai/SelfPlayRunner.gd`:

```gdscript
class_name SelfPlayRunner
extends RefCounted

## 批量自博弈执行器。
## 接收两个 agent config，在多组卡组对上跑 N 局 headless 对战，输出结构化结果。

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")


func run_batch(
	agent_a_config: Dictionary,
	agent_b_config: Dictionary,
	deck_pairings: Array,
	seeds: Array,
	max_steps_per_match: int = 200
) -> Dictionary:
	var runner := AIBenchmarkRunnerScript.new()
	var total_matches: int = 0
	var agent_a_wins: int = 0
	var agent_b_wins: int = 0
	var draws: int = 0
	var match_results: Array[Dictionary] = []

	for pairing: Variant in deck_pairings:
		if not pairing is Array or (pairing as Array).size() < 2:
			continue
		var deck_a_id: int = int((pairing as Array)[0])
		var deck_b_id: int = int((pairing as Array)[1])
		var deck_a: DeckData = CardDatabase.get_deck(deck_a_id)
		var deck_b: DeckData = CardDatabase.get_deck(deck_b_id)
		if deck_a == null or deck_b == null:
			print("[SelfPlay] 跳过无法加载的卡组对: %d vs %d" % [deck_a_id, deck_b_id])
			continue

		for seed_value: Variant in seeds:
			var sv: int = int(seed_value)
			## agent_a 做 player 0
			var result_a0 := _run_one_match(
				runner, agent_a_config, agent_b_config,
				deck_a, deck_b, sv, max_steps_per_match
			)
			var match_entry_a0 := _build_match_entry(result_a0, sv, deck_a_id, deck_b_id, 0)
			match_results.append(match_entry_a0)
			total_matches += 1
			var winner_a0: int = int(result_a0.get("winner_index", -1))
			if winner_a0 == 0:
				agent_a_wins += 1
			elif winner_a0 == 1:
				agent_b_wins += 1
			else:
				draws += 1

			## agent_a 做 player 1
			var result_a1 := _run_one_match(
				runner, agent_b_config, agent_a_config,
				deck_a, deck_b, sv + 10000, max_steps_per_match
			)
			var match_entry_a1 := _build_match_entry(result_a1, sv + 10000, deck_a_id, deck_b_id, 1)
			match_results.append(match_entry_a1)
			total_matches += 1
			var winner_a1: int = int(result_a1.get("winner_index", -1))
			if winner_a1 == 1:
				agent_a_wins += 1
			elif winner_a1 == 0:
				agent_b_wins += 1
			else:
				draws += 1

	var win_rate: float = 0.0 if total_matches == 0 else float(agent_a_wins) / float(total_matches)
	return {
		"total_matches": total_matches,
		"agent_a_wins": agent_a_wins,
		"agent_b_wins": agent_b_wins,
		"draws": draws,
		"agent_a_win_rate": win_rate,
		"match_results": match_results,
	}


func _run_one_match(
	runner: AIBenchmarkRunner,
	p0_config: Dictionary,
	p1_config: Dictionary,
	deck_a: DeckData,
	deck_b: DeckData,
	seed_value: int,
	max_steps: int,
) -> Dictionary:
	var p0_ai := _make_agent(0, p0_config)
	var p1_ai := _make_agent(1, p1_config)

	var gsm := GameStateMachine.new()
	_apply_seed(gsm, seed_value)
	_set_forced_shuffle_seed(seed_value)
	gsm.start_game(deck_a, deck_b, 0)

	var result: Dictionary = runner.run_headless_duel(p0_ai, p1_ai, gsm, max_steps)
	_clear_forced_shuffle_seed()
	return result


func _make_agent(player_index: int, config: Dictionary) -> AIOpponent:
	var agent := AIOpponentScript.new()
	agent.configure(player_index, 1)
	var weights: Variant = config.get("heuristic_weights", {})
	if weights is Dictionary and not (weights as Dictionary).is_empty():
		agent.heuristic_weights = (weights as Dictionary).duplicate(true)
	var mcts: Variant = config.get("mcts_config", {})
	if mcts is Dictionary and not (mcts as Dictionary).is_empty():
		agent.use_mcts = true
		agent.mcts_config = (mcts as Dictionary).duplicate(true)
	return agent


func _build_match_entry(result: Dictionary, seed_value: int, deck_a_id: int, deck_b_id: int, agent_a_player_index: int) -> Dictionary:
	return {
		"winner_index": int(result.get("winner_index", -1)),
		"turn_count": int(result.get("turn_count", 0)),
		"steps": int(result.get("steps", 0)),
		"seed": seed_value,
		"deck_a_id": deck_a_id,
		"deck_b_id": deck_b_id,
		"agent_a_player_index": agent_a_player_index,
		"failure_reason": str(result.get("failure_reason", "")),
		"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
		"stalled": bool(result.get("stalled", false)),
	}


func _apply_seed(gsm: GameStateMachine, seed_value: int) -> void:
	if gsm == null or gsm.coin_flipper == null:
		return
	var rng: Variant = gsm.coin_flipper.get("_rng")
	if rng is RandomNumberGenerator:
		(rng as RandomNumberGenerator).seed = seed_value


func _set_forced_shuffle_seed(seed_value: int) -> void:
	var ps := PlayerState.new()
	if ps.has_method("set_forced_shuffle_seed"):
		ps.call("set_forced_shuffle_seed", seed_value)


func _clear_forced_shuffle_seed() -> void:
	var ps := PlayerState.new()
	if ps.has_method("clear_forced_shuffle_seed"):
		ps.call("clear_forced_shuffle_seed")
```

- [ ] **Step 5: Run tests**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 90 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: All SelfPlayRunner tests pass. Note: these tests run real headless duels and may take 10-30 seconds.

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/SelfPlayRunner.gd tests/test_self_play_runner.gd tests/TestRunner.gd
git commit -m "feat: add SelfPlayRunner for batch self-play duels"
```

---

## Task 3: Add EvolutionEngine

**Files:**
- Create: `scripts/ai/EvolutionEngine.gd`
- Create: `tests/test_evolution_engine.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/test_evolution_engine.gd`:

```gdscript
class_name TestEvolutionEngine
extends TestBase

const EvolutionEngineScript = preload("res://scripts/ai/EvolutionEngine.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")


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
```

- [ ] **Step 2: Register test in TestRunner**

In `tests/TestRunner.gd`, add at the top const area (after `TestSelfPlayRunner`):

```gdscript
const TestEvolutionEngine = preload("res://tests/test_evolution_engine.gd")
```

In `_ready()`, add after the SelfPlayRunner line:

```gdscript
_run_test_suite("EvolutionEngine", TestEvolutionEngine.new())
```

- [ ] **Step 3: Run tests to verify failure**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: EvolutionEngine tests fail because the script doesn't exist.

- [ ] **Step 4: Implement EvolutionEngine**

Create `scripts/ai/EvolutionEngine.gd`:

```gdscript
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
		var result: Dictionary = _runner.run_batch(
			mutant_config,
			current_best,
			deck_pairings,
			seed_set,
			max_steps_per_match,
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
```

- [ ] **Step 5: Run tests**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: All EvolutionEngine tests pass, no regressions.

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/EvolutionEngine.gd tests/test_evolution_engine.gd tests/TestRunner.gd
git commit -m "feat: add EvolutionEngine for self-play weight+MCTS tuning"
```

---

## Task 4: Update TunerRunner to Use EvolutionEngine

**Files:**
- Modify: `scenes/tuner/TunerRunner.gd`

- [ ] **Step 1: Rewrite TunerRunner.gd**

Replace the entire content of `scenes/tuner/TunerRunner.gd`:

```gdscript
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
extends Control

const EvolutionEngineScript = preload("res://scripts/ai/EvolutionEngine.gd")


func _ready() -> void:
	print("===== Self-Play Evolution Runner =====")

	var engine := EvolutionEngineScript.new()
	var from_latest: bool = false

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
```

- [ ] **Step 2: Run full test suite**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 90 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: No regressions. TunerRunner.tscn still loads without errors.

- [ ] **Step 3: Commit**

```bash
git add scenes/tuner/TunerRunner.gd
git commit -m "feat: upgrade TunerRunner to use EvolutionEngine"
```

---

## Task 5: End-to-End Verification and HeuristicTuner Cleanup

**Files:**
- Delete: `scripts/ai/HeuristicTuner.gd`

- [ ] **Step 1: Run a 2-generation smoke test**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 300 --path "D:/ai/code/ptcgtrain" "res://scenes/tuner/TunerRunner.tscn" -- --generations=2 2>&1 | tail -30
```

Expected output should include:
- `[Evolution] 启动进化: 2 代`
- Two generation results (accept/reject)
- `[Evolution] 完成!`
- Final weights JSON printed

If it fails, debug and fix before continuing.

- [ ] **Step 2: Delete HeuristicTuner.gd**

Remove the deprecated file:

```bash
git rm scripts/ai/HeuristicTuner.gd
```

Also remove the `.uid` file if present:

```bash
rm -f scripts/ai/HeuristicTuner.gd.uid 2>/dev/null
```

- [ ] **Step 3: Verify no remaining references to HeuristicTuner**

Search the codebase for any remaining references:

```bash
grep -r "HeuristicTuner" scripts/ tests/ scenes/ --include="*.gd" --include="*.tscn"
```

Expected: No results (TunerRunner.gd was already updated in Task 4).

- [ ] **Step 4: Run full test suite**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 90 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: All tests pass, no regressions.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove deprecated HeuristicTuner, replaced by EvolutionEngine"
```

---

## Execution Notes

- SelfPlayRunner 测试会跑真实 headless 对局，需要 CardDatabase 已加载（项目 autoload）。quit-after 至少 90 秒。
- EvolutionEngine 的单元测试只测突变和 sigma 逻辑，不跑对局（快速）。端到端测试在 Task 5 的 smoke test 中覆盖。
- AgentVersionStore 使用 `user://ai_agents_test` 做测试，测试后自动清理。
- TunerRunner 场景和 .tscn 文件已存在，只需更新 .gd 脚本。
- MCTS config 如果 agent config 中没有 `mcts_config` 字段，SelfPlayRunner 会用纯 heuristic 模式（更快）。

## Suggested Commit Sequence

1. `feat: add AgentVersionStore for agent config persistence`
2. `feat: add SelfPlayRunner for batch self-play duels`
3. `feat: add EvolutionEngine for self-play weight+MCTS tuning`
4. `feat: upgrade TunerRunner to use EvolutionEngine`
5. `chore: remove deprecated HeuristicTuner, replaced by EvolutionEngine`
