#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export DECK_NAME="gardevoir"
export DECK_PREFIX="gardevoir"
export ENCODER="gardevoir"
export PIPELINE_NAME="gardevoir_focus_training"
export PIPELINE_SUFFIX="gardevoir_focus"
export OPTIMIZED_DECK="578647"
export OPPONENTS="${OPPONENTS:-575720 575716 569061}"
exec bash "$SCRIPT_DIR/run_decision_training.sh"
