# Unified Top-Deck Draw Reveal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing draw-reveal animation so all in-scope card effects that draw from the top of the deck into hand produce the same reveal flow as `Professor's Research`.

**Architecture:** Keep `BattleDrawRevealController` as the only presentation path and fix the missing coverage at the engine/effect boundary. Add one shared draw helper bridge in `GameStateMachine` / `EffectProcessor`, then migrate every direct `player.draw_card(s)` effect to that bridge so `DRAW_CARD` actions always include exact drawn-card metadata for reveal.

**Tech Stack:** Godot 4.6, GDScript, existing `BattleScene` reveal pipeline, focused functional tests under `tests/`

---

## File Structure

- Modify: `D:/ai/code/ptcgtrain/scripts/engine/GameStateMachine.gd`
  - Add a shared helper for card-effect-driven draws that logs exact card metadata into `DRAW_CARD`.
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/EffectProcessor.gd`
  - Hold an optional bridge back to `GameStateMachine` and expose a tiny helper effects can call.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectDrawCards.gd`
  - Replace direct `player.draw_cards()` with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectIono.gd`
  - Replace both player draws with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectRoxanne.gd`
  - Replace draw branch with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectShuffleDrawCards.gd`
  - Replace post-shuffle draw with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectSerena.gd`
  - Replace both draw branches with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectCarmine.gd`
  - Replace direct draw with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectMela.gd`
  - Replace repeated `draw_card()` loop with helper that logs the actual drawn cards.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectSadasVitality.gd`
  - Replace direct draw with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectTrekkingShoes.gd`
  - Replace discard-then-draw branch with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectUnfairStamp.gd`
  - Replace post-shuffle draw with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityBonusDrawIfActive.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDiscardDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDiscardDrawAny.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDrawCard.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDrawIfActive.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDrawIfKnockoutLastTurn.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDrawToN.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityEndTurnDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityFirstTurnDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityRunAwayDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityShuffleHandDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityThunderousCharge.gd`
  - Replace all direct draw call sites in abilities with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AttackDiscardHandDrawCards.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AttackDrawTo7.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AttackDrawToHandSize.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AttackReadWindDraw.gd`
  - Replace all direct draw call sites in attacks with shared helper.
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/energy_effects/EffectGiftEnergy.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/energy_effects/EffectSpecialEnergyOnAttach.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/stadium_effects/EffectStadiumDraw.gd`
  - Replace triggered/stadium draw call sites with shared helper.
- Modify: `D:/ai/code/ptcgtrain/tests/test_game_state_machine.gd`
  - Add engine-level draw metadata regression tests.
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
  - Add representative reveal-routing UI tests for covered card effects.
- Modify: `D:/ai/code/ptcgtrain/tests/test_specialized_effects.gd`
  - Add representative non-UI effect regressions where needed.

### Task 1: Shared Draw Helper Bridge

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/GameStateMachine.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/EffectProcessor.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_game_state_machine.gd`

- [ ] **Step 1: Write the failing tests**

Add focused tests that prove a shared helper exists and logs exact drawn-card metadata:

```gdscript
func test_draw_cards_for_effect_logs_exact_drawn_card_names() -> String:
	var gsm := GameStateMachine.new()
	# Seed a known top-deck order, call the new helper for draw 3,
	# and assert the last DRAW_CARD action includes count=3 and the exact names.
	return ""


