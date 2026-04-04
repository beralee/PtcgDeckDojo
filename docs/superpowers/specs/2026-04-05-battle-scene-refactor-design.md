# BattleScene Refactor Design

**Date:** 2026-04-05

## Context

`BattleScene.gd` has become the highest-risk UI file in the project.

It currently mixes:

- scene lifecycle and node wiring
- game-state orchestration
- layout and visual styling
- dialog and field interaction flow
- replay flow
- AI advice and battle review formatting
- battle-domain visible copy

This creates two concrete maintenance problems:

1. The file is too large to navigate reliably, so changes are slow and easy to place in the wrong area.
2. Visible copy is still embedded directly in battle-domain source files and tests, which keeps the project exposed to mojibake and encoding regressions and blocks future localization work.

This refactor is intended to reduce change risk, make responsibilities easy to find, and remove the direct source-level dependency on battle UI copy.

## Goals

- Make battle UI code easier to read and modify by splitting `BattleScene` into focused units with clear ownership.
- Eliminate direct hard-coded visible battle copy from `BattleScene`, `ReplayBrowser`, and battle-related tests.
- Introduce a battle-domain i18n boundary that can later switch to Godot translations without changing battle callers.
- Preserve current battle behavior, replay behavior, and functional coverage while refactoring.

## Non-Goals

- This is not a full-project i18n rollout.
- This is not a redesign of battle UI behavior or scene structure.
- This is not a rewrite of `BattleScene` into a minimal shell with every behavior externalized.
- This does not require immediate migration to `.translation` resources in the first step.

## Recommended Approach

Use a medium-granularity refactor:

- keep `BattleScene` as the top-level coordinator
- extract focused controllers/helpers for secondary responsibilities
- route all visible battle copy through a dedicated `BattleI18n` facade

This balances maintainability with regression risk. It improves file ownership without forcing a full runtime architecture rewrite.

## Target Architecture

### `BattleScene.gd`

`BattleScene` remains the scene entry point and owns:

- node lifecycle
- controller construction and dependency injection
- `GameStateMachine` ownership
- high-level event routing between callbacks and controllers

`BattleScene` should stop owning:

- detailed copy lookup
- advice/review text formatting
- replay state transition internals
- detailed layout/style implementation
- most dialog and field-interaction mechanics

### New Units

#### `BattleSceneRefs.gd`

Purpose:

- centralize battle scene node references and common lookup helpers

Responsibilities:

- hold the long list of scene node references currently cluttering `BattleScene`
- expose a stable, typed access surface for controllers

Benefits:

- sharply reduces top-of-file noise
- makes it easier to understand available UI surfaces without reading behavior code

#### `BattleI18n.gd`

Purpose:

- be the only battle-domain source of visible copy

Responsibilities:

- map string keys to display text
- support parameterized templates
- define a stable interface that can later route through `TranslationServer`

Non-goal for phase 1:

- direct dependency on Godot translation resources

Contract:

- callers request copy by key, never by literal user-facing text
- parameter interpolation happens inside the i18n layer, not ad hoc in callers

#### `BattleLayoutController.gd`

Purpose:

- own battle layout, style, and presentation refresh logic

Responsibilities:

- responsive sizing
- panel/button styling
- backdrop and card-back loading
- HUD presentation refresh
- other pure-display updates that do not own gameplay flow

#### `BattleInteractionController.gd`

Purpose:

- own interaction-heavy UI flow

Responsibilities:

- dialog setup and resolution
- field slot selection
- assignment UI
- handover UI
- effect interaction step progression

Constraint:

- it should not own core battle state, only interaction flow and view coordination

#### `BattleReplayController.gd`

Purpose:

- isolate replay-mode behavior from live battle flow

Responsibilities:

- replay launch payload handling
- previous-turn / next-turn navigation
- replay-mode guards
- continue-from-here restoration handoff

#### `BattleAdviceFormatter.gd`

Purpose:

- format AI battle advice into display text

Responsibilities:

- advice section structure
- readable section titles
- formatting of list/branch/risk/confidence blocks

#### `BattleReviewFormatter.gd`

Purpose:

- format battle review output into display text

Responsibilities:

- review turn headings
- structured review sections
- readable labels for fallback lines, goals, risks, and summaries

## i18n Contract

This refactor must enforce a stricter battle-domain copy policy.

### Rules

1. `BattleScene.gd`, `ReplayBrowser.gd`, and battle-related tests must not contain user-facing copy literals except where a test is specifically validating i18n output.
2. All visible battle copy must be resolved through `BattleI18n`.
3. Parameterized text must use key + parameters, not inline `%` formatting with hard-coded visible strings.
4. Tests should assert semantic output from `BattleI18n` or rendered UI values, not rely on scattered source literals.

