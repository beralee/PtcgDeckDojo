# Deck Strategy Iteration Skill Design

## Goal

Create a new `.claude` skill dedicated to iterative improvement of existing deck-specific rule strategies in this repo. The skill should guide a model-driven loop that keeps refining a deck's strategy against Miraidon until the benchmark is both clean and above a fixed win-rate gate.

## Why A New Skill

`deck-strategy-design` already covers first-time strategy creation and unified-architecture compliance. It is the wrong place for repeated benchmark-driven tuning because:

- it mixes initial design with later optimization
- it does not enforce repeated benchmark loops
- it does not define a hard completion gate for low-performing decks

The new skill should only handle post-design iteration on already-existing `DeckStrategy*.gd` files.

## Scope

### In Scope

1. Existing deck strategy refinement only.
2. Benchmark-driven iteration against Miraidon.
3. Re-reading decklists and key card effects every round.
4. Root-cause analysis from matchup results and game-flow evidence.
5. Mandatory red-test-before-fix workflow.
6. Mandatory fresh benchmark rerun after each iteration.
7. Hard completion gate:
   - benchmark must be clean
   - win rate must be `>45%`

### Out Of Scope

1. First-time strategy design.
2. Single-card effect debugging that does not change deck-level strategic behavior.
3. New value nets, encoders, exporters, or training pipelines.
4. Matchup-specific hardcoding against Miraidon unless a human explicitly asks for that.

## Skill Name

`deck-strategy-iteration`

## Trigger Conditions

Use this skill when:

- a deck already has a `DeckStrategy*.gd`
- the deck underperforms versus Miraidon
- benchmark results show the deck's opening, transition, conversion, trainer timing, energy routing, or target selection is still strategically wrong
- a user wants continued iterative refinement, not first-pass design

Do not use it for new strategy scaffolding. That remains owned by `deck-strategy-design`.

## Core Principle

This is a hard-loop skill, not a coaching note.

The model must not stop at "better than before." It must keep iterating until:

1. the fresh Miraidon benchmark is clean
2. the deck's Miraidon win rate is above `45%`

If either condition fails, the skill requires another reflection and optimization round.

## Iteration Loop

Each round must follow this sequence:

1. Read the decklist.
2. Re-read key card effects and strategic roles.
3. Read the current `DeckStrategy*.gd`.
4. Read the latest Miraidon benchmark report and per-game details.
5. Classify the main failure mode.
6. Choose only the highest-value one or two root causes for this round.
7. Write a failing focused or headless regression test.
8. Implement the minimum strategy change needed.
9. Run the focused suite.
10. Run a fresh Miraidon benchmark.
11. Judge both win rate and result cleanliness.
12. If `<=45%` or dirty benchmark, loop again.

## Root Cause Buckets

The skill should require each round to explicitly categorize the dominant issue as one of:

- opening failure
- transition delay
- conversion / finisher failure
- trainer timing
- energy routing
- target selection
- benchmark pollution

This prevents unfocused "weight tweaking everywhere."

## Hard Rules

The skill must state these as non-negotiable:

- Do not treat a small sample like `10` games as final evidence.
- Do not skip decklist review or card-text review.
- Do not skip writing a failing test for the chosen failure mode.
- Do not claim success without a fresh benchmark.
- Do not accept `unsupported_prompt`, `unsupported_interaction_step`, `action_cap_reached`, or `stalled` as a valid result.
- Do not declare the iteration complete while Miraidon win rate is `<=45%`.
- Do not use Miraidon-specific hardcoded counter-logic unless the human explicitly asks for matchup-specific tuning.

## Structure

The new skill should stay small and focused:

1. `Overview`
2. `When To Use`
3. `Do Not Use For`
4. `Hard Gate`
5. `Iteration Loop`
6. `Root Cause Buckets`
7. `Required Verification`
8. `Completion Rule`

## Relationship To Existing Skills

- `deck-strategy-design`: first-pass creation and unified architecture
- `deck-strategy-iteration`: repeated post-design benchmark-driven refinement
- `card-audit`: card-effect correctness
- `training-pipeline`: training / benchmark run trustworthiness

The new skill should cross-reference these without duplicating their full workflows.

## Acceptance Criteria

1. A new skill exists at `.claude/skills/deck-strategy-iteration/SKILL.md`.
2. Its description clearly signals iterative improvement of existing strategies.
3. It defines the `>45%` hard completion gate.
4. It requires fresh Miraidon benchmark evidence before success claims.
5. It clearly distinguishes itself from `deck-strategy-design`.
