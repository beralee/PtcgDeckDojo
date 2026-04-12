# Shared AI Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the shared AI stack, preserve a frozen Miraidon baseline, and add regression coverage so shared-layer improvements can raise weaker decks without silently degrading current Miraidon behavior.

**Architecture:** Keep deck-specific strategies intact and concentrate this work in the shared decision stack: `AIHeuristics`, `AIActionFeatureEncoder`, `AILegalActionBuilder`, `AIInteractionPlanner`, `AIStepResolver`, and `AIOpponent`. Add a read-only Miraidon baseline strategy copy plus focused tests and direct benchmark coverage for both weak-deck improvement and Miraidon regression protection.

**Tech Stack:** Godot 4 GDScript, unified `DeckStrategyBase` architecture, headless `AITrainingTestRunner`, existing AI benchmark runners, focused strategy suites.

---

### Task 1: Add Miraidon Baseline Backup And Safety Tests

**Files:**
- Create: `scripts/ai/DeckStrategyMiraidonBaseline.gd`
- Modify: `tests/test_miraidon_strategy.gd`
- Read: `scripts/ai/DeckStrategyMiraidon.gd`, `scripts/ai/DeckStrategyRegistry.gd`

- [ ] **Step 1: Add a failing test that expects a dedicated baseline Miraidon strategy file to load and expose the same strategy contract methods as the live Miraidon strategy.**
- [ ] **Step 2: Add a failing test that ensures the production registry still resolves the live Miraidon strategy, not the baseline copy.**
- [ ] **Step 3: Run the focused Miraidon suite and verify the new assertions fail for the right reason before implementation.**
- [ ] **Step 4: Create `DeckStrategyMiraidonBaseline.gd` as a frozen copy of the current live implementation.**
- [ ] **Step 5: Re-run the focused Miraidon suite and verify the baseline safety tests pass.**

### Task 2: Expand Shared Feature Extraction

**Files:**
- Modify: `scripts/ai/AIActionFeatureEncoder.gd`
- Modify: `scripts/ai/AIFeatureExtractor.gd`
- Modify: `tests/test_ai_strategy_wiring.gd`

- [ ] **Step 1: Add failing tests for shared features that distinguish active readiness, bench readiness, search productivity, churn risk, and deck-out pressure.**
- [ ] **Step 2: Run the focused shared wiring tests and confirm the new assertions fail before implementation.**
- [ ] **Step 3: Extend `AIActionFeatureEncoder` to compute the new readiness and churn-aware fields with minimal logic.**
- [ ] **Step 4: Keep `AIFeatureExtractor` as a thin wrapper over the richer encoder output.**
- [ ] **Step 5: Re-run the focused suite and verify all new feature tests pass.**

### Task 3: Generalize Shared Attach And Tool Authority

**Files:**
- Modify: `scripts/ai/AIHeuristics.gd`
- Modify: `tests/test_ai_strategy_wiring.gd`

- [ ] **Step 1: Add a failing test that injects a non-Miraidon, non-Gardevoir strategy and proves shared attach/tool bonuses no longer override the strategy’s intent.**
- [ ] **Step 2: Run the focused suite and verify the test fails before implementation.**
- [ ] **Step 3: Change `AIHeuristics` so any injected strategy can fully control attach and tool scoring in fallback mode.**
- [ ] **Step 4: Keep existing deck-bias fallbacks only for cases where no injected strategy exists.**
- [ ] **Step 5: Re-run focused shared tests and `MiraidonStrategy` to confirm the generalization does not break current strong decks.**

### Task 4: Improve Headless Search, Assignment, And Counter Fallbacks

**Files:**
- Modify: `scripts/ai/AILegalActionBuilder.gd`
- Modify: `scripts/ai/AIInteractionPlanner.gd`
- Modify: `scripts/ai/AIStepResolver.gd`
- Modify: `tests/test_ai_interaction_planner.gd`
- Modify: `tests/test_charizard_strategy.gd`
- Modify: `tests/test_future_ancient_strategies.gd`

