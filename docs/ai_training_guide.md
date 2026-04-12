# AI Decision Training Guide

This document describes the current training architecture for the PTCG AI.
It replaces the old "value-net only" view of training with the run-scoped
decision-training pipeline that now drives Miraidon and Gardevoir.

If a future run does not follow this document, treat it as a local experiment,
not a promotable training result.

## Current Default

Promotable training now means:

1. Collect run-scoped self-play and decision data.
2. Train three artifacts from that run:
   - value net
   - action scorer
   - interaction scorer
3. Benchmark the full candidate stack against the current approved baseline.
4. Publish only if the benchmark gate passes and the run is clean.

Current authoritative entrypoints:

- `scripts/training/run_decision_training.ps1`
- `scripts/training/run_decision_training.sh`
- `scripts/training/gardevoir_decision_training_v3.ps1`
- `scripts/training/miraidon_decision_training_v3.ps1`

## Why The Old Flow Was Not Enough

The older training flow had three structural problems:

- value training mostly learned "what winning states look like", not "which
  concrete decision was better"
- action training mostly imitated the action already chosen by the current AI
- interaction target choice was not part of the learned pipeline

The current architecture fixes that by exporting richer decision traces,
training action and interaction scorers, and using counterfactual action
teachers from the live planner.

## Learned Artifacts

Each promotable run now trains a full decision stack:

- `value_net`
  - scores board states
  - is used by MCTS and benchmark/runtime evaluation
- `action_scorer`
  - ranks top-level legal actions
  - covers the full decision surface used by the live AI
- `interaction_scorer`
  - ranks prompt-owned targets and subsets
  - is used to learn fine-grained search, assignment, discard, and target
    selection

Legacy "value net only" training is no longer the default.

## Decision Coverage

Action training is intended to cover the full main-action surface, not a narrow
"at least these few actions" subset.

Current covered action kinds:

- `play_trainer`
- `play_stadium`
- `play_basic_to_bench`
- `evolve`
- `use_ability`
- `attach_tool`
- `attach_energy`
- `retreat`
- `attack`
- `granted_attack`
- `end_turn`

Interaction training covers prompt-owned choices such as:

- search targets
- assignment targets
- discard selection
- damage / counter distribution targets
- effect-owned selection subsets

If a new gameplay decision exists but is not exported into this training loop,
the architecture is incomplete until that gap is closed.

## Data And Teachers

### Self-play / decision export

Collection is done through:

- `res://scenes/tuner/ValueNetDataRunner.tscn`

Exports now include:

- full self-play state records
- top-level decision samples
- interaction choice samples
- dirty-match metadata and sample quality information

### Value training

Value training now uses:

- grouped train/validation split by match, not random record split
- `winner_only=false`
- dirty-match filtering by default
- optional decision/interaction state blending
- weighted targets through match-quality signals

Relevant script:

- `scripts/training/train_value_net.py`

### Action training

Action training no longer uses "chosen action + outcome" as its primary teacher.

The current teacher order is:

1. exported counterfactual single-step teacher from `MCTSPlanner`
2. normalized post-action value
3. normalized value delta vs the pre-action baseline
4. heuristic fallback only when teacher data is unavailable

Relevant files:

- `scripts/ai/MCTSPlanner.gd`
- `scripts/ai/AIOpponent.gd`
- `scripts/ai/AIDecisionSampleExporter.gd`
- `scripts/training/train_action_scorer.py`

### Interaction training

Interaction training is trained from exported prompt-choice samples and uses
strategy-first / result-second targets instead of a crude chosen-action bonus.

Relevant files:

- `scripts/ai/AIInteractionFeatureEncoder.gd`
- `scripts/ai/AIInteractionScorer.gd`
- `scripts/training/train_interaction_scorer.py`

## Runtime Wiring

The trained artifacts are only meaningful if runtime and benchmark use the same
AI wiring.

Required properties:

- AI must be created through `AIOpponent.set_deck_strategy()`
- live battle and headless benchmark must use the same strategy injection path
- benchmark must actually load:
  - candidate value net
  - candidate action scorer
  - candidate interaction scorer
- negative or weak learned scorers must be runtime-gated, not blindly forced on

Key files:

- `scripts/ai/AIOpponent.gd`
- `scripts/ai/AIActionScorer.gd`
- `scripts/ai/AIInteractionScorer.gd`
- `scripts/ai/AIBenchmarkRunner.gd`
- `scripts/ai/HeadlessMatchBridge.gd`
- `tests/AITrainingRunnerScene.gd`
- `scenes/battle/BattleScene.gd`

