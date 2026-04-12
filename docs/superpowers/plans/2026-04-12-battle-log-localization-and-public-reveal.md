# Battle Log Localization And Public Reveal Plan

## Goal

Optimize the right-side battle log so it is clearer in combat, fully Chinese for player-facing copy, and capable of showing public card-reveal information from supporter and item cards when the rules make that information visible to the opponent.

Examples that must be covered:
- `高级球` searched which Pokemon
- `派帕` searched which Item and which Tool
- Any other supporter/item effect whose text implies the searched or revealed cards are shown to the opponent

This plan is intentionally scoped to the visible in-battle log and the action metadata that feeds it. It does not redesign the whole battle scene or replace the runtime debug log.

## Current State

### Player-facing log chain

- `GameStateMachine.action_logged` emits `GameAction`
- `BattleScene._on_action_logged()` appends `action.description` into the right-side log
- `BattleScene._log()` writes plain text into `MainArea/LogPanel/LogPanelVBox/LogList`

Relevant files:
- `scenes/battle/BattleScene.gd`
- `scenes/battle/BattleScene.tscn`
- `scripts/engine/GameStateMachine.gd`
- `scripts/engine/GameAction.gd`
- `scripts/ui/battle/BattleI18n.gd`

### Current problems

1. The right-side log panel is visually thin and dense.
2. Some player-facing action descriptions are still English engine strings.
3. Search effects usually mutate deck/hand directly without logging the specific publicly revealed result.
4. There is no shared rule for “this searched card should appear in the opponent-visible log”.
5. Runtime debug logging is separate and should remain separate from the visible battle log.

## Design Direction

### 1. Separate visible battle log concerns from runtime/debug logs

Keep `BattleRuntimeLogController` unchanged as a developer/debug channel.

Visible right-side combat log will continue to use `GameAction.description`, but the descriptions and supporting metadata must become:
- Chinese
- concise
- based on structured action data where needed

### 2. Introduce public-reveal logging as structured action metadata

Do not hardcode card names into `BattleScene`.

Instead, card effects and shared engine helpers should emit structured public-reveal data into `GameAction.data`, then the visible log can render it consistently.

Recommended metadata shape:
- `public_result_kind`: `"search_to_hand" | "toplook_to_hand" | "discard_cost" | ...`
- `public_result_cards`: array of card names
- `public_result_labels`: optional array of category labels such as `["物品", "宝可梦道具"]`
- `source_card_name`
- `source_kind`

This keeps logging extensible and testable.

### 3. Only log opponent-visible information

A card should only disclose selected card names in the battle log if the rules text implies that the found/revealed card becomes public information to the opponent.

Initial policy for this task:
- Log exact card identities for supporter/item searches where the card is revealed before going to hand.
- Do not log hidden information for effects that search secretly.
- If a card reveals categories but not identity, log only the public category-level action.

This policy must be encoded centrally so new cards follow the same rule.

## Planned Changes

### A. Optimize the right-side log panel UI

Update `BattleScene.tscn` and, if needed, layout refresh logic in `BattleScene.gd`:
- Slightly widen the log panel from the current narrow column.
- Increase title and body readability.
- Add inner padding and line spacing.
- Keep auto-scroll.
- Preserve compatibility with the existing AI advice block inserted into the same panel.

The target is better scanability, not a wholesale visual redesign.

### B. Convert player-facing battle log copy to Chinese

Audit all player-visible `GameAction.description` strings in `GameStateMachine.gd`.

Replace English descriptions with concise Chinese copy, for example:
- `Game start. Player 1 goes first` -> `对战开始，由玩家1先攻`
- `Player 1 used attack X` -> `玩家1使用了招式：X`
- `Player 1 drew 1 card for turn` -> `玩家1从牌库抽了1张牌`

Keep `BattleI18n.gd` as the source for scene/UI prompts where practical, but for engine action descriptions the priority is:
- no English
- no mojibake
- stable readable wording

### C. Add shared helper(s) for public reveal log events

Add a shared engine helper near the existing draw/discard log helpers so effects can record public reveal results without custom one-off log code.

Candidate API shape:
- `log_public_cards_added_to_hand(...)`
- or a more generic `log_public_resolution(...)`

Responsibilities:
- accept source card
- accept revealed cards and optional category labels
- create one visible action entry with Chinese description
- store structured metadata in `GameAction.data`

This helper should be used by trainer/supporter effect scripts rather than writing ad hoc descriptions inline.

### D. Patch supporter/item effects that reveal searched cards

Audit supporter/item effects under `scripts/effects/trainer_effects/` and classify them into:

1. Public reveal to hand  
Examples likely in scope:
- `EffectUltraBall`
- `EffectArven`
- `EffectIrida`
- `EffectLance`
- `EffectJacq`
- `EffectHyperAroma`
- `EffectSearchDeck`
- `EffectSearchBasicEnergy`
- `EffectSecretBox`
- `EffectTechnoRadar`

2. Secret search to hand  
Do not log exact card names.

3. Top-look / reveal / choose patterns  
Log only what is actually public.

For this task, supporter and item cards are the priority. Pokemon abilities and attacks are out of scope unless they already share the same helper path and can be included safely without extra complexity.

### E. Teach the visible log renderer to prefer structured public-result copy

Current visible log uses `action.description` directly.

If needed, add a small formatting layer in `BattleScene._on_action_logged()` or a dedicated formatter so that:
- action descriptions remain the default path
- public reveal metadata can render richer Chinese lines
- future public-reveal events do not require `BattleScene` to know card-specific rules

Preferred outcome:
- keep `BattleScene` generic
- put card-specific knowledge in effects/helpers

## Implementation Order

1. Audit all player-visible English action descriptions in `GameStateMachine.gd`
2. Convert those descriptions to Chinese and lock them with tests
3. Add shared public-reveal log helper and action metadata shape
4. Patch priority supporter/item effects to use the helper
5. Update right-side log panel layout in `BattleScene.tscn`
6. Add/adjust UI and engine tests
7. Run functional suites plus encoding audit

## Tests

### Engine tests

Add focused regression coverage in `tests/test_game_state_machine.gd` and/or `tests/test_effect_interaction_flow.gd`:
- `高级球` logs the searched Pokemon name publicly
- `派帕` logs the selected Item and Tool publicly
- secret searches do not leak hidden card names
- player-facing action descriptions are Chinese

### UI tests

Add/adjust `tests/test_battle_ui_features.gd`:
- right-side log panel still appends and autoscrolls correctly
- structured public reveal action appears in the visible log
- AI advice panel insertion is still compatible with the resized log panel

### Encoding and safety tests

Run:
- `SourceEncodingAudit`
- relevant focused suites
- full functional runner before completion

## Risks

1. Over-logging hidden information  
Mitigation: use an explicit allowlist/policy for public reveal effects.

2. Copy drift between engine descriptions and UI prompts  
Mitigation: keep engine descriptions concise and reserve UI prompt wording for `BattleI18n`.

3. Reintroducing mojibake while touching Chinese strings  
Mitigation: UTF-8 only, no shell text rewrites, run `SourceEncodingAudit`.

4. Log spam from too many granular actions  
Mitigation: add one public-reveal summary action per completed search effect, not per internal move.

## Deliverables

- Chinese player-facing action descriptions in the visible battle log
- Improved right-side log panel readability
- Public reveal logging for supporter/item cards that should show searched cards to the opponent
- Regression coverage proving no hidden information leak and no English fallback remains in the player-facing combat log
