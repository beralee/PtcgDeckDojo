# AI Deck Entry And Low-Winrate Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fixed AI strategy selection in battle setup with AI deck-driven strategy resolution, then re-review and improve every bundled deck at or below 30% win rate versus Miraidon.

**Architecture:** The setup UI will stop selecting hardcoded strategy labels and instead select an AI deck. Runtime AI construction will resolve the deck’s unified strategy through the central registry path and inject it via `AIOpponent.set_deck_strategy()`. Low-performing decks will be reworked in parallel by deck-specific workers, while shared integration, benchmark harnesses, and final validation stay on the main thread.

**Tech Stack:** Godot 4 GDScript, unified `DeckStrategyBase` framework, `DeckStrategyRegistry`, `BattleSetup` / `BattleScene`, bundled deck JSON fixtures, headless benchmark tooling, `gpt-5.4` workers with `high` reasoning.

---

### Task 1: Add Setup-Flow Regression Tests For Deck-Driven AI Entry

**Files:**
- Modify: `tests/test_battle_setup_ai_versions.gd`
- Modify: `tests/test_ai_strategy_wiring.gd`
- Modify: `tests/TestSuiteCatalog.gd`
- Read: `scenes/battle_setup/BattleSetup.gd`
- Read: `scenes/battle/BattleScene.gd`
- Read: `scripts/ai/DeckStrategyRegistry.gd`

- [ ] **Step 1: Write a failing battle-setup test that expects VS-AI mode to use the selected AI deck instead of a fixed strategy label.**
- [ ] **Step 2: Write a failing battle-scene wiring test that expects the selected AI deck to resolve through a registry-owned deck-resolution API instead of a deck-id side table.**
- [ ] **Step 3: Write failing setup-version tests for incompatible or missing version payload fallback and for legacy `ai_strategy` state migration.**
- [ ] **Step 4: Run the focused setup/wiring suites and confirm they fail for the right reason before implementation.**
- [ ] **Step 5: Add the new/updated test suites to the AI/training catalog if they are not already included.**

### Task 2: Replace Fixed AI Strategy UI With Deck-Driven Setup

**Files:**
- Modify: `scenes/battle_setup/BattleSetup.gd`
- Modify: `scenes/battle_setup/BattleSetup.tscn`
- Modify: `scripts/autoload/GameManager.gd`
- Modify: `scripts/ai/AIVersionRegistry.gd`

- [ ] **Step 1: Remove or hide the fixed `AIStrategyOption` flow from setup state management.**
- [ ] **Step 2: Make VS-AI mode treat the second selected deck as the AI deck without writing new fixed strategy labels.**
- [ ] **Step 3: Add version compatibility metadata or filtering support so setup only offers versions valid for the selected AI deck’s resolved strategy.**
- [ ] **Step 4: Keep AI source/version selection intact while decoupling it from the old strategy dropdown.**
- [ ] **Step 5: Update saved setup state and return-context handling so deck-driven AI selection survives scene round-trips and legacy `ai_strategy` values are ignored or migrated safely.**
- [ ] **Step 6: Re-run the focused setup tests and keep them green.**

### Task 3: Refactor BattleScene Default AI Construction To Resolve By Deck

**Files:**
- Modify: `scenes/battle/BattleScene.gd`
- Modify: `scripts/ai/DeckStrategyRegistry.gd`
- Read: `scripts/ai/AIOpponent.gd`

- [ ] **Step 1: Write a failing wiring assertion if battle-scene AI construction still depends on `GameManager.ai_deck_strategy` for default deck selection.**
- [ ] **Step 2: Add one registry-owned helper that resolves a selected `DeckData` into the correct unified strategy instance using deck contents/signatures.**
- [ ] **Step 3: Make `_build_default_ai_opponent()` inject the resolved strategy through `set_deck_strategy()`.**
- [ ] **Step 4: Add explicit fallback behavior for unresolved deck ids so runtime defaults to generic AI with a visible warning.**
- [ ] **Step 5: Preserve versioned weights/value nets layered from `GameManager.ai_selection`, but reject incompatible version payloads and fall back to the selected deck’s default rule strategy when assets are missing or incompatible.**
- [ ] **Step 6: Run setup/wiring/focused strategy suites and fix regressions.**

