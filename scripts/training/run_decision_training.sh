#!/usr/bin/env bash
# Run-scoped deck training with value-net + action-scorer artifacts.

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
deck_name=$DECK_NAME
started_at=$(date)
log=$LOG
EOF
		return 0
	fi
	printf 'another %s training run is active: %s\n' "$DECK_NAME" "$LOCK_DIR" >&2
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
print(str(latest.get("action_scorer_path", "")))
print(str(latest.get("interaction_scorer_path", "")))
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

summarize_training_data() {
	local source_dir="$1"
	find "$source_dir" -maxdepth 1 -type f -name 'game_*.json' 2>/dev/null | wc -l | tr -d ' '
}

summarize_action_training_data() {
	local source_dir="$1"
	find "$source_dir" -maxdepth 1 -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' '
}

sync_current_best() {
	local value_source_user_path="$1"
	local action_source_user_path="$2"
	local interaction_source_user_path="$3"
	local value_source_global_path
	value_source_global_path="$(globalize_user_path "$value_source_user_path")"
	if [[ ! -f "$value_source_global_path" ]]; then
		return 1
	fi
	cp "$value_source_global_path" "$CURRENT_BEST_VALUE_GLOBAL_PATH"
	cp "$value_source_global_path" "$LEGACY_VALUE_NET"
	CURRENT_BASELINE_VALUE_USER_PATH="$CURRENT_BEST_VALUE_USER_PATH"
	CURRENT_BASELINE_VALUE_GLOBAL_PATH="$CURRENT_BEST_VALUE_GLOBAL_PATH"

	if [[ -n "$action_source_user_path" ]]; then
		local action_source_global_path
		action_source_global_path="$(globalize_user_path "$action_source_user_path")"
		if [[ -f "$action_source_global_path" ]]; then
			cp "$action_source_global_path" "$CURRENT_BEST_ACTION_GLOBAL_PATH"
			cp "$action_source_global_path" "$LEGACY_ACTION_SCORER"
			CURRENT_BASELINE_ACTION_USER_PATH="$CURRENT_BEST_ACTION_USER_PATH"
			CURRENT_BASELINE_ACTION_GLOBAL_PATH="$CURRENT_BEST_ACTION_GLOBAL_PATH"
		fi
	fi
	if [[ -n "$interaction_source_user_path" ]]; then
		local interaction_source_global_path
		interaction_source_global_path="$(globalize_user_path "$interaction_source_user_path")"
		if [[ -f "$interaction_source_global_path" ]]; then
			cp "$interaction_source_global_path" "$CURRENT_BEST_INTERACTION_GLOBAL_PATH"
			cp "$interaction_source_global_path" "$LEGACY_INTERACTION_SCORER"
			CURRENT_BASELINE_INTERACTION_USER_PATH="$CURRENT_BEST_INTERACTION_USER_PATH"
			CURRENT_BASELINE_INTERACTION_GLOBAL_PATH="$CURRENT_BEST_INTERACTION_GLOBAL_PATH"
		fi
	fi
	return 0
}

collect_parallel() {
	local deck_a="$1"
	local deck_b="$2"
	local games="$3"
	local seed_base="$4"
	for worker in $(seq 0 $((WORKERS - 1))); do
		local offset=$((seed_base + worker * 10000))
		local args=(
			--headless
			--path "$PROJECT"
			--quit-after 9999
			"$COLLECT_SCENE"
			--
			--games="$games"
			--deck-a="$deck_a"
			--deck-b="$deck_b"
			--encoder="$ENCODER"
			--pipeline-name="$PIPELINE_NAME"
			--data-dir="$ROUND_DATA_USER_DIR"
			--action-data-dir="$ROUND_ACTION_DATA_USER_DIR"
			--export-action-data
			--seed-offset="$offset"
		)
		if [[ -n "$CURRENT_BASELINE_VALUE_USER_PATH" ]]; then
			args+=(--value-net="$CURRENT_BASELINE_VALUE_USER_PATH")
		fi
		if [[ -n "$CURRENT_BASELINE_ACTION_USER_PATH" ]]; then
			args+=(--action-scorer="$CURRENT_BASELINE_ACTION_USER_PATH")
		fi
		if [[ -n "$CURRENT_BASELINE_INTERACTION_USER_PATH" ]]; then
			args+=(--interaction-scorer="$CURRENT_BASELINE_INTERACTION_USER_PATH")
		fi
		"$GODOT" "${args[@]}" >> "$LOG" 2>&1 &
	done
	wait || true
}

