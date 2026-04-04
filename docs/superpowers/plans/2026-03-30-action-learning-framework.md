# Action Learning Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable action-learning framework that fixes AI tool usage first, exports action-level decision samples, trains an action scorer, and uses it at runtime for selected action kinds without invoking heavy AI training suites.

**Architecture:** Keep the existing legality engine, heuristic scorer, MCTS, value-net pipeline, and version registry. Add one new action-sample data path plus one new action-scorer artifact, then let runtime combine learned action scores with heuristic scores only for `play_trainer`, `use_ability`, `attach_tool`, `attach_energy`, and `attack`.

**Tech Stack:** Godot GDScript, PowerShell helpers, Python training scripts, JSON/JSONL artifacts

---

## File Structure

### Existing files to modify

- `scripts/ai/AILegalActionBuilder.gd`
  - Add `attach_tool` legal action generation.
- `scripts/ai/AIFeatureExtractor.gd`
  - Expand from heuristic-context-only features into reusable action feature extraction.
- `scripts/ai/AIHeuristics.gd`
  - Keep as the baseline scorer; expose combined-score-friendly behavior without changing unrelated action kinds.
- `scripts/ai/AIOpponent.gd`
  - Execute tool attachments and incorporate action scorer output into selected action kinds.
- `scripts/ai/MCTSPlanner.gd`
  - Record decision metadata when available for sample export.
- `scripts/ai/AIDecisionTrace.gd`
  - Extend trace payload if needed so exported decision samples can reuse scored action data.
- `scripts/ai/StateEncoder.gd`
  - Reuse existing state vector plumbing where needed for decision samples and runtime action scoring.
- `scripts/training/train_loop.sh`
  - Add optional action-scorer training and artifact wiring.
- `scripts/training/train_value_net.py`
  - No behavior change expected beyond shared artifact conventions; touch only if a helper should be shared.
- `scripts/ai/AIVersionRegistry.gd`
  - Support `action_scorer_path` in playable version records.
- `scripts/ai/TrainingRunRegistry.gd`
  - Support action-scorer artifact and training metadata.

### New files to create

- `scripts/ai/AIActionFeatureEncoder.gd`
  - Produce normalized action vectors for supported action kinds.
- `scripts/ai/AIDecisionSampleExporter.gd`
  - Convert self-play / benchmark decision points into compact training samples.
- `scripts/ai/AIActionScorer.gd`
  - Runtime inference wrapper for the trained action scorer artifact.
- `scripts/training/train_action_scorer.py`
  - Train the action scorer on exported decision samples.
- `scripts/training/test_train_action_scorer.py`
  - Small Python smoke test for trainer CLI and tiny-dataset fit/load behavior.

### Existing tests to modify or use

- `tests/test_ai_headless_action_builder.gd`
- `tests/test_ai_decision_trace.gd`
- `tests/test_tuner_runner_args.gd`
- `tests/test_training_run_registry.gd`
- `tests/test_ai_version_registry.gd`

### New tests to create

- `tests/test_ai_tool_actions.gd`
  - Focused legality and runtime execution coverage for `attach_tool`.
- `tests/test_ai_action_feature_encoder.gd`
  - Action-vector shape and semantic-field tests for the supported action kinds.
- `tests/test_ai_decision_sample_exporter.gd`
  - Decision-sample schema and export behavior.
- `tests/test_ai_action_scorer_runtime.gd`
  - Runtime score combination for the selected action kinds.

### Verification entry points

- Focused Godot runs through `tests/FocusedSuiteRunner.gd`
- Small Python smoke tests only
- No long-running end-to-end AI training validation in this feature pass

---

### Task 1: Fix AI Tool Usage First

**Files:**
- Modify: `scripts/ai/AILegalActionBuilder.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Test: `tests/test_ai_tool_actions.gd`

- [ ] **Step 1: Write the failing tool-action tests**

Add focused tests that prove:
- AI legal actions include `attach_tool` for a valid target.
- AI can execute a tool attachment.
- Forest Seal Stone attachment allows the granted ability to show up through the normal ability path.

- [ ] **Step 2: Run the focused tool tests and confirm failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path "D:/ai/code/ptcgtrain" -s "res://tests/FocusedSuiteRunner.gd" -- --suite-script=res://tests/test_ai_tool_actions.gd
```

Expected:
- FAIL because `attach_tool` actions are not yet constructed and/or executed by AI.

- [ ] **Step 3: Implement legal `attach_tool` action construction**

