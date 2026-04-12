#!/bin/bash
# Miraidon Value Net v2 training: reward shaping + tournament gating + parallel collection
#
# Each round:
#   1. Collect data in 8 parallel Godot processes (winner-only + reward shaping)
#   2. Train candidate net
#   3. Tournament: candidate vs current champion
#   4. If candidate wins >55%, promote; else discard
#
# No data accumulation — each round uses only its own fresh data.

## 不用 set -e：Godot headless 进程退出码可能非零（资源清理警告），不应中断管线

GODOT="D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe"
PROJECT="D:/ai/code/ptcgtrain"
DATA_DIR="$APPDATA/Godot/app_userdata/PTCG Train/training_data/miraidon"
AGENTS_DIR="$APPDATA/Godot/app_userdata/PTCG Train/ai_agents"
CHAMPION="$AGENTS_DIR/miraidon_value_net.json"
CANDIDATE="$AGENTS_DIR/miraidon_value_net_candidate.json"
TRAIN_SCRIPT="$PROJECT/scripts/training/train_value_net.py"
COLLECT_SCENE="res://scenes/tuner/ValueNetDataRunner.tscn"
TOURNAMENT_SCENE="res://scenes/tuner/TournamentRunner.tscn"
TOURNAMENT_RESULT="$AGENTS_DIR/tournament_result.json"

MIRAIDON=575720
GARDEVOIR=578647
CHARIZARD=575716

ROUNDS=5
WORKERS=8
# Per-worker games (8 workers total)
MIRROR_GAMES_PER_WORKER=25   # 25 × 8 = 200 mirror
CROSS_GAMES_PER_WORKER=13    # 13 × 8 ≈ 100 per cross-deck
TOURNAMENT_GAMES=60
TEACHER_WEIGHT=0.2

LOG="$PROJECT/miraidon_training_v2.log"

# Parallel collection helper
# Usage: collect_parallel DECK_A DECK_B GAMES_PER_WORKER VNET_ARG SEED_BASE
collect_parallel() {
    local DECK_A=$1
    local DECK_B=$2
    local GAMES=$3
    local VNET_ARG="$4"
    local SEED_BASE=$5

    for WORKER in $(seq 0 $((WORKERS - 1))); do
        local OFFSET=$((SEED_BASE + WORKER * 10000))
        "$GODOT" --headless --path "$PROJECT" --quit-after 9999 \
            "$COLLECT_SCENE" -- \
            --games=$GAMES --deck-a=$DECK_A --deck-b=$DECK_B \
            --encoder=miraidon \
            --seed-offset=$OFFSET $VNET_ARG \
            > /dev/null 2>&1 &
    done
    wait || true
}

echo "===== Miraidon Training v2: Parallel + Reward Shaping + Tournament =====" | tee "$LOG"
echo "Start: $(date)" | tee -a "$LOG"
echo "Workers: $WORKERS parallel Godot instances" | tee -a "$LOG"
echo "Per round: ~200 mirror + ~100 vs Gardevoir + ~100 vs Charizard" | tee -a "$LOG"
echo "Tournament: ${TOURNAMENT_GAMES} games, threshold >55%" | tee -a "$LOG"
echo "" | tee -a "$LOG"

mkdir -p "$AGENTS_DIR"
mkdir -p "$DATA_DIR"

PROMOTIONS=0

