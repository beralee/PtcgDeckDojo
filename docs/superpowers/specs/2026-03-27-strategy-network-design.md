# Phase 5.2 策略网络设计文档（价值网络优先）

日期：2026-03-27

## 1. 背景

Phase 5.1 建立了 self-play pipeline（EvolutionEngine + SelfPlayRunner + AgentVersionStore），可以通过进化搜索调优 heuristic 权重和 MCTS 参数。但 AI 的上限受限于手写 heuristic 评估函数——无论怎么调权重，AI 都不能发现 heuristic 未编码的策略。

本设计引入神经网络价值函数，替代 MCTS 的 rollout 模拟，让 AI 从自博弈数据中学到更深层的局面评估能力。

## 2. 目标

### 2.1 功能目标

1. GameState → 固定长度特征向量的编码器（StateEncoder）
2. 自博弈过程中导出训练数据（SelfPlayDataExporter）
3. Python 训练脚本，用对局数据训练价值网络（train_value_net.py）
4. GDScript 纯前馈网络推理引擎（NeuralNetInference）
5. MCTSPlanner 集成价值网络，替代 rollout 评估

### 2.2 性能目标

1. StateEncoder.encode() 单次调用 < 0.1ms
2. NeuralNetInference.predict() 单次推理 < 0.5ms（30→64→32→1 MLP）
3. MCTS 评估单条序列从 ~500ms（20 次 rollout）降到 < 1ms（单次推理）
4. Python 训练 1000 局数据 < 5 分钟

### 2.3 非目标

1. 不实现策略头（Policy head）——属于后续 P+V 升级
2. 不实现在线训练（训练和推理严格分离）
3. 不实现卷积网络或 Transformer——只用 MLP
4. 不修改游戏引擎核心

## 3. 架构

### 3.1 语言边界

```
Godot (GDScript)                         Python
+-- StateEncoder.gd                      +-- train_value_net.py
|   GameState -> float[30]               |   PyTorch 训练
+-- SelfPlayDataExporter.gd              |   导出权重 JSON
|   对局数据 -> JSON 文件                 +----------+
+-- NeuralNetInference.gd                           |
|   加载 JSON 权重, 前馈推理              <-- 权重 JSON --+
+-- MCTSPlanner.gd (修改)
    用 NeuralNetInference 替代 rollout
```

训练离线运行（Python 脚本），推理嵌入游戏（GDScript）。两端通过 JSON 文件通信，无需实时进程间通信。

### 3.2 新增模块

| 文件 | 语言 | 职责 |
|------|------|------|
| `scripts/ai/StateEncoder.gd` | GDScript | 局面编码为特征向量 |
| `scripts/ai/SelfPlayDataExporter.gd` | GDScript | 对局数据收集和导出 |
| `scripts/ai/NeuralNetInference.gd` | GDScript | 前馈网络推理 |
| `scripts/training/train_value_net.py` | Python | 价值网络训练 |
| `scripts/training/requirements.txt` | Python | Python 依赖 |

### 3.3 修改模块

| 文件 | 修改内容 |
|------|----------|
| `scripts/ai/MCTSPlanner.gd` | 添加价值网络评估路径 |
| `scripts/ai/SelfPlayRunner.gd` | 集成 SelfPlayDataExporter |
| `scripts/ai/EvolutionEngine.gd` | 支持 value_net_path 配置 |

## 4. StateEncoder 详细设计

### 4.1 特征向量结构

对称编码，以当前评估玩家为视角。向量维度 = 30。

```
索引 0-13:   自己的特征 (14 维)
索引 14-27:  对手的特征 (14 维)
索引 28:     回合数归一化 (turn_number / 30, clamp 到 1.0)
索引 29:     是否先手 (0.0 或 1.0)
```

每个玩家 14 维特征：

| 索引 | 特征 | 计算方式 | 值域 |
|------|------|----------|------|
| 0 | active_hp_ratio | (max_hp - damage) / max_hp | [0, 1] |
| 1 | active_damage_ratio | damage / max_hp | [0, 1] |
| 2 | active_energy_count | attached_energy.size() / 5.0 | [0, 1+] |
| 3 | active_can_attack | 1.0 if 能量满足任意攻击 else 0.0 | {0, 1} |
| 4 | active_is_ex | 1.0 if 名字含 "ex" | {0, 1} |
| 5 | active_stage | 0=Basic, 0.5=Stage1, 1.0=Stage2 | {0, 0.5, 1} |
| 6 | bench_count | bench.size() / 5.0 | [0, 1] |
| 7 | bench_total_hp | 备战区总剩余HP / 500.0 | [0, 1+] |
| 8 | bench_total_energy | 备战区总能量数 / 10.0 | [0, 1+] |
| 9 | hand_size | hand.size() / 20.0 | [0, 1+] |
| 10 | deck_size | deck.size() / 40.0 | [0, 1+] |
| 11 | prizes_remaining | prizes.size() / 6.0 | [0, 1] |
| 12 | supporter_available | 1.0 if !supporter_used_this_turn | {0, 1} |
| 13 | energy_available | 1.0 if !energy_attached_this_turn | {0, 1} |

