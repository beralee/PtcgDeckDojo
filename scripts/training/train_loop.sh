#!/usr/bin/env bash
# PTCG Train 价值网络迭代训练脚本
# 自动循环: 自博弈导出数据 -> Python 训练 -> 加载新权重 -> 重复
#
# 用法:
#   bash scripts/training/train_loop.sh [OPTIONS]
#
# 选项:
#   --godot PATH        Godot 可执行文件路径 (默认: godot)
#   --iterations N      训练迭代次数 (默认: 5)
#   --generations N     每轮自博弈代数 (默认: 10)
#   --epochs N          每轮 Python 训练轮数 (默认: 100)
#   --data-dir PATH     训练数据目录 (默认: 自动检测 user:// 路径)
#   --model-dir PATH    模型输出目录 (默认: ./models)

set -euo pipefail

# 默认参数
GODOT="${GODOT:-godot}"
ITERATIONS=5
GENERATIONS=10
EPOCHS=100
DATA_DIR=""
MODEL_DIR="./models"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --godot) GODOT="$2"; shift 2 ;;
        --iterations) ITERATIONS="$2"; shift 2 ;;
        --generations) GENERATIONS="$2"; shift 2 ;;
        --epochs) EPOCHS="$2"; shift 2 ;;
        --data-dir) DATA_DIR="$2"; shift 2 ;;
        --model-dir) MODEL_DIR="$2"; shift 2 ;;
        *) echo "[错误] 未知参数: $1"; exit 1 ;;
    esac
done

# 自动检测 Godot user:// 目录
if [[ -z "$DATA_DIR" ]]; then
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        DATA_DIR="$APPDATA/Godot/app_userdata/PTCG Train/training_data"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/PTCG Train/training_data"
    else
        DATA_DIR="$HOME/.local/share/godot/app_userdata/PTCG Train/training_data"
    fi
fi

mkdir -p "$MODEL_DIR"
mkdir -p "$DATA_DIR"

echo "===== PTCG Train 迭代训练 ====="
echo "Godot:       $GODOT"
echo "项目目录:    $PROJECT_DIR"
echo "数据目录:    $DATA_DIR"
echo "模型目录:    $MODEL_DIR"
echo "迭代次数:    $ITERATIONS"
echo "每轮代数:    $GENERATIONS"
echo "训练轮数:    $EPOCHS"
echo ""

CURRENT_WEIGHTS=""

for i in $(seq 1 "$ITERATIONS"); do
    echo ""
    echo "===== 迭代 $i / $ITERATIONS ====="

    # 阶段 1: 自博弈导出训练数据
    echo "[阶段 1] 运行自博弈 ($GENERATIONS 代)..."
    GODOT_ARGS="--headless --quit-after 3600 --path $PROJECT_DIR res://scenes/tuner/TunerRunner.tscn -- --generations=$GENERATIONS --export-data"
    if [[ -n "$CURRENT_WEIGHTS" ]]; then
        GODOT_ARGS="$GODOT_ARGS --value-net=$CURRENT_WEIGHTS"
        echo "  使用价值网络: $CURRENT_WEIGHTS"
    fi
    "$GODOT" $GODOT_ARGS || {
        echo "[警告] Godot 退出码非零，继续训练..."
    }

    # 统计训练数据
    DATA_COUNT=$(find "$DATA_DIR" -name "game_*.json" 2>/dev/null | wc -l)
    echo "  累计训练数据: $DATA_COUNT 局"

    if [[ "$DATA_COUNT" -eq 0 ]]; then
        echo "[错误] 没有训练数据，跳过训练"
        continue
    fi

    # 阶段 2: Python 训练
    WEIGHTS_FILE="$MODEL_DIR/value_net_v${i}.json"
    echo "[阶段 2] 训练价值网络 ($EPOCHS epochs)..."
    python "$PROJECT_DIR/scripts/training/train_value_net.py" \
        --data-dir "$DATA_DIR" \
        --output "$WEIGHTS_FILE" \
        --epochs "$EPOCHS" \
        --batch-size 256 \
        --lr 0.001

    if [[ ! -f "$WEIGHTS_FILE" ]]; then
        echo "[错误] 训练输出文件不存在: $WEIGHTS_FILE"
        continue
    fi

    echo "  权重已保存: $WEIGHTS_FILE"

    # 阶段 3: 更新权重路径供下一轮使用
    # 注意: TunerRunner 需要 user:// 格式路径, 但 --value-net 也接受绝对路径
    # 这里使用绝对路径
    CURRENT_WEIGHTS="$WEIGHTS_FILE"

    echo "[迭代 $i 完成] 权重: $WEIGHTS_FILE"
done

echo ""
echo "===== 训练完成 ====="
echo "最终权重: ${CURRENT_WEIGHTS:-无}"
echo "训练数据: ${DATA_COUNT:-0} 局"
echo ""
echo "使用方法:"
echo "  将权重拷贝到 Godot user://ai_models/ 目录"
echo "  或直接使用: --value-net=$CURRENT_WEIGHTS"
