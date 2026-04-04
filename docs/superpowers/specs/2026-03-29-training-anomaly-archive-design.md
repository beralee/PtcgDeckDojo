# Training Anomaly Archive Design

## Goal

Record non-normal training match terminations in a structured, queryable format so long-running self-play and benchmark jobs can be diagnosed after the fact.

## Scope

This design covers:

- phase1 self-play anomaly aggregation
- phase3 benchmark anomaly aggregation
- representative anomaly sample retention
- run-level anomaly summary files
- benchmark-time run record backfill with anomaly summary metadata

This design does not add new gameplay rules, new failure reasons, or live UI visualizations beyond existing dashboard consumption of generated files.

## Problem

Current training logs expose failures such as `action_cap_reached`, `stalled_no_progress`, and unsupported interaction failures only as transient text or benchmark aggregates. That makes it hard to answer:

- which failure reasons dominate a run
- which deck pairings reproduce them
- whether phase1 and phase3 fail in the same way
- which exact sample games should be inspected to fix missing rules or AI behaviors

## Design

### 1. Dedicated anomaly archive helper

Add a focused helper that:

- accepts raw match result arrays plus run metadata
- counts anomalies by phase, failure reason, pairing, lane, and generation
- keeps representative samples capped per `failure_reason + pairing`
- reads and writes JSON summaries
- merges phase1 and phase3 summaries into a run-level archive

The helper should treat only non-empty `failure_reason` values other than `normal_game_end` as anomalies.

### 2. Phase1 capture

`EvolutionEngine` already sees per-generation `match_results`. It should feed them into the anomaly helper while the generation loop runs and write `phase1_anomalies.json` at the end of the run.

Required metadata per recorded sample:

- `phase`
- `run_id`
- `lane_id`
- `generation`
- `pairing`
- `deck_a_id`
- `deck_b_id`
- `seed`
- `winner_index`
- `failure_reason`
- `terminated_by_cap`
- `stalled`

### 3. Phase3 capture

`BenchmarkRunner` already has structured per-case benchmark results. It should build a phase3 anomaly summary from the underlying raw matches and merge it with the optional phase1 anomaly file into a final `anomaly_summary.json`.

### 4. Sample retention policy

Representative samples should be stored as:

- grouped by `failure_reason`
- then by `pairing`
- keeping the first `3` samples for each group

This balances coverage and file size.

### 5. Run record backfill

When benchmark runs complete, the run registry record should be patched with:

- `anomaly_summary_path`
- `anomaly_summary`
- `anomaly_count`
- `anomaly_failure_counts`
- `has_stalled_anomalies`
- `has_cap_anomalies`

If a training iteration exits before benchmark, the run directory should still retain the phase1 anomaly file for later manual inspection.

## Data Shape

Run-level anomaly summary should include:

- `schema_version`
- `total_anomalies`
- `phase_counts`
- `failure_reason_counts`
- `pairing_counts`
- `lane_counts`
- `generation_counts`
- `samples`

Each sample entry should be self-contained enough to locate the originating run context without reopening raw logs.

## Integration Points

- `scripts/ai/TrainingAnomalyArchive.gd`: new helper
- `scripts/ai/EvolutionEngine.gd`: phase1 aggregation and write-out
- `scenes/tuner/TunerRunner.gd`: parse and pass anomaly output path
- `scenes/tuner/BenchmarkRunner.gd`: phase3 aggregation, merge, final write-out, run record patch
- `scripts/training/train_loop.sh`: pass phase1 and final anomaly output paths

## Testing

Add focused coverage for:

- summary aggregation by failure reason and pairing
- representative sample capping
- summary merging across phase1 and phase3
- phase1 anomaly file generation
- benchmark-time run record anomaly metadata patching

## Risks

- Match result schemas differ slightly between phase1 and phase3. The helper must normalize missing optional fields.
- Large runs can generate many anomalies. Sample retention must remain capped.
- Existing training logs must remain readable and should not depend on anomaly generation succeeding.