## Promotable Run Shape

Every promotable run must be run-scoped.

Required run layout:

- `user://training_data/<deck>/runs/<run_id>/round_XX/self_play/`
- `user://training_data/<deck>/runs/<run_id>/round_XX/action_decisions/`
- `user://training_data/<deck>/runs/<run_id>/round_XX/models/`
- `user://training_data/<deck>/runs/<run_id>/round_XX/benchmark/`
- `user://training_data/<deck>/runs/<run_id>/current_best/`

Promotion is allowed only through `BenchmarkRunner`, `TrainingRunRegistry`, and
`AIVersionRegistry`.

Do not treat raw artifacts written directly to `user://ai_agents/` as
authoritative unless they were synced there by a passed run.

## Commands

### Start a deck-specific training run

Gardevoir:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/training/gardevoir_decision_training_v3.ps1
```

Miraidon:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/training/miraidon_decision_training_v3.ps1
```

### Start a custom run

```powershell
powershell -ExecutionPolicy Bypass -File scripts/training/run_decision_training.ps1 `
  -DeckName "gardevoir" `
  -DeckPrefix "gardevoir" `
  -Encoder "gardevoir" `
  -PipelineName "gardevoir_focus_training" `
  -PipelineSuffix "gardevoir_focus" `
  -OptimizedDeck 578647 `
  -Opponents @(575720, 575716, 569061) `
  -Rounds 4 `
  -TimeBudgetSeconds 7200
```

Unix-like shell:

```bash
DECK_NAME=gardevoir \
DECK_PREFIX=gardevoir \
ENCODER=gardevoir \
PIPELINE_NAME=gardevoir_focus_training \
PIPELINE_SUFFIX=gardevoir_focus \
OPTIMIZED_DECK=578647 \
OPPONENTS="575720 575716 569061" \
bash scripts/training/run_decision_training.sh
```

## Clean Run Checklist

Before interpreting win rate, confirm all of these:

- run artifacts are isolated under one `run_id`
- benchmark summary exists
- anomaly summary exists when expected
- no mixed logs from another run
- no shared-path candidate overwrite
- benchmark did not rely on legacy direct strategy wiring
- failure reasons do not include:
  - `unsupported_prompt`
  - `unsupported_interaction_step`
  - `action_cap_reached`
  - `stalled`

If a run fails this checklist, the result is not promotable.

## Promotion Rules

Loss alone never promotes a model.

Current promotion contract:

1. candidate stack trains successfully
2. benchmark summary is present
3. benchmark gate passes
4. run is clean
5. artifacts are registered through run/version registries

Recommended validation after a pass:

- baseline regression smoke
- `100`-game matchup sanity check on the main target pool
- review of action and interaction metrics

## Legacy Scripts And Boundaries

These scripts are now legacy or local-experiment surfaces:

- `scripts/training/overnight_5deck.sh`
- `scripts/training/overnight_remaining3.sh`
- `scripts/training/overnight_gardevoir_v2.sh`
- `scripts/training/overnight_miraidon_v2.sh`
- `scripts/training/train_loop.sh`

Do not use them as the default path for future promotable training.

Reasons:

- they do not represent the full decision-training stack
- some older variants only trained value nets
- some older variants could overwrite shared artifacts directly
- they do not consistently enforce the current benchmark contract

They are acceptable only for local debugging or historical comparison.

## What To Check When Training Does Not Improve

Check this order:

1. Did the benchmark load the candidate value net, action scorer, and
   interaction scorer?
2. Did the run export dirty-match metadata and filter bad games?
3. Are action metrics improving against heuristic ranking?
4. Is interaction learning still weaker than the rule strategy and being gated
   low at runtime?
5. Is the deck actually using the learned path in benchmark, or mostly falling
   back to rule logic?
6. Are the matchups too narrow, causing overfitting?

Do not conclude "training failed" from validation loss alone.

## Current Ground Truth For Future Work

When starting new training work in this repo, assume all of the following:

- the default training architecture is decision training, not value-only
- a complete candidate is `value + action + interaction`
- benchmark and promotion are run-scoped
- legacy overnight scripts are not the source of truth
- new decision types must be added to export, training, and runtime together
- future training documentation and automation should extend this architecture,
  not fork away from it
