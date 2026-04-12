#!/bin/bash
## 补跑 3 个卡组的训练（沙奈朵和密勒顿已完成）

GODOT="${GODOT:-D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe}"
PROJECT="${PROJECT:-D:/ai/code/ptcgtrain}"
PYTHON_BIN="${PYTHON:-python}"
USER_ROOT="$APPDATA/Godot/app_userdata/PTCG Train"
AGENTS_DIR="$USER_ROOT/ai_agents"
TRAIN_SCRIPT="$PROJECT/scripts/training/train_value_net.py"
COLLECT_SCENE="res://scenes/tuner/ValueNetDataRunner.tscn"

WORKERS=8
ROUNDS=4
MIRROR_PW=25
CROSS_PW=13
TEACHER_WEIGHT=0.2

LOG="$PROJECT/overnight_remaining3_$(date +%Y%m%d_%H%M%S).log"

log() { printf '%s\n' "$*" >> "$LOG"; printf '%s\n' "$*"; }

collect_p() {
    local da=$1 db=$2 gm=$3 sb=$4 enc=$5
    for w in $(seq 0 $((WORKERS - 1))); do
        "$GODOT" --headless --path "$PROJECT" --quit-after 9999 \
            "$COLLECT_SCENE" -- \
            --games=$gm --deck-a=$da --deck-b=$db \
            --encoder=$enc --seed-offset=$((sb + w * 10000)) \
            > /dev/null 2>&1 &
    done
    wait || true
}

do_train() {
    local enc=$1 data_dir=$2
    local champ="$AGENTS_DIR/${enc}_value_net.json"
    local cand="$AGENTS_DIR/${enc}_value_net_candidate.json"
    local fc=$(find "$data_dir" -name 'game_*.json' 2>/dev/null | wc -l)
    log "  数据: $fc 文件"
    if [ "$fc" -lt 10 ]; then log "  [跳过] 数据不足"; return; fi
    "$PYTHON_BIN" "$TRAIN_SCRIPT" --data-dir "$data_dir" --output "$cand" \
        --hidden1 128 --hidden2 64 --hidden3 32 \
        --epochs 200 --teacher-weight $TEACHER_WEIGHT --patience 15 \
        --batch-size 256 --lr 0.001 >> "$LOG" 2>&1 || true
    if [ -f "$cand" ]; then
        cp "$cand" "$champ"
        log "  >>> Champion 更新 ($(wc -c < "$champ") bytes)"
    fi
}

log "===== 补跑 3 卡组 $(date) ====="
mkdir -p "$AGENTS_DIR"

# ========== 阿尔宙斯 骑拉帝纳 ==========
DID=569061; ENC=arceus_giratina; DDIR="$USER_ROOT/training_data/$ENC"
mkdir -p "$DDIR"
log ""
log "########## 阿尔宙斯骑拉帝纳 ($DID) ##########"
for r in $(seq 1 $ROUNDS); do
    log "--- R$r/$ROUNDS ($(date +%H:%M:%S)) ---"
    rm -f "$DDIR"/game_*.json
    RS=$((DID + r * 100000))
    collect_p $DID $DID $MIRROR_PW $RS $ENC
    collect_p $DID 575720 $CROSS_PW $((RS+50000)) $ENC
    collect_p $DID 578647 $CROSS_PW $((RS+70000)) $ENC
    collect_p $DID 575723 $CROSS_PW $((RS+90000)) $ENC
    do_train $ENC "$DDIR"
    log "  R$r 完成"
done
log "===== 阿尔宙斯骑拉帝纳 完成 ====="

# ========== 多龙巴鲁托 黑夜魔灵 ==========
DID=575723; ENC=dragapult_dusknoir; DDIR="$USER_ROOT/training_data/$ENC"
mkdir -p "$DDIR"
log ""
log "########## 多龙巴鲁托黑夜魔灵 ($DID) ##########"
for r in $(seq 1 $ROUNDS); do
    log "--- R$r/$ROUNDS ($(date +%H:%M:%S)) ---"
    rm -f "$DDIR"/game_*.json
    RS=$((DID + r * 100000))
    collect_p $DID $DID $MIRROR_PW $RS $ENC
    collect_p $DID 575720 $CROSS_PW $((RS+50000)) $ENC
    collect_p $DID 578647 $CROSS_PW $((RS+70000)) $ENC
    collect_p $DID 569061 $CROSS_PW $((RS+90000)) $ENC
    do_train $ENC "$DDIR"
    log "  R$r 完成"
done
log "===== 多龙巴鲁托黑夜魔灵 完成 ====="

# ========== 多龙巴鲁托 喷火龙 ==========
DID=579502; ENC=dragapult_charizard; DDIR="$USER_ROOT/training_data/$ENC"
mkdir -p "$DDIR"
log ""
log "########## 多龙巴鲁托喷火龙 ($DID) ##########"
for r in $(seq 1 $ROUNDS); do
    log "--- R$r/$ROUNDS ($(date +%H:%M:%S)) ---"
    rm -f "$DDIR"/game_*.json
    RS=$((DID + r * 100000))
    collect_p $DID $DID $MIRROR_PW $RS $ENC
    collect_p $DID 575720 $CROSS_PW $((RS+50000)) $ENC
    collect_p $DID 578647 $CROSS_PW $((RS+70000)) $ENC
    collect_p $DID 575723 $CROSS_PW $((RS+90000)) $ENC
    do_train $ENC "$DDIR"
    log "  R$r 完成"
done
log "===== 多龙巴鲁托喷火龙 完成 ====="

END=$(date +%s)
log ""
log "===== 全部完成 $(date) ====="
for e in arceus_giratina dragapult_dusknoir dragapult_charizard; do
    f="$AGENTS_DIR/${e}_value_net.json"
    if [ -f "$f" ]; then log "  $e: $(wc -c < "$f") bytes"; else log "  $e: 无"; fi
done