deck_prefix() {
	local raw="$1"
	echo "$raw" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/_/g'
}

GODOT="${GODOT:-D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe}"
PROJECT="${PROJECT:-D:/ai/code/ptcgtrain}"
PYTHON_BIN="${PYTHON:-python}"
USER_ROOT="${USER_ROOT:-$(resolve_user_root)}"

DECK_NAME="${DECK_NAME:-gardevoir}"
DECK_PREFIX="${DECK_PREFIX:-$(deck_prefix "$DECK_NAME")}"
ENCODER="${ENCODER:-gardevoir}"
PIPELINE_NAME="${PIPELINE_NAME:-gardevoir_mirror_training}"
PIPELINE_SUFFIX="${PIPELINE_SUFFIX:-$DECK_PREFIX}"
OPTIMIZED_DECK="${OPTIMIZED_DECK:-578647}"
OPPONENTS="${OPPONENTS:-575720 575716}"

RUNS_USER_DIR="${RUNS_USER_DIR:-user://training_data/$DECK_PREFIX/runs}"
RUNS_GLOBAL_DIR="${RUNS_GLOBAL_DIR:-$(globalize_user_path "$RUNS_USER_DIR")}"
RUN_REGISTRY_USER_DIR="${RUN_REGISTRY_USER_DIR:-user://training_runs/$PIPELINE_SUFFIX}"
VERSION_REGISTRY_USER_DIR="${VERSION_REGISTRY_USER_DIR:-user://ai_versions/$PIPELINE_SUFFIX}"
VERSION_REGISTRY_GLOBAL_DIR="${VERSION_REGISTRY_GLOBAL_DIR:-$(globalize_user_path "$VERSION_REGISTRY_USER_DIR")}"
AI_AGENTS_DIR="${AI_AGENTS_DIR:-$USER_ROOT/ai_agents}"
LEGACY_VALUE_NET="${LEGACY_VALUE_NET:-$AI_AGENTS_DIR/${DECK_PREFIX}_value_net.json}"
LEGACY_ACTION_SCORER="${LEGACY_ACTION_SCORER:-$AI_AGENTS_DIR/${DECK_PREFIX}_action_scorer.json}"
LEGACY_INTERACTION_SCORER="${LEGACY_INTERACTION_SCORER:-$AI_AGENTS_DIR/${DECK_PREFIX}_interaction_scorer.json}"
LATEST_LOG_POINTER="${LATEST_LOG_POINTER:-$PROJECT/${DECK_PREFIX}_decision_training_latest.txt}"
LOCK_DIR="${LOCK_DIR:-$USER_ROOT/locks/${DECK_PREFIX}_decision_training.lock}"

TRAIN_SCRIPT="${TRAIN_SCRIPT:-$PROJECT/scripts/training/train_value_net.py}"
ACTION_TRAIN_SCRIPT="${ACTION_TRAIN_SCRIPT:-$PROJECT/scripts/training/train_action_scorer.py}"
INTERACTION_TRAIN_SCRIPT="${INTERACTION_TRAIN_SCRIPT:-$PROJECT/scripts/training/train_interaction_scorer.py}"
COLLECT_SCENE="${COLLECT_SCENE:-res://scenes/tuner/ValueNetDataRunner.tscn}"
BENCHMARK_SCENE="${BENCHMARK_SCENE:-res://scenes/tuner/BenchmarkRunner.tscn}"

