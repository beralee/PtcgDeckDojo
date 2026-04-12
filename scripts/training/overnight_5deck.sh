#!/bin/bash
## 5 卡组通宵训练（沙奈朵重点版）
## 沙奈朵：6 轮 × 14 个对手，~3 小时
## 其余 4 个卡组：各 4 轮，~1 小时/个
## 总计约 7 小时

GODOT="${GODOT:-D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe}"
PROJECT="${PROJECT:-D:/ai/code/ptcgtrain}"
PYTHON_BIN="${PYTHON:-python}"
USER_ROOT="$APPDATA/Godot/app_userdata/PTCG Train"
AGENTS_DIR="$USER_ROOT/ai_agents"
TRAIN_SCRIPT="$PROJECT/scripts/training/train_value_net.py"
COLLECT_SCENE="res://scenes/tuner/ValueNetDataRunner.tscn"

WORKERS=8
TEACHER_WEIGHT=0.2

LOG="$PROJECT/overnight_5deck_$(date +%Y%m%d_%H%M%S).log"

log() { printf '%s\n' "$*" >> "$LOG"; printf '%s\n' "$*"; }

collect_parallel() {
    local deck_a=$1 deck_b=$2 games=$3 seed_base=$4 encoder=$5
    for w in $(seq 0 $((WORKERS - 1))); do
        local offset=$((seed_base + w * 10000))
        "$GODOT" --headless --path "$PROJECT" --quit-after 9999 \
            "$COLLECT_SCENE" -- \
            --games=$games --deck-a=$deck_a --deck-b=$deck_b \
            --encoder=$encoder --seed-offset=$offset \
            > /dev/null 2>&1 &
    done
    wait || true
}

train_and_deploy() {
    local ENCODER=$1
    local DATA_DIR=$2
    local CHAMPION="$AGENTS_DIR/${ENCODER}_value_net.json"
    local CANDIDATE="$AGENTS_DIR/${ENCODER}_value_net_candidate.json"

    local FILE_COUNT=$(find "$DATA_DIR" -name 'game_*.json' 2>/dev/null | wc -l)
    log "  数据文件: $FILE_COUNT"

    if [ "$FILE_COUNT" -lt 10 ]; then
        log "  [跳过] 数据不足"
        return 1
    fi

    log "  训练候选模型..."
    "$PYTHON_BIN" "$TRAIN_SCRIPT" \
        --data-dir "$DATA_DIR" \
        --output "$CANDIDATE" \
        --hidden1 128 --hidden2 64 --hidden3 32 \
        --epochs 200 --teacher-weight $TEACHER_WEIGHT --patience 15 \
        --batch-size 256 --lr 0.001 \
        >> "$LOG" 2>&1 || true

    if [ ! -f "$CANDIDATE" ]; then
        log "  [跳过] 候选模型生成失败"
        return 1
    fi

    cp "$CANDIDATE" "$CHAMPION"
    local SIZE=$(wc -c < "$CHAMPION")
    log "  >>> Champion 已更新 ($SIZE bytes)"
    return 0
}


# ===== 主流程 =====

log "=================================================="
log "  5 卡组通宵训练（沙奈朵重点版）"
log "  $(date)"
log "  日志: $LOG"
log "=================================================="

START_TIME=$(date +%s)

# =====================================================
#  沙奈朵：6 轮，14 个对手，数据量最大
#  每轮：400 镜像 + 14 × 120 跨卡组 = ~2080 局
#  预计 6 × 25 分钟 = 2.5 小时
# =====================================================

GARDEVOIR=578647
GARDEVOIR_ENCODER=gardevoir
GARDEVOIR_DATA="$USER_ROOT/training_data/gardevoir"
GARDEVOIR_ROUNDS=6
GARDEVOIR_MIRROR_PER_WORKER=50    # 8×50 = 400 镜像
GARDEVOIR_CROSS_PER_WORKER=15     # 8×15 = 120 per opponent

# 所有可用对手
GARDEVOIR_OPPONENTS=(
    575720   # 密勒顿
    575723   # 多龙巴鲁托 黑夜魔灵
    579502   # 多龙巴鲁托 喷火龙
    569061   # 阿尔宙斯 骑拉帝纳
    575716   # 喷火龙 大比鸟
    580445   # 多龙巴鲁托 诅咒娃娃
    575653   # 雷吉铎拉戈
    575657   # 洛奇亚 始祖大鸟
    561444   # 起源帝牙卢卡
    575718   # 猛雷鼓 厄诡椪
    579577   # 铁荆棘
    581056   # 雷吉铎拉戈(另一套)
    575620   # 放逐Box
    582754   # 破空焰
)

