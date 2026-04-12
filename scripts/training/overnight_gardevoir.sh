#!/bin/bash
# Gardevoir Value Net overnight training: 5 rounds iterative self-play
# Accumulates data across rounds, decreasing teacher weight each round

set -e

GODOT="D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe"
PROJECT="D:/ai/code/ptcgtrain"
DATA_DIR="$APPDATA/Godot/app_userdata/PTCG Train/training_data/gardevoir"
WEIGHTS="$APPDATA/Godot/app_userdata/PTCG Train/ai_agents/gardevoir_value_net.json"
TRAIN_SCRIPT="$PROJECT/scripts/training/train_value_net.py"
SCENE="res://scenes/tuner/ValueNetDataRunner.tscn"

GARDEVOIR=578647
MIRAIDON=575720
CHARIZARD=575716

TEACHER_WEIGHTS=(0.3 0.25 0.2 0.15 0.1)
MIRROR_GAMES=80
CROSS_GAMES=40

LOG="$PROJECT/gardevoir_training.log"
echo "===== Gardevoir Overnight Training =====" | tee "$LOG"
echo "Start: $(date)" | tee -a "$LOG"

for ROUND in 1 2 3 4 5; do
    echo "" | tee -a "$LOG"
    echo "========== ROUND $ROUND / 5 ==========" | tee -a "$LOG"
    echo "Time: $(date)" | tee -a "$LOG"

    TW=${TEACHER_WEIGHTS[$((ROUND-1))]}
    VNET_ARG=""
    if [ $ROUND -gt 1 ] && [ -f "$WEIGHTS" ]; then
        VNET_ARG="--value-net=user://ai_agents/gardevoir_value_net.json"
        echo "Using value net from previous round" | tee -a "$LOG"
    fi

    # Use different seed offsets per round to avoid duplicate games
    SEED_OFFSET=$((ROUND * 10000))

    # Mirror matches (Gardevoir vs Gardevoir)
    echo "[R$ROUND] Collecting $MIRROR_GAMES mirror matches..." | tee -a "$LOG"
    "$GODOT" --headless --path "$PROJECT" --quit-after 9999 \
        "$SCENE" -- --games=$MIRROR_GAMES --deck-a=$GARDEVOIR --deck-b=$GARDEVOIR $VNET_ARG \
        2>&1 | tail -5 | tee -a "$LOG"

    # vs Miraidon
    echo "[R$ROUND] Collecting $CROSS_GAMES vs Miraidon..." | tee -a "$LOG"
    "$GODOT" --headless --path "$PROJECT" --quit-after 9999 \
        "$SCENE" -- --games=$CROSS_GAMES --deck-a=$GARDEVOIR --deck-b=$MIRAIDON $VNET_ARG \
        2>&1 | tail -5 | tee -a "$LOG"

    # vs Charizard
    echo "[R$ROUND] Collecting $CROSS_GAMES vs Charizard..." | tee -a "$LOG"
    "$GODOT" --headless --path "$PROJECT" --quit-after 9999 \
        "$SCENE" -- --games=$CROSS_GAMES --deck-a=$GARDEVOIR --deck-b=$CHARIZARD $VNET_ARG \
        2>&1 | tail -5 | tee -a "$LOG"

    # Count accumulated data
    FILE_COUNT=$(ls "$DATA_DIR"/game_*.json 2>/dev/null | wc -l)
    echo "[R$ROUND] Accumulated files: $FILE_COUNT" | tee -a "$LOG"

    # Train
    echo "[R$ROUND] Training with teacher_weight=$TW ..." | tee -a "$LOG"
    python "$TRAIN_SCRIPT" \
        --data-dir "$DATA_DIR" \
        --output "$WEIGHTS" \
        --hidden1 128 --hidden2 64 --hidden3 32 \
        --epochs 200 --teacher-weight $TW --patience 15 \
        --batch-size 256 --lr 0.001 \
        2>&1 | tee -a "$LOG"

    echo "[R$ROUND] Done. Weights saved." | tee -a "$LOG"
done

echo "" | tee -a "$LOG"
echo "===== ALL 5 ROUNDS COMPLETE =====" | tee -a "$LOG"
echo "End: $(date)" | tee -a "$LOG"
echo "Final weights: $WEIGHTS" | tee -a "$LOG"
FILE_COUNT=$(ls "$DATA_DIR"/game_*.json 2>/dev/null | wc -l)
echo "Total data files: $FILE_COUNT" | tee -a "$LOG"
echo "Training log: $LOG" | tee -a "$LOG"
