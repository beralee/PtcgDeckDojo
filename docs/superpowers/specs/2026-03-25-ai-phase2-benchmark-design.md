# AI Phase 2 Benchmark And Runner Design

日期：2026-03-25

## 1. 背景

Phase 1 已完成 baseline AI、`VS_AI` 接管、基础 headless benchmark harness，以及围绕开局、奖赏、换位、交互步骤的一轮稳定性收口。

当前系统已经具备：

1. `AIOpponent` 负责单侧 AI 决策与执行
2. `AILegalActionBuilder` 负责合法动作枚举
3. `AIStepResolver` 负责 interaction step 自动选择
4. `AIBenchmarkRunner` 负责 baseline 级 headless smoke 对局

但 Phase 1 的 benchmark 仍然偏 baseline：

1. headless bridge 只覆盖了最小可用的起始链路
2. 真实牌组对局的稳定性还没有系统性锁定
3. benchmark 输出还不足以作为后续 deck matrix 的正式输入

因此 Phase 2 的目标不是继续直接“加强 AI”，而是先把真实对局 runner 和 benchmark 套件打造成稳定评测底座。

## 2. 目标

Phase 2 的目标分为两层。

### 2.1 Runner 目标

建立稳定的 headless `AI vs AI` runner，覆盖：

1. `start_game`
2. `mulligan`
3. `setup`
4. `main`
5. `attack`
6. `pokemon check`
7. `take_prize`
8. `send_out`
9. `game over`

该 runner 不依赖 `BattleScene` 的可视 UI，不通过 UI 点击驱动决策，而是复用现有规则接口和 interaction-step 协议推进对局。

### 2.2 Benchmark 目标

在稳定 runner 之上，建立固定 benchmark 套件，先锁定三套牌组：

1. 密勒顿
2. 沙奈朵
3. 喷火龙 ex

benchmark 结果要求：

1. 主产物为结构化 JSON
2. 辅助产物为文本摘要
3. 同时支持固定种子和随机运行
4. Phase 2 默认以固定种子为主
5. 默认比较“同一个共享 AI 驾驶三套牌组互打”
6. 兼容“新 AI 版本 vs 旧 AI 版本”的回归评测

## 3. 非目标

Phase 2 不做以下内容：

1. 不做强化学习、自博弈训练或 MCTS
2. 不做全卡池、全主流牌组一次性 headless 全覆盖
3. 不把 deck-vs-deck 胜率矩阵一次做完
4. 不把 AI heuristics 升级到高水平实战驾驶
5. 不为 runner 额外发明一套独立规则系统

Phase 2 只解决“真实对局可批跑、结果可评测、三套高频牌组可稳定验证”的问题。

## 4. 路线选项

### 方案 A：Benchmark-first

先定义 benchmark 输入与输出格式，边跑边补 runner。

优点：

1. 很快能看到结构化结果
2. 很快能开始做版本对比

缺点：

1. runner 不稳时，结果里会混入大量系统噪声
2. benchmark case 和失败分类容易反复推倒重来

### 方案 B：Runner-first

先把 headless `AI vs AI` 跑稳，再做 benchmark。

优点：

1. 地基最稳
2. 后续扩展到矩阵评测返工最少

缺点：

1. 短期缺少直观评测产物
2. 容易把结果层推迟过久

### 方案 C：Hybrid Staged（推荐）

先以 runner 稳定性为前置，但从第一天就按 benchmark 产物来设计。

Phase 2 顺序：

1. 先补 runner 缺口
2. 同时定义 benchmark case 结构、结果 schema、失败分类、固定 seed 约定
3. runner 一旦稳定，立刻接入三套牌组互打和 AI 版本回归

推荐理由：

1. 符合已有 `Evaluation-first Hybrid` 路线
2. 能避免 runner 与结果层二次返工
3. 最适合后续扩展到 deck matrix

## 5. 成功标准

### 5.1 Runner Stability

三套牌组都必须满足：

1. 能从 `start_game` 开始
2. 能覆盖随机先后攻与固定先攻
3. 能完整经过开局、主阶段、KO、奖赏、换位和结算链路
4. 能到达正常胜负
5. 不允许卡死在 prompt、step、奖赏、换位或 action cap

### 5.2 Deck Identity

每套牌组至少要在部分对局里体现核心资源线。

密勒顿：

1. 至少在部分对局中主动铺基础电系宝可梦
2. 至少在部分对局中使用 `电气发生器`
3. 至少在部分对局中形成可攻击场面

沙奈朵：

1. 至少在部分对局中完成演化推进到 `奇鲁莉安 / 沙奈朵 ex`
2. 至少在部分对局中使用 `精神拥抱`
3. 至少在部分对局中走通弃牌区能量到场上攻击的资源线

喷火龙 ex：

1. 至少在部分对局中完成 `小火龙 -> 喷火龙 ex` 的演化推进
2. 至少在部分对局中用到关键演化支撑资源
3. 至少在部分对局中由喷火龙 ex 形成主攻

这里的目标是“体现 deck identity”，不是“每局都打得像高手”。

## 6. 系统拆分

Phase 2 建议拆成四个子系统。

### 6.1 HeadlessMatchBridge

职责：

1. 连接 `GameStateMachine.start_game()` 与 headless 对局执行
2. 消费 `player_choice_required`
3. 驱动 `mulligan / setup / take_prize / send_out`
4. 在没有 `BattleScene` 可视 UI 的情况下继续推进对局

约束：

1. 不引入 AI 专用规则
2. 不把决策逻辑塞进 bridge
3. 只处理对局推进和 prompt 接线