In `AILegalActionBuilder.gd`:
- add a `_build_attach_tool_actions(...)` helper
- enumerate valid player slots
- filter against `RuleValidator.can_attach_tool(...)`
- insert `attach_tool` actions into the main legal-action list

- [ ] **Step 4: Implement AI tool execution**

In `AIOpponent.gd`:
- add `attach_tool` execution handling in `_execute_action(...)`
- ensure the action succeeds through `GameStateMachine.attach_tool(...)`

- [ ] **Step 5: Verify tool tests pass**

Run the focused suite again and expect PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/AILegalActionBuilder.gd scripts/ai/AIOpponent.gd tests/test_ai_tool_actions.gd
git commit -m "fix: allow ai to attach and use tools"
```

---

### Task 2: Build Reusable Action Feature Encoding

**Files:**
- Create: `scripts/ai/AIActionFeatureEncoder.gd`
- Modify: `scripts/ai/AIFeatureExtractor.gd`
- Test: `tests/test_ai_action_feature_encoder.gd`

- [ ] **Step 1: Write failing action-feature tests**

Cover:
- stable vector shape across action kinds
- nonzero semantic fields for `play_trainer`, `use_ability`, `attach_tool`, `attach_energy`, and `attack`
- target metadata and tactical flags where expected

- [ ] **Step 2: Run the focused feature tests and confirm failure**

Run the focused suite for `tests/test_ai_action_feature_encoder.gd`.

- [ ] **Step 3: Implement `AIActionFeatureEncoder.gd`**

Create a dedicated encoder that produces normalized vectors for the supported action kinds and shared helper methods for:
- action kind one-hot
- target role flags
- attack metadata
- readiness delta
- bench development delta
- immediate KO or prize potential
- resource-consumption flags

- [ ] **Step 4: Refactor `AIFeatureExtractor.gd` to reuse the new action encoder where needed**

Keep backward compatibility for heuristic context fields, but make the new action vector reusable by exporter and runtime.

- [ ] **Step 5: Verify the focused feature tests pass**

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/AIActionFeatureEncoder.gd scripts/ai/AIFeatureExtractor.gd tests/test_ai_action_feature_encoder.gd
git commit -m "feat: add reusable ai action feature encoder"
```

---

### Task 3: Export Decision Samples From Self-Play and Benchmark

**Files:**
- Create: `scripts/ai/AIDecisionSampleExporter.gd`
- Modify: `scripts/ai/AIDecisionTrace.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `scripts/ai/MCTSPlanner.gd`
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Modify: `scripts/ai/SelfPlayRunner.gd`
- Test: `tests/test_ai_decision_sample_exporter.gd`
- Test: `tests/test_ai_decision_trace.gd`

- [ ] **Step 1: Write failing exporter and trace tests**

Cover:
- compact decision-sample schema
- legal action list plus chosen action
- heuristic scores per legal action
- MCTS metadata when present
- downstream outcome labels

- [ ] **Step 2: Run the focused exporter/trace tests and confirm failure**

- [ ] **Step 3: Extend `AIDecisionTrace.gd` only as needed**

Keep it small and focused; add fields only if the exporter requires them.

- [ ] **Step 4: Implement `AIDecisionSampleExporter.gd`**

The exporter should:
- accept runtime decision traces plus final outcome context
- write compact JSONL samples
- avoid storing giant per-step state dumps

- [ ] **Step 5: Hook exporter into self-play and benchmark**

Modify self-play / benchmark flows so they can emit action-learning samples without changing the current value-net export behavior.

- [ ] **Step 6: Verify focused exporter tests pass**

- [ ] **Step 7: Commit**

```bash
git add scripts/ai/AIDecisionSampleExporter.gd scripts/ai/AIDecisionTrace.gd scripts/ai/AIOpponent.gd scripts/ai/MCTSPlanner.gd scripts/ai/AIBenchmarkRunner.gd scripts/ai/SelfPlayRunner.gd tests/test_ai_decision_sample_exporter.gd tests/test_ai_decision_trace.gd
git commit -m "feat: export action learning decision samples"
```

---

### Task 4: Train and Persist the Action Scorer Artifact

**Files:**
- Create: `scripts/training/train_action_scorer.py`
- Create: `scripts/training/test_train_action_scorer.py`
- Modify: `scripts/training/train_loop.sh`
- Modify: `scripts/ai/TrainingRunRegistry.gd`
- Modify: `scripts/ai/AIVersionRegistry.gd`

- [ ] **Step 1: Write the Python smoke test first**

Cover:
- CLI argument parsing
- tiny dataset load
- short train pass
- artifact write and reload

- [ ] **Step 2: Run the Python smoke test and confirm failure**

Run:

```powershell
py -3.13 scripts/training/test_train_action_scorer.py
```

Expected:
- FAIL because `train_action_scorer.py` does not exist yet.

- [ ] **Step 3: Implement `train_action_scorer.py`**

Requirements:
- input: compact decision-sample dataset
- output: scalar future-value model
- options for device and thread control similar to `train_value_net.py`
- lightweight artifact format compatible with runtime loading

- [ ] **Step 4: Wire artifact metadata into training registries**

Add:
- `action_scorer_path`
- training metadata
- enabled action kinds / learned-weight config as needed

- [ ] **Step 5: Add optional train-loop support**

Extend `train_loop.sh` only far enough to:
- train the scorer when action samples exist
- persist the artifact alongside agent/value-net artifacts
- avoid breaking existing loops when no scorer is present

- [ ] **Step 6: Run the Python smoke test and any targeted registry tests**

- [ ] **Step 7: Commit**

```bash
git add scripts/training/train_action_scorer.py scripts/training/test_train_action_scorer.py scripts/training/train_loop.sh scripts/ai/TrainingRunRegistry.gd scripts/ai/AIVersionRegistry.gd
git commit -m "feat: train and version ai action scorer"
```

---

### Task 5: Runtime Integration for Selected Action Kinds

**Files:**
- Create: `scripts/ai/AIActionScorer.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `scripts/ai/AIHeuristics.gd`
- Test: `tests/test_ai_action_scorer_runtime.gd`