### Task 4: Align Benchmark And Quick-Matchup Entry Points With Deck-Driven Resolution

**Files:**
- Modify: `scripts/training/quick_matchup_test.gd`
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Modify: `tests/AITrainingTestRunner.gd`
- Modify: `tests/AITrainingRunnerScene.gd`
- Modify: `tests/test_ai_training_test_runner.gd`
- Modify: the shared registry/helper from Task 3 if extraction is required

- [ ] **Step 1: Add a failing test or smoke assertion for any benchmark entry point that still bypasses deck-driven strategy resolution.**
- [ ] **Step 2: Make `AIBenchmarkRunner`, `AITrainingTestRunner`, and `quick_matchup_test` call the exact same registry-owned resolution helper used by live battle.**
- [ ] **Step 3: Extend the runner only as far as needed for repeated per-deck Miraidon validation while keeping `--suite=...` mode unchanged.**
- [ ] **Step 4: Re-run the runner’s focused tests, one matchup-sweep smoke command, and one quick-matchup smoke command.**

### Task 5: Fix Happiness / Action-Cap Anomaly Before Worker Rollout

**Files:**
- Modify: `scripts/ai/DeckStrategyBlisseyTank.gd`
- Modify: `scripts/ai/AILegalActionBuilder.gd` or `scripts/ai/AIStepResolver.gd` only if the investigation proves the bug lives there
- Modify/Create: dedicated regression under `tests/test_blissey_tank_strategy.gd` or a new headless test

- [ ] **Step 1: Reproduce the `action_cap_reached` behavior with a failing focused or headless regression test.**
- [ ] **Step 2: Identify whether the cap issue is caused by repeated low-value actions, missing end-turn preference, or unresolved prompt flow.**
- [ ] **Step 3: Implement the narrowest fix that eliminates the action-cap loop.**
- [ ] **Step 4: Re-run the deck’s focused suite and a small matchup sample to confirm the anomaly is gone.**
- [ ] **Step 5: If the root cause is in shared files, keep the fix on the main thread and do not delegate it to deck workers.**

### Task 6: Build The Low-Winrate Rework Queue And Worker Briefs

**Files:**
- Read: `data/bundled_user/decks/*.json`
- Read: `scripts/ai/DeckStrategyMiraidon.gd`
- Read: the current low-winrate `DeckStrategy*.gd` files
- Optional notes: `docs/superpowers/specs/2026-04-11-ai-deck-entry-and-low-winrate-rework-design.md`

- [ ] **Step 1: Split the 15 low-winrate decks into worker-sized batches with disjoint write sets.**
- [ ] **Step 2: Prepare a per-worker brief requiring decklist review, key card-effect review, current strategy review, Miraidon study, and explicit analysis of engine pieces, attackers, closers, tempo cards, and dead-phase cards.**
- [ ] **Step 3: Exclude `581614` from worker ownership until the main-thread anomaly task is clean.**
- [ ] **Step 4: Launch workers with model `gpt-5.4` and reasoning `high`.**

### Task 7: Rework Deck Strategies In Parallel

**Files:**
- Modify: deck-specific `scripts/ai/DeckStrategy*.gd`
- Modify/Create: matching focused tests under `tests/test_*strategy*.gd`
- Create/Modify: deck-specific headless regression tests when prompts or benchmark-owned interactions are involved

- [ ] **Step 1: For each assigned deck, write or extend a failing focused test for the weakest matchup behavior.**
- [ ] **Step 2: Run the deck’s focused test and confirm it fails before changing the strategy.**
- [ ] **Step 3: Update opening setup, search priorities, energy routing, attack choice, and board evaluation based on actual card text and matchup study.**
- [ ] **Step 4: Add or refine `score_interaction_target()` coverage where target choice is the bottleneck.**
- [ ] **Step 5: Add mandatory headless/prompt regression coverage if the deck relies on prompt-owned choices or previously showed benchmark anomalies.**
- [ ] **Step 6: Re-run the focused suite until green.**
- [ ] **Step 7: Run a small per-deck Miraidon sample before declaring the deck batch complete.**

