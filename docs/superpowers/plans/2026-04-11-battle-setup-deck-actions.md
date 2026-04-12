# Battle Setup Deck Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-player `查看 / 编辑` deck actions in Battle Setup, reuse the existing deck view behavior, and return from Deck Editor back to Battle Setup with settings preserved.

**Architecture:** Keep the UI local to `BattleSetup`, extract deck viewing into a reusable helper, and store a minimal deck-editor return context in `GameManager`. `DeckEditor` remains the editor; only its return destination becomes context-aware.

**Tech Stack:** Godot 4 GDScript, existing `GameManager` scene routing, existing `DeckData` / `CardDatabase` UI patterns, focused Godot headless tests.

---

### Task 1: Add failing Battle Setup deck-action tests

**Files:**
- Modify: `tests/test_battle_setup_layout.gd`
- Modify: `tests/test_battle_ui_features.gd`

- [ ] Write failing tests for player1/player2 `查看 / 编辑` buttons existing and disabling without valid decks.
- [ ] Write a failing test for `查看` opening deck details from Battle Setup.
- [ ] Write a failing test for `编辑` routing into deck editor with a Battle Setup return target.
- [ ] Run focused suites and confirm they fail for the missing behavior.

### Task 2: Add reusable deck-view dialog helper

**Files:**
- Create: `scripts/ui/decks/DeckViewDialog.gd`
- Modify: `scenes/deck_manager/DeckManager.gd`
- Modify: `scenes/battle_setup/BattleSetup.gd`

- [ ] Extract the current DeckManager view-dialog build logic into a reusable helper.
- [ ] Keep DeckManager behavior unchanged by switching it to the helper.
- [ ] Wire BattleSetup `查看` buttons to the same helper.
- [ ] Run the focused tests and confirm the new helper passes the view behavior.

### Task 3: Add Battle Setup buttons and state refresh

**Files:**
- Modify: `scenes/battle_setup/BattleSetup.tscn`
- Modify: `scenes/battle_setup/BattleSetup.gd`
- Modify: `tests/test_battle_setup_layout.gd`

- [ ] Add deck-action rows for both deck selectors in the layout.
- [ ] Bind `查看 / 编辑` for both player deck selectors.
- [ ] Disable buttons when the selected deck id is invalid.
- [ ] Refresh button state whenever deck options refresh or selection changes.
- [ ] Run the focused Battle Setup suites and confirm they pass.

### Task 4: Add Deck Editor return-to-BattleSetup flow

**Files:**
- Modify: `scripts/autoload/GameManager.gd`
- Modify: `scenes/deck_editor/DeckEditor.gd`
- Modify: `scenes/battle_setup/BattleSetup.gd`
- Modify: `tests/test_deck_editor.gd`

- [ ] Add minimal deck-editor return context storage to `GameManager`.
- [ ] Update BattleSetup edit actions to launch DeckEditor with `BattleSetup` return context and current setup snapshot.
- [ ] Update DeckEditor back/save exit flow to honor the stored return scene.
- [ ] Restore BattleSetup settings and selected deck ids after returning.
- [ ] Run the focused routing tests and confirm they pass.

### Task 5: Verification

**Files:**
- Test: `tests/test_battle_setup_layout.gd`
- Test: `tests/test_battle_ui_features.gd`
- Test: `tests/test_deck_editor.gd`

- [ ] Run `test_battle_setup_layout.gd`.
- [ ] Run `test_battle_ui_features.gd`.
- [ ] Run `test_deck_editor.gd`.
- [ ] Summarize any unrelated existing failures separately if they appear.
