# Action Learning Framework Design

## Context

The current AI stack can improve through:

- heuristic weight evolution
- MCTS parameter tuning
- value network training on self-play state snapshots

This is enough to improve coarse play strength, but it does not teach the AI to make human-like action judgments. The clearest symptom is resource behavior: if a card is legal and has a positive heuristic score, the AI often plays it immediately instead of preserving it for a stronger future line.

There is also a separate blocking bug: the AI currently does not construct tool attachment actions at all, so Pokemon Tools such as Forest Seal Stone and Rescue Board are never used. That is not a training failure; it is a legality/action-construction gap and must be fixed before tool-related action learning can be meaningful.

## Problem

The current learning target is misaligned with the desired behavior.

- `phase1` learns better heuristic weights and MCTS parameters.
- `phase2` learns a state value network.
- Runtime action selection is still dominated by hand-authored action heuristics.

As a result, the system can learn that a board state is good or bad, but it still cannot reliably learn:

- whether a trainer should be held or spent now
- whether an ability should be used immediately or delayed
- whether a tool should be attached now or saved
- which energy attachment target is correct
- which attack is best in context

The project needs an action-level learning layer that can score legal actions based on future value, while preserving the existing legality engine, benchmark system, and versioned training pipeline.

## Goals

- Build a reusable action-learning framework that works across archetypes.
- Keep deck-specific training possible through pipeline-specific data selection.
- Deliver a minimum viable end-to-end loop:
  - record decision points
  - export action-learning samples
  - train an action scorer
  - version the resulting artifact
  - use it at runtime
- Improve judgment quality for the actions that most affect human-like play:
  - `play_trainer`
  - `use_ability`
  - `attach_tool`
  - `attach_energy`
  - `attack`

## Non-Goals

- Replace the full AI stack with an end-to-end policy model in this phase.
- Rewrite MCTS around a new planner in this phase.
- Introduce LLM online decision-making during live games.
- Solve full card-pool generalization in one step.
- Remove heuristics entirely in the first implementation.

## Approach Options

### Option 1: Keep extending heuristics

Add more features and continue tuning heuristic weights.

Pros:

- minimal engineering cost
- compatible with current pipeline

Cons:

- limited ceiling
- poor learning signal for "should I save this resource"
- hard to scale to many archetypes

### Option 2: Add a reusable action scorer on top of heuristics

Train a model that scores individual legal actions using state features plus action features, then combine that score with the existing heuristic score.

Pros:

- directly targets judgment quality
- fits the existing "enumerate legal actions, then score" flow
- can be introduced incrementally by action type

Cons:

- requires new decision-sample export
- requires runtime wiring and artifact management

### Option 3: Jump straight to full policy learning

Replace action ranking with a policy model over legal actions.

Pros:

- strongest long-term direction

Cons:

- too much surface area for the first iteration
- higher risk to existing training and runtime behavior

## Recommendation

Use Option 2 now and design the framework so it can evolve toward Option 3 later.

That means:

- build a reusable decision-sample pipeline
- train an `action_scorer`
- use it only on selected action types at first
- keep heuristic scoring as a fallback and stabilizer

## Existing Touchpoints

The first implementation should extend the current AI pipeline rather than introducing a parallel runtime.

Primary code touchpoints:

- `scripts/ai/AILegalActionBuilder.gd`
- `scripts/ai/AIFeatureExtractor.gd`
- `scripts/ai/AIHeuristics.gd`
- `scripts/ai/AIOpponent.gd`
- `scripts/ai/MCTSPlanner.gd`
- `scripts/ai/StateEncoder.gd`
- `scripts/training/train_loop.sh`
- `scripts/training/train_value_net.py`
- future `scripts/training/train_action_scorer.py`

Related systems to reuse:

- battle recording outputs (`detail.jsonl`, `turns.json`, `llm_digest.json`)
- benchmark summaries and anomaly archives
- AI version registry and training run registry

## Architecture

### 1. Decision Sample Export

Add a reusable export path that captures action-level training data from self-play and benchmark runs.

Each decision sample should record:

- `run_id`
- `match_id`
- `decision_id`
- `turn_number`
- `phase`
- `player_index`
- `pipeline_name`
- `deck_identity`
- `opponent_deck_identity`
- encoded `state_features`
- `legal_actions`
- `chosen_action`
- heuristic score per legal action
- MCTS ordering or selected-sequence metadata when available
- downstream outcome labels

Initial data sources:

- self-play
- benchmark runs

Future sources:

- human vs human battle records
- human vs AI battle records
- LLM or human coaching labels

First implementation boundary:

- training consumes AI self-play and benchmark decision points first
- battle-recording outputs should be schema-compatible where practical
- human-vs-human logs are a future source, not a blocker for the first training loop

### Decision Sample Schema

The exported unit should be a `decision sample`, not a whole-turn dump.

Each legal action entry should include:

- `action_index`
- `kind`
- normalized `action_features`
- normalized target metadata
- card / attack / ability identifiers when applicable
- heuristic score at decision time
- whether it was chosen
- whether it required interaction handling

Downstream labels should include:

- final game result from the acting player's perspective
- discounted return / future-value proxy
- optional tactical flags such as immediate KO, prize swing, improved attack readiness, and improved bench development

Schema requirements:

- compact enough to export at training scale
- stable enough for both Python training scripts and future battle-log postprocessors
- explicit enough to debug why a learned score disagrees with heuristic scoring

### 2. Action Feature Layer

Introduce a reusable action feature encoder separate from `StateEncoder`.

It should encode action semantics in a general format rather than hardcode per-card logic into the model input. Example categories:

- action type one-hot
- target role
- target active or bench flags
- attack metadata
- energy-readiness delta
- bench-development delta
- immediate prize or KO potential
- interaction-required flags
- resource-consumption tags

