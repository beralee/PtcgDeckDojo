# VS_AI Opponent Hand View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `对手手牌` debug button in `VS_AI` battles that opens a read-only thumbnail viewer for the AI opponent's current hand.

**Architecture:** Reuse `BattleScene`'s top-bar action row and the existing read-only card gallery overlay. Keep the feature gated behind `VS_AI` mode and avoid touching rule or AI decision code.

**Tech Stack:** Godot 4, GDScript, existing `BattleScene` overlay/card preview components, `TestRunner` UI tests

---

### Task 1: Add failing UI tests

**Files:**
- Modify: `tests/test_battle_ui_features.gd`

- [ ] Write a failing test for `VS_AI`-only button visibility.
- [ ] Write a failing test for opening a read-only opponent hand viewer.
- [ ] Run the targeted tests and confirm they fail for the missing button/method.

### Task 2: Add the top-bar button and viewer wiring

**Files:**
- Modify: `scenes/battle/BattleScene.tscn`
- Modify: `scenes/battle/BattleScene.gd`

- [ ] Add `BtnOpponentHand` to the top-bar row, to the left of `BtnZeusHelp`.
- [ ] Connect the button in `_ready()`.
- [ ] Gate visibility by `GameManager.current_mode == VS_AI`.
- [ ] Implement a read-only opponent hand viewer using the existing gallery overlay.

### Task 3: Verify and clean up

**Files:**
- Modify: `tests/test_battle_ui_features.gd`

- [ ] Re-run targeted tests and confirm they pass.
- [ ] Re-run the full suite.
- [ ] Keep the change UI-only; do not modify gameplay rules or AI action logic.
