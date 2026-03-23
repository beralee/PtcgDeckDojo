# PTCG AI Roadmap Design

日期：2026-03-23

## 1. 目标定义

本项目的 AI 目标分为两层：

### 短期目标

在固定卡组条件下，持续迭代一个共享 AI，找到更强的驾驶方式。

这意味着第一阶段的核心不是“做一个能动的陪练 Bot”，而是：

1. 做一个可评测的 baseline agent
2. 让它能在固定卡组上稳定完成整局对战
3. 能通过统一评测集比较不同 AI 版本强弱

### 长期目标

在固定 AI 条件下，跑不同卡组之间的两两对局，生成胜率矩阵，用于判断当前环境里哪个卡组更合适。

这里的核心产物不是单一卡组排行榜，而是：

1. deck-vs-deck 胜率矩阵
2. 矩阵上的环境分析
3. 稳定可重复的批量评测体系

### 默认研究假设

默认假设是“不同卡组的驾驶经验具有较强迁移性”，因此主线应以一个共享 AI 为主，而不是为每个卡组训练一个完全独立的 agent。

卡组专属 AI 可以作为补充实验，但不应成为第一条主线。

## 2. 成功标准

### 短期成功标准

1. `VS_AI` 模式下，AI 可以稳定接管一侧玩家
2. AI 能自动完成 setup、主阶段决策、攻击和结束回合
3. AI 不会因为 interaction step 卡死
4. 不同 AI 版本可以在固定评测集上做 A/B 对比
5. “更强”由固定卡组与固定对局集上的总胜率定义

### 长期成功标准

1. 可以用同一个共享 AI 跑 `AI vs AI`
2. 可以批量执行 deck-vs-deck 对局
3. 可以产出稳定的胜率矩阵
4. 可以基于矩阵估计环境适配性，而不是只给一个单点排名

## 3. 非目标

当前设计明确不把这些内容作为近期必做目标：

1. 不做像素输入、鼠标点击式 AI
2. 不为 AI 单独重写一套规则
3. 不在第一阶段就做强化学习训练
4. 不在卡牌实现尚不稳定时直接上大规模 MCTS
5. 不把“AI 与卡组共同进化”作为当前架构主约束

`AI + 卡组共同进化` 可以保留为远期研究方向，但不进入当前设计的核心验收标准。

## 4. 现有代码基础

当前仓库已经具备做这条路线的关键基础：

1. `scripts/engine/GameStateMachine.gd`
2. `scripts/engine/EffectProcessor.gd`
3. `scripts/engine/RuleValidator.gd`
4. `scripts/autoload/GameManager.gd`
5. `scenes/battle/BattleScene.gd`

结论：

1. 规则执行层已经相对独立，适合复用为 simulator
2. 当前大量 trainer / ability / attack 已经抽象成 interaction step
3. `GameManager` 已经有 `VS_AI` 模式入口
4. UI 层可以继续服务人类玩家，但 AI 不应依赖 UI 点击进行决策

因此，推荐路线不是“让 AI 模拟玩家点按钮”，而是：

1. 直接读结构化状态
2. 枚举合法动作
3. 自动解析 interaction steps
4. 通过现有规则接口执行动作

## 5. 路线选项

### 方案 A：Bot-first

先做一个本地陪练 AI，只追求 `VS_AI` 可玩。

优点：

1. 交付快
2. 很快能看到 AI 在 UI 中行动

缺点：

1. 后续做批量评测和矩阵分析会返工
2. 容易把 AI 逻辑绑死在 `BattleScene`

### 方案 B：Evaluation-first Hybrid（推荐）

从第一天就把 AI、评测和未来 runner 设计成一套体系，但实现顺序仍然是先落地本地 AI。

优点：

1. 短期能得到可玩的 `VS_AI`
2. 中期能自然扩展到 `AI vs AI`
3. 长期能直接复用到 deck-vs-deck 胜率矩阵
4. 与当前项目的长期目标最一致

缺点：

1. 第一阶段设计成本略高于单纯做 Bot

### 方案 C：Research-first

先做 headless runner 和评测矩阵，再回头接 UI。

优点：

1. 研究导向最纯
2. 最容易直接走向批量实验

缺点：

1. 短期没有可玩的 AI 对手
2. 用户反馈回路慢

### 推荐结论

采用方案 B。

它能同时满足：

1. 短期先把 `VS_AI` 跑起来
2. 中期进入 `AI vs AI`
3. 长期输出 deck 胜率矩阵

而且返工最少。

## 6. 系统设计

建议把 AI 系统拆成 4 层。

### Layer 1：Rules Simulator

职责：

1. 复用现有规则执行层进行完整结算
2. 提供可重复、可批量、可控制随机性的对局执行能力
3. 为未来搜索、批跑和训练提供底座

约束：

1. 同一输入应尽量得到同一输出
2. 随机过程需要可控
3. 后续应支持复制状态、试走动作和获取结果

### Layer 2：Action / Step Abstraction

职责：

1. 统一枚举合法动作
2. 统一解析 interaction steps
3. 统一把高层动作映射回规则执行接口

建议组件：

