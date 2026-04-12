# Raging Bolt Precision Iteration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Raging Bolt use exact energy typing, smarter discard ordering, and a minimal-lethal damage calculator so its attack conversion matches the deck's real game plan.

**Architecture:** Keep changes local to `DeckStrategyRagingBoltOgerpon.gd` and its focused tests. Add precise helper functions for attack requirements, discard candidate ranking, and Sada routing, then wire those helpers into existing action and interaction scoring paths.

**Tech Stack:** Godot 4 GDScript, existing AI strategy interfaces, `AITrainingTestRunner.gd`

---

### Task 1: Add failing focused tests

**Files:**
- Modify: `tests/test_future_ancient_strategies.gd`
- Test: `tests/test_future_ancient_strategies.gd`

- [ ] **Step 1: Write failing tests for precise discard and routing behavior**
- [ ] **Step 2: Run `FutureAncientStrategies` to verify the new tests fail**
- [ ] **Step 3: Keep failures limited to the new Raging Bolt behaviors**

### Task 2: Implement precise energy and discard helpers

**Files:**
- Modify: `scripts/ai/DeckStrategyRagingBoltOgerpon.gd`
- Test: `tests/test_future_ancient_strategies.gd`

- [ ] **Step 1: Add helpers for exact Bolt color needs and expendable energy classification**
- [ ] **Step 2: Add minimal-lethal / best-threshold discard calculation**
- [ ] **Step 3: Use helpers in discard priority, assignment scoring, trainer scoring, and attack scoring**
- [ ] **Step 4: Re-run `FutureAncientStrategies` until green**

### Task 3: Run safety validation

**Files:**
- Test: `tests/test_future_ancient_strategies.gd`
- Test: `tests/test_miraidon_strategy.gd`

- [ ] **Step 1: Run `MiraidonStrategy,FutureAncientStrategies`**
- [ ] **Step 2: Confirm no new regressions in Miraidon**

### Task 4: Fresh benchmark and review

**Files:**
- Test runner: `tests/AITrainingTestRunner.gd`

- [ ] **Step 1: Run fresh 100-game Miraidon vs Raging Bolt benchmark**
- [ ] **Step 2: Inspect win rate and failure reasons**
- [ ] **Step 3: If win rate is still `<=45%`, identify the next highest-leverage root cause for another iteration**