### Why this is required

This is the only reliable way to cut the mojibake failure mode off at the source.

If battle-domain source stops carrying fragile visible strings directly, encoding breakage becomes dramatically harder to reintroduce, and localization can evolve behind a stable lookup interface.

### Future compatibility

`BattleI18n` should be designed so that:

- phase 1 can use an internal dictionary-based key table
- a later phase can switch the implementation to Godot translation resources without changing call sites

## File Layout

Planned targets:

- modify `scenes/battle/BattleScene.gd`
- create `scenes/battle/BattleSceneRefs.gd`
- create `scripts/ui/battle/BattleI18n.gd`
- create `scripts/ui/battle/BattleLayoutController.gd`
- create `scripts/ui/battle/BattleInteractionController.gd`
- create `scripts/ui/battle/BattleReplayController.gd`
- create `scripts/ui/battle/BattleAdviceFormatter.gd`
- create `scripts/ui/battle/BattleReviewFormatter.gd`

Likely related updates:

- `scenes/replay_browser/ReplayBrowser.gd`
- battle-related functional tests
- battle-domain copy/encoding audits

## Dependency Rules

To avoid recreating the same maintenance problem in smaller files:

- `BattleScene` owns all controllers and passes only the dependencies they need.
- Controllers/helpers must not create hidden back-references to each other.
- Controllers communicate through `BattleScene` orchestration or explicitly injected collaborators.
- Formatting units must remain pure helpers and not depend on scene nodes.
- `BattleI18n` must not depend on scene state.

## Migration Strategy

The refactor should proceed in four stages.

### Stage 1: Battle i18n boundary

Do first:

- create `BattleI18n`
- move visible battle copy behind keys
- update battle tests to stop depending on embedded literals where possible
- strengthen copy/encoding audits to protect the new boundary

Reason:

- this removes the root cause of the recurring mojibake problem before structural extraction begins

### Stage 2: Formatter extraction

Extract:

- AI advice formatting
- battle review formatting

Reason:

- high payoff, comparatively low risk
- removes a large amount of long-form string formatting from `BattleScene`

### Stage 3: Replay and layout extraction

Extract:

- replay-mode behavior into `BattleReplayController`
- layout/style refresh into `BattleLayoutController`

Reason:

- both areas already have relatively clear boundaries
- behavior is easier to regression-test with existing functional suites

### Stage 4: Interaction extraction

Extract:

- dialog flow
- field selection
- assignment flow
- handover and effect-interaction coordination

Reason:

- this is the most coupled part of the scene and should move last

## Testing Strategy

Refactor safety depends on preserving current functional behavior.

### Must keep green during refactor

- `BattleUIFeatures`
- `ReplayBrowser`
- `GameManager`
- `BattleReplayStateRestorer`
- `SourceEncodingAudit`
- `BattleAIAdviceCopy`
- `CoinFlipper`
- `RuleValidator`
- `ParserRegressions`

### Additional refactor checks

- add battle-domain source audit rules that verify visible copy is routed through the i18n layer where applicable
- add focused tests for formatter output keyed through `BattleI18n`
- add focused tests for controller boundaries where pure helpers are introduced

## Acceptance Criteria

The refactor is complete when all of the following are true:

- `BattleScene.gd` is materially smaller and clearly limited to top-level coordination responsibilities.
- Layout, replay, formatting, and interaction responsibilities are easy to locate in dedicated units.
- Battle-domain visible copy no longer lives directly in `BattleScene`, `ReplayBrowser`, or the migrated battle tests.
- Battle-domain copy resolution goes through a stable i18n facade.
- `SourceEncodingAudit` and battle copy audits protect against recurring mojibake regressions.
- Battle/replay functional suites remain green under the new `FunctionalTestRunner` flow.

## Risks

### Over-fragmentation

If too many tiny files are created without clear boundaries, navigation will become worse, not better.

Mitigation:

- split by responsibility, not by arbitrary helper count
- keep formatters pure and controllers cohesive

### Controller coupling

If new controllers call each other directly, the refactor will only relocate the complexity.

Mitigation:

- central orchestration stays in `BattleScene`
- dependency directions stay explicit

### Partial i18n migration

If some visible strings remain scattered in battle-domain source, the project will still be exposed to encoding regressions and localization drift.

Mitigation:

- treat i18n extraction as the first mandatory stage
- protect with audits and focused tests

## Open Follow-Up

After this refactor lands, the next logical follow-up is a project-level decision on when to replace the dictionary-backed `BattleI18n` implementation with official Godot translation assets. That decision is intentionally deferred until the battle-domain boundary is stable.