1. `scripts/ai/AILegalActionBuilder.gd`
2. `scripts/ai/AIStepResolver.gd`
3. `scripts/ai/AIActionCodec.gd`
4. `scripts/ai/AIStateEncoder.gd`

### Layer 3：Agents

职责：

1. 实现不同决策策略
2. 允许多个 agent 共存与对比

建议类型：

1. `RuleBasedRandomAgent`
2. `HeuristicAgent`
3. `SearchAgent`
4. `LearnedAgent`

短期只需要落地：

1. baseline random / rule-based agent
2. baseline heuristic agent

### Layer 4：Evaluation / Matrix / Research

职责：

1. AI 版本 A/B 对比
2. `AI vs AI` 批跑
3. deck-vs-deck 胜率矩阵生成
4. 环境分析与 deck 适配性评估

建议未来组件：

1. `scripts/ai/SelfPlayRunner.gd`
2. `scripts/ai/MatchEvaluator.gd`
3. `scripts/ai/LeagueManager.gd`
4. `scripts/ai/DeckMatrixRunner.gd`

## 7. 数据流设计

短期 `VS_AI` 的数据流建议如下：

1. `BattleScene` 判断当前回合是否由 AI 接管
2. AI 从 `GameState` 读取当前结构化状态
3. `AILegalActionBuilder` 枚举当前合法动作
4. agent 对动作评分并选出动作
5. 若动作涉及 interaction step，则交给 `AIStepResolver`
6. 将解析结果回注到现有规则执行接口
7. 规则层完成结算
8. `BattleScene` 刷新 UI
9. 若仍在 AI 可行动阶段，则继续下一步

长期 `AI vs AI / 胜率矩阵` 的数据流建议如下：

1. `DeckMatrixRunner` 生成 deck pairing 列表
2. 对每组 pairing 多次运行 `AI vs AI`
3. 每局通过同一套 action / step 抽象执行
4. 记录胜负、回合数、关键行为统计
5. 聚合生成胜率矩阵与环境视图

## 8. 评测设计

### 短期评测

短期“AI 变强”的判断方式已经明确：

使用固定一组基准卡组和固定对局集，对比不同 AI 版本的总胜率。

这意味着：

1. 不以镜像对局为主
2. 不以纯自博弈为主
3. 评测口径必须稳定，可复现

### 长期评测

长期系统的主产物是 deck-vs-deck 胜率矩阵。

默认评测设定：

1. 以同一个共享 AI 驾驶所有卡组
2. 比较不同卡组之间的对抗表现
3. 卡组专属 AI 只作为补充实验，不作为主表

这可以最大程度贴近你要的结论：

“在当前环境里，哪个卡组更适合上手和实战选择。”

## 9. 错误处理与保护

第一阶段必须显式处理以下风险：

1. interaction step 未覆盖导致 AI 卡死
2. AI 在单回合内无限循环
3. 因随机性导致评测波动过大
4. AI 在 UI busy 状态下重入
5. 某些低频卡牌因为没有 AI 选择器而无法继续

建议保护机制：

1. 单回合动作上限
2. step 未支持时显式记录日志并终止当前实验
3. 批跑时固定随机种子集合
4. smoke 测试优先覆盖高频卡组和高频交互

## 10. 测试策略

测试分三层：

### 1. 单元测试

覆盖：

1. 合法动作枚举
2. 常见 step 自动选择
3. 启发式评分规则

### 2. BattleScene / 集成测试

覆盖：

1. `VS_AI` 模式自动接管
2. AI setup
3. AI 主阶段行动
4. AI 结束回合

### 3. Smoke / Evaluation 测试

覆盖：

1. AI 能完成整局对战
2. AI 不会超出单回合动作上限
3. 固定对局集上可以对比 A/B 版本结果

## 11. 实施边界

本次 spec 只定义 AI 路线和系统边界，不直接要求：

1. 立即实现 headless 自博弈
2. 立即实现 deck 搜索算法
3. 立即接入训练框架

当前优先级仍然应该是：

1. 先落地可评测 baseline agent
2. 先把统一动作和 step 解析层打稳
3. 再向 `AI vs AI` 和矩阵评测扩展

## 12. 第一阶段建议范围

第一阶段建议只做以下范围：

1. `VS_AI` 模式下接管玩家 2
2. baseline agent 能自动 setup
3. baseline agent 能完成主阶段、攻击和结束回合
4. `AILegalActionBuilder`
5. `AIStepResolver`
6. 固定基准对局集上的 AI A/B 评测入口

这能同时服务：

1. 你短期想要的本地 AI 对手
2. 后续 `AI vs AI`
3. 长期 deck-vs-deck 胜率矩阵

## 13. 结论

当前最合适的设计，不是单纯做一个“能动的 AI”，而是：

1. 先做一个可评测的共享 baseline agent
2. 让它在固定卡组上持续增强
3. 再用同一个 AI 去评测卡组两两对局
4. 最终产出环境胜率矩阵

因此，后续研发计划应以 `Evaluation-first Hybrid` 为核心路线：

1. 先落地 `VS_AI`
2. 同时保持 action / step / evaluation 接口可扩展
3. 避免把 AI 绑死在当前 UI 层
