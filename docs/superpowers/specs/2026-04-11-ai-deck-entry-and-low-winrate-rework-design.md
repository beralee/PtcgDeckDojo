# AI Deck Entry And Low-Winrate Rework Design

## Goal

Replace the old fixed `AI策略` battle-setup entry with deck-driven strategy selection, then rework every bundled deck that currently performs at or below `30%` win rate versus Miraidon so the live battle UI, headless benchmark tooling, and unified deck-strategy framework stay aligned.

This work has two linked outcomes:

- users choose an `AI卡组`, not a hardcoded `gardevoir/miraidon/generic` strategy label
- low-performing bundled decks are re-reviewed and reworked under the unified `DeckStrategyBase` architecture

## Context

The current setup UI and battle bootstrap still reflect the pre-unified era:

- `BattleSetup.gd` exposes a fixed `AIStrategyOption`
- `GameManager.ai_deck_strategy` persists a small enum-like string
- `BattleScene._build_default_ai_opponent()` still hand-matches only Gardevoir and Miraidon

That design now conflicts with the strategy framework already in place:

- `DeckStrategyBase.gd`
- `DeckStrategyRegistry.gd`
- `AIInteractionPlanner.gd`
- `AIOpponent.set_deck_strategy()`

It also conflicts with the new bundled-deck strategy rollout, where most decks already have dedicated `DeckStrategy*.gd` classes.

## Scope

### In Scope

1. Replace fixed AI strategy selection in battle setup with AI deck-driven selection.
2. Make runtime AI creation resolve the selected AI deck into a unified strategy automatically through a registry-owned deck-resolution API.
3. Preserve existing AI version-source controls (`default`, `latest_trained`, `specific_version`).
4. Re-review and rework every bundled deck at or below `30%` win rate versus Miraidon.
5. Use multi-agent parallel review for low-performing decks, with `gpt-5.4` and `high` reasoning.
6. Require each low-performing deck review to read:
   - its bundled deck list
   - its key card effects
   - the current strategy implementation
   - Miraidon’s strategy and matchup behavior
7. Re-run matchup validation against Miraidon after each deck is revised.

### Out of Scope

1. A brand-new general training system.
2. Replacing the unified strategy framework with a separate UI-only selection system.
3. Value-net retraining as part of this first pass.
4. Non-bundled user decks.

## Current Low-Winrate Rework Set

These bundled decks are in scope for second-pass strategy review because they scored `<=30%` against Miraidon in the latest `10-game` sweep:

- `561444` 起源帝牙卢卡
- `569061` 阿尔宙斯 骑拉帝纳
- `575479` 赛富豪 起源帕路奇亚
- `575620` 放逐Box
- `575653` 雷吉铎拉戈
- `575657` 洛奇亚 始祖大鸟
- `575716` 喷火龙 大比鸟
- `575718` 猛雷鼓 厄诡椪
- `575723` 多龙巴鲁托 黑夜魔灵
- `579502` 多龙巴鲁托 喷火龙
- `579577` 铁荆棘
- `580445` 多龙巴鲁托 诅咒娃娃
- `581056` 雷吉铎拉戈
- `581614` 幸福蛋
- `582754` 破空焰

`581614` 幸福蛋 is a special case because its benchmark result is polluted by repeated `action_cap_reached`; it must be treated as both a weak deck and a headless-loop debugging target.

## Design

### 1. Battle Setup Entry Becomes Deck-Driven

`BattleSetup` should no longer expose a fixed list of strategy names like “Gardevoir v8” or “Miraidon v1”.

Instead:

- the player selects mode
- the player selects `玩家1卡组`
- in `VS_AI` mode, the second deck selector becomes `AI卡组`
- AI source/version controls remain available
- the chosen AI deck becomes the only user-facing default-strategy input

This keeps the setup UI honest: the strategy follows the selected AI deck, not a disconnected label.

### 2. Runtime Resolution Must Stay Registry-Owned

`GameManager.ai_deck_strategy` should no longer be the main runtime driver for default AI setup.

Runtime default AI construction should not add a new `deck_id -> strategy_id` shortcut path.

Instead, this work should add one registry-owned resolution API, for example:

- `DeckStrategyRegistry.resolve_strategy_for_deck(deck: DeckData) -> RefCounted`
- or an equivalent helper that derives a deck profile from deck contents and then instantiates the correct strategy

That helper should internally use registry-owned logic based on deck contents/signatures, not a UI-only side table.

Runtime default AI construction should derive the strategy from:

- `GameManager.selected_deck_ids[1]` when `current_mode == VS_AI`
- the selected `DeckData`
- the registry-owned deck-resolution API

This preserves the unified architecture instead of reintroducing a parallel `deck_id`-driven runtime.

Short-term compatibility is acceptable internally, but the UI should stop writing new fixed strategy labels.

### 3. BattleScene Uses Registry-Based Deck Resolution

`BattleScene._build_default_ai_opponent()` should stop hardcoding only Gardevoir and Miraidon branches as the main path.

The new flow should be:

- load the selected AI deck
- pass the selected `DeckData` through the single registry-owned deck-resolution API
- instantiate the matching strategy
- inject it through `AIOpponent.set_deck_strategy()`
- optionally layer versioned weights/value nets from `ai_selection`

This preserves the unified architecture while still allowing trained version assets to override heuristic weights or value nets.

### 4. Versioned AI Must Declare Compatibility

The current `AIVersionRegistry` is global and does not describe which strategy/deck family a published version is compatible with.

This refactor must define that compatibility explicitly. The minimum acceptable shape is:

- version records carry a `strategy_id` or compatible deck-family key
- `BattleSetup` only shows versions compatible with the selected AI deck’s resolved strategy
- `BattleScene` refuses to layer an incompatible versioned payload onto an unrelated deck strategy

