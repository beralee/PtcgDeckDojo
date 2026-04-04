# BattleScene Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `BattleScene` into smaller, easier-to-maintain battle UI units and remove direct battle-domain visible copy from source so future changes stop reintroducing mojibake and localization debt.

**Architecture:** Keep `BattleScene` as the top-level coordinator, but move battle-domain visible copy into `BattleI18n`, extract formatter helpers, then extract replay, layout, and interaction responsibilities into dedicated controllers. Execute directly on the main workspace as requested, using small commits and keeping the battle functional suites green after each stage.

**Tech Stack:** Godot 4 GDScript, existing battle scene/UI architecture, `FunctionalTestRunner.gd`, battle functional suites, source/copy audit tests.

---

## File Map

### Existing files to modify

- `scenes/battle/BattleScene.gd`
  Current monolith. Target: top-level scene orchestration only.
- `scenes/replay_browser/ReplayBrowser.gd`
  Must route visible copy through the battle i18n layer or a replay-domain facade if battle copy lives here.
- `tests/test_battle_ai_advice_copy.gd`
  Update to assert i18n/formatted output without embedding scattered battle literals.
- `tests/test_battle_scene_visible_copy_audit.gd`
  Tighten to enforce no direct mojibake markers and no direct visible copy leakage in battle-domain source.
- `tests/test_battle_ui_features.gd`
  Update for any extracted controller seams and i18n-backed output checks.
- `tests/test_replay_browser.gd`
  Update for replay text lookup changes if needed.
- `tests/test_parser_regressions.gd`
  Extend only if new parser/encoding guardrails are needed.
- `tests/test_source_encoding_audit.gd`
  Extend battle-domain source protection if needed.

### New files to create

- `scenes/battle/BattleSceneRefs.gd`
  Central typed access to scene nodes used by battle controllers.
- `scripts/ui/battle/BattleI18n.gd`
  Battle-domain string key lookup and parameter interpolation facade.
- `scripts/ui/battle/BattleAdviceFormatter.gd`
  AI advice formatting helper.
- `scripts/ui/battle/BattleReviewFormatter.gd`
  Battle review formatting helper.
- `scripts/ui/battle/BattleReplayController.gd`
  Replay-mode state/navigation helper.
- `scripts/ui/battle/BattleLayoutController.gd`
  Layout/style/display refresh helper.
- `scripts/ui/battle/BattleInteractionController.gd`
  Dialog/field/assignment/effect interaction helper.
- `tests/test_battle_i18n.gd`
  Focused coverage for key lookup and parameter interpolation.
- `tests/test_battle_advice_formatter.gd`
  Focused formatter coverage.
- `tests/test_battle_review_formatter.gd`
  Focused formatter coverage.
- `tests/test_battle_scene_refs.gd`
  Focused reference wiring coverage if the refs object has logic worth testing.

### Existing files to inspect while implementing

- `docs/superpowers/specs/2026-04-05-battle-scene-refactor-design.md`
- `tests/FunctionalTestRunner.gd`
- `tests/TestSuiteCatalog.gd`
- `tests/test_game_manager.gd`
- `tests/test_battle_replay_state_restorer.gd`

## Execution Rules

- Work directly in `D:\ai\code\ptcgtrain` as requested by the user.
- Do not bundle unrelated cleanup into this refactor.
- Keep commits narrow and stage-aligned.
- Run the named functional suites after each task group, not just at the end.
- Do not leave any new visible battle copy literals in `BattleScene.gd` or battle-domain tests unless the test is specifically validating rendered text.

## Task 1: Establish the battle i18n seam

**Files:**
- Create: `scripts/ui/battle/BattleI18n.gd`
- Create: `tests/test_battle_i18n.gd`
- Modify: `scenes/battle/BattleScene.gd`
- Modify: `scenes/replay_browser/ReplayBrowser.gd`
- Modify: `tests/test_battle_ai_advice_copy.gd`
- Modify: `tests/test_battle_scene_visible_copy_audit.gd`
- Modify: `tests/test_source_encoding_audit.gd`

- [ ] **Step 1: Write focused i18n tests**

Add `tests/test_battle_i18n.gd` covering:

- key lookup for stable battle labels/buttons/titles
- parameter interpolation for battle strings with numbers or names
- fallback behavior for missing keys