### Task 8: Integrate Worker Results On The Main Thread

**Files:**
- Modify: shared registry/helpers only if worker results require central updates
- Read: all changed deck strategy files and their focused tests

- [ ] **Step 1: Review each worker patch for contract compliance and shared-architecture violations.**
- [ ] **Step 2: Reject any worker changes that introduce direct `_deck_strategy` shortcuts or deck-specific UI-only paths.**
- [ ] **Step 3: Merge worker results into the shared branch without overwriting unrelated changes.**
- [ ] **Step 4: Re-run shared contract and wiring suites after each integration batch.**
- [ ] **Step 5: After `581614` anomaly cleanup is green, explicitly queue its normal second-pass strategy review and validation before final acceptance.**

### Task 9: Run Post-Rework Miraidon Validation

**Files:**
- Read: `tests/AITrainingRunnerScene.gd`
- Output: `user://` matchup JSON artifacts

- [ ] **Step 1: Run small per-deck Miraidon samples for newly revised decks to catch obvious regressions quickly.**
- [ ] **Step 2: Run the full low-winrate sweep versus Miraidon again with clean JSON output.**
- [ ] **Step 3: Review failure reasons, not just win rate, and flag any remaining `unsupported_prompt`, `unsupported_interaction_step`, or `action_cap_reached`.**
- [ ] **Step 4: Re-run mandatory deck-specific prompt/headless regressions for any deck still showing anomalies.**
- [ ] **Step 5: Summarize which decks improved, which remain weak but clean, and which still need follow-up.**

### Task 10: Perform Roster-Level Acceptance Review

**Files:**
- Read: `docs/superpowers/specs/2026-04-11-ai-deck-entry-and-low-winrate-rework-design.md`
- Read: final matchup JSON artifacts
- Read: all focused suites touched during the rework

- [ ] **Step 1: Check that all 15 in-scope low-winrate decks were assigned, reworked, and validated.**
- [ ] **Step 2: Check that `581614` completed both anomaly cleanup and normal second-pass strategy review.**
- [ ] **Step 3: Mark any remaining anomalous deck as explicitly blocked instead of silently counting it as complete.**
- [ ] **Step 4: Record the final roster status as cleared or blocked deck-by-deck.**

### Parallelization Rules

- Worker model: `gpt-5.4`
- Worker reasoning effort: `high`
- Workers may edit only:
  - their assigned `DeckStrategy*.gd`
  - their assigned focused test file(s)
  - one deck-specific headless regression test if required by that deck
- Main thread owns:
  - `scenes/battle_setup/BattleSetup.gd`
  - `scenes/battle_setup/BattleSetup.tscn`
  - `scenes/battle/BattleScene.gd`
  - `scripts/autoload/GameManager.gd`
  - `scripts/ai/DeckStrategyRegistry.gd`
  - `scripts/training/quick_matchup_test.gd`
  - shared benchmark entry-point helpers
  - `tests/AITrainingTestRunner.gd`
  - `tests/AITrainingRunnerScene.gd`
  - shared test catalog and shared wiring tests

### Verification Commands

- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=BattleSetupAIVersions,AIStrategyWiring,AITrainingTestRunner`
- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain -s res://tests/AITrainingTestRunner.gd -- --suite=MiraidonStrategy,VSTAREngineStrategies`
- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain --quit-after 9999 res://scripts/training/quick_matchup_test.tscn`
- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain -s res://tests/AITrainingTestRunner.gd -- --matchup-anchor-deck=575720 --exclude-decks=575720,578647 --games-per-matchup=10 --max-steps=200 --json-output=user://matchup_sweep_vs_miraidon_post_rework.json`
