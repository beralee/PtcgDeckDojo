# AI 训练闭环与可体验版本设计

日期：2026-03-28

## 1. 背景

项目已经具备以下 AI 基础设施：

- `EvolutionEngine`：联合调优 heuristic 权重与 MCTS 参数
- `SelfPlayRunner`：批量自博弈与训练数据导出
- `StateEncoder`：当前已扩展到 44 维局面特征
- `train_value_net.py`：离线训练 value net
- `AIOpponent` + `MCTSPlanner`：在游戏内与 headless 环境中使用 value net

当前问题不是“能不能训练”，而是“如何把训练流程稳定地转化为更强、且可在游戏内直接体验的 AI 版本”。

当前痛点：

1. 训练结果主要体现在脚本输出和文件落盘，缺少统一的版本语义
2. `VS_AI` 模式只能按难度选择，不能明确指定训练版本
3. 训练指标、benchmark 结果、人工试玩反馈没有绑定到同一个版本对象
4. 短期目标并不是泛化最强，而是在固定 3 套卡组环境中把 current-best 继续练强

## 2. 目标

### 2.1 功能目标

1. 建立固定的 AI 训练闭环：`current-best -> 小轮进化 -> 导出数据 -> 训练 value net -> 固定 benchmark 验收 -> 版本晋级`
2. 把训练产物收口为“AI 版本”，而不是松散的 `agent` / `value_net` 文件
3. 让用户在游戏内 `VS_AI` 模式中选择：
   - 默认 AI
   - 最新训练版 AI
   - 指定训练版本 AI
4. 让每轮训练结果都能产出可读 benchmark 摘要和可试玩版本
5. 让人工反馈能绑定到具体版本号，而不是模糊指向“上一版 AI”

### 2.2 训练目标

短期训练目标固定为：

1. 只针对当前 3 套环境：`密勒顿 / 沙奈朵 / 喷火龙ex`
2. 以 `mutant vs current-best` 为主线继续爬坡
3. 重点提升固定环境下的对战强度，不优先优化泛化能力

### 2.3 非目标

1. 本轮不引入联盟制、Elo 或更大 benchmark 池
2. 本轮不扩卡池，不把训练目标扩展到 5-10 套或更广环境
3. 本轮不重做 AI 核心算法，不切换到全新搜索或强化学习框架
4. 本轮不把所有训练中间产物都开放给游戏内选择

## 3. 设计原则

1. 训练结果必须先通过固定 benchmark，才能成为“可体验版本”
2. 游戏内“最新训练版”应指向最新通过验收的版本，而不是最新生成的文件
3. 训练指标、文件路径、试玩入口、人工反馈必须围绕同一版本号组织
4. 短期只优化固定 3 套环境，不为了泛化牺牲当前环境内的上升速度
5. 玩家体验与 headless 训练结果要分开描述，避免把轻量训练配置误认为真实对战表现

## 4. 训练闭环设计

### 4.1 每轮训练流程

每一轮训练固定为四步：

1. **小轮进化**
   - 从当前 `current-best` 出发
   - 跑中等规模的 `Phase 5.1`
   - 建议默认 `20-30` 代，而不是长时间一次性大轮次
   - 目标是快速找到 challenger

2. **定向导出训练数据**
   - 用本轮 challenger 跑 self-play 导出训练数据
   - 训练数据按“轮次”组织，避免无限累积旧弱版本样本
   - 仅保留最近 `2-3` 轮主数据集作为默认训练输入

3. **训练 value net**
   - 用最新数据训练新的 value net
   - `val_loss` 只作为训练健康度参考
   - 不以 `val_loss` 直接决定是否晋级

4. **固定 benchmark 验收**
   - 新 agent 对当前 best 跑固定评测
   - 环境仍只看这 3 套卡组
   - benchmark 局数要高于训练期单代评估，建议固定为 `60-120` 局
   - 只有 benchmark 通过，才能晋级为新的 `current-best`

### 4.2 晋级门槛

建议默认门槛：

1. 新 agent 对当前 best 胜率 `> 55%`
2. 失败局、异常局必须为 `0`
3. 超时局保持在可接受范围内，不得明显恶化
4. 如果新 value net 未通过 benchmark，则不得覆盖当前可体验版本

