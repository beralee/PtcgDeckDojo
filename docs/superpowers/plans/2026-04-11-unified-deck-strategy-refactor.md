# Unified Deck Strategy Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify the Gardevoir and Miraidon deck-strategy architecture so all strategy-aware AI systems use one shared contract, one detection path, and one interaction-target selection flow.

**Architecture:** Add a shared strategy base, registry, and interaction planner; make `AIOpponent` the single strategy wiring hub; then migrate both deck strategies and their consumers onto the unified contract. Keep deck-specific heuristics, but route every external integration through the same interface.

**Tech Stack:** Godot 4 GDScript, existing AI systems (`AIOpponent`, `AILegalActionBuilder`, `AIStepResolver`, `AIHeuristics`, `MCTSPlanner`), focused headless test suites.

---

### Task 1: Add failing contract and registry tests

**Files:**
- Create: `tests/test_deck_strategy_contract.gd`
- Modify: `tests/TestSuiteCatalog.gd`

- [ ] **Step 1: Write the failing test**

Add tests that assert:
- Gardevoir and Miraidon both expose the unified external methods
- the shared registry resolves Gardevoir and Miraidon signature decks to the expected strategy ids

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s tests/test_deck_strategy_contract.gd`
Expected: FAIL because the shared base/registry do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `DeckStrategyBase.gd` and `DeckStrategyRegistry.gd` with just enough structure for the contract and registry detection to exist.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s tests/test_deck_strategy_contract.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/test_deck_strategy_contract.gd tests/TestSuiteCatalog.gd scripts/ai/DeckStrategyBase.gd scripts/ai/DeckStrategyRegistry.gd
git commit -m "test: add unified deck strategy contract coverage"
```

### Task 2: Add failing interaction-planner parity tests

**Files:**
- Create: `tests/test_ai_interaction_planner.gd`
- Modify: `tests/TestSuiteCatalog.gd`

- [ ] **Step 1: Write the failing test**

Add tests that assert:
- resolver-style selection and builder-style headless selection both choose the same target for the same interaction step
- Gardevoir search / discard / embrace / assignment selection can be expressed through one unified scoring interface
- Miraidon search and energy-target selection work without builder-specific hardcoding

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s tests/test_ai_interaction_planner.gd`
Expected: FAIL because the shared interaction planner does not exist and current paths are split.

- [ ] **Step 3: Write minimal implementation**

Create `AIInteractionPlanner.gd` and add only the minimal sorting/selection helpers needed to satisfy the new tests.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s tests/test_ai_interaction_planner.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/test_ai_interaction_planner.gd tests/TestSuiteCatalog.gd scripts/ai/AIInteractionPlanner.gd
git commit -m "test: cover unified AI interaction target planning"
```

### Task 3: Refactor strategies onto the shared contract

**Files:**
- Modify: `scripts/ai/DeckStrategyGardevoir.gd`
- Modify: `scripts/ai/DeckStrategyMiraidon.gd`
- Test: `tests/test_deck_strategy_contract.gd`
- Test: `tests/test_ai_interaction_planner.gd`
- Test: `tests/test_gardevoir_strategy.gd`
- Test: `tests/test_miraidon_strategy.gd`

- [ ] **Step 1: Write the next failing tests**

Extend tests to assert:
- both strategies inherit or conform to the shared contract
- Gardevoir now exposes `score_interaction_target()` for all externally needed selection cases
- legacy helper behavior is preserved where expected through the new interface

- [ ] **Step 2: Run tests to verify they fail**

Run:
- `godot --headless --path . -s tests/test_deck_strategy_contract.gd`
- `godot --headless --path . -s tests/test_ai_interaction_planner.gd`
- `godot --headless --path . -s tests/test_gardevoir_strategy.gd`
- `godot --headless --path . -s tests/test_miraidon_strategy.gd`

Expected: FAIL for missing shared methods and mismatched interaction behavior.

- [ ] **Step 3: Write minimal implementation**

Update both strategies to:
- use shared contract method names for encoder and value-net access
- move external target-selection behavior behind `score_interaction_target()`
- keep any deck-specific helper functions internal only

- [ ] **Step 4: Run tests to verify they pass**

Run the same four suites and confirm all are green.

- [ ] **Step 5: Commit**

```bash
git add scripts/ai/DeckStrategyGardevoir.gd scripts/ai/DeckStrategyMiraidon.gd tests/test_deck_strategy_contract.gd tests/test_ai_interaction_planner.gd tests/test_gardevoir_strategy.gd tests/test_miraidon_strategy.gd
git commit -m "refactor: unify gardevoir and miraidon strategy contracts"
```

