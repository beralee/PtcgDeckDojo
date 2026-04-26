# AI 对战设计文档

## 北极星目标

`PtcgDeckDojo` 的 AI 终局目标，不只是“做一个能陪玩家练牌的 Bot”，而是逐步建立一套可持续演进的 PTCG AI 研究与训练系统：

1. 支持 `AI vs Player`
2. 支持 `AI vs AI`
3. 支持大规模自博弈（self-play）
4. 支持 AI 强度评测与版本淘汰
5. 支持卡组搜索、卡组对抗和元环境分析
6. 最终尽可能逼近“在当前规则与卡池下，找到最强 AI 与最强卡组组合”

如果借类比来说，短期目标是“先有能打的规则型 Bot”，长期目标更接近：

1. 一个基于规则引擎的自博弈系统
2. 一个能持续产出训练数据和对局数据的模拟平台
3. 一个能做策略迭代、评测和 deck search 的实验底座

注意：
这个目标和 AlphaGo 有相似处，但不应照搬 AlphaGo 的表达方式。
本项目更现实的路线，不是“端到端看像素学下棋”，而是：

1. 复用现有完整规则引擎
2. 用结构化状态与动作空间做决策
3. 先做规则型 / 启发式 / 搜索型 AI
4. 再逐步过渡到学习型 AI

## 当前阶段目标

在通往长期目标之前，当前阶段仍然应该先完成：

1. 一个稳定的本地单机 AI 对手
2. 能复用现有 `GameStateMachine` 与 interaction step 协议
3. 能完整打一局
4. 能作为将来自博弈系统的 baseline agent

也就是说：
短期 Bot 不是终点，而是整套 AI 系统的第一个可运行 agent。

## 非目标

当前文档不把以下内容作为近期必做目标：

1. 不直接接大模型做在线决策
2. 不做像素输入、鼠标点击式 AI
3. 不为 AI 重写一套独立规则
4. 不在第一阶段就做深度强化学习训练
5. 不在卡牌效果尚未稳定前过早做大规模 MCTS

## 当前架构结论

### 1. 规则执行层已经独立

当前核心结算主要在：

- `scripts/engine/GameStateMachine.gd`
- `scripts/engine/EffectProcessor.gd`
- `scripts/engine/RuleValidator.gd`
- `scripts/engine/DamageCalculator.gd`

这些层天然适合做 AI simulator，因为它们关心的是：

1. 当前 `GameState`
2. 合法动作
3. 在给定上下文后的结算结果

这意味着未来无论是：

1. 本地对战 Bot
2. 纯后台 `AI vs AI`
3. 自博弈训练 runner
4. deck search 批量实验

都应优先复用这一层，而不是从 UI 层倒推规则。

### 2. 交互 step 协议是 AI 的关键接口

当前很多 trainer / ability / attack 的交互，已经统一成：

1. `get_interaction_steps()`
2. `get_attack_interaction_steps()`
3. `get_followup_attack_interaction_steps()`

这点非常重要。
对于 AI 来说，真正该复用的不是当前人类玩家的弹窗 UI，而是这套 step 协议本身。

长期看，AI 系统应该有一个统一的 step resolver：

1. 给人类玩家时，交给 `BattleScene` 呈现
2. 给本地 Bot 时，自动选择
3. 给自博弈 runner 时，纯后台自动选择

### 3. 已有 VS_AI 模式入口

`GameManager.gd` 已经定义：

1. `GameMode.VS_AI`
2. `ai_difficulty`

说明这个仓库的数据结构已经允许“一个玩家由 AI 接管”。
接下来真正缺的是：

1. 决策层
2. 后台模拟层
3. 评测与训练层

## 长期目标架构

建议把 AI 系统分成 4 层，而不是只做一个 `AIOpponent.gd`。

```text
Layer 1: Rules Simulator
Layer 2: Action / Step Abstraction
Layer 3: Agents
Layer 4: Training / Evaluation / Deck Search
```

## Layer 1: Rules Simulator

职责：

1. 负责完整、可重复、可批量执行的对局结算
2. 支持无 UI、headless、高速模拟
3. 支持固定随机种子与可回放日志

依赖当前已有层：

- `GameState`
- `GameStateMachine`
- `EffectProcessor`
- `RuleValidator`

长期要求：

1. 同一输入必须得到同一输出
2. 随机过程必须可控
3. 允许“复制状态 -> 试走一步 -> 回收结果”

如果未来要做搜索、MCTS、强化学习，这层是绝对核心。

## Layer 2: Action / Step Abstraction

职责：

1. 统一枚举合法动作
2. 统一解析 interaction steps
3. 统一把 AI 决策映射回现有执行接口

建议新增组件：

```text
scripts/ai/
  AILegalActionBuilder.gd
  AIStepResolver.gd
  AIActionCodec.gd
  AIStateEncoder.gd
```

### AILegalActionBuilder.gd

负责：

1. 枚举当前所有合法动作
2. 给搜索与学习层提供稳定动作空间
3. 不直接负责评分

### AIStepResolver.gd

负责：

1. 自动完成 `PokemonSlot` 目标选择
2. 自动完成 `card_assignment`
3. 自动完成 deck / discard / hand 的检索选择
4. 处理 `opponent_chooses` 与 `chooser_player_index`

### AIActionCodec.gd

负责：

1. 把高层动作编码成统一结构
2. 支持日志、训练数据、回放和评测

### AIStateEncoder.gd

负责：

1. 把 `GameState` 编码成 agent 可消费的结构化特征
2. 为未来搜索 / 学习 / 评测共用

## Layer 3: Agents

这一层允许多个 agent 并存，而不是只有一个 AI。

建议长期维护以下 agent 类型：