- [ ] **Step 1: Add failing tests for generic headless search fallback quality when strategy coverage is partial.**
- [ ] **Step 2: Add a failing test for counter/distribution fallback so it no longer always dumps all counters on a single legal target.**
- [ ] **Step 3: Run the relevant focused suites and confirm the tests fail before implementation.**
- [ ] **Step 4: Replace first-item and legacy fixed-name fallbacks with plan-aware generic scoring for search and assignment steps.**
- [ ] **Step 5: Update counter/distribution resolution so it can choose smarter target distributions under generic fallback.**
- [ ] **Step 6: Re-run interaction and deck-focused suites to verify search and assignment behavior stays coherent.**

### Task 5: Add Light Combo-Aware Greedy Turn Selection

**Files:**
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `tests/test_ai_baseline.gd`
- Modify: `tests/test_ai_strategy_wiring.gd`

- [ ] **Step 1: Add a failing test that demonstrates single-step absolute scoring incorrectly misses a short setup combo line.**
- [ ] **Step 2: Run the focused suite and confirm the new test fails before implementation.**
- [ ] **Step 3: Add a bounded combo-aware greedy helper that can evaluate short enabling sequences before defaulting to single-step choice.**
- [ ] **Step 4: Keep the implementation deterministic and small; do not replace the current MCTS path.**
- [ ] **Step 5: Re-run focused suites and confirm the combo-aware path now prefers the enabling line.**

### Task 6: Add Miraidon Baseline Benchmark Coverage

**Files:**
- Modify: `tests/AITrainingTestRunner.gd`
- Modify: `tests/test_ai_training_test_runner.gd`
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Read: `scripts/ai/DeckBenchmarkCase.gd`, `scenes/tuner/BenchmarkRunner.gd`

- [ ] **Step 1: Add a failing test that expects a benchmark path to run live Miraidon versus Miraidon baseline explicitly.**
- [ ] **Step 2: Run the runner-focused suite and confirm the new benchmark-mode assertion fails before implementation.**
- [ ] **Step 3: Implement the Miraidon-vs-baseline benchmark path using separate strategy selection without changing normal registry resolution.**
- [ ] **Step 4: Re-run runner-focused tests and confirm the new benchmark path is available.**

### Task 7: Run Safety Suites And Fresh Benchmarks

**Files:**
- Read: `tests/AITrainingTestRunner.gd`
- Output: `user://miraidon_vs_charizard100_shared_hardened_2026-04-11.json`
- Output: `user://miraidon_vs_ragingbolt100_shared_hardened_2026-04-11.json`
- Output: `user://miraidon_vs_miraidon_baseline100_shared_hardened_2026-04-11.json`

- [ ] **Step 1: Run focused suites for Miraidon, Gardevoir, AI wiring, AI interaction, Charizard, Future/Ancient, and runner coverage.**
- [ ] **Step 2: Run a fresh 100-game Miraidon vs Charizard benchmark and compare it to the `30%` post-iteration baseline.**
- [ ] **Step 3: Run a fresh 100-game Miraidon vs Raging Bolt benchmark and compare it to the `6%` post-iteration baseline.**
- [ ] **Step 4: Run a fresh 100-game live Miraidon vs Miraidon baseline benchmark and confirm the result is clean.**
- [ ] **Step 5: Summarize improvements, remaining gaps, and any sign that live Miraidon regressed against its frozen baseline.**

### Verification Commands

- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain -s res://tests/AITrainingTestRunner.gd -- --suite=MiraidonStrategy,AIStrategyWiring,AIInteractionPlanner,CharizardStrategy,FutureAncientStrategies,AITrainingTestRunner`
- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain -s res://tests/AITrainingTestRunner.gd -- --matchup-anchor-deck=575720 --deck-ids=575716 --games-per-matchup=100 --max-steps=200 --json-output=user://miraidon_vs_charizard100_shared_hardened_2026-04-11.json`
- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain -s res://tests/AITrainingTestRunner.gd -- --matchup-anchor-deck=575720 --deck-ids=575718 --games-per-matchup=100 --max-steps=200 --json-output=user://miraidon_vs_ragingbolt100_shared_hardened_2026-04-11.json`
- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain -s res://tests/AITrainingTestRunner.gd -- --mode=miraidon_baseline_regression --games-per-matchup=100 --max-steps=200 --json-output=user://miraidon_vs_miraidon_baseline100_shared_hardened_2026-04-11.json`