### Task 4: Refactor AI integration points to use one strategy instance

**Files:**
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `scripts/ai/AIHeuristics.gd`
- Modify: `scripts/ai/AIStepResolver.gd`
- Modify: `scripts/ai/AILegalActionBuilder.gd`
- Modify: `scenes/battle/BattleScene.gd`
- Test: `tests/test_ai_interaction_planner.gd`
- Test: `tests/test_miraidon_strategy.gd`
- Test: `tests/test_gardevoir_strategy.gd`

- [ ] **Step 1: Write the next failing tests**

Add coverage for:
- `AIOpponent.set_deck_strategy()` synchronizing builder, resolver, heuristics, and MCTS
- builder removing deck-specific hardcoded Miraidon branches
- resolver and builder both delegating to the shared interaction planner

- [ ] **Step 2: Run tests to verify they fail**

Run the focused AI integration suites and confirm failures reflect the old split wiring.

- [ ] **Step 3: Write minimal implementation**

Implement:
- centralized strategy injection in `AIOpponent`
- shared strategy plumbing into heuristics, builder, and resolver
- builder conversion from special-case helpers/hardcoding to interaction-planner-driven selection
- `BattleScene` setup updated to use the centralized strategy wiring entry point

- [ ] **Step 4: Run tests to verify they pass**

Run the focused AI integration suites again and confirm green.

- [ ] **Step 5: Commit**

```bash
git add scripts/ai/AIOpponent.gd scripts/ai/AIHeuristics.gd scripts/ai/AIStepResolver.gd scripts/ai/AILegalActionBuilder.gd scenes/battle/BattleScene.gd tests/test_ai_interaction_planner.gd tests/test_miraidon_strategy.gd tests/test_gardevoir_strategy.gd
git commit -m "refactor: centralize deck strategy wiring across AI systems"
```

### Task 5: Add failing encoder-preservation regression tests

**Files:**
- Modify: `tests/test_mcts_action_resolution.gd`
- Create: `tests/test_ai_strategy_wiring.gd`
- Modify: `tests/TestSuiteCatalog.gd`

- [ ] **Step 1: Write the failing test**

Add regression coverage that asserts:
- deck-specific encoder class is preserved when `AIOpponent` runs MCTS
- trace/state encoding uses the strategy-selected encoder instead of reverting to generic `StateEncoder`

- [ ] **Step 2: Run test to verify it fails**

Run:
- `godot --headless --path . -s tests/test_ai_strategy_wiring.gd`
- `godot --headless --path . -s tests/test_mcts_action_resolution.gd`

Expected: FAIL because current MCTS setup overwrites the encoder class.

- [ ] **Step 3: Write minimal implementation**

Fix the MCTS and trace wiring to use `strategy.get_state_encoder_class()` consistently.

- [ ] **Step 4: Run test to verify it passes**

Run the same suites and confirm green.

- [ ] **Step 5: Commit**

```bash
git add tests/test_ai_strategy_wiring.gd tests/test_mcts_action_resolution.gd tests/TestSuiteCatalog.gd scripts/ai/AIOpponent.gd
git commit -m "fix: preserve deck-specific encoders in AI strategy wiring"
```

### Task 6: Full focused verification

**Files:**
- Test: `tests/test_deck_strategy_contract.gd`
- Test: `tests/test_ai_interaction_planner.gd`
- Test: `tests/test_ai_strategy_wiring.gd`
- Test: `tests/test_gardevoir_strategy.gd`
- Test: `tests/test_miraidon_strategy.gd`
- Test: `tests/test_mcts_action_resolution.gd`

- [ ] **Step 1: Run the verification suite**

Run:
- `godot --headless --path . -s tests/test_deck_strategy_contract.gd`
- `godot --headless --path . -s tests/test_ai_interaction_planner.gd`
- `godot --headless --path . -s tests/test_ai_strategy_wiring.gd`
- `godot --headless --path . -s tests/test_gardevoir_strategy.gd`
- `godot --headless --path . -s tests/test_miraidon_strategy.gd`
- `godot --headless --path . -s tests/test_mcts_action_resolution.gd`

- [ ] **Step 2: Run any additional impacted suites**

If the refactor touches catalog or battle bootstrap behavior, also run any directly impacted focused suites that exercise `BattleScene` AI setup.

- [ ] **Step 3: Summarize results**

Record:
- what changed architecturally
- which tests passed
- any unrelated existing failures that remain outside this refactor
