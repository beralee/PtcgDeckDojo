# Training Anomaly Archive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist structured training anomalies for phase1 self-play and phase3 benchmark runs, including representative samples and run registry metadata.

**Architecture:** Introduce a small anomaly archive helper that normalizes raw match results into a stable summary shape. Wire phase1 and phase3 to emit partial summaries, then merge them into a final run-level archive and patch benchmark run records with anomaly metadata.

**Tech Stack:** GDScript, existing Godot test runner, Bash training loop

---

### Task 1: Add anomaly archive helper tests

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_training_anomaly_archive.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for aggregation and merge behavior**
- [ ] **Step 2: Run targeted tests to verify they fail for the missing helper**
- [ ] **Step 3: Register the new suite in `TestRunner.gd`**
- [ ] **Step 4: Re-run the targeted tests to confirm the expected failure remains helper-related**

### Task 2: Implement anomaly archive helper

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/ai/TrainingAnomalyArchive.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_training_anomaly_archive.gd`

- [ ] **Step 1: Implement normalization and aggregation over raw match results**
- [ ] **Step 2: Implement representative sample capping by failure reason and pairing**
- [ ] **Step 3: Implement summary merge, read, and write helpers**
- [ ] **Step 4: Run targeted helper tests and make them pass**

### Task 3: Wire phase1 anomaly output

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/ai/EvolutionEngine.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/tuner/TunerRunner.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_evolution_engine.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_tuner_runner_args.gd`

- [ ] **Step 1: Add failing tests for anomaly output argument parsing and phase1 anomaly file generation**
- [ ] **Step 2: Extend `TunerRunner` to accept `--anomaly-output`**
- [ ] **Step 3: Extend `EvolutionEngine` to aggregate and write `phase1_anomalies.json`**
- [ ] **Step 4: Run the targeted tests until they pass**

### Task 4: Wire phase3 merge and run record patch

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scenes/tuner/BenchmarkRunner.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_ai_phase2_benchmark.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_training_run_registry.gd`

- [ ] **Step 1: Write failing tests for anomaly merge output and run record metadata**
- [ ] **Step 2: Implement benchmark anomaly aggregation and final merge output**
- [ ] **Step 3: Patch run records with anomaly summary metadata**
- [ ] **Step 4: Run targeted benchmark/run-registry tests until they pass**

### Task 5: Wire training loop paths

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/training/train_loop.sh`

- [ ] **Step 1: Pass phase1 anomaly output path into `TunerRunner`**
- [ ] **Step 2: Pass phase1 input and final anomaly output path into `BenchmarkRunner`**
- [ ] **Step 3: If phase2 is skipped, copy the phase1 anomaly file to the run-level anomaly summary path**

### Task 6: Verify end to end

**Files:**
- Test: `D:/ai/code/ptcgtrain/tests/test_training_anomaly_archive.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_evolution_engine.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_tuner_runner_args.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_ai_phase2_benchmark.gd`
- Test: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Run targeted tests for the helper and integrations**
- [ ] **Step 2: Run the full Godot test suite**
- [ ] **Step 3: Check `git diff --check`**
- [ ] **Step 4: Summarize any remaining risks**
