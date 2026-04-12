#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export DECK_NAME="miraidon"
export DECK_PREFIX="miraidon"
export ENCODER="miraidon"
export PIPELINE_NAME="miraidon_focus_training"
export PIPELINE_SUFFIX="miraidon_focus"
export OPTIMIZED_DECK="575720"
export OPPONENTS="${OPPONENTS:-578647 575716 569061}"
exec bash "$SCRIPT_DIR/run_decision_training.sh"