If no compatible version is available:

- the UI falls back to default rule AI for that deck
- the battle still starts cleanly

### 4. One Strategy Architecture Across UI, Live Battle, And Benchmark

The same deck identity must drive all of these:

- battle setup default AI
- live battle AI
- `AIBenchmarkRunner`-based headless duel helpers
- `AITrainingTestRunner` matchup sweep mode
- quick benchmark scripts such as `quick_matchup_test`

All of these callers should consume the same registry-owned factory/helper. “Same path” means shared code, not merely similar logic.

No new side-door strategy selection path should be added just for the setup UI.

### 5. Low-Winrate Deck Rework Workflow

Every low-performing deck must be reworked through the same review checklist:

1. Read the bundled deck list.
2. Identify primary engine pieces, attackers, closers, tempo cards, and dead-phase cards.
3. Read the key card effects in code/data, not just deck names.
4. Read Miraidon’s current strategy implementation and matchup tendencies.
5. Review the current deck strategy implementation.
6. Update opening, search, energy routing, target selection, attack timing, and board evaluation.
7. Add or revise focused tests.
8. Re-run a small Miraidon matchup sample before broader sweep inclusion.

This is intentionally stricter than the first rollout. The first pass proved coverage; this pass is about deck quality.

### 6. Multi-Agent Execution Model

The low-winrate rework should use multiple `gpt-5.4` workers with `high` reasoning.

Main-thread ownership:

- `BattleSetup.gd`
- `BattleScene.gd`
- `GameManager.gd`
- shared harness and benchmark scripts
- shared registry ordering or helper changes
- final integration and verification

Worker ownership:

- one or two low-performing deck strategies per worker
- the focused tests tied to those strategies
- deck-specific review notes if needed

Workers must not edit shared integration files.

### 7. Happiness/Action-Cap Special Handling

`581614` 幸福蛋 must receive an additional debugging pass:

- inspect why repeated actions fail to terminate a turn in headless play
- determine whether the loop is in strategy scoring, interaction resolution, or legal-action generation
- add a targeted regression test before accepting matchup results as valid

This deck cannot be considered “reviewed” if it only improves heuristics while still hitting action caps.
This debugging pass must happen before the general low-winrate worker wave for that deck, because polluted benchmark data makes later strategy tuning unreliable.

## Data Flow

### Default AI Flow After Refactor

`BattleSetup`
-> store selected deck ids and AI source/version metadata
-> selected AI deck id resolves to `DeckData`
-> selected `DeckData` goes through the registry-owned deck-resolution API
-> `AIOpponent.set_deck_strategy()`
-> synchronized strategy reaches `MCTSPlanner`, `AIHeuristics`, `AILegalActionBuilder`, `AIStepResolver`

### Rework Validation Flow

deck review
-> focused tests
-> headless prompt/path regressions if needed
-> small Miraidon sample
-> shared sweep rerun

## Error Handling

- If the selected AI deck does not resolve to a strategy, fall back to generic AI but emit a visible warning in logs.
- If a versioned AI asset is missing, fall back to the deck’s default rule strategy instead of breaking battle setup.
- If a selected version record is incompatible with the selected AI deck’s resolved strategy, ignore the version payload and fall back to the deck’s default rule strategy with a visible warning.
- If a low-winrate deck still hits `unsupported_prompt`, `unsupported_interaction_step`, or `action_cap_reached`, it fails the rework gate even if the raw win rate rises.
- If quick benchmark helpers and training runners do not resolve the same deck strategy as live battle, the work is incomplete even if setup UI is correct.

## State Migration

Removing `AIStrategyOption` also changes setup persistence and return-context behavior.

This refactor must explicitly handle:

- old `battle_setup.json` records that still contain `ai_strategy`
- old deck-editor return contexts that still carry `ai_strategy`
- old `GameManager.ai_deck_strategy` values that may still exist in memory from previous sessions

Expected behavior:

- legacy `ai_strategy` values are ignored or translated only for backward compatibility
- new setup state is persisted in deck-driven form
- deck-editor round-trips preserve deck-driven AI selection without reviving the removed dropdown

## Testing

### Setup / Wiring Tests

- battle setup should map AI deck selection into runtime AI deck resolution without requiring fixed strategy labels
- battle scene should instantiate the matching unified deck strategy for the selected AI deck
- version pickers should only expose versions compatible with the selected AI deck’s resolved strategy
- incompatible or missing versioned payloads should fall back cleanly to the selected deck’s default strategy
- legacy setup state containing `ai_strategy` should not break loading or round-trip behavior
- legacy suite invocation through `AITrainingTestRunner.gd` must still work

### Deck Rework Tests

Each reworked deck needs:

- focused strategy tests
- target-selection coverage where relevant
- prompt/headless tests whenever the deck depends on prompt-owned interactions or benchmark-owned prompts
- anomaly regression coverage for any deck that previously produced `action_cap_reached`, `unsupported_prompt`, or `unsupported_interaction_step`

### Benchmark Tests

- small per-deck sample versus Miraidon after rework
- final batched matchup sweep across the whole low-winrate set
- explicit anomaly review for failure reasons, not just win rate
- quick benchmark script alignment checks so the same deck identity path is used outside the batch runner

## Success Criteria

The work is complete when:

1. `BattleSetup` no longer requires a fixed AI strategy dropdown.
2. Live battle default AI follows the selected AI deck automatically.
3. The unified strategy architecture remains the only injection path.
4. All 15 low-performing bundled decks have completed a second-pass strategy review.
5. Any reworked deck with benchmark anomalies is called out and fixed or explicitly blocked.
6. Post-rework matchup results versus Miraidon are regenerated from a clean run.
