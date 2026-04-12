# Multi-Deck Strategy Expansion Design

## Goal

Expand the unified `DeckStrategyBase` architecture beyond Gardevoir and Miraidon so every bundled deck in `data/bundled_user/decks/` resolves to a non-generic deck strategy.

This expansion should follow the current unified design:

- detection through `DeckStrategyRegistry`
- runtime wiring through `AIOpponent.set_deck_strategy()`
- target selection through `AIInteractionPlanner`
- no new direct `_deck_strategy` shortcuts

## Scope

Bundled decks currently in scope:

- `561444` 起源帝牙卢卡
- `569061` 阿尔宙斯 骑拉帝纳
- `572568` 未来Box
- `575479` 赛富豪 起源帕路奇亚
- `575620` 放逐Box
- `575653` 雷吉铎拉戈
- `575657` 洛奇亚 始祖大鸟
- `575716` 喷火龙 大比鸟
- `575718` 猛雷鼓 厄诡椪
- `575723` 多龙巴鲁托 黑夜魔灵
- `577861` 起源帕路奇亚 黑夜魔灵
- `579502` 多龙巴鲁托 喷火龙
- `579577` 铁荆棘
- `580445` 多龙巴鲁托 诅咒娃娃
- `581056` 雷吉铎拉戈
- `581614` 幸福蛋
- `582754` 破空焰

Existing out-of-scope archetypes:

- `575720` 密勒顿
- `578647` 沙奈朵

## Approach

Do not create one strategy per `deck_id`.

Instead, group bundled decks into strategy families that match the actual AI decision surface. Different decklists that share the same search priorities, setup pattern, attacker routing, and prize plan should resolve to the same strategy id.

## Strategy Families

### 1. `charizard_ex`

Decks:

- `575716` 喷火龙 大比鸟

Core plan:

- prioritize setup for Charmander -> Charizard ex and Pidgey -> Pidgeot ex
- value `Rare Candy`, evolution sequencing, and tutor timing highly
- protect Charizard ex attack-ready transitions over medium-value trainer actions

### 2. `dragapult_dusknoir`

Decks:

- `575723` 多龙巴鲁托 黑夜魔灵

Core plan:

- prioritize Dragapult ex evolution chain
- value Duskull / Dusclops / Dusknoir setup when it converts prize tempo
- treat spread placement and devolution timing as first-class interaction choices

### 3. `dragapult_banette`

Decks:

- `580445` 多龙巴鲁托 诅咒娃娃

Core plan:

- same Dragapult shell as above, but target selection and board evaluation should reward Banette ex disruption lines more than Dusknoir lines

### 4. `dragapult_charizard`

Decks:

- `579502` 多龙巴鲁托 喷火龙

Core plan:

- hybrid stage-2 shell
- opening and search priorities need to distinguish whether the board is closer to Dragapult pressure or Charizard stabilization

### 5. `regidrago`

Decks:

- `575653` 雷吉铎拉戈
- `581056` 雷吉铎拉戈

Core plan:

- prioritize Regidrago V -> VSTAR setup
- aggressively stock discard with high-value dragon attacks
- treat attack-copy selection as a strategy-owned decision

### 6. `palkia_gholdengo`

Decks:

- `575479` 赛富豪 起源帕路奇亚

Core plan:

- prioritize Palkia VSTAR setup and bench water support
- value resource loops and burst turns that convert benched energy into Gholdengo damage

### 7. `palkia_dusknoir`

Decks:

- `577861` 起源帕路奇亚 黑夜魔灵

Core plan:

- prioritize Palkia setup first, then Dusknoir pressure
- weight spread / devolution / counter placement decisions higher than generic water setup

### 8. `lost_box`

Decks:

- `575620` 放逐Box

Core plan:

- prize-trade deck
- early actions should strongly reward lost-zone progress, pivot options, and flexible single-prize attacker access

### 9. `lugia_archeops`

Decks:

- `575657` 洛奇亚 始祖大鸟

Core plan:

- maximize access to Archeops
- prioritize discard setup and efficient special-energy deployment
- evaluate attack lines by immediate prize pressure rather than long setup

### 10. `dialga_metang`

Decks:

- `561444` 起源帝牙卢卡

Core plan:

- prioritize Beldum -> Metang -> Dialga VSTAR engine
- strongly reward extra-turn setup and metal-energy acceleration sequencing

### 11. `arceus_giratina`

Decks:

- `569061` 阿尔宙斯 骑拉帝纳

Core plan:

- prioritize Arceus VSTAR opening line
- route energy and tutor actions toward Giratina VSTAR closer
- value high-leverage stadium and gust timing

### 12. `future_box`

Decks:

- `572568` 未来Box

Core plan:

- prioritize Future Pokemon bench development
- favor `Techno Radar`, `Future Booster Energy Capsule`, `Electric Generator`, and efficient attacker rotation

### 13. `iron_thorns`

Decks:

- `579577` 铁荆棘

Core plan:

- disruption-first strategy
- value lock maintenance, pivot denial, and energy acceleration that preserves lock turns

### 14. `raging_bolt_ogerpon`

Decks:

- `575718` 猛雷鼓 厄诡椪

Core plan:

- aggressive tempo shell
- prioritize burst-energy lines and efficient two-hit / one-hit prize exchanges

### 15. `blissey_tank`

Decks:

- `581614` 幸福蛋

Core plan:

- prioritize Chansey -> Blissey ex setup
- reward high-HP tank lines, damage-moving support, and reset / heal patterns

### 16. `gouging_fire_ancient`

Decks:

- `582754` 破空焰

Core plan:

- ancient aggro shell
- reward early pressure, Sada acceleration, and attacker rotation that preserves tempo

## Shared Implementation Rules

- Every new strategy extends `DeckStrategyBase`.
- Every new strategy must implement at least:
  - `get_strategy_id()`
  - `get_signature_names()`
  - `plan_opening_setup()`
  - `score_action_absolute()`
  - `evaluate_board()`
  - `score_interaction_target()`
- `DeckStrategyRegistry` owns all family detection and deck-to-strategy mapping.
- Shared files with broad conflict risk stay on the main thread:
  - `scripts/ai/DeckStrategyRegistry.gd`
  - `tests/test_deck_strategy_contract.gd`
  - `tests/test_ai_strategy_wiring.gd`
  - any benchmark identity / registry expansion files

## Detection Policy

Detection should not depend on `deck_id` at runtime.

It should use signature-card names that are stable enough to distinguish the family from generic overlap. If a family cannot be detected from one name, use a small signature set and conservative ordering in the registry.

## Testing Requirements

Minimum required coverage per family:

- registry detection
- one opening/setup preference
- one high-priority action preference
- one interaction-target preference when the archetype has nontrivial target selection

Additional required coverage for special cases:

- spread / devolution / counter-placement decks
- copied-attack decks
- disruption / lock decks
- prompt-owned choices that can appear in headless matches

## Non-Goals

- value-net training for all new archetypes in this round
- new benchmark pipelines for every archetype
- generic data-driven strategy DSL
- unrelated AI balance work outside bundled deck support