- [ ] **Step 1: Write failing runtime scoring tests**

Cover:
- supported action kinds use `heuristic + learned_score * learned_weight`
- unsupported kinds remain heuristic-only
- missing artifact falls back cleanly
- missing action-feature vector falls back cleanly

- [ ] **Step 2: Run the focused runtime tests and confirm failure**

- [ ] **Step 3: Implement `AIActionScorer.gd`**

Keep it as a small inference wrapper that:
- loads the action scorer artifact
- scores one action given state vector + action vector
- returns a scalar learned score

- [ ] **Step 4: Integrate scorer into `AIOpponent.gd`**

Apply learned scoring only for:
- `play_trainer`
- `use_ability`
- `attach_tool`
- `attach_energy`
- `attack`

All other actions must remain heuristic-only.

- [ ] **Step 5: Keep `AIHeuristics.gd` stable**

Do not move decision ownership out of heuristics wholesale. Only make the minimum changes needed so learned scores combine cleanly and reason-tagging remains usable.

- [ ] **Step 6: Verify focused runtime tests pass**

- [ ] **Step 7: Commit**

```bash
git add scripts/ai/AIActionScorer.gd scripts/ai/AIOpponent.gd scripts/ai/AIHeuristics.gd tests/test_ai_action_scorer_runtime.gd
git commit -m "feat: apply learned action scoring at runtime"
```

---

### Task 6: Final Focused Verification

**Files:**
- Test only

- [ ] **Step 1: Run focused Godot suites**

Run only the suites touched by this feature, for example:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path "D:/ai/code/ptcgtrain" -s "res://tests/FocusedSuiteRunner.gd" -- --suite-script=res://tests/test_ai_tool_actions.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path "D:/ai/code/ptcgtrain" -s "res://tests/FocusedSuiteRunner.gd" -- --suite-script=res://tests/test_ai_action_feature_encoder.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path "D:/ai/code/ptcgtrain" -s "res://tests/FocusedSuiteRunner.gd" -- --suite-script=res://tests/test_ai_decision_sample_exporter.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path "D:/ai/code/ptcgtrain" -s "res://tests/FocusedSuiteRunner.gd" -- --suite-script=res://tests/test_ai_action_scorer_runtime.gd
```

Expected:
- PASS on each focused suite

- [ ] **Step 2: Run Python smoke tests**

```powershell
py -3.13 scripts/training/test_train_action_scorer.py
py -3.13 -m py_compile scripts/training/train_action_scorer.py
```

Expected:
- PASS

- [ ] **Step 3: Run `git diff --check`**

Expected:
- no diff syntax errors

- [ ] **Step 4: Commit final verification-only adjustments if needed**

```bash
git add <touched files>
git commit -m "test: verify action learning framework integration"
```
