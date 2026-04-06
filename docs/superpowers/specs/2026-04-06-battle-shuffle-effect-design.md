# Battle Shuffle Effect Design

**Date:** 2026-04-06

## Goal

Add a 1 second shuffle effect during battle so the deck pile visibly shakes when that player's deck is shuffled.

## Approved Behavior

- Only the shuffled player's deck pile animates.
- The effect lasts 1 second.
- If the same player shuffles again before the current effect finishes, the effect restarts from the beginning.
- The effect is visual-only and must not change battle logic or input flow.

## Recommended Approach

Implement the effect in `BattleScene` on top of the existing deck HUD/preview nodes.

This keeps the change out of `PlayerState.shuffle_deck()`, effect scripts, and recorder logic. The scene already owns pile presentation, so it is the safest place to add a local visual response.

## Detection Strategy

Track a deck-order signature per player inside `BattleScene`.

- Each UI refresh computes the current deck signature from the ordered deck contents.
- Compare the new signature with the previous one for that player.
- Trigger the effect only when the deck contents are the same set of cards but the order changed.

This avoids false positives for common non-shuffle actions:

- drawing cards
- searching cards out of the deck
- milling
- placing cards on top of the deck

Those actions change deck size or composition and should not play the shuffle animation.

## Animation Design

Animate the existing deck preview node, not the count label.

- Use a lightweight tween-based shake on local position.
- Keep the amplitude small so the pile reads as "shuffling" rather than "taking damage".
- Restore the node to its original position after the tween finishes.
- On restart, kill the previous tween, snap back to the base position, then start a fresh 1 second shake.

## Scene Responsibilities

`BattleScene.gd` gains:

- previous deck signatures for each player
- active shuffle tween handles for each player
- base positions for the animated deck preview nodes
- a helper such as `_play_deck_shuffle_effect(player_index)`
- a signature comparison helper that distinguishes reorder from size/content changes

No changes are required in:

- `PlayerState`
- `GameStateMachine`
- per-card effect scripts
- battle recording / replay data formats

## Error Handling

- If the target deck preview node is missing, hidden, or already freed, skip the effect quietly.
- If the scene refresh runs before deck previews are initialized, update the cached signature without animating.
- If the battle is ending or the scene is exiting, kill any running tween and restore the node position.

## Testing

Add focused coverage for:

- shuffle triggers effect for the correct player only
- draw/search actions do not trigger the effect
- repeated shuffle on the same player restarts the 1 second animation
- deck preview position is restored after the animation completes

Manual verification should include a normal search-then-shuffle trainer play in battle and confirm that only the shuffled side's deck pile shakes.

## Non-Goals

- No particle effects, card spread, or deck flip animation
- No animations for discard, prizes, lost zone, or hand
- No changes to shuffle rules, randomness, or battle timing
