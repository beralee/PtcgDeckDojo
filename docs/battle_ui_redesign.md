# Battle UI Redesign

## Goals

1. Replace the current text-heavy battle presentation with real card art.
2. Use the cached local images from `CardData.image_local_path` everywhere the player inspects or selects cards.
3. Add right-click zoom so any visible card can be inspected at a large readable size.
4. Replace list-based card selection dialogs with horizontal card selection layouts for setup flow, effect interactions, discard inspection, and similar choice-heavy actions.
5. Keep the battle flow logic in `BattleScene.gd` intact while isolating UI concerns into reusable components.

## Current Problems

1. `BattleScene.tscn` is built around `Label`, `RichTextLabel`, and `ItemList`, so the field looks like a debug screen instead of a playable card game.
2. Hand, active slot, and bench all use different ad-hoc rendering code.
3. Right-click only opens a text detail modal; it does not show the actual card image.
4. Effect selection relies on `ItemList`, which is poor for item/supporter/ability choices that should be made visually from actual cards.
5. Cached card art exists on disk now, but the battle UI does not consume it.

## Visual Direction

1. Use the actual card image as the primary representation.
2. Keep information overlays minimal: selection glow, disabled tint, compact badges for HP/energy/status when needed.
3. Reserve text panels for logs, phase state, and compact counters only.
4. Use a table-like battlefield with clear zones:
   Opponent hand and field at top.
   Stadium and shared status band in center.
   Player field and hand at bottom.
   Deck/discard/prize counters on the sides.
5. Give choice dialogs a gallery/ribbon feel instead of a list box.

## New UI Building Blocks

### 1. `BattleCardView`

Reusable card art component for battle.

Responsibilities:

1. Render a card from `CardInstance` or `CardData`.
2. Load texture from `image_local_path`.
3. Support display modes:
   `hand`
   `slot_active`
   `slot_bench`
   `choice`
   `preview`
4. Support states:
   selected
   disabled
   clickable
   face_down
5. Emit left-click and right-click signals.

### 2. `CardPreviewOverlay`

Large modal preview used by right-click.

Responsibilities:

1. Show full card image centered.
2. Optionally show short metadata beside or below the image.
3. Close on button click, overlay click, or right-click.

### 3. `CardChoiceDialog`

Horizontal card chooser used by setup and effect interactions.

Responsibilities:

1. Render selectable card views in an `HBoxContainer` inside a `ScrollContainer`.
2. Support single-select and multi-select.
3. Support optional cancel.
4. Support non-card fallback items only when no `CardData`/`CardInstance` is available.

## Data and Loading Rules

1. Always prefer `CardData.image_local_path`.
2. If the local image is missing, show a styled placeholder panel with the card name.
3. Never fetch network images from battle UI; battle UI only reads local cache.
4. Keep `BattleScene` responsible for mapping game state to view models, not for low-level image loading.

## Interaction Rules

### Right-click preview

1. Right-clicking a hand card opens the large card image.
2. Right-clicking active or bench cards opens the same preview.
3. Right-clicking cards inside choice dialogs also opens the same preview.

### Card selection

1. Setup active/basic bench selection becomes horizontal card choices.
2. Effect choices that refer to cards become horizontal card choices.
3. Multi-select effects show selected glow and enable confirm when valid.
4. Non-card choices such as “cancel”, “finish setup”, or “skip extra draw” remain as compact buttons or utility cards in the same dialog footer.

## Execution Plan

### Phase 1: Core card-art components

1. Create `BattleCardView` with image loading and state styling.
2. Create preview overlay and wire right-click behavior.
3. Keep current battle layout intact during this phase.

### Phase 2: Main battlefield replacement

1. Replace hand text panels with `BattleCardView`.
2. Replace active and bench `RichTextLabel` displays with card-art slot views.
3. Keep side counters and log panel, but restyle the field container to support card art.

### Phase 3: Choice UI replacement

1. Replace `ItemList`-based dialog content with a card gallery when the choice data represents cards.
2. Use the same dialog for:
   setup active
   setup bench
   send out replacement
   retreat target selection
   effect interaction steps with card payloads
3. Keep a small text-only fallback for choices that are not cards.

### Phase 4: Polish

1. Improve spacing, background panels, and zone labels.
2. Tune card sizes for desktop and smaller widths.
3. Ensure all selection states remain readable.

## Code Touch Points

1. `scenes/battle/BattleScene.tscn`
2. `scenes/battle/BattleScene.gd`
3. `scenes/battle/CardUI.gd`
4. `scenes/battle/HandArea.gd`
5. `scenes/battle/PokemonSlotUI.gd`
6. New reusable scene/scripts under `scenes/battle/`

## Validation

1. Existing battle tests must still pass.
2. Hand, active, bench, and dialog selections must be operable by mouse only.
3. Right-click preview must work for hand, field, and dialog cards.
4. Cached images should appear for real imported cards without extra downloads.