ROUNDS="${ROUNDS:-24}"
TIME_BUDGET_SECONDS="${TIME_BUDGET_SECONDS:-7200}"
WORKERS="${WORKERS:-8}"
MIRROR_GAMES_PER_WORKER="${MIRROR_GAMES_PER_WORKER:-25}"
CROSS_GAMES_PER_WORKER="${CROSS_GAMES_PER_WORKER:-13}"
BENCHMARK_GATE_THRESHOLD="${BENCHMARK_GATE_THRESHOLD:-0.55}"
BOOTSTRAP_GATE_THRESHOLD="${BOOTSTRAP_GATE_THRESHOLD:-0.0}"
BENCHMARK_SEED_SET="${BENCHMARK_SEED_SET:-11,29,47,83,101,149,197,239,283,331,379,431}"
TEACHER_WEIGHT="${TEACHER_WEIGHT:-0.0}"
DECISION_STATE_WEIGHT="${DECISION_STATE_WEIGHT:-0.75}"
INTERACTION_STATE_WEIGHT="${INTERACTION_STATE_WEIGHT:-0.5}"
VALUE_EPOCHS="${VALUE_EPOCHS:-160}"
ACTION_EPOCHS="${ACTION_EPOCHS:-24}"

RUN_STAMP="$(date +%Y%m%d_%H%M%S)_$$"
RUN_ID="${RUN_ID:-${DECK_PREFIX}_decision_run_$RUN_STAMP}"
RUN_USER_DIR="$RUNS_USER_DIR/$RUN_ID"
RUN_DIR="$RUNS_GLOBAL_DIR/$RUN_ID"
CURRENT_BEST_VALUE_USER_PATH="$RUN_USER_DIR/current_best/${DECK_PREFIX}_value_net.json"
CURRENT_BEST_VALUE_GLOBAL_PATH="$RUN_DIR/current_best/${DECK_PREFIX}_value_net.json"
CURRENT_BEST_ACTION_USER_PATH="$RUN_USER_DIR/current_best/${DECK_PREFIX}_action_scorer.json"
CURRENT_BEST_ACTION_GLOBAL_PATH="$RUN_DIR/current_best/${DECK_PREFIX}_action_scorer.json"
CURRENT_BEST_INTERACTION_USER_PATH="$RUN_USER_DIR/current_best/${DECK_PREFIX}_interaction_scorer.json"
CURRENT_BEST_INTERACTION_GLOBAL_PATH="$RUN_DIR/current_best/${DECK_PREFIX}_interaction_scorer.json"
LOG="$RUN_DIR/${DECK_PREFIX}_decision_training.log"
START_TS="$(date +%s)"

mkdir -p "$RUN_DIR/current_best" "$AI_AGENTS_DIR" "$VERSION_REGISTRY_GLOBAL_DIR"
printf '%s\n' "$LOG" > "$LATEST_LOG_POINTER"
: > "$LOG"

if ! acquire_lock; then
	exit 1
fi
trap 'release_lock' EXIT INT TERM

CURRENT_BASELINE_VERSION_ID=""
CURRENT_BASELINE_DISPLAY_NAME=""
CURRENT_BASELINE_SOURCE="greedy-bootstrap"
CURRENT_BASELINE_VALUE_USER_PATH=""
CURRENT_BASELINE_VALUE_GLOBAL_PATH=""
CURRENT_BASELINE_ACTION_USER_PATH=""
CURRENT_BASELINE_ACTION_GLOBAL_PATH=""
CURRENT_BASELINE_INTERACTION_USER_PATH=""
CURRENT_BASELINE_INTERACTION_GLOBAL_PATH=""
PROMOTIONS=0

if APPROVED_BASELINE_RAW="$(latest_approved_baseline 2>/dev/null)" && [[ -n "$APPROVED_BASELINE_RAW" ]]; then
	mapfile -t APPROVED_BASELINE_LINES <<<"$APPROVED_BASELINE_RAW"
	CURRENT_BASELINE_VERSION_ID="${APPROVED_BASELINE_LINES[0]:-}"
	CURRENT_BASELINE_DISPLAY_NAME="${APPROVED_BASELINE_LINES[1]:-}"
	CURRENT_BASELINE_VALUE_USER_PATH="${APPROVED_BASELINE_LINES[2]:-}"
	CURRENT_BASELINE_ACTION_USER_PATH="${APPROVED_BASELINE_LINES[3]:-}"
	CURRENT_BASELINE_INTERACTION_USER_PATH="${APPROVED_BASELINE_LINES[4]:-}"
	CURRENT_BASELINE_SOURCE="approved-playable"
	if [[ -n "$CURRENT_BASELINE_VALUE_USER_PATH" && -f "$(globalize_user_path "$CURRENT_BASELINE_VALUE_USER_PATH")" ]]; then
		sync_current_best "$CURRENT_BASELINE_VALUE_USER_PATH" "$CURRENT_BASELINE_ACTION_USER_PATH" "$CURRENT_BASELINE_INTERACTION_USER_PATH" || true
	fi