log ""
log "########## 沙奈朵 重点训练 (6 轮 × 14 对手) ##########"

mkdir -p "$GARDEVOIR_DATA" "$AGENTS_DIR"

for round in $(seq 1 $GARDEVOIR_ROUNDS); do
    log ""
    log "--- 沙奈朵 R$round/$GARDEVOIR_ROUNDS ($(date +%H:%M:%S)) ---"

    rm -f "$GARDEVOIR_DATA"/game_*.json
    RSEED=$((GARDEVOIR + round * 100000))

    # 镜像
    log "  采集镜像 ($WORKERS×$GARDEVOIR_MIRROR_PER_WORKER = $((WORKERS * GARDEVOIR_MIRROR_PER_WORKER)))..."
    collect_parallel $GARDEVOIR $GARDEVOIR $GARDEVOIR_MIRROR_PER_WORKER $RSEED $GARDEVOIR_ENCODER
    log "  镜像完成"

    # 跨卡组：14 个对手
    local opp_offset=50000
    for opp_id in "${GARDEVOIR_OPPONENTS[@]}"; do
        collect_parallel $GARDEVOIR $opp_id $GARDEVOIR_CROSS_PER_WORKER $((RSEED + opp_offset)) $GARDEVOIR_ENCODER
        opp_offset=$((opp_offset + 5000))
    done
    log "  14 个对手采集完成"

    train_and_deploy $GARDEVOIR_ENCODER "$GARDEVOIR_DATA"
    log "  R$round 完成"
done

log ""
log "===== 沙奈朵 6 轮训练完成 ====="


# =====================================================
#  其余 4 个卡组：各 4 轮，标准配置
#  每轮：200 镜像 + 3 × 104 跨卡组 = ~512 局
#  预计 4 × 12 分钟 × 4 卡组 = 3.2 小时
# =====================================================

OTHER_ROUNDS=4
OTHER_MIRROR_PER_WORKER=25
OTHER_CROSS_PER_WORKER=13

train_other_deck() {
    local DECK_NAME=$1
    local DECK_ID=$2
    local ENCODER=$3
    shift 3
    local OPPONENTS=("$@")
    local DATA_DIR="$USER_ROOT/training_data/$ENCODER"

    mkdir -p "$DATA_DIR"

    log ""
    log "########## $DECK_NAME (ID=$DECK_ID) ##########"

    for round in $(seq 1 $OTHER_ROUNDS); do
        log "--- $DECK_NAME R$round/$OTHER_ROUNDS ($(date +%H:%M:%S)) ---"

        rm -f "$DATA_DIR"/game_*.json
        local RSEED=$((DECK_ID + round * 100000))

        log "  采集镜像 ($WORKERS×$OTHER_MIRROR_PER_WORKER)..."
        collect_parallel $DECK_ID $DECK_ID $OTHER_MIRROR_PER_WORKER $RSEED $ENCODER
        log "  镜像完成"

        local opp_offset=50000
        for opp_id in "${OPPONENTS[@]}"; do
            collect_parallel $DECK_ID $opp_id $OTHER_CROSS_PER_WORKER $((RSEED + opp_offset)) $ENCODER
            opp_offset=$((opp_offset + 20000))
        done
        log "  跨卡组完成"

        train_and_deploy $ENCODER "$DATA_DIR"
        log "  R$round 完成"
    done

    log "===== $DECK_NAME 训练完成 ====="
}

# 密勒顿
train_other_deck "密勒顿" 575720 miraidon \
    578647 569061 575723 575716

# 阿尔宙斯 骑拉帝纳
train_other_deck "阿尔宙斯骑拉帝纳" 569061 arceus_giratina \
    575720 578647 575723

# 多龙巴鲁托 黑夜魔灵
train_other_deck "多龙巴鲁托黑夜魔灵" 575723 dragapult_dusknoir \
    575720 578647 569061

# 多龙巴鲁托 喷火龙
train_other_deck "多龙巴鲁托喷火龙" 579502 dragapult_charizard \
    575720 578647 575723


# ===== 汇总 =====

END_TIME=$(date +%s)
ELAPSED=$(( (END_TIME - START_TIME) / 60 ))

log ""
log "=================================================="
log "  全部完成！总耗时: ${ELAPSED} 分钟"
log "  $(date)"
log "=================================================="
log ""
log "--- Champion 文件 ---"
for enc in gardevoir miraidon arceus_giratina dragapult_dusknoir dragapult_charizard; do
    f="$AGENTS_DIR/${enc}_value_net.json"
    if [ -f "$f" ]; then
        log "  $enc: $(wc -c < "$f") bytes ($(date -r "$f" +%H:%M))"
    else
        log "  $enc: 无"
    fi
done