- [ ] **Step 2: Run the new i18n test and verify it fails**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=BattleI18n
```

Expected:

- suite missing or failing because `BattleI18n.gd` and the new catalog entry do not exist yet

- [ ] **Step 3: Implement `BattleI18n.gd`**

Implement:

- a dictionary-backed `t(key: String, params := {}) -> String`
- a small interpolation helper for `{name}`, `{count}` style placeholders
- battle keys for all currently user-visible copy touched by replay/battle scene paths

Constraints:

- keep the file pure, no scene/node dependency
- do not call `TranslationServer` yet
- keep lookup surface stable so a future backend swap is possible

- [ ] **Step 4: Register the new test suite if needed**

Update test catalog files so `BattleI18n` can run through `FunctionalTestRunner`.

- [ ] **Step 5: Move battle-domain visible copy to keys**

Update `BattleScene.gd` and `ReplayBrowser.gd` so visible copy resolves through `BattleI18n`.

At minimum replace:

- button titles
- dialog titles/buttons/messages
- replay labels
- battle log guidance
- AI advice/review section labels that still live in scene code

- [ ] **Step 6: Update battle copy audits**

Adjust audits so they:

- continue detecting mojibake markers
- catch replacement characters
- stop relying on fragile direct literals where possible
- enforce the new “no scattered visible battle copy” rule where practical

- [ ] **Step 7: Run focused battle copy suites**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=BattleI18n,BattleAIAdviceCopy,SourceEncodingAudit,ParserRegressions
```

Expected:

- all selected suites pass

- [ ] **Step 8: Commit**

```powershell
git add scripts/ui/battle/BattleI18n.gd tests/test_battle_i18n.gd scenes/battle/BattleScene.gd scenes/replay_browser/ReplayBrowser.gd tests/test_battle_ai_advice_copy.gd tests/test_battle_scene_visible_copy_audit.gd tests/test_source_encoding_audit.gd tests/TestSuiteCatalog.gd tests/FunctionalTestRunner.gd
git commit -m "refactor: add battle i18n boundary"
```

## Task 2: Extract advice and review formatters

**Files:**
- Create: `scripts/ui/battle/BattleAdviceFormatter.gd`
- Create: `scripts/ui/battle/BattleReviewFormatter.gd`
- Create: `tests/test_battle_advice_formatter.gd`
- Create: `tests/test_battle_review_formatter.gd`
- Modify: `scenes/battle/BattleScene.gd`
- Modify: `tests/test_battle_ai_advice_copy.gd`

- [ ] **Step 1: Write formatter tests**

Create focused tests for:

- readable AI advice section ordering
- rationale/risk/confidence rendering
- review turn block formatting
- fallback/best-line/goal section rendering

- [ ] **Step 2: Run the formatter suites and verify they fail**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=BattleAdviceFormatter,BattleReviewFormatter
```

Expected:

- failing because formatters are not created and/or not wired

- [ ] **Step 3: Implement `BattleAdviceFormatter.gd`**

Move AI advice formatting out of `BattleScene`:

- section titles
- main-line rendering
- branch rendering
- prize-plan rendering
- rationale/risk/confidence rendering

Make it pure:

- input dictionary in
- formatted string out

- [ ] **Step 4: Implement `BattleReviewFormatter.gd`**

Move review formatting out of `BattleScene`:

- selected-turn review output
- turn headers
- best line / fallback line / risk / takeaway sections

- [ ] **Step 5: Replace scene formatting calls with formatter usage**

`BattleScene` should delegate formatting and stop owning the string assembly details.

- [ ] **Step 6: Run formatter and battle copy suites**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=BattleAdviceFormatter,BattleReviewFormatter,BattleAIAdviceCopy,SourceEncodingAudit
```

Expected:

- all selected suites pass

- [ ] **Step 7: Commit**

```powershell
git add scripts/ui/battle/BattleAdviceFormatter.gd scripts/ui/battle/BattleReviewFormatter.gd tests/test_battle_advice_formatter.gd tests/test_battle_review_formatter.gd scenes/battle/BattleScene.gd tests/test_battle_ai_advice_copy.gd
git commit -m "refactor: extract battle text formatters"
```

## Task 3: Extract replay controller

**Files:**
- Create: `scripts/ui/battle/BattleReplayController.gd`
- Modify: `scenes/battle/BattleScene.gd`
- Modify: `tests/test_battle_ui_features.gd`
- Modify: `tests/test_replay_browser.gd`
- Modify: `tests/test_game_manager.gd`
- Modify: `tests/test_battle_replay_state_restorer.gd`