elif [[ -f "$LEGACY_VALUE_NET" ]]; then
	cp "$LEGACY_VALUE_NET" "$CURRENT_BEST_VALUE_GLOBAL_PATH"
	CURRENT_BASELINE_VALUE_USER_PATH="$CURRENT_BEST_VALUE_USER_PATH"
	CURRENT_BASELINE_VALUE_GLOBAL_PATH="$CURRENT_BEST_VALUE_GLOBAL_PATH"
	CURRENT_BASELINE_SOURCE="legacy-champion"
	if [[ -f "$LEGACY_ACTION_SCORER" ]]; then
		cp "$LEGACY_ACTION_SCORER" "$CURRENT_BEST_ACTION_GLOBAL_PATH"
		CURRENT_BASELINE_ACTION_USER_PATH="$CURRENT_BEST_ACTION_USER_PATH"
		CURRENT_BASELINE_ACTION_GLOBAL_PATH="$CURRENT_BEST_ACTION_GLOBAL_PATH"
	fi
	if [[ -f "$LEGACY_INTERACTION_SCORER" ]]; then
		cp "$LEGACY_INTERACTION_SCORER" "$CURRENT_BEST_INTERACTION_GLOBAL_PATH"
		CURRENT_BASELINE_INTERACTION_USER_PATH="$CURRENT_BEST_INTERACTION_USER_PATH"
		CURRENT_BASELINE_INTERACTION_GLOBAL_PATH="$CURRENT_BEST_INTERACTION_GLOBAL_PATH"
	fi
fi

log "===== ${DECK_NAME} Decision Training ====="
log "Run ID: $RUN_ID"
log "Start: $(date)"
log "Pipeline: $PIPELINE_NAME"
log "Encoder: $ENCODER"
log "Optimized deck: $OPTIMIZED_DECK"
log "Opponents: $OPPONENTS"
log "Time budget: ${TIME_BUDGET_SECONDS}s"
log "Baseline source: $CURRENT_BASELINE_SOURCE"
if [[ -n "$CURRENT_BASELINE_VERSION_ID" ]]; then
	log "Baseline version: $CURRENT_BASELINE_VERSION_ID"
fi
log ""