说明：

Phase 1 的 `AIBenchmarkRunner.HeadlessBattleBridge` 可以作为起点，但 Phase 2 应将其提升为正式 runner 组件，而不是继续停留在测试辅助壳层。

### 6.2 DeckBenchmarkCase

职责：

1. 定义 benchmark 输入
2. 表达单个 pairing 的配置、种子、局数和检查项

建议字段：

1. `deck_a`
2. `deck_b`
3. `shared_agent_config`
4. `seed_set`
5. `match_count`
6. `identity_checks`
7. `expected_stability`

### 6.3 BenchmarkEvaluator

职责：

1. 聚合单局结果
2. 输出 JSON 汇总
3. 输出人工可读文本摘要

建议聚合项：

1. 总局数
2. 双方胜场
3. 胜率
4. 平均回合数
5. stalled 率
6. action-cap 终止率
7. identity check 通过率
8. failure reason 统计

### 6.4 Phase 2 Smoke / Regression Layer

职责：

1. runner 稳定性 smoke
2. 牌组 identity smoke
3. benchmark schema 与结果回归

说明：

这层不是为了证明“AI 已经很强”，而是为了证明：

1. runner 可靠
2. 结果稳定
3. 三套牌组没有跑偏到完全失去身份

## 7. 数据流

Phase 2 的推荐数据流：

1. `DeckBenchmarkCase` 提供 pairing、agent config、seed set 和检查项
2. `HeadlessMatchBridge` 从 `start_game()` 驱动整局
3. 双方共享 AI 通过 `AIOpponent + AILegalActionBuilder + AIStepResolver` 行动
4. 对局结束后生成单局 `match result`
5. `BenchmarkEvaluator` 聚合多局结果
6. 输出 JSON 与文本摘要

这条数据流需要与现有 UI 逻辑解耦，但必须复用现有规则系统。

## 8. 结果格式

### 8.1 单局结果

每局结果至少包含：

1. `deck_a`
2. `deck_b`
3. `seed`
4. `winner_index`
5. `turn_count`
6. `terminated_by_cap`
7. `stalled`
8. `failure_reason`
9. `event_counters`
10. `identity_hits`

### 8.2 聚合结果

每个 pairing 的 benchmark summary 至少包含：

1. `pairing`
2. `total_matches`
3. `wins_a`
4. `wins_b`
5. `win_rate_a`
6. `win_rate_b`
7. `avg_turn_count`
8. `stall_rate`
9. `cap_termination_rate`
10. `failure_breakdown`
11. `identity_check_pass_rate`

### 8.3 文本摘要

文本摘要只做人工可读用途，例如：

1. pairing 名称
2. seed 集合
3. 局数
4. 胜率
5. stalled 次数
6. cap 次数
7. 关键 identity 指标

JSON 是主产物，文本摘要是辅助手段。

## 9. 失败分类

Phase 2 必须区分“AI 决策弱”和“runner / 交互层坏了”。

建议 failure reason 至少包含：

1. `normal_game_end`
2. `deck_out`
3. `stalled_no_progress`
4. `action_cap_reached`
5. `unsupported_prompt`
6. `unsupported_interaction_step`
7. `invalid_state_transition`

其中真正需要优先消除的是：

1. `stalled_no_progress`
2. `action_cap_reached`
3. `unsupported_prompt`
4. `unsupported_interaction_step`
5. `invalid_state_transition`

## 10. 测试策略

Phase 2 测试分三层。

### 10.1 Runner Unit Tests

覆盖：

1. bridge 消费 `setup / mulligan / prize / send_out`
2. start-game 到 main-phase 的起始链路
3. 结果 schema 和 failure tagging

### 10.2 Deck Smoke Tests

针对：

1. 密勒顿
2. 沙奈朵
3. 喷火龙 ex

覆盖：

1. 从 `start_game` 到 `game_over`
2. runner 不 stall
3. 不异常 hit action cap
4. deck identity checks 至少能命中一部分

### 10.3 Benchmark Regression Tests

覆盖：

1. 固定少量 seeds
2. 固定少量局数
3. JSON 输出结构稳定
4. 文本摘要可生成
5. 同一 benchmark 配置可用于新旧 AI 版本回归比较

## 11. Phase 2 初始 Benchmark 套件

第一版 benchmark pairing 固定为：

1. `Miraidon vs Gardevoir`
2. `Miraidon vs Charizard ex`
3. `Gardevoir vs Charizard ex`

每个 pairing：

1. 双方交换先手
2. 运行固定 seed 集合
3. 同时保留随机模式接口
4. 输出 pairing 级 JSON 与总汇总文本

## 12. 实施边界

Phase 2 的重点不是“让 AI 变得更聪明”，而是：

1. 让真实对局 runner 稳定
2. 让三套高频牌组能稳定批跑
3. 让 benchmark 产物可比较、可重复、可扩展

如果 runner 还不能稳定支撑这三套牌组，就不应该提前进入 deck matrix 或高级搜索阶段。

## 13. 结论

Phase 2 推荐采用 `Hybrid Staged` 路线：

1. 先补强真实 headless `AI vs AI` runner
2. 用三套高频牌组锁定稳定性和 deck identity
3. 同步定义 benchmark case、结果 schema 和失败分类
4. 在 runner 稳定后输出第一版固定 benchmark 套件

这样可以最小化返工，并自然衔接后续的：

1. AI 版本 A/B 评测
2. deck-vs-deck 胜率矩阵
3. 更长期的环境分析能力