- [ ] **Step 1: Write or extend replay controller seam tests**

Cover:

- replay launch payload application
- previous/next turn navigation
- replay-mode live-action guards
- continue-from-here handoff

- [ ] **Step 2: Run replay-focused suites and record the baseline**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=ReplayBrowser,GameManager,BattleReplayStateRestorer,BattleUIFeatures
```

Expected:

- currently green baseline before extraction

- [ ] **Step 3: Implement `BattleReplayController.gd`**

Move out of `BattleScene`:

- replay mode state
- launch payload handling
- turn loading
- previous/next turn transitions
- continue/back actions

- [ ] **Step 4: Keep `BattleScene` as the orchestrator**

`BattleScene` should:

- construct the replay controller
- pass scene dependencies and callbacks
- keep only thin wrapper entry points for UI/button integration where needed

- [ ] **Step 5: Run replay-focused suites again**

Run the same command from Step 2.

Expected:

- replay suites stay green after extraction

- [ ] **Step 6: Commit**

```powershell
git add scripts/ui/battle/BattleReplayController.gd scenes/battle/BattleScene.gd tests/test_battle_ui_features.gd tests/test_replay_browser.gd tests/test_game_manager.gd tests/test_battle_replay_state_restorer.gd
git commit -m "refactor: extract battle replay controller"
```

## Task 4: Extract layout controller

**Files:**
- Create: `scripts/ui/battle/BattleLayoutController.gd`
- Modify: `scenes/battle/BattleScene.gd`
- Modify: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Identify layout-only battle responsibilities**

Move only pure display logic:

- responsive sizing
- panel/button styling
- background/card-back loading
- HUD refresh helpers that only render data

- [ ] **Step 2: Write or extend layout-focused assertions**

Use existing `BattleUIFeatures` coverage for:

- replay buttons present and sized
- field interaction panel metrics
- backdrop loading
- stable HUD display paths

- [ ] **Step 3: Implement `BattleLayoutController.gd`**

Keep the controller focused on:

- computing layout values
- applying visual styles
- updating display-only labels and preview state

- [ ] **Step 4: Replace scene layout internals with delegation**

`BattleScene` should still call layout refresh methods, but not own the detailed implementation.

- [ ] **Step 5: Run battle UI suites**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=BattleUIFeatures,SourceEncodingAudit
```

Expected:

- battle UI and encoding suites pass

- [ ] **Step 6: Commit**

```powershell
git add scripts/ui/battle/BattleLayoutController.gd scenes/battle/BattleScene.gd tests/test_battle_ui_features.gd
git commit -m "refactor: extract battle layout controller"
```

## Task 5: Introduce `BattleSceneRefs`

**Files:**
- Create: `scenes/battle/BattleSceneRefs.gd`
- Create: `tests/test_battle_scene_refs.gd`
- Modify: `scenes/battle/BattleScene.gd`
- Modify: extracted battle controllers as needed

- [ ] **Step 1: Write refs construction test**

Cover:

- the refs object resolves required named nodes from an instantiated `BattleScene.tscn`
- missing required nodes fail loudly

- [ ] **Step 2: Run the refs test and verify it fails**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=BattleSceneRefs
```

Expected:

- failing because refs object is not created/wired

- [ ] **Step 3: Implement `BattleSceneRefs.gd`**

Move battle node references into a dedicated object with typed fields or accessors.

- [ ] **Step 4: Rewire `BattleScene` and controllers to consume refs**

Goal:

- remove the worst `@onready` sprawl from `BattleScene`
- keep node ownership understandable

- [ ] **Step 5: Run refs and battle UI suites**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=BattleSceneRefs,BattleUIFeatures
```

Expected:

- both suites pass

- [ ] **Step 6: Commit**

```powershell
git add scenes/battle/BattleSceneRefs.gd tests/test_battle_scene_refs.gd scenes/battle/BattleScene.gd scripts/ui/battle/BattleLayoutController.gd scripts/ui/battle/BattleReplayController.gd
git commit -m "refactor: centralize battle scene refs"
```

## Task 6: Extract interaction controller

**Files:**
- Create: `scripts/ui/battle/BattleInteractionController.gd`
- Modify: `scenes/battle/BattleScene.gd`
- Modify: `tests/test_battle_ui_features.gd`
- Modify: `tests/test_rule_validator.gd`
- Modify: `tests/test_parser_regressions.gd`