Archetype-specific usefulness should come from the combination of:

- shared state features
- shared action features
- pipeline-specific training data

not from duplicating the whole framework per deck.

First-pass supported action kinds:

- `play_trainer`
- `use_ability`
- `attach_tool`
- `attach_energy`
- `attack`

The encoder should emit one normalized vector shape even if some fields are action-kind-specific.

### 3. Action Scorer Training

Add a separate training script, for example:

- `scripts/training/train_action_scorer.py`

This remains independent from `train_value_net.py` but uses the same model and artifact conventions.

Inputs:

- state vector
- action vector

Outputs:

- scalar future-value estimate for that action in that decision context

Label strategy:

- primary label: action return / future value
- auxiliary signals:
  - chosen action flag
  - relative rank among legal actions
  - tactical short-term outcomes such as improved attack readiness or immediate KO

This keeps the model focused on "which legal action is best here," not merely "which action happened."

Model expectations for v1:

- small MLP consistent with the current value-net scale
- CPU/GPU support aligned with existing training scripts
- artifact format light enough for runtime loading without introducing a new heavyweight integration path

### 4. Runtime Scoring

At runtime, the action scorer is applied only to a narrow set of action kinds:

- `play_trainer`
- `use_ability`
- `attach_tool`
- `attach_energy`
- `attack`

All other actions continue to use the current heuristic-only path initially.

Scoring flow:

- build legal actions
- compute heuristic score
- if action kind is action-scorer-enabled and a model is loaded:
  - compute learned action score
  - combine with heuristic score
- choose by the combined score

Initial combination rule:

- `combined_score = heuristic_score + learned_action_score * learned_weight`

The combination weight should be configurable so rollout behavior can be tuned without retraining.

Runtime fallback rules:

- if no action scorer artifact is loaded, behavior stays on the current heuristic path
- if an action kind is not enabled for learned scoring, it stays heuristic-only
- if action features cannot be built for a legal action, that action falls back to heuristic-only and records a debug reason

The first implementation should wire the learned score into heuristic selection before attempting deeper MCTS integration changes.

### 5. Artifact and Version Wiring

Training artifacts should expand from:

- `agent config`
- `value net`

to:

- `agent config`
- `value net`
- `action scorer`

Version and run records should therefore support:

- `action_scorer_path`
- action scorer training metadata
- whether runtime scoring used the action scorer
- scorer configuration such as enabled action kinds and learned-weight scaling

This keeps the current playable-version system intact while making action-level models first-class artifacts.

## Training Pipelines

The framework is reusable, but pipeline selection remains archetype-specific.

Examples:

- `miraidon_focus_training`
- future `gardevoir_focus_training`
- future mixed fixed-pool training

The framework stays shared; what changes by pipeline is:

- which decks generate the decision samples
- which benchmark cases gate promotion
- which archetype-specific action distributions the model sees most often

## Tool Bug Prerequisite

Before meaningful action-scoring evaluation can happen for tools, the AI must be able to generate and execute tool attachment actions.

Required fix:

- add `attach_tool` legal action construction
- route it through runtime execution
- ensure tool-granted abilities such as Forest Seal Stone can then appear through the normal ability action path

This is a prerequisite bugfix, not a training improvement.

Concrete first-pass expectation:

- `AILegalActionBuilder` must enumerate `attach_tool` actions against valid player slots
- `AIOpponent` must be able to execute `attach_tool`
- tool-granted abilities should then surface naturally through existing ability action enumeration after the tool is attached
- focused regression coverage should include at least one ordinary tool and one tool-granted ability path

## Data Flow

### During self-play / benchmark

1. Enumerate legal actions.
2. Build per-action features and heuristic scores.
3. Record chosen action and available alternatives.
4. Record downstream outcome.
5. Export decision samples.

### During training

1. Load exported decision samples.
2. Train action scorer.
3. Save artifact in versioned model directory.

### During runtime

1. Load current agent config.
2. Load optional value net.
3. Load optional action scorer.
4. Use combined action scoring on enabled action kinds.

## Testing Strategy

This work should avoid heavy AI training test suites.

Focused validation only:

- legal action builder tests for `attach_tool`
- runtime execution tests for AI tool attachment
- decision-sample exporter unit tests
- action feature encoder tests
- action scorer trainer smoke tests on tiny datasets
- runtime scoring tests for selected action kinds
- regression tests for tool attachment action generation
- version registry tests for `action_scorer_path`
- battle-recording compatibility tests only where schema reuse is touched

No long-running end-to-end training validation is required for the first implementation pass.

Test discipline:

- prefer focused Godot suite runs and small Python smoke tests
- do not invoke the long-running AI training validation suites as part of this feature pass
- keep runtime verification centered on legality, scoring integration, artifact wiring, and small deterministic fixtures

## Rollout Plan

### Phase A: Prerequisite fix

- fix `attach_tool` action generation and execution
- verify tool-granted ability visibility after attachment

### Phase B: Decision data layer

- export legal action sets and chosen actions from self-play / benchmark
- define and persist the reusable decision-sample schema

### Phase C: Training artifact

- add `train_action_scorer.py`
- train on compact decision datasets
- version and persist the resulting scorer artifact

### Phase D: Runtime integration

- load action scorer
- apply to the selected action kinds
- keep heuristic-only fallback for unsupported or unloaded cases

### Phase E: Versioning

- store and expose `action_scorer_path` in run/version metadata

## Success Criteria

The first version is successful if:

- the AI can legally use tools
- decision samples are exported from self-play and benchmark runs
- an action scorer artifact can be trained and loaded
- runtime action scoring affects the selected action kinds
- the system remains compatible with the current versioned training pipeline
- manual playtesting shows fewer obviously wasteful resource plays on supported action types
