# Battle Status HUD Redesign

## Goal

Replace the old dark overlay slabs under battle-zone cards with a dedicated 4-row status HUD that sits inside the visible card area and reads cleanly against the new battlefield background.

This redesign applies to:

1. Active Pokemon on both sides.
2. Bench Pokemon on both sides.
3. Any card-choice dialog item backed by `PokemonSlot`.

It does not replace the hand-card subtitle system in this phase.

## Problems Being Solved

1. The current field cards still rely on a bottom dark info slab that visually extends below the card and clashes with the new battlefield art.
2. Field cards and `PokemonSlot` choice dialogs do not have a dedicated visual status system; they still use a compact text subtitle.
3. Energy attachments are shown as text only, which wastes the energy icons already added to `assets/ui`.
4. The visual language for field state is not yet isolated as a reusable system.

## Target Visual Structure

Each battle-zone card gets a HUD anchored near the lower portion of the visible card art.

The HUD is composed of 4 rows:

1. HP text row:
   Format `current/max`, for example `50/100`.
2. HP bar row:
   A horizontal bar inspired by fighting-game health bars.
   The fill ratio is `current_hp / max_hp`.
3. Energy icon row:
   One icon per attached/provided energy unit.
   Icons are laid out horizontally.
   If a special energy provides multiple units, repeat the icon by provided count.
4. Tool row:
   Tool name only.
   Use dark compact text over a lighter translucent strip.

If a row has no content:

1. HP text and HP bar always render for Pokemon cards on field.
2. Energy row is hidden when there is no attached energy.
3. Tool row is hidden when there is no attached tool.

## Resource Mapping

Energy icons live under `assets/ui/` and are mapped by energy code:

1. `R` -> `res://assets/ui/e-huo.png`
2. `W` -> `res://assets/ui/e-shui.png`
3. `G` -> `res://assets/ui/e-cao.png`
4. `L` -> `res://assets/ui/e-lei.png`
5. `P` -> `res://assets/ui/e-chao.png`
6. `F` -> `res://assets/ui/e-dou.png`
7. `D` -> `res://assets/ui/e-e.png`
8. `M` -> `res://assets/ui/e-gang.png`
9. `N` -> `res://assets/ui/e-long.png`
10. `C` -> `res://assets/ui/e-wu.png`

If an icon is missing, fall back to a compact text chip for that energy type.

## Component Design

### `BattleCardView`

`BattleCardView` becomes the owner of the status HUD.

New responsibilities:

1. Keep the existing card-art rendering and selection behavior.
2. Support a `battle_status` payload for field-style overlays.
3. Render a dedicated 4-row HUD instead of the old two-line title/subtitle block when `battle_status` is active.

New API shape:

1. `clear_battle_status()`
2. `set_battle_status(data: Dictionary)`

Expected data format:

1. `hp_current: int`
2. `hp_max: int`
3. `hp_ratio: float`
4. `energy_icons: PackedStringArray`
5. `tool_name: String`

### `BattleScene`

`BattleScene` remains responsible for translating `PokemonSlot` into HUD data.

New responsibilities:

1. Build a battle-status dictionary from `PokemonSlot`.
2. Feed the same dictionary to:
   field active slots
   field bench slots
   `PokemonSlot` dialog cards
3. Remove reliance on `_slot_overlay_text()` for any visual card HUD that represents an in-play Pokemon.

## Behavior Rules

1. Field cards use the 4-row HUD only.
2. `PokemonSlot` dialog cards use the same 4-row HUD only.
3. Plain `CardInstance` or `CardData` dialog cards keep the normal title/subtitle presentation.
4. Empty field slots keep no info overlay.
5. The field slot container itself should remain visually neutral when occupied so only the card and HUD are visible.

## Execution Plan

### Phase 1. Specification and asset mapping

1. Add this design doc.
2. Map energy types to icon resources.

### Phase 2. `BattleCardView` HUD system

1. Add a dedicated status HUD container.
2. Add HP text row.
3. Add HP bar row.
4. Add energy icon row.
5. Add tool row.
6. Add API to toggle between normal info mode and battle-status mode.

### Phase 3. Field integration

1. Replace field subtitle text usage with `set_battle_status()`.
2. Keep empty slots on `clear_battle_status()`.
3. Keep occupied slot background transparent.

### Phase 4. Dialog integration

1. Feed the same HUD data into any `PokemonSlot` dialog card.
2. Ensure bench-selection dialogs visually match the field cards.

### Phase 5. Validation

1. Load `BattleScene.tscn` headless without parse errors.
2. Run the existing test suite.
3. Manually verify:
   field cards no longer show the old dark bottom slab
   HP text and HP bar render correctly
   energy icons repeat correctly
   tool row appears only when a tool is attached
   `PokemonSlot` dialogs match field cards

## Risks

1. Existing dialog cards that are not `PokemonSlot` must keep their current title/subtitle behavior.
2. The HUD must not block mouse input.
3. Energy icon rows can overflow if not size-limited, so icon size and separation must be clamped.
4. Imported card art varies in brightness, so HUD strip backgrounds should stay translucent but readable.