- [ ] **Step 1: Freeze current behavior with focused interaction tests**

Ensure current suites cover:

- dialog selection
- field slot choice
- assignment UI flow
- effect interaction progression
- handover flow
- retreat energy selection

If gaps exist, add the missing focused tests first.

- [ ] **Step 2: Run interaction-heavy suites and record baseline**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=BattleUIFeatures,RuleValidator,ParserRegressions
```

Expected:

- baseline green before extraction

- [ ] **Step 3: Implement `BattleInteractionController.gd`**

Move:

- dialog opening/rendering/confirmation
- field interaction state
- assignment source/target selection
- effect interaction step flow
- handover UI coordination

- [ ] **Step 4: Keep dependency directions strict**

Do not let:

- replay controller call interaction controller directly
- layout controller call interaction controller directly

All coordination stays routed through `BattleScene`.

- [ ] **Step 5: Run interaction-heavy suites again**

Use the same command from Step 2.

Expected:

- no behavior regression

- [ ] **Step 6: Commit**

```powershell
git add scripts/ui/battle/BattleInteractionController.gd scenes/battle/BattleScene.gd tests/test_battle_ui_features.gd tests/test_rule_validator.gd tests/test_parser_regressions.gd
git commit -m "refactor: extract battle interaction controller"
```

## Task 7: Shrink and normalize `BattleScene`

**Files:**
- Modify: `scenes/battle/BattleScene.gd`
- Modify: all extracted battle helpers/controllers as needed

- [ ] **Step 1: Remove dead inlined logic from `BattleScene`**

After controller extraction, delete duplicated helper code that remains only as transitional glue.

- [ ] **Step 2: Reorder the remaining scene file**

Final structure should read in this order:

- constants
- minimal state
- scene refs/controller fields
- lifecycle
- `GameStateMachine` callbacks
- thin UI event forwarders
- top-level orchestration helpers

- [ ] **Step 3: Check that `BattleScene` remains a coordinator**

Manual review checklist:

- can a developer find replay logic without scanning battle interaction code?
- can a developer find visible copy without scanning the scene file?
- can a developer find formatting logic without scanning gameplay callbacks?

- [ ] **Step 4: Run the full relevant battle functional pack**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd -- --suite=BattleUIFeatures,ReplayBrowser,GameManager,BattleReplayStateRestorer,SourceEncodingAudit,BattleAIAdviceCopy,CoinFlipper,RuleValidator,ParserRegressions,BattleI18n,BattleAdviceFormatter,BattleReviewFormatter,BattleSceneRefs
```

Expected:

- all selected suites pass

- [ ] **Step 5: Commit**

```powershell
git add scenes/battle/BattleScene.gd scripts/ui/battle/BattleI18n.gd scripts/ui/battle/BattleAdviceFormatter.gd scripts/ui/battle/BattleReviewFormatter.gd scripts/ui/battle/BattleReplayController.gd scripts/ui/battle/BattleLayoutController.gd scripts/ui/battle/BattleInteractionController.gd scenes/battle/BattleSceneRefs.gd tests
git commit -m "refactor: split battle scene responsibilities"
```

## Task 8: Final verification and cleanup

**Files:**
- Modify only if verification uncovers a real defect

- [ ] **Step 1: Run the default functional entry**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' -s res://tests/FunctionalTestRunner.gd
```

Expected:

- functional suites complete without new regressions introduced by the refactor

- [ ] **Step 2: Run compatibility functional group through `TestRunner.tscn`**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' 'res://tests/TestRunner.tscn' -- --group=functional
```

Expected:

- compatibility entry remains aligned with the functional runner

- [ ] **Step 3: Review remaining battle-domain source for direct copy leakage**

Use ripgrep to spot-check:

```powershell
rg -n "\"[^\"]*[一-龥]" scenes/battle scenes/replay_browser scripts/ui/battle tests
```

Expected:

- only allowed test assertions or centralized i18n tables remain

- [ ] **Step 4: Commit final cleanup**

```powershell
git add scenes/battle scenes/replay_browser scripts/ui/battle tests
git commit -m "test: finalize battle scene refactor coverage"
```

## Final Handoff Checklist

- `BattleScene.gd` is materially smaller and easier to scan.
- Visible battle copy is centralized.
- Mojibake-prone literals are no longer scattered through battle-domain code.
- Replay, layout, formatter, and interaction logic are easy to locate by file.
- Functional runner coverage stays green.
