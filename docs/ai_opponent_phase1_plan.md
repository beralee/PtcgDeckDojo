# AI 对战第一阶段研发计划

## 这份计划在长期路线中的位置

如果长期目标是：

1. `AI vs Player`
2. `AI vs AI`
3. 自博弈训练
4. deck search
5. 找到最强 AI 与最强卡组组合

那么第一阶段的定位必须写清楚：

这不是“最终 AI 方案”，而是整个 AI 系统的 baseline phase。

它的任务是先把下面几件事打稳：

1. AI 接入点
2. 合法动作枚举
3. interaction step 自动选择
4. headless 化的前置能力
5. smoke 测试与回归测试

没有这个 baseline，后面的 AI vs AI、自博弈、搜索和学习都没有稳定底座。

## 第一阶段目标

第一阶段只做一套“能陪练、能打完一局、能作为未来自博弈起点”的本地规则型 AI。

验收标准：

1. `VS_AI` 模式下可以由 AI 接管玩家 2
2. AI 能自动完成 setup
3. AI 能在自己的回合中做出合法动作
4. AI 能攻击或结束回合，不会卡死
5. AI 能完成整局 smoke 对战
6. 关键决策路径已经抽象成未来可复用的 agent / action / step 结构

## 第一阶段不做的内容

1. 不追求高强度
2. 不做多步搜索
3. 不接第三方模型
4. 不做强化学习训练
5. 不做 deck search
6. 不做完整 headless self-play runner

## 第一阶段产物

第一阶段结束后，应该至少拥有这些可复用资产：

```text
1. 一个可运行的 baseline Bot
2. 一套统一动作枚举器
3. 一套统一 step 自动选择器
4. 一套 AI smoke 测试
5. 一个可以继续向 AI vs AI 演进的 BattleScene / GSM 接口层
```

这些产物以后会被：

1. HeuristicAgent 继续复用
2. SearchAgent 复用
3. SelfPlayRunner 复用
4. DeckSearchRunner 复用

## 阶段拆分

## Phase 1A：AI 接管与调度

目标：

1. 在 `VS_AI` 模式下识别 AI 玩家
2. 当回合轮到 AI 时，自动进入 AI 决策循环
3. 确保 AI 不会在 UI busy 时重入

改动建议：

1. 新增 `scripts/ai/AIOpponent.gd`
2. 在 `BattleScene.gd` 新增 `_maybe_run_ai()` / `_run_ai_step()`
3. 第一版约定 AI 固定接管 `player_index = 1`

验收：

1. 双人模式不受影响
2. VS_AI 模式下轮到玩家 2 时会自动行动
3. 没有 pending dialog / field interaction 时才会继续

为什么这一步重要：

这是后续“把 AI 玩家从玩家 2 扩展成任意座位”“切掉 UI 做 headless runner”的入口。

## Phase 1B：Setup AI

目标：

1. AI 自动选择战斗位
2. AI 自动铺备战
3. AI 处理 Mulligan 后额外抽牌选择

最低策略：

1. 优先把更容易启动的基础宝可梦放战斗位
2. 尽可能铺更多基础到备战
3. Mulligan 额外抽牌统一选择“抽”

验收：

1. VS_AI 模式能自动完成 setup
2. setup 后正常进入第一回合

为什么这一步重要：

AI vs AI、自博弈和批量评测都不能依赖人工摆起手。
所以 setup 自动化必须尽早做。

## Phase 1C：合法动作枚举

目标：

新增 `AILegalActionBuilder.gd`，把 AI 当前可执行动作整理成统一候选列表。

第一版动作范围：

1. `attach_energy`
2. `play_basic_to_bench`
3. `evolve`
4. `play_trainer`
5. `play_stadium`
6. `use_ability`
7. `retreat`
8. `attack`
9. `end_turn`

验收：

1. 候选动作都合法
2. 不产生当前规则不允许的动作
3. 动作输出结构未来可直接用于评测与日志

为什么这一步重要：

未来无论是：

1. 启发式评分
2. 搜索
3. 学习模型输出动作分布

都必须基于统一动作空间。

## Phase 1D：基础 step 自动选择

目标：

新增 `AIStepResolver.gd`，自动处理第一批常见交互步骤。

第一版必须支持：

1. `PokemonSlot` 单选
2. `PokemonSlot` 多选
3. `card_assignment`
4. 牌库/弃牌区检索单选
5. `opponent_chooses`
6. `chooser_player_index`

优先支持的真实流程：

1. `宝可梦交替`
2. `交替推车`
3. `老大的指令`
4. `电气发生器`
5. `顶尖捕捉器`

验收：

1. AI 遇到这些卡不会卡住
2. AI 能正确生成 interaction context 并完成结算
3. step 输出结构未来可直接迁移到 headless self-play

为什么这一步重要：

真正把 AI 和卡牌复杂交互接起来的，不是 UI，而是 step resolver。
未来自博弈成不成，取决于这层能不能稳定通用。

