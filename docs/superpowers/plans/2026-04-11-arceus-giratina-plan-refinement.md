# Arceus Giratina Plan Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `DeckStrategyArceusGiratina` follow a clearer generic game plan built around Arceus launch, Giratina transition, and endgame conversion, then validate it with focused tests and a fresh 100-game Miraidon benchmark.

**Architecture:** Keep the unified strategy contract unchanged and concentrate all behavior changes inside `DeckStrategyArceusGiratina.gd`. Add focused regression coverage in the existing VSTAR strategy suite so opening, transition, and conversion behavior are tested directly before the benchmark rerun.

**Tech Stack:** Godot 4 GDScript, `DeckStrategyBase`, `DeckStrategyArceusGiratina`, existing VSTAR strategy tests, headless `AITrainingTestRunner`.

---

### Task 1: Add Failing Opening And Transition Tests

**Files:**
- Modify: `tests/test_vstar_engine_strategies.gd`
- Read: `scripts/ai/DeckStrategyArceusGiratina.gd`

- [ ] **Step 1: Write a failing test that expects launch-critical search or attachment choices to prioritize Arceus setup over support development.**
- [ ] **Step 2: Write a failing test that expects ordinary energy or assignment choices to shift toward Giratina after Arceus launch is effectively online.**
- [ ] **Step 3: Write a failing test that expects endgame search or attack value to favor Giratina conversion once the launch lane has already done its job.**
- [ ] **Step 4: Run `VSTAREngineStrategies` and confirm the new assertions fail for the right reason before implementation.**

### Task 2: Refine Internal Phase Modeling

**Files:**
- Modify: `scripts/ai/DeckStrategyArceusGiratina.gd`
- Test: `tests/test_vstar_engine_strategies.gd`

- [ ] **Step 1: Introduce internal helpers that identify `launch`, `transition`, and `convert` from board state, not just turn count.**
- [ ] **Step 2: Keep the helpers private to the strategy and avoid expanding the public unified strategy contract.**
- [ ] **Step 3: Re-run the focused suite and keep failures narrowed to still-unimplemented scoring logic.**

### Task 3: Tighten Launch-First Priorities

**Files:**
- Modify: `scripts/ai/DeckStrategyArceusGiratina.gd`
- Test: `tests/test_vstar_engine_strategies.gd`

- [ ] **Step 1: Update setup, trainer, and attachment scoring so Arceus launch pieces outrank support development while launch is incomplete.**
- [ ] **Step 2: Make `Starbirth`-relevant ability/search scoring explicitly close launch gaps first.**
- [ ] **Step 3: Keep support pieces viable, but secondary, while the deck still lacks its first clean Arceus attack.**
- [ ] **Step 4: Run the focused suite and verify launch tests now pass.**

### Task 4: Improve Transition And Conversion Logic

**Files:**
- Modify: `scripts/ai/DeckStrategyArceusGiratina.gd`
- Test: `tests/test_vstar_engine_strategies.gd`

- [ ] **Step 1: Reweight search, attachment, and assignment scoring so generic resources move toward Giratina once Arceus launch is complete.**
- [ ] **Step 2: Reduce unnecessary continued investment into an already-online Arceus lane.**
- [ ] **Step 3: Strengthen attack and board-evaluation scoring around Giratina finish readiness.**
- [ ] **Step 4: Re-run the focused suite and make sure all new Arceus tests pass.**

### Task 5: Run Verification And Benchmark

**Files:**
- Read: `tests/AITrainingTestRunner.gd`
- Output: `user://miraidon_vs_arceus_100_post_refine_2026-04-11.json`

- [ ] **Step 1: Run the full `VSTAREngineStrategies` suite and confirm it passes cleanly.**
- [ ] **Step 2: Run a fresh 100-game sweep of Miraidon versus Arceus Giratina.**
- [ ] **Step 3: Compare the new result with the pre-refinement 42% baseline and inspect whether the ending reasons remain clean.**
- [ ] **Step 4: Summarize both the code-level behavior improvements and the benchmark outcome without overstating the result.**

### Verification Commands

- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn -- --suite=VSTAREngineStrategies`
- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain -s res://tests/AITrainingTestRunner.gd -- --matchup-anchor-deck=575720 --deck-ids=569061 --games-per-matchup=100 --max-steps=200 --json-output=user://miraidon_vs_arceus_100_post_refine_2026-04-11.json`