### 1. RuleBasedRandomAgent

用途：

1. 烟雾测试
2. 检查合法性
3. 作为最弱 baseline

### 2. HeuristicAgent

用途：

1. 第一版可陪练 AI
2. 作为未来搜索型 AI 的 rollout / baseline

### 3. SearchAgent

用途：

1. 1 步前瞻
2. 有限宽度搜索
3. 后期可扩展到 MCTS

### 4. LearnedAgent

用途：

1. 使用自博弈数据训练策略 / 价值网络
2. 与 RuleBased / SearchAgent 对战评测

重要结论：
未来真正“最强”的 AI 很可能不是单一 agent，而是：

1. 启发式先验
2. 搜索
3. 学习模型

三者结合的版本。

## Layer 4: Training / Evaluation / Deck Search

这是当前文档和第一版 Bot 最大的区别。
如果目标是“像 AlphaGo 一样不断逼近最强策略”，就必须把这层提前写进架构。

建议新增目录：

```text
scripts/ai/training/
  SelfPlayRunner.gd
  MatchEvaluator.gd
  LeagueManager.gd
  ReplayExporter.gd
  DeckSearchRunner.gd
```

### SelfPlayRunner.gd

职责：

1. 让两个 AI 在 headless 模式下反复对战
2. 输出胜负、回合数、关键动作、日志
3. 形成训练集或统计集

### MatchEvaluator.gd

职责：

1. 评测多个 agent 之间的胜率
2. 输出 Elo / 胜率矩阵 / 对局统计

### LeagueManager.gd

职责：

1. 管理不同版本 agent
2. 新 agent 必须打过现有联盟才能晋级
3. 防止模型偶然打赢几场就被误判成“更强”

### ReplayExporter.gd

职责：

1. 保存结构化对局数据
2. 支持回放、复盘和训练样本导出

### DeckSearchRunner.gd

职责：

1. 固定一个 agent 搜索更强卡组
2. 固定一个环境搜索更优构筑
3. 做“agent + deck” 联合评估

## 最终目标为什么不只是“最强 AI”

PTCG 不是纯固定开局博弈，卡组构筑本身就是策略的一部分。
所以长期目标应该明确区分三个问题：

### 问题 1：给定卡组，谁是最强 agent

这是传统 AI 对战问题。

### 问题 2：给定 agent，什么卡组最强

这是 deck optimization 问题。

### 问题 3：agent 与卡组联合优化，最终组合谁最强

这是最终目标，也最接近你说的“找到最强的 AI 和卡组”。

因此未来的评测单位，不应只是一份模型，而应是：

```text
(agent version, deck version, rules version)
```

## 数据与实验要求

如果以后真的要往自博弈和训练走，文档里必须先把这些基础要求写死：

### 1. 可复现

1. 固定随机种子
2. 固定牌库顺序或可重建牌库顺序
3. 固定版本号

### 2. 可批量

1. headless 模式下可连续跑大量对局
2. 不依赖 BattleScene UI
3. 不要求人工交互

### 3. 可观测

1. 每步动作可导出
2. 每局结果可导出
3. 关键状态变化可导出

### 4. 可回放

1. 训练集和评测集必须可重放
2. 回放应能定位 bug、坏策略、规则偏差

## 近期实现原则

尽管长期目标很大，但近期实现仍然必须遵守：

1. AI 只负责决策，不负责结算
2. 所有动作仍回到 `GameStateMachine`
3. interaction step 必须复用统一协议
4. 第一版先做 RuleBased / Heuristic agent
5. 学习型 agent 必须建立在稳定 simulator 之上

## 路线图

### Stage 0：Baseline Bot

目标：

1. 先做一个能完整打完一局的本地 Bot
2. 支持 `AI vs Player`
3. 这个版本主要是规则验证和架构打底

### Stage 1：Headless AI vs AI

目标：

1. 支持不依赖 UI 的后台 AI 对战
2. 能跑批量对局
3. 能输出胜率和日志

### Stage 2：Evaluation League

目标：

1. 支持多个 AI 版本互打
2. 建立稳定评测基线
3. 输出 Elo 或胜率矩阵

### Stage 3：Deck Search

目标：

1. 固定 agent 搜索更强卡组
2. 对不同卡组做批量对局统计
3. 建立元环境分析能力

### Stage 4：Search / MCTS Agent

目标：

1. 在部分局面做前瞻搜索
2. 提升关键决策质量
3. 为学习型 agent 提供更强 teacher

### Stage 5：Self-Play Learning

目标：

1. 产出自博弈数据
2. 训练策略 / 价值模型
3. 让 LearnedAgent 与现有 agent 联盟对战

## 当前第一阶段的正确定位

所以，当前这份“第一版 AI 研发计划”仍然是对的，但它应该在文档中被明确定位为：

1. 不是终局方案
2. 而是整个 AI 系统的 baseline layer
3. 它的价值是先把 AI 接入点、动作编码、step 自动选择、测试框架打稳

如果没有这一步，后面的：

1. AI vs AI
2. batch evaluation
3. deck search
4. self-play

都没有可靠底座。

## 结论

如果长期目标是“像 AlphaGo 一样不断自我对战，最终找到最强 AI 和最强卡组”，那文档就不该只写“本地单机陪练 AI”。

它应该明确写成一套分层目标：

1. 短期：本地 RuleBased / Heuristic Bot
2. 中期：Headless AI vs AI + 评测联盟
3. 中长期：Deck Search + Search Agent
4. 长期：Self-Play Learning

也就是说：

- 当前要做的不是把文档推翻
- 而是把现有第一阶段文档放到更大的长期路线图里
- 让之后每一轮 AI 开发都知道自己是在为“自博弈与最强策略搜索系统”铺路