## Phase 1E：基础启发式

目标：

新增 `AIHeuristics.gd`，让 AI 不只是随机乱点。

第一版规则：

1. 能击倒对手战斗宝可梦的攻击最高优先
2. 可攻击时优先攻击
3. 能形成本回合或下回合攻击的贴能优先
4. 能铺备战优先
5. 明显无收益动作降权
6. 没事可做就结束回合

验收：

1. AI 会优先攻击而不是无脑结束回合
2. AI 会做最基本的铺场和贴能
3. AI 表现明显强于纯随机 Bot

为什么这一步重要：

它会成为未来所有更强 agent 的 baseline。
之后任何搜索型或学习型 agent，都必须至少打赢这版 baseline 才算升级。

## Phase 1F：整局 smoke 测试

目标：

建立 AI 能打完整局的自动化验证。

建议测试：

1. `VS_AI` 模式 setup smoke
2. AI 回合最大动作数限制
3. AI 单回合不会无限循环
4. AI vs 玩家的整局 smoke
5. AI 处理 step 的 smoke

建议增加保护：

1. 单回合 AI 最多动作数，例如 `20`
2. 超过上限自动结束回合并记录日志

为什么这一步重要：

以后 AI vs AI 和自博弈会跑成千上万局。
如果这一步不先锁住，后面会很难定位卡死和策略异常。

## 文件规划

建议新增：

```text
scripts/ai/AIOpponent.gd
scripts/ai/AILegalActionBuilder.gd
scripts/ai/AIStepResolver.gd
scripts/ai/AIHeuristics.gd
scripts/ai/AIAgentConfig.gd
tests/test_ai_opponent.gd
tests/test_ai_step_resolver.gd
```

建议改动：

```text
scenes/battle/BattleScene.gd
scenes/battle_setup/BattleSetup.gd
scripts/autoload/GameManager.gd
tests/TestRunner.gd
```

## 第一阶段的里程碑

### M1：AI 能接管并自动 setup

完成后应达到：

1. 进入 VS_AI 后无需手动帮玩家 2 摆牌
2. setup 能稳定进入主流程

### M2：AI 能完成基础回合

完成后应达到：

1. AI 会贴能、铺场、攻击、结束回合
2. 不会非法操作
3. 不会无限卡住

### M3：AI 能处理常见 step 卡

完成后应达到：

1. AI 能打常见主流卡组的基础流程
2. `电气发生器`、`老大的指令`、`交替类` 不会卡死

### M4：AI 具备迁移到 AI vs AI 的接口基础

完成后应达到：

1. agent 决策不再依赖玩家 UI 点击
2. step resolver 可后台运行
3. 行动与日志结构可供未来批量 runner 复用

## 与长期路线的衔接

第一阶段结束后，下一步不是直接“把这版 Bot 调得更强”，而应该开始做系统化演进。

## 第二阶段建议目标：Headless AI vs AI

建议新增：

1. `AISimulationRunner.gd`
2. 无 UI 对局循环
3. 固定随机种子
4. 批量对局统计输出

验收：

1. 两个 baseline AI 能后台完整对战
2. 可以连续跑多局
3. 可以输出胜率和回合数统计

## 第三阶段建议目标：评测联盟

建议新增：

1. agent 版本号
2. baseline / candidate 对战矩阵
3. Elo 或胜率统计

验收：

1. 新 agent 必须通过联盟评测
2. 可以知道“是不是变强了”而不是只凭体感

## 第四阶段建议目标：Deck Search

建议新增：

1. deck 配置批量跑分
2. agent 固定、deck 变动的评测模式
3. deck 变异与筛选机制

验收：

1. 能比较不同构筑强度
2. 能逐步接近“当前 agent 下的更优卡组”

## 风险控制

### 1. 不要一开始做“最强 AI”叙事

当前真正要做的是：

1. 先拿到稳定 simulator
2. 先拿到统一动作空间
3. 先拿到统一 step resolver

没有这三样，“最强 AI”只是空口号。

### 2. 所有 AI 动作都必须回到 GSM

禁止：

1. 直接改 `GameState`
2. 在 AI 层手搓结算
3. 绕过现有 effect step 协议

### 3. 第一阶段必须有限步、可中断、可定位

否则非常容易出现：

1. AI 无限循环
2. 某张卡交互卡死
3. 批量实验无法定位问题

## 结论

如果长期目标是：

1. AI 对战 AI
2. 自博弈训练
3. 最终找到最强 AI 与最强卡组组合

那么第一阶段文档就必须明确：

它不是一个孤立的小功能，而是整套 AI 系统的第一块地基。

第一阶段真正的成功标准不是“AI 很强”，而是：

1. AI 能合法行动
2. AI 能稳定打完一局
3. AI 接口可复用
4. AI 决策与 step 协议已经脱离纯 UI 人工操作
5. 后续 AI vs AI、评测联盟和 deck search 都能在这套基础上继续搭
