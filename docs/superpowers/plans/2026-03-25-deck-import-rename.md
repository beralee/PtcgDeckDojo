# Deck Import Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Force the user to enter a unique deck name when an imported deck name conflicts with an existing saved deck.

**Architecture:** Keep duplicate-name handling inside `DeckManager` because it already owns the import-complete and save flow. Add small helper methods for conflict detection and name validation so UI behavior can be tested without touching network code.

**Tech Stack:** Godot 4, GDScript, existing custom test runner

---

### Task 1: Add failing tests for duplicate-name import flow

**Files:**
- Create: `tests/test_deck_manager.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run the test runner to verify the new test fails**
- [ ] **Step 3: Keep the failure focused on missing duplicate-name handling**

### Task 2: Add deck-name conflict helpers to `DeckManager`

**Files:**
- Modify: `scenes/deck_manager/DeckManager.gd`
- Test: `tests/test_deck_manager.gd`

- [ ] **Step 1: Add helper methods for exact-name conflict detection and trimmed-name validation**
- [ ] **Step 2: Run tests and verify helper expectations**

### Task 3: Add the forced-rename dialog flow

**Files:**
- Modify: `scenes/deck_manager/DeckManager.gd`
- Test: `tests/test_deck_manager.gd`

- [ ] **Step 1: Change `_on_import_completed()` so duplicate names do not save immediately**
- [ ] **Step 2: Add a modal rename dialog with no cancel path**
- [ ] **Step 3: Wire input-change validation to the confirm button and message label**
- [ ] **Step 4: Confirming a unique name should update `deck.deck_name` and continue the existing save flow**

### Task 4: Verify the end-to-end behavior

**Files:**
- Modify: `tests/test_deck_manager.gd` if needed

- [ ] **Step 1: Run the test runner and confirm the new deck-manager tests pass**
- [ ] **Step 2: Run the full headless test suite and confirm no regressions**
