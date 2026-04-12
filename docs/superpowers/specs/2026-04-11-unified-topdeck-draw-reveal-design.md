# Unified Top-Deck Draw Reveal Design

Date: 2026-04-11

## Goal

Extend the existing draw-reveal animation so every card effect that draws cards directly from the top of the deck into hand uses the same reveal flow as `Professor's Research`.

This pass is about consistency, not rules changes:
- drawn cards should continue resolving through existing rules logic
- reveal animation should reuse the current battle draw-reveal controller
- human-controlled reveals should wait for click
- AI-controlled reveals should auto-continue

## Scope

### In Scope

- all card-originated top-deck draw effects that currently call `player.draw_card()` or `player.draw_cards()` directly
- trainer, ability, attack, special-energy, and stadium effects that draw from deck to hand
- single-card draws and multi-card draws
- draw-to-N and draw-to-hand-size effects
- shuffle-then-draw effects, as long as the draw still comes from the top of deck
- preserving exact card identity in `DRAW_CARD` action payloads so the reveal UI shows the real cards

### Out of Scope

- setup opening draw
- mulligan redraw and bonus draws
- normal turn-start draw
- search deck to hand effects
- look-at-top-cards then choose one effects
- discard/recovery to hand effects
- prize-taking flow

Those system draws already have their own engine path. This spec only expands card-effect-driven top-deck draws.

## Effect Families To Cover

The current direct-draw callers are:

### Trainer Effects

- `EffectDrawCards`
- `EffectIono`
- `EffectRoxanne`
- `EffectShuffleDrawCards`
- `EffectSerena`
- `EffectCarmine`
- `EffectMela`
- `EffectSadasVitality`
- `EffectTrekkingShoes`
- `EffectUnfairStamp`

### Pokemon Effects

- `AbilityAttachBasicEnergyFromHandDraw`
- `AbilityBonusDrawIfActive`
- `AbilityDiscardDraw`
- `AbilityDiscardDrawAny`
- `AbilityDrawCard`
- `AbilityDrawIfActive`
- `AbilityDrawIfKnockoutLastTurn`
- `AbilityDrawToN`
- `AbilityEndTurnDraw`
- `AbilityFirstTurnDraw`
- `AbilityRunAwayDraw`
- `AbilityShuffleHandDraw`
- `AbilityThunderousCharge`

### Attack Effects

- `AttackDiscardHandDrawCards`
- `AttackDrawTo7`
- `AttackDrawToHandSize`
- `AttackReadWindDraw`

### Special Energy / Stadium Effects

- `EffectGiftEnergy`
- `EffectSpecialEnergyOnAttach`
- `EffectStadiumDraw`

## Recommended Approach

Use a shared draw helper instead of patching each effect with ad-hoc `DRAW_CARD` logging.

### Why This Approach

- the reveal UI already listens to `DRAW_CARD` actions
- the current gap exists because many effects bypass `GameStateMachine.draw_card()`
- patching 29 draw call sites with custom logging would be fragile and easy to miss later
- a shared helper gives one place to preserve exact drawn cards, names, and count

## Architecture

### 1. Central Draw Logging Helper

Add a `GameStateMachine` helper dedicated to card-effect-driven draws, for example:

- `draw_cards_for_effect(player_index, count, source_card := null, source_kind := "")`

Responsibilities:
- draw from the real player deck
- return the real drawn cards
- emit one `DRAW_CARD` action containing:
  - `count`
  - `card_names`
  - `drawn_cards`
  - optional source metadata for debugging

This helper should not change reveal policy itself. It only guarantees draw metadata exists.

### 2. EffectProcessor Bridge

Many effects currently only receive `GameState`, not `GameStateMachine`.

Recommended bridge:
- let `EffectProcessor` hold an optional `game_state_machine` reference
- set that reference from `GameStateMachine` during construction / reset
- expose a tiny helper like `effect_processor.draw_cards_with_log(...)`

This keeps effect scripts thin:
- if a GSM bridge exists, use it
- otherwise fall back to direct `player.draw_cards()` for isolated tests that intentionally do not build a full machine

### 3. UI Reuse

Do not add a second reveal system.

Keep `BattleDrawRevealController` as the only presentation layer:
- new covered effects only need to start producing proper `DRAW_CARD` actions
- existing reveal queueing, human click wait, AI auto-continue, and layout behavior stay unchanged

## Data Flow

### Before

`effect.execute()` -> `player.draw_card(s)` -> hand mutates -> no exact `DRAW_CARD` action -> no reveal

### After

`effect.execute()` -> shared draw helper -> hand mutates -> exact `DRAW_CARD` action logged -> `BattleScene` enqueues reveal -> reveal completes -> hand UI refreshes

## Behavior Notes

### Single Draw

Effects that draw one card should use the same single-card reveal as turn-start draw:
- deck to center
- face-up at `2x`
- click to continue for human
- timed auto-continue for AI

### Multi-Draw

Effects that draw multiple cards should use the same batch reveal as `Professor's Research`:
- sequential reveal from deck
- face-up batch layout
- one confirmation for the full batch on human side
- timed auto-continue for AI side

### Draw-To-N / Draw-To-Hand-Size

These remain eligible:
- reveal only the actual number of cards drawn
- if the player already has enough cards and draws zero, no reveal should enqueue

### Shuffle-Then-Draw

These remain eligible:
- shuffle first using existing rules
- reveal the cards actually drawn after the shuffle

## Testing Strategy

### Engine Tests

Add focused tests proving the shared helper emits correct `DRAW_CARD` metadata for:
- fixed-count draw
- draw-to-N
- zero-draw no-op
- shuffle-then-draw

### UI Tests

Add focused reveal-routing tests proving representative cards now enqueue reveal:
- trainer: `Iono` or `Roxanne`
- ability: `AbilityDrawCard` or `AbilityThunderousCharge`
- attack: `AttackDrawTo7` or `AttackReadWindDraw`
- conditional single draw: `Trekking Shoes`
- triggered draw: `Gift Energy`

### Regression Goal

After this pass:
- every in-scope top-deck card draw should visibly reveal
- no out-of-scope search/look/recover effects should accidentally start using draw reveal

## Risks

### Partial GSM Coverage

Some tests instantiate effects without a full `GameStateMachine`.

Mitigation:
- keep the shared helper bridge optional
- fall back to direct draw in narrow unit tests where action logging is irrelevant

### Double Logging

If an effect already logs draw metadata elsewhere, routing through the shared helper could duplicate reveal.

Mitigation:
- remove ad-hoc special cases once the shared helper covers them
- keep one reveal-producing `DRAW_CARD` action per actual draw resolution

### Multi-Step Effects

Effects like `Serena`, `Mela`, and `Trekking Shoes` mix discard/attach/choice flow with later draw.

Mitigation:
- only replace the final draw call site
- keep the rest of each interaction chain unchanged

## Recommendation

Implement this as one shared draw-logging path plus targeted updates at each direct draw call site.

That keeps the UI behavior consistent, avoids scattering custom reveal logic across 29 scripts, and makes future top-deck draw cards automatically easier to wire up.
