#!/usr/bin/env bash
# Gardevoir Value Net training with run-scoped artifacts and benchmark-gated promotion.
#
# Fixes over the legacy flow:
# - single-run lock to avoid concurrent writers
# - per-run/per-round logs, models, summaries, and benchmark outputs
# - benchmark gating through BenchmarkRunner + TrainingRunRegistry
# - local current-best copy so rounds never race on a shared champion file

set -u

resolve_user_root() {
	if [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "win32" || "${OSTYPE:-}" == "cygwin" ]]; then
		echo "$APPDATA/Godot/app_userdata/PTCG Train"
	elif [[ "${OSTYPE:-}" == "darwin"* ]]; then
		echo "$HOME/Library/Application Support/Godot/app_userdata/PTCG Train"
	else
		echo "$HOME/.local/share/godot/app_userdata/PTCG Train"
	fi
}

globalize_user_path() {
	local path="$1"
	if [[ "$path" == user://* ]]; then
		echo "$USER_ROOT/${path#user://}"
	else
		echo "$path"
	fi
}

log() {
	printf '%s\n' "$*" >> "$LOG"
	printf '%s\n' "$*"
}

acquire_lock() {
	mkdir -p "$(dirname "$LOCK_DIR")"
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		cat > "$LOCK_DIR/owner.txt" <<EOF
pid=$$
run_id=$RUN_ID
started_at=$(date)
log=$LOG
EOF
		return 0
	fi

	printf 'another Gardevoir training run is active: %s\n' "$LOCK_DIR" >&2
	if [[ -f "$LOCK_DIR/owner.txt" ]]; then
		cat "$LOCK_DIR/owner.txt" >&2
	fi
	return 1
}

release_lock() {
	if [[ -d "$LOCK_DIR" ]]; then
		rm -f "$LOCK_DIR/owner.txt"
		rmdir "$LOCK_DIR" 2>/dev/null || true
	fi
}

move_exported_games() {
	local source_dir="$1"
	local destination="$2"
	mkdir -p "$destination"
	find "$source_dir" -maxdepth 1 -type f -name 'game_*.json' -print0 2>/dev/null | while IFS= read -r -d '' file; do
		mv "$file" "$destination/"
	done
}

summarize_training_data() {
	local source_dir="$1"
	find "$source_dir" -maxdepth 1 -type f -name 'game_*.json' 2>/dev/null | wc -l | tr -d ' '
}

latest_approved_baseline() {
	local index_path="$VERSION_REGISTRY_GLOBAL_DIR/index.json"
	if [[ ! -f "$index_path" ]]; then
		return 1
	fi

	"$PYTHON_BIN" - "$index_path" <<'PY'
import json
import sys

index_path = sys.argv[1]
try:
    with open(index_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    sys.exit(1)

if not isinstance(data, dict):
    sys.exit(1)

playable = [
    value for value in data.values()
    if isinstance(value, dict) and str(value.get("status", "")) == "playable"
]
if not playable:
    sys.exit(1)

def sort_key(record):
    return (
        str(record.get("created_at", "")),
        int(record.get("save_order", 0)),
        str(record.get("version_id", "")),
    )

latest = sorted(playable, key=sort_key)[-1]
print(str(latest.get("version_id", "")))
print(str(latest.get("display_name", "")))
print(str(latest.get("value_net_path", "")))
PY
}

read_summary_value() {
	local summary_path="$1"
	local key="$2"
	"$PYTHON_BIN" - "$summary_path" "$key" <<'PY'
import json
import sys

summary_path, key = sys.argv[1], sys.argv[2]
try:
    with open(summary_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    sys.exit(1)

value = data
for part in key.split("."):
    if isinstance(value, dict):
        value = value.get(part)
    else:
        value = None
        break

if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
PY
}

sync_current_best() {
	local source_user_path="$1"
	local source_global_path
	source_global_path="$(globalize_user_path "$source_user_path")"
	if [[ ! -f "$source_global_path" ]]; then
		return 1
	fi
	cp "$source_global_path" "$CURRENT_BEST_GLOBAL_PATH"
	cp "$source_global_path" "$LEGACY_CHAMPION"
	CURRENT_BASELINE_USER_PATH="$CURRENT_BEST_USER_PATH"
	CURRENT_BASELINE_GLOBAL_PATH="$CURRENT_BEST_GLOBAL_PATH"
	return 0
}

collect_parallel() {
	local deck_a="$1"
	local deck_b="$2"
	local games="$3"
	local seed_base="$4"

	for worker in $(seq 0 $((WORKERS - 1))); do
		local offset=$((seed_base + worker * 10000))
		"$GODOT" --headless --path "$PROJECT" --quit-after 9999 \
			"$COLLECT_SCENE" -- \
			--games="$games" --deck-a="$deck_a" --deck-b="$deck_b" \
			--encoder=gardevoir \
			--seed-offset="$offset" \
			>> "$LOG" 2>&1 &
	done
	wait || true
}

GODOT="${GODOT:-D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe}"
PROJECT="${PROJECT:-D:/ai/code/ptcgtrain}"
PYTHON_BIN="${PYTHON:-python}"
USER_ROOT="${USER_ROOT:-$(resolve_user_root)}"

EXPORT_DATA_DIR="${EXPORT_DATA_DIR:-$USER_ROOT/training_data/gardevoir}"
RUNS_USER_DIR="${RUNS_USER_DIR:-user://training_data/gardevoir/runs}"
RUNS_GLOBAL_DIR="${RUNS_GLOBAL_DIR:-$(globalize_user_path "$RUNS_USER_DIR")}"
RUN_REGISTRY_USER_DIR="${RUN_REGISTRY_USER_DIR:-user://training_runs/gardevoir_mirror}"
VERSION_REGISTRY_USER_DIR="${VERSION_REGISTRY_USER_DIR:-user://ai_versions/gardevoir_mirror}"
VERSION_REGISTRY_GLOBAL_DIR="${VERSION_REGISTRY_GLOBAL_DIR:-$(globalize_user_path "$VERSION_REGISTRY_USER_DIR")}"
AI_AGENTS_DIR="${AI_AGENTS_DIR:-$USER_ROOT/ai_agents}"
LEGACY_CHAMPION="${LEGACY_CHAMPION:-$AI_AGENTS_DIR/gardevoir_value_net.json}"
LATEST_LOG_POINTER="${LATEST_LOG_POINTER:-$PROJECT/gardevoir_training_latest.txt}"
LOCK_DIR="${LOCK_DIR:-$USER_ROOT/locks/gardevoir_training.lock}"

TRAIN_SCRIPT="${TRAIN_SCRIPT:-$PROJECT/scripts/training/train_value_net.py}"
COLLECT_SCENE="${COLLECT_SCENE:-res://scenes/tuner/ValueNetDataRunner.tscn}"
BENCHMARK_SCENE="${BENCHMARK_SCENE:-res://scenes/tuner/BenchmarkRunner.tscn}"
PIPELINE_NAME="${PIPELINE_NAME:-gardevoir_mirror_training}"

GARDEVOIR="${GARDEVOIR:-578647}"
MIRAIDON="${MIRAIDON:-575720}"
CHARIZARD="${CHARIZARD:-575716}"

ROUNDS="${ROUNDS:-4}"
WORKERS="${WORKERS:-8}"
MIRROR_GAMES_PER_WORKER="${MIRROR_GAMES_PER_WORKER:-25}"
CROSS_GAMES_PER_WORKER="${CROSS_GAMES_PER_WORKER:-13}"
BENCHMARK_GATE_THRESHOLD="${BENCHMARK_GATE_THRESHOLD:-0.55}"
BOOTSTRAP_GATE_THRESHOLD="${BOOTSTRAP_GATE_THRESHOLD:-0.0}"
TEACHER_WEIGHT="${TEACHER_WEIGHT:-0.2}"

RUN_STAMP="$(date +%Y%m%d_%H%M%S)_$$"
RUN_ID="${RUN_ID:-gardevoir_run_$RUN_STAMP}"
RUN_USER_DIR="$RUNS_USER_DIR/$RUN_ID"
RUN_DIR="$RUNS_GLOBAL_DIR/$RUN_ID"
CURRENT_BEST_USER_PATH="$RUN_USER_DIR/current_best/gardevoir_value_net.json"
CURRENT_BEST_GLOBAL_PATH="$RUN_DIR/current_best/gardevoir_value_net.json"
LOG="$RUN_DIR/gardevoir_training.log"

mkdir -p "$RUN_DIR/current_best" "$EXPORT_DATA_DIR" "$AI_AGENTS_DIR" "$VERSION_REGISTRY_GLOBAL_DIR"
printf '%s\n' "$LOG" > "$LATEST_LOG_POINTER"
: > "$LOG"

if ! acquire_lock; then
	exit 1
fi
trap 'release_lock' EXIT INT TERM

CURRENT_BASELINE_USER_PATH=""
CURRENT_BASELINE_GLOBAL_PATH=""
CURRENT_BASELINE_VERSION_ID=""
CURRENT_BASELINE_DISPLAY_NAME=""
CURRENT_BASELINE_SOURCE="greedy-bootstrap"
PROMOTIONS=0

if APPROVED_BASELINE_RAW="$(latest_approved_baseline 2>/dev/null)" && [[ -n "$APPROVED_BASELINE_RAW" ]]; then
	mapfile -t APPROVED_BASELINE_LINES <<<"$APPROVED_BASELINE_RAW"
	CURRENT_BASELINE_VERSION_ID="${APPROVED_BASELINE_LINES[0]:-}"
	CURRENT_BASELINE_DISPLAY_NAME="${APPROVED_BASELINE_LINES[1]:-}"
	CURRENT_BASELINE_USER_PATH="${APPROVED_BASELINE_LINES[2]:-}"
	CURRENT_BASELINE_GLOBAL_PATH="$(globalize_user_path "$CURRENT_BASELINE_USER_PATH")"
	CURRENT_BASELINE_SOURCE="approved-playable"
	if [[ -f "$CURRENT_BASELINE_GLOBAL_PATH" ]]; then
		cp "$CURRENT_BASELINE_GLOBAL_PATH" "$CURRENT_BEST_GLOBAL_PATH"
		CURRENT_BASELINE_USER_PATH="$CURRENT_BEST_USER_PATH"
		CURRENT_BASELINE_GLOBAL_PATH="$CURRENT_BEST_GLOBAL_PATH"
	else
		CURRENT_BASELINE_USER_PATH=""
		CURRENT_BASELINE_GLOBAL_PATH=""
		CURRENT_BASELINE_VERSION_ID=""
		CURRENT_BASELINE_DISPLAY_NAME=""
		CURRENT_BASELINE_SOURCE="greedy-bootstrap"
	fi
elif [[ -f "$LEGACY_CHAMPION" ]]; then
	cp "$LEGACY_CHAMPION" "$CURRENT_BEST_GLOBAL_PATH"
	CURRENT_BASELINE_USER_PATH="$CURRENT_BEST_USER_PATH"
	CURRENT_BASELINE_GLOBAL_PATH="$CURRENT_BEST_GLOBAL_PATH"
	CURRENT_BASELINE_SOURCE="legacy-champion"
fi

log "===== Gardevoir Training ====="
log "Run ID: $RUN_ID"
log "Start: $(date)"
log "Pipeline: $PIPELINE_NAME"
log "Log: $LOG"
log "Export dir: $EXPORT_DATA_DIR"
log "Run dir: $RUN_DIR"
log "Baseline source: $CURRENT_BASELINE_SOURCE"
if [[ -n "$CURRENT_BASELINE_VERSION_ID" ]]; then
	log "Baseline version: $CURRENT_BASELINE_VERSION_ID"
fi
if [[ -n "$CURRENT_BASELINE_GLOBAL_PATH" ]]; then
	log "Baseline weights: $CURRENT_BASELINE_GLOBAL_PATH"
else
	log "Baseline weights: <greedy>"
fi
log ""

round=1
while [[ "$round" -le "$ROUNDS" ]]; do
	printf -v round_label "%02d" "$round"
	ROUND_DIR="$RUN_DIR/round_$round_label"
	ROUND_USER_DIR="$RUN_USER_DIR/round_$round_label"
	ROUND_DATA_DIR="$ROUND_DIR/self_play"
	ROUND_MODEL_DIR="$ROUND_DIR/models"
	ROUND_BENCHMARK_DIR="$ROUND_DIR/benchmark"
	ROUND_STALE_DIR="$ROUND_DIR/stale_stage"
	ROUND_CANDIDATE_GLOBAL_PATH="$ROUND_MODEL_DIR/gardevoir_value_net_candidate_round_$round_label.json"
	ROUND_CANDIDATE_USER_PATH="$ROUND_USER_DIR/models/gardevoir_value_net_candidate_round_$round_label.json"
	ROUND_SUMMARY_GLOBAL_PATH="$ROUND_BENCHMARK_DIR/summary.json"
	ROUND_SUMMARY_USER_PATH="$ROUND_USER_DIR/benchmark/summary.json"
	ROUND_ANOMALY_USER_PATH="$ROUND_USER_DIR/benchmark/anomaly_summary.json"
	ROUND_RUN_ID="${RUN_ID}_round_$round_label"
	mkdir -p "$ROUND_DATA_DIR" "$ROUND_MODEL_DIR" "$ROUND_BENCHMARK_DIR" "$ROUND_STALE_DIR"

	log "========== ROUND $round / $ROUNDS =========="
	log "Time: $(date)"

	move_exported_games "$EXPORT_DATA_DIR" "$ROUND_STALE_DIR"
	log "[R$round] Collecting greedy data..."
	log "[R$round] Mirror ($WORKERS x $MIRROR_GAMES_PER_WORKER)..."
	collect_parallel "$GARDEVOIR" "$GARDEVOIR" "$MIRROR_GAMES_PER_WORKER" $((round * 100000))
	log "[R$round] Mirror done"

	log "[R$round] vs Miraidon ($WORKERS x $CROSS_GAMES_PER_WORKER)..."
	collect_parallel "$GARDEVOIR" "$MIRAIDON" "$CROSS_GAMES_PER_WORKER" $((round * 100000 + 50000))
	log "[R$round] vs Miraidon done"

	log "[R$round] vs Charizard ($WORKERS x $CROSS_GAMES_PER_WORKER)..."
	collect_parallel "$GARDEVOIR" "$CHARIZARD" "$CROSS_GAMES_PER_WORKER" $((round * 100000 + 80000))
	log "[R$round] vs Charizard done"

	move_exported_games "$EXPORT_DATA_DIR" "$ROUND_DATA_DIR"
	DATA_COUNT="$(summarize_training_data "$ROUND_DATA_DIR")"
	log "[R$round] Data files moved into round dir: $DATA_COUNT"
	if [[ "$DATA_COUNT" -eq 0 ]]; then
		log "[R$round] No training data exported; skipping round."
		log ""
		round=$((round + 1))
		continue
	fi

	log "[R$round] Training candidate..."
	"$PYTHON_BIN" "$TRAIN_SCRIPT" \
		--data-dir "$ROUND_DATA_DIR" \
		--output "$ROUND_CANDIDATE_GLOBAL_PATH" \
		--hidden1 128 --hidden2 64 --hidden3 32 \
		--epochs 200 --teacher-weight "$TEACHER_WEIGHT" --patience 15 \
		--batch-size 256 --lr 0.001 \
		>> "$LOG" 2>&1 || true

	if [[ ! -f "$ROUND_CANDIDATE_GLOBAL_PATH" ]]; then
		log "[R$round] Candidate weights missing; skipping benchmark."
		log ""
		round=$((round + 1))
		continue
	fi

	ROUND_GATE_THRESHOLD="$BENCHMARK_GATE_THRESHOLD"
	if [[ -z "$CURRENT_BASELINE_GLOBAL_PATH" || ! -f "$CURRENT_BASELINE_GLOBAL_PATH" ]]; then
		ROUND_GATE_THRESHOLD="$BOOTSTRAP_GATE_THRESHOLD"
	fi

	log "[R$round] Benchmark gate via BenchmarkRunner (threshold=$ROUND_GATE_THRESHOLD)..."
	BENCHMARK_ARGS=(
		--headless
		--path "$PROJECT"
		--quit-after 3600
		"$BENCHMARK_SCENE"
		--
		--pipeline-name="$PIPELINE_NAME"
		--gate-threshold="$ROUND_GATE_THRESHOLD"
		--value-net-a="$ROUND_CANDIDATE_USER_PATH"
		--summary-output="$ROUND_SUMMARY_USER_PATH"
		--anomaly-output="$ROUND_ANOMALY_USER_PATH"
		--run-id="$ROUND_RUN_ID"
		--run-dir="$ROUND_USER_DIR"
		--run-registry-dir="$RUN_REGISTRY_USER_DIR"
		--version-registry-dir="$VERSION_REGISTRY_USER_DIR"
		--publish-display-name="gardevoir round $round candidate"
		--baseline-source="$CURRENT_BASELINE_SOURCE"
		--baseline-version-id="$CURRENT_BASELINE_VERSION_ID"
		--baseline-display-name="$CURRENT_BASELINE_DISPLAY_NAME"
		--baseline-value-net="$CURRENT_BASELINE_USER_PATH"
	)
	if [[ -n "$CURRENT_BASELINE_USER_PATH" ]]; then
		BENCHMARK_ARGS+=(--value-net-b="$CURRENT_BASELINE_USER_PATH")
	fi

	if "$GODOT" "${BENCHMARK_ARGS[@]}" >> "$LOG" 2>&1; then
		GATE_RESULT="published"
	else
		GATE_RESULT="benchmark_failed"
	fi

	WIN_RATE="?"
	GATE_PASSED="false"
	if [[ -f "$ROUND_SUMMARY_GLOBAL_PATH" ]]; then
		WIN_RATE="$("$PYTHON_BIN" - "$ROUND_SUMMARY_GLOBAL_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
print(f"{float(data.get('win_rate_vs_current_best', 0.0)) * 100.0:.1f}")
PY
)"
		GATE_PASSED="$(read_summary_value "$ROUND_SUMMARY_GLOBAL_PATH" "gate_passed" 2>/dev/null || echo "false")"
	fi

	if [[ "$GATE_RESULT" == "published" && "$GATE_PASSED" == "true" ]]; then
		if sync_current_best "$ROUND_CANDIDATE_USER_PATH"; then
			PROMOTIONS=$((PROMOTIONS + 1))
			CURRENT_BASELINE_SOURCE="published-run"
			if PROMOTED_BASELINE_RAW="$(latest_approved_baseline 2>/dev/null)" && [[ -n "$PROMOTED_BASELINE_RAW" ]]; then
				mapfile -t PROMOTED_BASELINE_LINES <<<"$PROMOTED_BASELINE_RAW"
				CURRENT_BASELINE_VERSION_ID="${PROMOTED_BASELINE_LINES[0]:-}"
				CURRENT_BASELINE_DISPLAY_NAME="${PROMOTED_BASELINE_LINES[1]:-}"
			fi
			log "[R$round] >>> PROMOTED via BenchmarkRunner (${WIN_RATE}%)"
		else
			log "[R$round] >>> Benchmark published, but syncing current best failed"
		fi
	else
		log "[R$round] >>> Rejected (${WIN_RATE}%). Baseline unchanged."
	fi

	log ""
	round=$((round + 1))
done

log "===== COMPLETE ====="
log "End: $(date)"
log "Promotions: $PROMOTIONS / $ROUNDS"
log "Current best: $CURRENT_BEST_GLOBAL_PATH"
log "Legacy champion sync: $LEGACY_CHAMPION"