### 4.2 接口

```gdscript
class_name StateEncoder
extends RefCounted

const FEATURE_DIM: int = 30

static func encode(game_state: GameState, perspective_player: int) -> Array[float]
```

## 5. SelfPlayDataExporter 详细设计

### 5.1 职责

在自博弈对战中收集每回合的局面特征，对局结束后用胜负结果回填，导出为 JSON。

### 5.2 接口

```gdscript
class_name SelfPlayDataExporter
extends RefCounted

var base_dir: String = "user://training_data"

func start_game() -> void
func record_state(game_state: GameState, current_player: int) -> void
func end_game(winner_index: int) -> void
func export_game() -> String  # 返回写入文件路径
```

### 5.3 导出文件格式

```json
{
  "version": "1.0",
  "winner_index": 0,
  "total_turns": 12,
  "records": [
    {
      "turn": 1,
      "player": 0,
      "features": [0.83, 0.0, 0.2, 1.0, 0.0, ...],
      "result": 1.0
    },
    {
      "turn": 1,
      "player": 1,
      "features": [1.0, 0.0, 0.0, 0.0, 1.0, ...],
      "result": 0.0
    }
  ]
}
```

- `result`: 1.0 = 该玩家最终获胜, 0.0 = 最终落败, 0.5 = 平局/未终局
- 每回合开始时记录双方视角各一条

### 5.4 存储路径

`user://training_data/game_{timestamp}_{seed}.json`

### 5.5 集成点

SelfPlayRunner._run_one_match() 中：
1. 创建 exporter, 调用 start_game()
2. 在 run_headless_duel 循环中，每次回合切换时调用 record_state()
3. 对局结束后调用 end_game() + export_game()

为保持向后兼容，通过一个 `export_training_data: bool = false` 开关控制。

## 6. NeuralNetInference 详细设计

### 6.1 职责

纯 GDScript 前馈网络推理。加载 JSON 权重，执行矩阵-向量乘法。

### 6.2 网络结构

```
Input (30) → Linear(30, 64) → ReLU → Linear(64, 32) → ReLU → Linear(32, 1) → Sigmoid
```

参数量：30×64 + 64 + 64×32 + 32 + 32×1 + 1 = 1920 + 64 + 2048 + 32 + 32 + 1 = 4097

### 6.3 接口

```gdscript
class_name NeuralNetInference
extends RefCounted

var _layers: Array[Dictionary] = []  # 每层 {"weights": Array, "bias": Array}
var _loaded: bool = false

func load_weights(path: String) -> bool
func predict(features: Array[float]) -> float
func is_loaded() -> bool
```

### 6.4 权重文件格式

```json
{
  "architecture": "mlp",
  "input_dim": 30,
  "layers": [
    {
      "out_features": 64,
      "activation": "relu",
      "weights": [[w00, w01, ...], [w10, w11, ...], ...],
      "bias": [b0, b1, ...]
    },
    {
      "out_features": 32,
      "activation": "relu",
      "weights": [[...], ...],
      "bias": [...]
    },
    {
      "out_features": 1,
      "activation": "sigmoid",
      "weights": [[...], ...],
      "bias": [...]
    }
  ]
}
```

### 6.5 推理实现

```
对每层:
  output = []
  对每个输出神经元 j:
    sum = bias[j]
    对每个输入 i:
      sum += weights[j][i] * input[i]
    output.append(sum)
  应用激活函数 (ReLU 或 Sigmoid)
  input = output
返回 output[0]
```

## 7. train_value_net.py 详细设计

### 7.1 职责

加载 Godot 导出的 JSON 训练数据，训练 PyTorch 价值网络，导出权重为 GDScript 可读的 JSON。

### 7.2 命令行接口

```bash
python scripts/training/train_value_net.py \
  --data-dir "path/to/training_data" \
  --output "path/to/value_net_weights.json" \
  --epochs 100 \
  --batch-size 256 \
  --lr 0.001 \
  --hidden1 64 \
  --hidden2 32
```

### 7.3 训练流程

1. 扫描 data-dir 下所有 `game_*.json` 文件
2. 提取所有 (features, result) 对
3. 80/20 划分训练集/验证集
4. 训练 BCELoss, Adam 优化器
5. 每 10 epoch 打印训练/验证 loss
6. 训练完成后导出权重 JSON

### 7.4 依赖

```
torch>=2.0
numpy
```

## 8. MCTSPlanner 集成

### 8.1 修改点

`MCTSPlanner._evaluate_sequence()` 当前逻辑：

