# Multi-Deck Strategy Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add unified rule-based deck strategies for every bundled deck family beyond Gardevoir and Miraidon, and wire registry detection so bundled decks no longer fall back to generic play.

**Architecture:** Implement one strategy per archetype family instead of one strategy per deck id. Keep shared integration on the main thread, while independent family strategies and their focused tests are implemented in parallel with disjoint write sets. All runtime wiring must continue to flow through `DeckStrategyRegistry` and `AIOpponent.set_deck_strategy()`.

**Tech Stack:** Godot 4 GDScript, existing AI strategy framework, bundled deck JSON fixtures, focused Godot test suites.

---

### Task 1: Add Registry Expansion Test Harness

**Files:**
- Create: `tests/test_deck_strategy_registry_expansion.gd`
- Modify: `tests/TestSuiteCatalog.gd`
- Read: `scripts/ai/DeckStrategyRegistry.gd`

- [ ] **Step 1: Write failing tests for bundled deck family resolution**
- [ ] **Step 2: Run the new focused suite and confirm missing strategy ids fail**
- [ ] **Step 3: Add helper fixtures for minimal family detection boards**
- [ ] **Step 4: Re-run the focused suite and keep it red until registry support lands**

### Task 2: Implement Stage-2 Fire / Dragon Families

**Files:**
- Create: `scripts/ai/DeckStrategyCharizardEx.gd`
- Create: `scripts/ai/DeckStrategyDragapultDusknoir.gd`
- Create: `scripts/ai/DeckStrategyDragapultBanette.gd`
- Create: `scripts/ai/DeckStrategyDragapultCharizard.gd`
- Create: `tests/test_charizard_strategy.gd`
- Create: `tests/test_dragapult_strategy.gd`

- [ ] **Step 1: Write failing tests for Charizard and Dragapult family action priorities**
- [ ] **Step 2: Run only those tests and confirm the generic strategy path fails expectations**
- [ ] **Step 3: Implement minimal strategy classes extending `DeckStrategyBase`**
- [ ] **Step 4: Add setup, evolution, attack, and target-scoring behavior until tests pass**
- [ ] **Step 5: Re-run the family suites and keep output green**

### Task 3: Implement VSTAR Engine Families

**Files:**
- Create: `scripts/ai/DeckStrategyRegidrago.gd`
- Create: `scripts/ai/DeckStrategyLugiaArcheops.gd`
- Create: `scripts/ai/DeckStrategyDialgaMetang.gd`
- Create: `scripts/ai/DeckStrategyArceusGiratina.gd`
- Create: `tests/test_vstar_engine_strategies.gd`

- [ ] **Step 1: Write failing tests covering opening plan and high-value setup actions for each VSTAR family**
- [ ] **Step 2: Run the focused suite and confirm all expectations fail before implementation**
- [ ] **Step 3: Implement the minimal family strategy classes**
- [ ] **Step 4: Add discard, search, and attack-choice scoring until tests pass**
- [ ] **Step 5: Re-run the focused suite and verify green**

### Task 4: Implement Water / Lost-Zone Families

**Files:**
- Create: `scripts/ai/DeckStrategyPalkiaGholdengo.gd`
- Create: `scripts/ai/DeckStrategyPalkiaDusknoir.gd`
- Create: `scripts/ai/DeckStrategyLostBox.gd`
- Create: `tests/test_water_lost_strategies.gd`

- [ ] **Step 1: Write failing tests for water setup, lost-zone progress, and special interaction priorities**
- [ ] **Step 2: Run the focused suite and confirm the failures are real**
- [ ] **Step 3: Implement the minimal family strategy classes**
- [ ] **Step 4: Add board evaluation and interaction scoring until tests pass**
- [ ] **Step 5: Re-run the focused suite and verify green**

### Task 5: Implement Future / Ancient Tempo Families

**Files:**
- Create: `scripts/ai/DeckStrategyFutureBox.gd`
- Create: `scripts/ai/DeckStrategyIronThorns.gd`
- Create: `scripts/ai/DeckStrategyRagingBoltOgerpon.gd`
- Create: `scripts/ai/DeckStrategyGougingFireAncient.gd`
- Create: `tests/test_future_ancient_strategies.gd`

- [ ] **Step 1: Write failing tests for generator / Sada / lock / capsule priorities**
- [ ] **Step 2: Run the focused suite and confirm the new expectations fail**
- [ ] **Step 3: Implement the minimal family strategy classes**
- [ ] **Step 4: Add aggressive tempo and disruption scoring until tests pass**
- [ ] **Step 5: Re-run the focused suite and verify green**

### Task 6: Implement Tank / Utility Family

**Files:**
- Create: `scripts/ai/DeckStrategyBlisseyTank.gd`
- Create: `tests/test_blissey_tank_strategy.gd`

- [ ] **Step 1: Write failing tests for Chansey setup, tank routing, and damage-move support priorities**
- [ ] **Step 2: Run the focused suite and confirm failures**
- [ ] **Step 3: Implement the minimal strategy class**
- [ ] **Step 4: Add setup, action, and target scoring until tests pass**
- [ ] **Step 5: Re-run the suite and verify green**

### Task 7: Integrate Registry And Shared Wiring

**Files:**
- Modify: `scripts/ai/DeckStrategyRegistry.gd`
- Modify: `tests/test_deck_strategy_contract.gd`
- Modify: `tests/test_ai_strategy_wiring.gd`
- Modify: `tests/test_deck_strategy_registry_expansion.gd`

- [ ] **Step 1: Add new strategy preloads and registry ids**
- [ ] **Step 2: Add deterministic detection ordering so overlapping shells resolve correctly**
- [ ] **Step 3: Extend contract and wiring tests to include a representative sample of the new families**
- [ ] **Step 4: Run focused registry / contract / wiring suites and fix ordering conflicts**

### Task 8: Verify End-To-End Focused Coverage

**Files:**
- Read: `tests/test_deck_strategy_contract.gd`
- Read: `tests/test_ai_strategy_wiring.gd`
- Read: `tests/test_deck_strategy_registry_expansion.gd`
- Read: all new family suites

- [ ] **Step 1: Run all newly added strategy suites**
- [ ] **Step 2: Run existing shared strategy suites to catch regressions**
- [ ] **Step 3: Fix failures without widening scope**
- [ ] **Step 4: Summarize coverage gaps that still remain for future benchmark work**

### Parallelization Rules

- Parallel workers may edit only their assigned strategy files and the assigned new test file for that family.
- The main thread owns shared files:
  - `scripts/ai/DeckStrategyRegistry.gd`
  - `tests/TestSuiteCatalog.gd`
  - `tests/test_deck_strategy_contract.gd`
  - `tests/test_ai_strategy_wiring.gd`
  - `tests/test_deck_strategy_registry_expansion.gd`
- Worker model: `gpt-5.4`
- Worker reasoning effort: `high`

### Verification Commands

- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn --test-suite=test_deck_strategy_registry_expansion.gd`
- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn --test-suite=test_deck_strategy_contract.gd`
- `D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn --test-suite=test_ai_strategy_wiring.gd`
- Run each new focused family suite after implementation