for ROUND in $(seq 1 $ROUNDS); do
    echo "========== ROUND $ROUND / $ROUNDS ==========" | tee -a "$LOG"
    echo "Time: $(date)" | tee -a "$LOG"

    VNET_ARG=""
    if [ -f "$CHAMPION" ]; then
        VNET_ARG="--value-net=user://ai_agents/miraidon_value_net.json"
        echo "[R$ROUND] Collecting with current champion net" | tee -a "$LOG"
    else
        echo "[R$ROUND] No champion yet, collecting with greedy" | tee -a "$LOG"
    fi

    # Clean data from previous round
    rm -f "$DATA_DIR"/game_*.json

    ROUND_SEED=$((ROUND * 100000))

    # Parallel collection: mirror
    echo "[R$ROUND] Collecting mirror ($WORKERS × $MIRROR_GAMES_PER_WORKER games)..." | tee -a "$LOG"
    collect_parallel $MIRAIDON $MIRAIDON $MIRROR_GAMES_PER_WORKER "$VNET_ARG" $ROUND_SEED
    echo "[R$ROUND] Mirror done" | tee -a "$LOG"

    # Parallel collection: vs Gardevoir
    echo "[R$ROUND] Collecting vs Gardevoir ($WORKERS × $CROSS_GAMES_PER_WORKER games)..." | tee -a "$LOG"
    collect_parallel $MIRAIDON $GARDEVOIR $CROSS_GAMES_PER_WORKER "$VNET_ARG" $((ROUND_SEED + 50000))
    echo "[R$ROUND] vs Gardevoir done" | tee -a "$LOG"

    # Parallel collection: vs Charizard
    echo "[R$ROUND] Collecting vs Charizard ($WORKERS × $CROSS_GAMES_PER_WORKER games)..." | tee -a "$LOG"
    collect_parallel $MIRAIDON $CHARIZARD $CROSS_GAMES_PER_WORKER "$VNET_ARG" $((ROUND_SEED + 80000))
    echo "[R$ROUND] vs Charizard done" | tee -a "$LOG"

    FILE_COUNT=$(ls "$DATA_DIR"/game_*.json 2>/dev/null | wc -l)
    echo "[R$ROUND] Data files: $FILE_COUNT" | tee -a "$LOG"

    # Train candidate
    echo "[R$ROUND] Training candidate net..." | tee -a "$LOG"
    python "$TRAIN_SCRIPT" \
        --data-dir "$DATA_DIR" \
        --output "$CANDIDATE" \
        --hidden1 128 --hidden2 64 --hidden3 32 \
        --epochs 200 --teacher-weight $TEACHER_WEIGHT --patience 15 \
        --batch-size 256 --lr 0.001 \
        2>&1 | grep -E "^\[|Epoch.*val_loss|early stop|best" | tee -a "$LOG"

    # Tournament: candidate vs champion
    echo "[R$ROUND] Tournament ($TOURNAMENT_GAMES games)..." | tee -a "$LOG"

    CHAMPION_ARG=""
    if [ -f "$CHAMPION" ]; then
        CHAMPION_ARG="--champion=user://ai_agents/miraidon_value_net.json"
    fi

    rm -f "$TOURNAMENT_RESULT"
    "$GODOT" --headless --path "$PROJECT" --quit-after 9999 \
        "$TOURNAMENT_SCENE" -- \
        --games=$TOURNAMENT_GAMES \
        --challenger=user://ai_agents/miraidon_value_net_candidate.json \
        $CHAMPION_ARG \
        --result=user://ai_agents/tournament_result.json \
        2>&1 | grep -E "Challenger win rate|WINS|HOLDS" | tee -a "$LOG"

    # Read result
    if [ -f "$TOURNAMENT_RESULT" ]; then
        PROMOTED=$(python -c "import json; d=json.load(open(r'$TOURNAMENT_RESULT')); print('yes' if d.get('promoted',False) else 'no')" 2>/dev/null || echo "no")
        WIN_RATE=$(python -c "import json; d=json.load(open(r'$TOURNAMENT_RESULT')); print('%.1f' % (d.get('challenger_win_rate',0)*100))" 2>/dev/null || echo "?")
    else
        PROMOTED="no"
        WIN_RATE="?"
    fi

    if [ "$PROMOTED" = "yes" ]; then
        cp "$CANDIDATE" "$CHAMPION"
        PROMOTIONS=$((PROMOTIONS + 1))
        echo "[R$ROUND] >>> PROMOTED! (${WIN_RATE}%)" | tee -a "$LOG"
    else
        # R1 special: no champion yet, always promote
        if [ $ROUND -eq 1 ] && [ ! -f "$CHAMPION" ]; then
            cp "$CANDIDATE" "$CHAMPION"
            PROMOTIONS=$((PROMOTIONS + 1))
            echo "[R$ROUND] >>> First net deployed as baseline champion (${WIN_RATE}%)" | tee -a "$LOG"
        else
            echo "[R$ROUND] >>> Rejected (${WIN_RATE}%). Champion unchanged." | tee -a "$LOG"
        fi
    fi

    echo "" | tee -a "$LOG"
done

echo "===== ALL $ROUNDS ROUNDS COMPLETE =====" | tee -a "$LOG"
echo "End: $(date)" | tee -a "$LOG"
echo "Promotions: $PROMOTIONS / $ROUNDS" | tee -a "$LOG"
echo "Final champion: $CHAMPION" | tee -a "$LOG"
echo "Log: $LOG" | tee -a "$LOG"