```
克隆 GSM → 执行序列 → 跑 N 次 rollout → 返回平均胜率
```

新增价值网络路径：

```
克隆 GSM → 执行序列 →
  如果有价值网络:
    StateEncoder.encode(gsm.game_state, player) → NeuralNetInference.predict() → 返回胜率
  否则:
    跑 N 次 rollout → 返回平均胜率
```

### 8.2 接口变更

MCTSPlanner 新增：

```gdscript
var value_net: NeuralNetInference = null
var state_encoder: StateEncoder = null
```

如果 `value_net != null` 且 `value_net.is_loaded()`，使用网络评估；否则 fallback 到 rollout。

## 9. 训练循环（手动串联）

```bash
# 1. 跑 100 局自博弈，导出训练数据
godot --headless --path . res://scenes/tuner/TunerRunner.tscn \
  -- --generations=1 --export-data

# 2. 训练价值网络
python scripts/training/train_value_net.py \
  --data-dir ~/.local/share/godot/app_userdata/PTCG_Train/training_data \
  --output value_net_v1.json \
  --epochs 100

# 3. 将权重拷贝到 Godot user:// 目录
cp value_net_v1.json ~/.local/share/godot/app_userdata/PTCG_Train/ai_models/

# 4. 再跑自博弈，这次 MCTS 使用价值网络
godot --headless --path . res://scenes/tuner/TunerRunner.tscn \
  -- --generations=5 --value-net=user://ai_models/value_net_v1.json --export-data

# 5. 用新数据重新训练
# 循环...
```

## 10. 测试策略

### 10.1 单元测试

1. **StateEncoder**: 构造已知 GameState，验证输出维度 = 30，值域正确，对称性（交换玩家视角时特征对称翻转）
2. **NeuralNetInference**: 构造已知权重（全 1 权重），验证输出与手算一致；加载/保存往返测试
3. **SelfPlayDataExporter**: 跑 1 局 headless 对战，验证导出文件存在、结构正确、records 非空

### 10.2 集成测试

1. **MCTSPlanner + 价值网络**: 加载训练好的网络，MCTS 使用网络评估，验证不崩溃且返回有效序列
2. **端到端**: 导出数据 → Python 训练 → 导入权重 → 对战，验证整条 pipeline

### 10.3 Python 测试

1. **train_value_net.py**: 用合成数据训练 10 epoch，验证 loss 下降
2. **权重导出**: 验证 JSON 格式正确，GDScript 可加载

## 11. 文件结构

### 新建

- `scripts/ai/StateEncoder.gd` — 局面特征编码
- `scripts/ai/SelfPlayDataExporter.gd` — 对局数据导出
- `scripts/ai/NeuralNetInference.gd` — 前馈网络推理
- `scripts/training/train_value_net.py` — Python 训练脚本
- `scripts/training/requirements.txt` — Python 依赖
- `tests/test_state_encoder.gd` — StateEncoder 测试
- `tests/test_neural_net_inference.gd` — NeuralNetInference 测试
- `tests/test_self_play_data_exporter.gd` — SelfPlayDataExporter 测试

### 修改

- `scripts/ai/MCTSPlanner.gd` — 添加价值网络评估路径
- `scripts/ai/SelfPlayRunner.gd` — 集成数据导出
- `scripts/ai/EvolutionEngine.gd` — 支持 value_net_path
- `scenes/tuner/TunerRunner.gd` — 新增 --value-net 和 --export-data 参数
- `tests/TestRunner.gd` — 注册新测试

## 12. 实施顺序

1. StateEncoder（无依赖）
2. NeuralNetInference（无依赖）
3. SelfPlayDataExporter（依赖 StateEncoder）
4. SelfPlayRunner 集成数据导出（依赖 SelfPlayDataExporter）
5. train_value_net.py（依赖导出的数据格式）
6. MCTSPlanner 集成价值网络（依赖 NeuralNetInference + StateEncoder）
7. TunerRunner 命令行参数更新
8. 端到端验证

## 13. 风险

1. **GDScript 推理性能**：30→64→32→1 MLP 约 4097 次乘加运算。GDScript 浮点运算性能约 10M ops/s，单次推理 ~0.4ms，可接受。如果需要更大网络，需考虑 GDExtension 加速。
2. **训练数据量**：价值网络需要大量对局数据才能学到有用的模式。初期可能需要 1000+ 局。EvolutionEngine 50 代 × 24 局 = 1200 局，基本够用。
3. **过拟合**：30 维输入 + 4097 参数，如果训练数据少于几千条可能过拟合。缓解：dropout、L2 正则、早停。
4. **特征工程天花板**：30 维全局面特征可能丢失重要信息（如具体卡牌身份、状态异常类型）。缓解：后续迭代可扩展特征维度。
5. **Python 依赖**：用户需安装 PyTorch。缓解：提供 requirements.txt 和安装说明。