### 4.3 数据管理

训练数据按轮次分目录组织，例如：

```text
user://training_runs/
  run_20260328_01/
    self_play/
    benchmark/
    models/
    reports/
```

默认策略：

1. 每轮自博弈数据写入独立目录
2. benchmark 结果和训练日志与该轮绑定
3. 当前 best 不直接依赖散落在 `user://training_data` 下的无版本文件

## 5. AI 版本模型

### 5.1 版本对象

引入“AI 版本”作为正式对象，每个可识别版本至少包含：

```json
{
  "version_id": "AI-20260328-01",
  "display_name": "v015 + value_net_v1",
  "created_at": "2026-03-28T20:30:00",
  "agent_config_path": "user://ai_agents/agent_v015_....json",
  "value_net_path": "user://ai_models/value_net_v1.json",
  "source_run_id": "run_20260328_01",
  "status": "trainable|playable|archived",
  "benchmark_summary": {
    "win_rate_vs_current_best": 0.57,
    "total_matches": 96,
    "timeouts": 0,
    "failures": 0
  }
}
```

### 5.2 版本状态

版本状态建议分为：

1. `trainable`
   - 训练流程生成的中间产物
   - 可用于继续训练或内部验证
   - 默认不出现在游戏内选择列表中

2. `playable`
   - 通过固定 benchmark 的版本
   - 可在 `VS_AI` 模式中直接选择
   - “最新训练版 AI”只指向这类版本

3. `archived`
   - 保留历史记录，但不建议默认展示

### 5.3 最新版规则

“最新训练版 AI”的解析规则：

1. 只在 `playable` 版本中查找
2. 优先按创建时间或可配置权重排序
3. 不允许指向未通过 benchmark 的版本

## 6. 游戏内体验设计

### 6.1 对战设置页

在 `BattleSetup` 中新增 AI 选择维度：

1. `AI 来源`
   - 默认 AI
   - 最新训练版 AI
   - 指定训练版本 AI

2. `AI 版本`
   - 当选择“指定训练版本 AI”时可选
   - 展示 `version_id + display_name + benchmark 摘要`

### 6.2 GameManager 配置

`GameManager` 不再只保存 `ai_difficulty`，还应保存一份 AI 装配配置，例如：

```gdscript
var ai_selection := {
  "source": "default|latest_trained|specific_version",
  "version_id": "",
  "agent_config_path": "",
  "value_net_path": "",
  "display_name": ""
}
```

### 6.3 BattleScene 装配

`BattleScene` 进入 `VS_AI` 时：

1. 根据 `GameManager.ai_selection` 决定使用默认 AI 或训练版 AI
2. 若为训练版 AI，则同时注入：
   - heuristic / MCTS 配置
   - value net 路径
3. 在战斗日志或 UI 中明确显示当前 AI 版本

建议显示：

```text
AI: AI-20260328-01
v015 + value_net_v1
```

### 6.4 缺失资源处理

如果指定版本缺失文件：

1. 明确输出错误信息
2. 禁止静默失败
3. 默认回退到内置 AI，或中断进入战斗并提示用户

推荐优先采用“提示并回退到默认 AI”，保证可体验性。

## 7. 人工验证设计

训练完成后，人工验证不只看报表，还包括真实对战体验。

### 7.1 每轮固定产物

每轮至少产出四类结果：

1. `benchmark 总表`
   - 新 agent vs 当前 best 总胜率
   - 分卡组对胜率
   - 分先后手胜率
   - 平均回合、超时数、失败数

2. `代表性对局样本`
   - 固定抽 `6-12` 局
   - 三个卡组对都覆盖
   - 每个卡组对至少覆盖先手与后手

3. `关键决策摘要`
   - 第一次贴能量
   - 第一次关键训练师牌
   - 第一次进化
   - 第一次攻击
   - 关键转折回合

4. `版本差异说明`
   - 相比上一可体验版本的主要变化
   - 哪些对局改善
   - 哪些对局退步
   - 风格更偏发展、爆发或保守

### 7.2 游戏内试玩

用户应能直接在 `VS_AI` 中选中版本并试玩。

试玩反馈建议绑定到版本号，例如：