round=1
while [[ "$round" -le "$ROUNDS" ]]; do
	now_ts="$(date +%s)"
	if (( now_ts - START_TS >= TIME_BUDGET_SECONDS )); then
		log "[budget] stopping before round $round; time budget reached"
		break
	fi

	printf -v round_label "%02d" "$round"
	ROUND_DIR="$RUN_DIR/round_$round_label"
	ROUND_USER_DIR="$RUN_USER_DIR/round_$round_label"
	ROUND_DATA_DIR="$ROUND_DIR/self_play"
	ROUND_DATA_USER_DIR="$ROUND_USER_DIR/self_play"
	ROUND_ACTION_DATA_DIR="$ROUND_DIR/action_decisions"
	ROUND_ACTION_DATA_USER_DIR="$ROUND_USER_DIR/action_decisions"
	ROUND_MODEL_DIR="$ROUND_DIR/models"
	ROUND_BENCHMARK_DIR="$ROUND_DIR/benchmark"
	ROUND_VALUE_GLOBAL_PATH="$ROUND_MODEL_DIR/${DECK_PREFIX}_value_net_candidate_round_$round_label.json"
	ROUND_VALUE_USER_PATH="$ROUND_USER_DIR/models/${DECK_PREFIX}_value_net_candidate_round_$round_label.json"
	ROUND_ACTION_GLOBAL_PATH="$ROUND_MODEL_DIR/${DECK_PREFIX}_action_scorer_candidate_round_$round_label.json"
	ROUND_ACTION_USER_PATH="$ROUND_USER_DIR/models/${DECK_PREFIX}_action_scorer_candidate_round_$round_label.json"
	ROUND_INTERACTION_GLOBAL_PATH="$ROUND_MODEL_DIR/${DECK_PREFIX}_interaction_scorer_candidate_round_$round_label.json"
	ROUND_INTERACTION_USER_PATH="$ROUND_USER_DIR/models/${DECK_PREFIX}_interaction_scorer_candidate_round_$round_label.json"
	ROUND_SUMMARY_GLOBAL_PATH="$ROUND_BENCHMARK_DIR/summary.json"
	ROUND_SUMMARY_USER_PATH="$ROUND_USER_DIR/benchmark/summary.json"
	ROUND_ANOMALY_USER_PATH="$ROUND_USER_DIR/benchmark/anomaly_summary.json"
	ROUND_RUN_ID="${RUN_ID}_round_$round_label"
	mkdir -p "$ROUND_DATA_DIR" "$ROUND_ACTION_DATA_DIR" "$ROUND_MODEL_DIR" "$ROUND_BENCHMARK_DIR"

	log "========== ROUND $round =========="
	log "Time: $(date)"
	log "[R$round] Collecting mirror ($WORKERS x $MIRROR_GAMES_PER_WORKER)..."
	collect_parallel "$OPTIMIZED_DECK" "$OPTIMIZED_DECK" "$MIRROR_GAMES_PER_WORKER" $((round * 100000))
	log "[R$round] Mirror done"

	for opponent in $OPPONENTS; do
		log "[R$round] Collecting vs $opponent ($WORKERS x $CROSS_GAMES_PER_WORKER)..."
		collect_parallel "$OPTIMIZED_DECK" "$opponent" "$CROSS_GAMES_PER_WORKER" $((round * 100000 + opponent))
		log "[R$round] vs $opponent done"
	done

	DATA_COUNT="$(summarize_training_data "$ROUND_DATA_DIR")"
	ACTION_DATA_COUNT="$(summarize_action_training_data "$ROUND_ACTION_DATA_DIR")"
	log "[R$round] Value files: $DATA_COUNT"
	log "[R$round] Action files: $ACTION_DATA_COUNT"
	if [[ "$DATA_COUNT" -eq 0 || "$ACTION_DATA_COUNT" -eq 0 ]]; then
		log "[R$round] Missing training artifacts; skipping round."
		log ""
		round=$((round + 1))
		continue
	fi

	log "[R$round] Training value net..."
	"$PYTHON_BIN" "$TRAIN_SCRIPT" \
		--data-dir "$ROUND_DATA_DIR" \
		--decision-data-dir "$ROUND_ACTION_DATA_DIR" \
		--output "$ROUND_VALUE_GLOBAL_PATH" \
		--hidden1 128 --hidden2 64 --hidden3 32 \
		--decision-state-weight "$DECISION_STATE_WEIGHT" \
		--interaction-state-weight "$INTERACTION_STATE_WEIGHT" \
		--epochs "$VALUE_EPOCHS" --teacher-weight "$TEACHER_WEIGHT" --patience 15 \
		--batch-size 256 --lr 0.001 \
		>> "$LOG" 2>&1 || true

	log "[R$round] Training action scorer..."
	"$PYTHON_BIN" "$ACTION_TRAIN_SCRIPT" \
		--data-dir "$ROUND_ACTION_DATA_DIR" \
		--output "$ROUND_ACTION_GLOBAL_PATH" \
		--epochs "$ACTION_EPOCHS" \
		--batch-size 256 --lr 0.001 \
		>> "$LOG" 2>&1 || true

	log "[R$round] Training interaction scorer..."
	"$PYTHON_BIN" "$INTERACTION_TRAIN_SCRIPT" \
		--data-dir "$ROUND_ACTION_DATA_DIR" \
		--output "$ROUND_INTERACTION_GLOBAL_PATH" \
		--epochs "$ACTION_EPOCHS" \
		--batch-size 256 --lr 0.001 \
		>> "$LOG" 2>&1 || true

	if [[ ! -f "$ROUND_VALUE_GLOBAL_PATH" || ! -f "$ROUND_ACTION_GLOBAL_PATH" || ! -f "$ROUND_INTERACTION_GLOBAL_PATH" ]]; then
		log "[R$round] Candidate model missing; skipping benchmark."
		log ""
		round=$((round + 1))
		continue
	fi

	ROUND_GATE_THRESHOLD="$BENCHMARK_GATE_THRESHOLD"
	if [[ -z "$CURRENT_BASELINE_VALUE_USER_PATH" ]]; then
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
		--seed-set="$BENCHMARK_SEED_SET"
		--gate-threshold="$ROUND_GATE_THRESHOLD"
		--value-net-a="$ROUND_VALUE_USER_PATH"
		--action-scorer-a="$ROUND_ACTION_USER_PATH"
		--interaction-scorer-a="$ROUND_INTERACTION_USER_PATH"
		--summary-output="$ROUND_SUMMARY_USER_PATH"
		--anomaly-output="$ROUND_ANOMALY_USER_PATH"
		--run-id="$ROUND_RUN_ID"
		--run-dir="$ROUND_USER_DIR"
		--run-registry-dir="$RUN_REGISTRY_USER_DIR"
		--version-registry-dir="$VERSION_REGISTRY_USER_DIR"
		--publish-display-name="${DECK_NAME} decision round $round candidate"
		--baseline-source="$CURRENT_BASELINE_SOURCE"
		--baseline-version-id="$CURRENT_BASELINE_VERSION_ID"
		--baseline-display-name="$CURRENT_BASELINE_DISPLAY_NAME"
		--baseline-value-net="$CURRENT_BASELINE_VALUE_USER_PATH"
		--baseline-action-scorer="$CURRENT_BASELINE_ACTION_USER_PATH"
		--baseline-interaction-scorer="$CURRENT_BASELINE_INTERACTION_USER_PATH"
	)
	if [[ -n "$CURRENT_BASELINE_VALUE_USER_PATH" ]]; then
		BENCHMARK_ARGS+=(--value-net-b="$CURRENT_BASELINE_VALUE_USER_PATH")
	fi
	if [[ -n "$CURRENT_BASELINE_ACTION_USER_PATH" ]]; then
		BENCHMARK_ARGS+=(--action-scorer-b="$CURRENT_BASELINE_ACTION_USER_PATH")
	fi
	if [[ -n "$CURRENT_BASELINE_INTERACTION_USER_PATH" ]]; then
		BENCHMARK_ARGS+=(--interaction-scorer-b="$CURRENT_BASELINE_INTERACTION_USER_PATH")
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
		if sync_current_best "$ROUND_VALUE_USER_PATH" "$ROUND_ACTION_USER_PATH" "$ROUND_INTERACTION_USER_PATH"; then
			PROMOTIONS=$((PROMOTIONS + 1))
			CURRENT_BASELINE_SOURCE="published-run"
			if PROMOTED_BASELINE_RAW="$(latest_approved_baseline 2>/dev/null)" && [[ -n "$PROMOTED_BASELINE_RAW" ]]; then
				mapfile -t PROMOTED_BASELINE_LINES <<<"$PROMOTED_BASELINE_RAW"
				CURRENT_BASELINE_VERSION_ID="${PROMOTED_BASELINE_LINES[0]:-}"
				CURRENT_BASELINE_DISPLAY_NAME="${PROMOTED_BASELINE_LINES[1]:-}"
				CURRENT_BASELINE_VALUE_USER_PATH="${PROMOTED_BASELINE_LINES[2]:-}"
				CURRENT_BASELINE_ACTION_USER_PATH="${PROMOTED_BASELINE_LINES[3]:-}"
				CURRENT_BASELINE_INTERACTION_USER_PATH="${PROMOTED_BASELINE_LINES[4]:-}"
			fi
			log "[R$round] >>> PROMOTED (${WIN_RATE}%)"
		else
			log "[R$round] >>> Published, but syncing current best failed"
		fi
	else
		log "[R$round] >>> Rejected (${WIN_RATE}%). Baseline unchanged."
	fi

	log ""
	round=$((round + 1))
done

log "===== COMPLETE ====="
log "End: $(date)"
log "Promotions: $PROMOTIONS"
log "Current best value: $CURRENT_BEST_VALUE_GLOBAL_PATH"
log "Current best action: $CURRENT_BEST_ACTION_GLOBAL_PATH"
log "Current best interaction: $CURRENT_BEST_INTERACTION_GLOBAL_PATH"
