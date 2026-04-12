# Hero Attack VFX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a non-blocking battle attack fireworks VFX system that plays on `ATTACK` actions, with hero-style profile overrides and safe fallback behavior.

**Architecture:** Add a small UI-only attack VFX stack made of a registry, profile object, and runtime controller. Hook BattleScene's existing `ATTACK` action log flow into this stack so effects are purely presentational and never drive attack resolution.

**Tech Stack:** Godot 4 GDScript, Control/ColorRect tween-based UI effects, existing BattleScene action log pipeline, FocusedSuiteRunner tests.

---

## File Map

- Create: `scripts/ui/battle/BattleAttackVfxProfile.gd`
- Create: `scripts/ui/battle/BattleAttackVfxRegistry.gd`
- Create: `scripts/ui/battle/BattleAttackVfxController.gd`
- Modify: `scenes/battle/BattleScene.gd`
- Modify: `tests/test_battle_ui_features.gd`
- Create: `tests/test_attack_vfx_registry.gd`

## Task 1: Add Registry and Profile Tests

**Files:**
- Create: `tests/test_attack_vfx_registry.gd`
- Test: `tests/test_attack_vfx_registry.gd`

- [ ] **Step 1: Write the failing registry tests**

Cover:
- hero override lookup returns different profile IDs for two named hero attackers
- fallback lookup returns a valid profile based on Pokemon energy type
- missing attacker data still returns a safe generic profile

- [ ] **Step 2: Run the registry test to verify it fails**

Run: `Godot --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_attack_vfx_registry.gd`

Expected: FAIL because the new registry/profile scripts do not exist yet.

- [ ] **Step 3: Implement the minimal registry/profile stack**

Create:
- `scripts/ui/battle/BattleAttackVfxProfile.gd`
- `scripts/ui/battle/BattleAttackVfxRegistry.gd`

Implementation notes:
- keep profile as a small ref-counted value object
- registry returns named hero overrides first
- fallback maps by energy type to a generic fireworks style
- no asset loading in v1

- [ ] **Step 4: Run the registry test to verify it passes**

Run the same FocusedSuiteRunner command.

- [ ] **Step 5: Commit**

`git add tests/test_attack_vfx_registry.gd scripts/ui/battle/BattleAttackVfxProfile.gd scripts/ui/battle/BattleAttackVfxRegistry.gd`

`git commit -m "feat: add attack vfx registry and profiles"`

## Task 2: Add BattleScene Attack VFX Runtime Tests

**Files:**
- Modify: `tests/test_battle_ui_features.gd`
- Test: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write the failing runtime tests**

Cover:
- `ATTACK` action starts a non-blocking attack VFX burst
- burst chooses the opponent active area as the default impact target
- attack VFX does not block `_can_accept_live_action()` after the action handler returns

- [ ] **Step 2: Run the UI suite to verify the new tests fail**

Run: `Godot --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd`

Expected: FAIL because no attack VFX controller is wired into BattleScene yet.

- [ ] **Step 3: Implement the runtime controller and BattleScene hook**

Create:
- `scripts/ui/battle/BattleAttackVfxController.gd`

Modify:
- `scenes/battle/BattleScene.gd`

Implementation notes:
- attach a dedicated overlay container for transient VFX nodes
- listen for `GameAction.ActionType.ATTACK` in `_on_action_logged`
- resolve attacker/defender anchors from existing active card views when available
- spawn tween-based sparks/smoke puffs only
- auto-cleanup nodes after animation completes
- keep the effect entirely visual; no waits, no confirm flow, no state-machine coupling

- [ ] **Step 4: Run the UI suite to verify it passes**

Run the same FocusedSuiteRunner command.

- [ ] **Step 5: Commit**

`git add scenes/battle/BattleScene.gd scripts/ui/battle/BattleAttackVfxController.gd tests/test_battle_ui_features.gd`

`git commit -m "feat: add non-blocking attack fireworks vfx"`

## Task 3: Polish Fallbacks and Verification

**Files:**
- Modify: `scripts/ui/battle/BattleAttackVfxRegistry.gd`
- Modify: `scripts/ui/battle/BattleAttackVfxController.gd`
- Test: `tests/test_attack_vfx_registry.gd`
- Test: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Add minimal hero override set**

Seed the registry with a first-pass hero set for built-in deck main attackers. Keep it data-light:
- profile id
- palette
- spark count
- smoke count
- burst scale

- [ ] **Step 2: Add one more regression test if needed**

If the first implementation exposes a gap, add one focused regression test rather than broadening existing assertions.

- [ ] **Step 3: Run focused verification**

Run:
- `Godot --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_attack_vfx_registry.gd`
- `Godot --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd`

Expected:
- both suites PASS

- [ ] **Step 4: Commit**

`git add scripts/ui/battle/BattleAttackVfxRegistry.gd scripts/ui/battle/BattleAttackVfxController.gd tests/test_attack_vfx_registry.gd tests/test_battle_ui_features.gd`

`git commit -m "test: cover attack vfx fallback and hero overrides"`