- `AI-20260328-02` 开局更保守
- `AI-20260328-01` 更会打训练师牌
- `AI-20260328-02` 进化节奏偏慢

这样人工反馈可以直接作为下一轮训练的调参依据。

## 8. 架构与模块改动

### 8.1 新增模块

建议新增：

1. `scripts/ai/AIVersionRegistry.gd`
   - 管理 AI 版本记录
   - 列出 `playable` 版本
   - 解析“最新训练版 AI”

2. `scripts/ai/TrainingRunRegistry.gd` 或等价持久化模块
   - 管理训练轮次目录
   - 记录 run 与版本的映射关系

### 8.2 修改模块

建议修改：

1. `scripts/autoload/GameManager.gd`
   - 增加 AI 版本选择配置

2. `scenes/battle_setup/BattleSetup.gd`
   - 增加 AI 来源与版本选择 UI

3. `scenes/battle/BattleScene.gd`
   - 根据 AI 版本配置装配 `AIOpponent`
   - 显示当前 AI 版本信息

4. `scripts/ai/AgentVersionStore.gd`
   - 保留底层 agent 文件管理职责
   - 但不直接承担“可体验版本”的业务语义

5. `scripts/training/train_loop.sh`
   - 从纯脚本循环升级为“训练轮次 + benchmark + 版本发布”流程

## 9. 数据流

```text
current-best
  -> 小轮 Phase 5.1
  -> 生成 challenger
  -> 导出 self-play 数据
  -> 训练 value net
  -> 固定 benchmark 对 current-best
  -> 通过:
       生成 playable AI version
       更新 latest playable
     未通过:
       保留 trainable 记录，不发布到游戏内
```

游戏内路径：

```text
BattleSetup 选择 AI 来源/版本
  -> GameManager 保存 ai_selection
  -> BattleScene 解析版本记录
  -> AIOpponent 加载 agent config + value net
  -> 在对战中显示版本号
```

## 10. 错误处理

### 10.1 训练阶段

1. 训练数据为空：中止本轮并记录失败
2. value net 训练失败：保留 challenger，但不得发布 playable 版本
3. benchmark 失败：版本保留为 `trainable`，不更新 latest playable

### 10.2 游戏内阶段

1. 版本记录存在但 agent 文件缺失：提示并回退默认 AI
2. value net 文件缺失：提示并按无 value net 的 agent 装配，或回退默认 AI
3. 版本记录损坏：不在选择列表中展示

## 11. 测试策略

### 11.1 单元测试

1. `AIVersionRegistry`
   - 版本保存/读取/排序
   - `playable` 过滤
   - latest playable 解析

2. `GameManager`
   - AI 选择配置读写

### 11.2 集成测试

1. benchmark 通过后能生成 playable 版本
2. benchmark 未通过时不会出现在游戏内列表
3. `BattleScene` 能正确加载指定版本
4. 指定版本缺失资源时能正确回退

### 11.3 手工验证

1. 在对战设置页选择不同 AI 版本进入对战
2. 验证战斗内显示的版本号与实际加载版本一致
3. 验证 `最新训练版 AI` 会随 benchmark 通过的版本更新

## 12. 实施顺序

1. 建立 AI 版本对象与版本注册表
2. 扩展 `GameManager` 的 AI 选择配置
3. 在 `BattleSetup` 中增加 AI 版本选择
4. 在 `BattleScene` 中接入训练版 AI 装配与版本显示
5. 将训练脚本与 benchmark 流程接到“版本发布”逻辑
6. 补齐测试与手工验证清单

## 13. 风险

1. **训练版与游戏内实际表现不一致**
   - 训练期可能使用轻量配置加速对局，真实 `VS_AI` 体感不一定完全等价
   - 缓解：把 benchmark 与游戏内体验都绑定到同一版本，并明确展示版本信息

2. **版本语义与底层文件语义混淆**
   - 直接把 `agent` 文件当“可体验版本”会导致选择列表混乱
   - 缓解：引入单独版本注册表

3. **训练数据无节制累积**
   - 旧版本弱样本过多会稀释新数据
   - 缓解：按轮次管理数据目录，只保留最近若干轮主数据集

4. **用户体验入口加载失败**
   - 训练版本文件可能被移动、删除或损坏
   - 缓解：显式错误提示与回退策略