func test_draw_cards_for_effect_skips_draw_log_when_count_is_zero() -> String:
	var gsm := GameStateMachine.new()
	# Call the helper with count=0 and assert no DRAW_CARD action is added.
	return ""
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_game_state_machine.gd
```

Expected:
- FAIL because no shared helper exists yet and no test-visible bridge logs effect-originated draws.

- [ ] **Step 3: Write minimal implementation**

In `GameStateMachine.gd`, add a helper shaped like:

```gdscript
func draw_cards_for_effect(
	player_index: int,
	count: int,
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	if count <= 0:
		return []
	var drawn: Array[CardInstance] = game_state.players[player_index].draw_cards(count)
	if drawn.is_empty():
		return drawn
	_log_action(
		GameAction.ActionType.DRAW_CARD,
		player_index,
		{
			"count": drawn.size(),
			"card_names": _card_names_from_cards(drawn),
			"card_instance_ids": _card_ids_from_cards(drawn),
			"source_kind": source_kind,
			"source_card_name": source_card.card_data.name if source_card != null and source_card.card_data != null else "",
		},
		"Player %d drew %d cards" % [player_index + 1, drawn.size()]
	)
	return drawn
```

In `EffectProcessor.gd`, add:

```gdscript
var game_state_machine: GameStateMachine = null

func bind_game_state_machine(gsm: GameStateMachine) -> void:
	game_state_machine = gsm

func draw_cards_with_log(
	player_index: int,
	count: int,
	state: GameState,
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	if game_state_machine != null and game_state_machine.game_state == state:
		return game_state_machine.draw_cards_for_effect(player_index, count, source_card, source_kind)
	return state.players[player_index].draw_cards(count)
```

Bind the bridge from `GameStateMachine._init()` and any path that recreates `effect_processor`.

- [ ] **Step 4: Run test to verify it passes**

Run the same focused suite.

Expected:
- PASS on the new helper tests
- no regression to existing turn-start and `Professor's Research` draw metadata tests

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/GameStateMachine.gd scripts/engine/EffectProcessor.gd tests/test_game_state_machine.gd
git commit -m "feat: add shared effect draw logging helper"
```

### Task 2: Trainer Draw Effects

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectDrawCards.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectIono.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectRoxanne.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectShuffleDrawCards.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectSerena.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectCarmine.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectMela.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectSadasVitality.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectTrekkingShoes.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/trainer_effects/EffectUnfairStamp.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_game_state_machine.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write the failing tests**

Add representative regressions:

```gdscript
func test_iono_logs_draw_card_actions_for_both_players() -> String:
	# Resolve Iono with known deck orders and prize counts.
	# Assert both players receive DRAW_CARD actions with exact card_names.
	return ""


func test_trekking_shoes_discard_branch_logs_reveal_draw() -> String:
	# Choose "discard", then assert one DRAW_CARD action exists with the exact drawn card.
	return ""


func test_battle_scene_iono_draws_enqueue_reveal() -> String:
	# Feed an Iono-style DRAW_CARD action into BattleScene and assert draw reveal activates.
	return ""
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_game_state_machine.gd
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:
- FAIL because these trainer effects still bypass the shared helper.

- [ ] **Step 3: Write minimal implementation**

For each trainer effect, replace direct draws with:

```gdscript
state.players[pi] -> effect_processor.draw_cards_with_log(pi, draw_count, state, card, "trainer")
```

Notes:
- `EffectMela.gd` should accumulate the actual number of cards needed and call the helper once rather than looping `draw_card()`
- `EffectSerena.gd` must only log the real number drawn in the chosen branch
- `EffectTrekkingShoes.gd` should only reveal the replacement draw on the discard branch, not the top-card-to-hand branch
- remove the old `GameStateMachine.play_trainer()` special-case `EffectDrawCards` logging once `EffectDrawCards` itself logs through the helper

- [ ] **Step 4: Run test to verify it passes**

Run the same two focused suites.

Expected:
- PASS on trainer-specific metadata and reveal routing tests
- no duplicate `DRAW_CARD` logs for `Professor's Research`

- [ ] **Step 5: Commit**

```bash
git add scripts/effects/trainer_effects/EffectDrawCards.gd scripts/effects/trainer_effects/EffectIono.gd scripts/effects/trainer_effects/EffectRoxanne.gd scripts/effects/trainer_effects/EffectShuffleDrawCards.gd scripts/effects/trainer_effects/EffectSerena.gd scripts/effects/trainer_effects/EffectCarmine.gd scripts/effects/trainer_effects/EffectMela.gd scripts/effects/trainer_effects/EffectSadasVitality.gd scripts/effects/trainer_effects/EffectTrekkingShoes.gd scripts/effects/trainer_effects/EffectUnfairStamp.gd scripts/engine/GameStateMachine.gd tests/test_game_state_machine.gd tests/test_battle_ui_features.gd
git commit -m "feat: route trainer draw effects through reveal logging"
```

### Task 3: Ability And Attack Draw Effects

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityBonusDrawIfActive.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDiscardDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDiscardDrawAny.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDrawCard.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDrawIfActive.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDrawIfKnockoutLastTurn.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityDrawToN.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityEndTurnDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityFirstTurnDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityRunAwayDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityShuffleHandDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AbilityThunderousCharge.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AttackDiscardHandDrawCards.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AttackDrawTo7.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AttackDrawToHandSize.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/pokemon_effects/AttackReadWindDraw.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_specialized_effects.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write the failing tests**

Add representative regressions:

```gdscript
func test_ability_thunderous_charge_logs_reveal_draw() -> String:
	# Use the ability and assert one exact DRAW_CARD action is present.
	return ""


func test_attack_draw_to_seven_logs_all_revealed_cards() -> String:
	# Attack with known top-deck order and assert exact logged names.
	return ""


func test_battle_scene_attack_draw_reveal_uses_batch_animation() -> String:
	# Feed an AttackDrawTo7-style action and assert batch reveal stages all cards.
	return ""
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_specialized_effects.gd
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:
- FAIL because abilities and attacks still draw directly.

- [ ] **Step 3: Write minimal implementation**

Replace each direct draw with `effect_processor.draw_cards_with_log(...)`.

Notes:
- for ability scripts, use the source Pokemon top card as `source_card`
- for attack scripts, use the attacker top card as `source_card`
- `AbilityDrawToN.gd` and `AttackDrawToHandSize.gd` must skip logging when the computed draw count is `<= 0`
- `AbilityRunAwayDraw.gd` must preserve current timing: draw first, then continue its existing self-move logic

- [ ] **Step 4: Run test to verify it passes**

Run the same two focused suites.

Expected:
- PASS on representative ability/attack draw reveal tests
- no regressions to existing once-per-turn and attack interaction behavior

- [ ] **Step 5: Commit**

```bash
git add scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandDraw.gd scripts/effects/pokemon_effects/AbilityBonusDrawIfActive.gd scripts/effects/pokemon_effects/AbilityDiscardDraw.gd scripts/effects/pokemon_effects/AbilityDiscardDrawAny.gd scripts/effects/pokemon_effects/AbilityDrawCard.gd scripts/effects/pokemon_effects/AbilityDrawIfActive.gd scripts/effects/pokemon_effects/AbilityDrawIfKnockoutLastTurn.gd scripts/effects/pokemon_effects/AbilityDrawToN.gd scripts/effects/pokemon_effects/AbilityEndTurnDraw.gd scripts/effects/pokemon_effects/AbilityFirstTurnDraw.gd scripts/effects/pokemon_effects/AbilityRunAwayDraw.gd scripts/effects/pokemon_effects/AbilityShuffleHandDraw.gd scripts/effects/pokemon_effects/AbilityThunderousCharge.gd scripts/effects/pokemon_effects/AttackDiscardHandDrawCards.gd scripts/effects/pokemon_effects/AttackDrawTo7.gd scripts/effects/pokemon_effects/AttackDrawToHandSize.gd scripts/effects/pokemon_effects/AttackReadWindDraw.gd tests/test_specialized_effects.gd tests/test_battle_ui_features.gd
git commit -m "feat: route ability and attack draws through reveal logging"
```

### Task 4: Triggered Energy And Stadium Draw Effects

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/energy_effects/EffectGiftEnergy.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/energy_effects/EffectSpecialEnergyOnAttach.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/effects/stadium_effects/EffectStadiumDraw.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/GameStateMachine.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_specialized_effects.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write the failing tests**

Add representative regressions:

```gdscript
func test_gift_energy_knockout_draw_logs_reveal_metadata() -> String:
	# Trigger Gift Energy through GSM knockout handling and assert exact draw metadata.
	return ""


func test_special_energy_on_attach_draw_logs_reveal_metadata() -> String:
	# Attach a draw-on-attach special energy and assert one DRAW_CARD action exists.
	return ""


func test_stadium_draw_logs_reveal_metadata() -> String:
	# Use a stadium draw effect and assert exact card_names are logged.
	return ""
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_specialized_effects.gd
```

Expected:
- FAIL because these triggered paths still mutate hand without reveal metadata.

- [ ] **Step 3: Write minimal implementation**

Update the three effect families to route through the same helper.

Notes:
- `EffectGiftEnergy.trigger_on_knockout` currently only receives `PlayerState`; change the call chain so it can use the shared helper without duplicating draw logic
- the cleanest version is to let `GameStateMachine` handle the Gift Energy draw itself after detecting the trigger, then remove the direct draw from the static effect helper
- `EffectSpecialEnergyOnAttach` and `EffectStadiumDraw` can use the processor bridge directly because they already execute through effect scripts with access to `state`

- [ ] **Step 4: Run test to verify it passes**

Run the same focused suite.

Expected:
- PASS on all new triggered draw regressions
- no duplicate draw actions during knockout/attach resolution

- [ ] **Step 5: Commit**

```bash
git add scripts/effects/energy_effects/EffectGiftEnergy.gd scripts/effects/energy_effects/EffectSpecialEnergyOnAttach.gd scripts/effects/stadium_effects/EffectStadiumDraw.gd scripts/engine/GameStateMachine.gd tests/test_specialized_effects.gd tests/test_battle_ui_features.gd
git commit -m "feat: route triggered draw effects through reveal logging"
```

### Task 5: Verification Sweep

**Files:**
- Verify only; no new files required unless a regression demands a small fix

- [ ] **Step 1: Run targeted functional suites**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_game_state_machine.gd
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_specialized_effects.gd
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:
- PASS for all three suites

- [ ] **Step 2: Run the full functional suite**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FunctionalTestRunner.gd'
```

Expected:
- PASS for the full functional suite
- existing non-fatal Godot shutdown warnings may still print, but the suite total should remain green

- [ ] **Step 3: Inspect for duplicate reveal producers**

Check:

```powershell
rg --line-number "ActionType\\.DRAW_CARD|draw_cards\\(|draw_card\\(" scripts\\engine scripts\\effects
```

Expected:
- in-scope effects should now go through the shared helper path
- no leftover ad-hoc `Professor's Research`-only logging in `play_trainer()`

- [ ] **Step 4: Final commit**

```bash
git add scripts/engine scripts/effects tests
git commit -m "feat: unify reveal animation for top-deck card draws"
```
