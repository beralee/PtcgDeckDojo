# Battle Shuffle Effect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 1 second deck shake effect in battle that plays only for the player whose deck was shuffled and restarts cleanly on repeated shuffles.

**Architecture:** Keep shuffle detection and animation inside `BattleScene.gd`. Detect a shuffle by comparing the previous and current ordered deck signatures during UI refresh, then play a tween on the corresponding deck preview node. Do not modify battle rules, `PlayerState.shuffle_deck()`, or per-card effect scripts.

**Tech Stack:** Godot 4, GDScript, scene-owned tween animation, existing battle UI test suite

---

## File Map

- Modify: `scenes/battle/BattleScene.gd`
  - Add per-player deck signature caches
  - Add per-player shuffle tween state and base positions
  - Detect reorder-only deck changes during UI refresh
  - Animate the matching deck preview node for 1 second
- Modify: `tests/test_battle_ui_features.gd`
  - Add focused regressions for shuffle detection and animation restart

### Task 1: Add failing shuffle-effect UI regressions

**Files:**
- Modify: `tests/test_battle_ui_features.gd`
- Test: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write the failing test for shuffle-only detection**

```gdscript
func test_refresh_ui_triggers_shuffle_effect_only_for_reordered_deck() -> String:
	var scene := _instantiate_battle_scene()
	var state := TestBattleHelpers.make_empty_state()
	state.players[0].deck = _make_named_cards(0, ["A", "B", "C"])
	state.players[1].deck = _make_named_cards(1, ["X", "Y", "Z"])
	_attach_state_machine(scene, state)
	seed_deck_previews(scene)
	scene.call("_refresh_ui")
	state.players[0].deck = [state.players[0].deck[2], state.players[0].deck[0], state.players[0].deck[1]]
	scene.call("_refresh_ui")
	assert_true(scene.get("_my_deck_shuffle_tween") != null, "Own deck reorder should trigger shuffle tween")
	assert_true(scene.get("_opp_deck_shuffle_tween") == null, "Opponent deck should stay idle")
	return ""
```

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:

```powershell
@'
extends SceneTree

func _init() -> void:
	var suite = preload("res://tests/test_battle_ui_features.gd").new()
	print(suite.test_refresh_ui_triggers_shuffle_effect_only_for_reordered_deck())
	quit()
'@ | godot --headless --script -
```

Expected: FAIL because `BattleScene` does not yet track deck reorder state or expose the tween handle.

- [ ] **Step 3: Write the failing test for repeated shuffle restart**

```gdscript
func test_shuffle_effect_restart_replaces_existing_tween() -> String:
	var scene := _instantiate_battle_scene()
	seed_deck_previews(scene)
	scene.call("_play_deck_shuffle_effect", 0)
	var first_tween: Tween = scene.get("_my_deck_shuffle_tween")
	scene.call("_play_deck_shuffle_effect", 0)
	var second_tween: Tween = scene.get("_my_deck_shuffle_tween")
	assert_true(first_tween != second_tween, "Restart should replace the running tween")
	return ""
```

- [ ] **Step 4: Run the targeted restart test to verify it fails**

Run:

```powershell
@'
extends SceneTree

func _init() -> void:
	var suite = preload("res://tests/test_battle_ui_features.gd").new()
	print(suite.test_shuffle_effect_restart_replaces_existing_tween())
	quit()
'@ | godot --headless --script -
```

Expected: FAIL because `_play_deck_shuffle_effect` does not exist yet.

### Task 2: Implement scene-owned shuffle detection and animation

**Files:**
- Modify: `scenes/battle/BattleScene.gd`
- Test: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Add deck signature and tween state**

Add scene members for:

```gdscript
var _deck_order_signatures: Dictionary = {}
var _deck_membership_signatures: Dictionary = {}
var _deck_shuffle_tweens: Dictionary = {}
var _deck_preview_base_positions: Dictionary = {}
```

and compatibility accessors for `0/1` player preview tweens if the tests need direct inspection.

- [ ] **Step 2: Add helper methods**

Implement:

```gdscript
func _build_deck_order_signature(deck: Array) -> String
func _build_deck_membership_signature(deck: Array) -> String
func _get_deck_preview_for_player(player_index: int) -> BattleCardView
func _play_deck_shuffle_effect(player_index: int) -> void
func _stop_deck_shuffle_effect(player_index: int) -> void
func _refresh_deck_shuffle_detection(gs: GameState) -> void
```

Rules:
- trigger only when membership signature is unchanged and order signature changed
- skip animation if preview node is missing
- kill and replace an existing tween on restart
- always restore the preview node to its base position at the end

- [ ] **Step 3: Wire detection into UI refresh**

Call:

```gdscript
_refresh_deck_shuffle_detection(gs)
```

from the existing `BattleScene` refresh path after the scene has valid deck preview nodes and current `GameState`.

- [ ] **Step 4: Add cleanup**

Ensure scene exit / preview rebuild paths stop tweens and reset preview positions so the effect cannot leave visual drift behind.

- [ ] **Step 5: Run the two targeted tests**

Run:

```powershell
@'
extends SceneTree

func _init() -> void:
	var suite = preload("res://tests/test_battle_ui_features.gd").new()
	print(suite.test_refresh_ui_triggers_shuffle_effect_only_for_reordered_deck())
	print(suite.test_shuffle_effect_restart_replaces_existing_tween())
	quit()
'@ | godot --headless --script -
```

Expected: PASS for both tests.

### Task 3: Verify no regression in focused battle UI behavior

**Files:**
- Modify: `tests/test_battle_ui_features.gd` (if helper extraction is needed)
- Test: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Run a focused nearby regression slice**

Run:

```powershell
@'
extends SceneTree

func _init() -> void:
	var suite = preload("res://tests/test_battle_ui_features.gd").new()
	print(suite.test_refresh_ui_triggers_shuffle_effect_only_for_reordered_deck())
	print(suite.test_shuffle_effect_restart_replaces_existing_tween())
	print(suite.test_refresh_prize_titles_uses_view_player_labels())
	quit()
'@ | godot --headless --script -
```

Expected: PASS, with only the repository's pre-existing headless resource-leak warnings allowed after completion.

- [ ] **Step 2: Manual smoke check**

Run a live battle, use a search-and-shuffle action, and confirm:

- only the shuffled side's deck pile shakes
- the effect lasts roughly 1 second
- a second shuffle during the animation restarts it cleanly

- [ ] **Step 3: Commit**

```powershell
git add scenes/battle/BattleScene.gd tests/test_battle_ui_features.gd docs/superpowers/plans/2026-04-06-battle-shuffle-effect.md
git commit -m "feat: add battle deck shuffle effect"
```
