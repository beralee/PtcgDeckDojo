# 场上直连交互 UI 改造设计

## 目标

本次改造只调整 `BattleScene` 的交互呈现，不改变 `GameStateMachine`、`EffectProcessor`、各 `Effect*.gd` 的结算语义。

目标是把“与场上宝可梦直接交互”的选择，从当前的弹框式选择，改成在战斗区内完成：

1. 选择场上宝可梦目标时，不再弹出遮挡战场的对话框。
2. 玩家需要能直接看见同名宝可梦当前的血量、能量、道具、受伤状态，再做选择。
3. 对于“源牌在面板里，目标在场上”的交互，保留一个较小的中心 HUD 面板显示源牌，但目标选择必须在场上完成。
4. 对于不涉及场上宝可梦的交互，继续沿用现有 `DialogOverlay`。

## 非目标

1. 不重写效果系统，不引入新的底层 effect step 语义。
2. 不修改卡牌真实规则和结算顺序。
3. 不在这一轮里重做“点击场上宝可梦后弹出的行动菜单”。
4. 不处理那些当前根本还没接入 interaction steps、属于效果实现缺口的卡牌逻辑。

## 当前架构结论

### 1. 现有弹框并不在 effect 层

当前所有效果交互的真正入口都在：

- `scenes/battle/BattleScene.gd`

核心链路：

1. `Effect*.gd` 通过 `get_interaction_steps()` / `get_attack_interaction_steps()` / `get_on_play_interaction_steps()` 返回步骤字典。
2. `BattleScene._start_effect_interaction()` 记录 pending state。
3. `BattleScene._show_next_effect_interaction_step()` 读取当前 step。
4. 当前实现几乎统一走 `_show_dialog()`，于是形成居中弹框。

这意味着：

1. 我们可以在 `BattleScene` 内对 step 做分流。
2. 只要 step 字典不变，底层 effect / GSM 语义就不需要动。

### 2. 现有项目已经有“场上直操作”先例

已有先例：

1. 击倒后拿奖赏卡已经改成了左侧奖赏区翻牌选择。
2. 场上 slot 已经全部用 `BattleCardView` 渲染，并且右键可看详情。
3. `BattleScene._on_slot_input()` 已经统一接管了 active / bench 的点击事件。

这说明“把某类 pending choice 交给场上 slot 点击消费”是可行路线。

## 交互类型拆分

### A. 场上单步点选

定义：

1. 当前 step 的 `items` 全部是 `PokemonSlot`
2. 玩家只是在场上选 1 个或多个宝可梦
3. 不需要在弹框里先选源牌

这类应改成：

1. 顶部或中央显示一条提示语
2. 合法 slot 高亮
3. 玩家直接点击战场完成选择
4. 若是 `max_select == 1 && min_select == 1`，点击后立刻进入下一步/执行
5. 若允许多选，则保留小型确认按钮，不再弹框

当前代码里属于这类的实现包括：

### 非 effect 的 choice

1. `send_out`：击倒后派出替换宝可梦
2. `retreat_bench`：撤退后选择新的战斗宝可梦
3. `heavy_baton_target`：沉重接力棒选择接收能量的备战宝可梦

### Trainer / Stadium / Ability / Attack steps

1. `EffectBossOrders.gd`：`opponent_bench_target`
2. `EffectCounterCatcher.gd`：`opponent_bench_target`
3. `EffectPrimeCatcher.gd`：`opponent_bench_target`、`own_bench_target`
4. `EffectSwitchPokemon.gd`：`self_switch_target`、`opponent_switch_target`
5. `EffectSwitchCart.gd`：`switch_target`
6. `AbilityGustFromBench.gd`：`opponent_bench_target`
7. `AttackSwitchSelfToBench.gd`：`switch_target`
8. `EffectCollapsedStadium.gd`：多选要弃掉的备战宝可梦
9. `EffectRareCandy.gd`：`target_pokemon`
10. `AbilityPsychicEmbrace.gd`：`embrace_target`
11. `AttackAttachBasicEnergyFromDiscard.gd`：`attach_target`
12. `AttackAnyTargetDamage.gd`：`any_target`
13. `AttackSelfDamageCounterTargetDamage.gd`：`target_pokemon`
14. `AttackTMEvolution.gd`：`evolution_bench`
15. `AbilityMoveDamageCountersToOpponent.gd`：`source_pokemon`、`target_pokemon`
16. `AbilityMoveOpponentDamageCounters.gd`：`source_pokemon`、`target_pokemon`

### B. 中央面板选源牌 + 场上选目标

定义：

1. step 本身是 `ui_mode = "card_assignment"`，或语义上属于“先选卡，再选场上宝可梦”
2. `target_items` 是 `PokemonSlot`
3. 玩家需要看到源牌，但最终目标必须点战场

这类应改成：

1. 中央显示一个较小的 HUD 面板，放源牌或伤害指示物
2. 玩家先在面板里选源牌/指示物
3. 再直接点击战场上的合法宝可梦
4. 分配结果实时在面板文案里汇总
5. 必须精确分满时，分满后可自动推进；否则保留确认按钮

当前代码里属于这类的实现包括：

1. `EffectElectricGenerator.gd`
2. `AbilityAttachFromDeck.gd`
3. `AbilityStarPortal.gd`
4. `EffectSadasVitality.gd`
5. `EffectEnergySwitch.gd`
6. `AttackSearchAndAttach.gd`
7. `AttackDistributedBenchCounters.gd`
8. `AttackReturnEnergyThenBenchDamage.gd` 的第二步目标选择

其中用户明确举的例子：

1. 电枪 / `EffectElectricGenerator.gd`
2. 多龙巴鲁托 ex / `AttackDistributedBenchCounters.gd`，以及雷吉铎拉戈 VSTAR 复制后注入的同类 follow-up step

### C. 继续保留弹框

定义：

1. 不涉及场上宝可梦目标
2. 主要是手牌/牌库/弃牌区/奖赏区/数值选项/确认类交互

这类保持现状：

1. 搜索牌库
2. 查看牌库顶并选牌
3. 选支持者/物品目标牌
4. 选数字、选正反面后续分支
5. 纯确认或提示步骤

## 当前代码中的例外项

有一类并不只是 UI 问题，而是“效果本身没有互动步骤”：

1. `AttackBenchDamageCounters.gd`

它现在还是旧的自动轮流分配 TODO，不属于单纯把弹框改到战场即可解决的问题。这类卡牌不纳入本轮“只改 UI 交互”的主线，后续应按 card-audit 单独修。

## 设计方案

### 1. 在 `BattleScene` 增加场上交互层

新增一个轻量级场上交互控制层，职责只在 UI：

1. 管理当前是否处于“场上点选模式”
2. 管理哪些 slot 可选
3. 管理哪些 slot 已选
4. 渲染中央小型 HUD 面板
5. 把场上点击转换成当前 step 的 `selected_indices` / assignment context

这层不触碰 effect 结算，只负责把玩家点击翻译回当前 step 需要的上下文。

### 2. 对 step 做 BattleScene 内部分流

在 `BattleScene._show_next_effect_interaction_step()` 增加分流：

1. 若 step 为 `PokemonSlot` 直接选择型，则启动场上 slot 选择
2. 若 step 为 `card_assignment` 且 `target_items` 为 `PokemonSlot`，则启动“中央面板 + 场上目标选择”
3. 其他步骤仍走 `_show_dialog()`

### 3. 非 effect 的 choice 统一接入同一套场上选择器

除了 effect steps，以下 pending choice 也迁移到同一套 UI：

1. `send_out`
2. `retreat_bench`
3. `heavy_baton_target`

好处：

1. 用户体验一致
2. 代码上只维护一套 slot 高亮和点击消费逻辑

### 4. 场上 slot 的视觉规则

合法目标：

1. 金色描边或更强高亮
2. 保持原有 HP/能量/道具 HUD 可见

已选择目标：

1. 比合法目标更强的选中态

非法 slot：

1. 保持正常外观，不响应当前交互

### 5. 中央面板规则

中央小面板用于展示：

1. 当前提示语
2. 源牌列表 / 伤害指示物列表
3. 当前已完成的分配摘要
4. `确认` / `清空` / `取消` 按钮

它不是阻断式 modal：

1. 不再整屏遮罩
2. 不遮住左右奖赏区和大部分战斗区

## 研发计划

### Phase 1：基础设施

1. 在 `BattleScene.gd` 增加场上交互状态机
2. 动态创建中央 HUD 面板
3. 给场上 slot 增加“合法/选中”高亮态
4. 将 `send_out`、`retreat_bench`、`heavy_baton_target` 切到场上点选

### Phase 2：单步 PokemonSlot effect step 分流

把所有 `items = PokemonSlot` 的 effect step 从 `_show_dialog()` 分流到场上：

1. 切换类
2. gust 类
3. 单体目标攻击类
4. 多选 bench 类

### Phase 3：assignment + 场上目标

实现“中央面板选源牌 + 场上点目标”：

1. Electric Generator
2. Star Portal / 各种 attach from deck / discard
3. Energy Switch
4. 伤害指示物分配

### Phase 4：补边角与回归

1. 双人本地交接模式检查
2. 取消/清空/多选边界
3. follow-up attack steps 与动态插入步骤回归
4. 全量测试

## 代码触点

主要只动：

1. `scenes/battle/BattleScene.gd`
2. 可能少量 `BattleCardView.gd` 选中/禁用样式增强
3. 测试文件：
   - `tests/test_battle_ui_features.gd`
   - 如有必要，补少量 interaction flow 回归

原则上不改：

1. `GameStateMachine.gd`
2. `EffectProcessor.gd`
3. 各卡牌 effect 的结算逻辑

## 验证策略

### BattleScene 级 UI 回归

至少覆盖：

1. `send_out` 不再依赖弹框，点击合法 bench 即可完成
2. `retreat_bench` 不再依赖弹框
3. effect step 为 `PokemonSlot` 时走场上直选
4. `card_assignment + PokemonSlot target` 时，会显示中央源牌面板并等待场上目标点击
5. 选满后 context 结构与旧弹框模式保持一致

### 全量回归

1. headless Godot 全量测试必须通过
2. 已有雷吉铎拉戈复制多龙的 follow-up 分配回归不能退化
3. 击倒后奖赏卡 UI 不能被新场上交互状态污染

## 当前研发进展

已完成：
1. `BattleScene` 新增场上交互层，支持高亮可选 `PokemonSlot`、记录选中态，以及在中心 HUD 面板里承载 assignment 型交互。
2. `send_out`、`retreat_bench`、`heavy_baton_target` 已从弹框切到场上直接选择。
3. `effect step` 中 `items` 全为 `PokemonSlot` 的步骤，已自动分流到场上点选。
4. `card_assignment + PokemonSlot target` 的步骤，已自动分流到“中心 HUD 选源牌 + 场上点目标”。

本轮仍保留旧 UI 的范围：
1. 非场上目标类交互，继续使用原有 `DialogOverlay`。
2. 本身还没有正确 interaction step 的卡牌，不在这一轮 UI 改造范围内。

下一步实现顺序：
1. 继续按文档中的卡牌/效果清单做 BattleScene 级回归，先锁住基础路由。
2. 再逐批用真实卡牌流程验证切换、gust、填能、伤害指示物分配这些高频交互。
3. 最后做局部视觉和取消/清空行为的细修。

## 面板停靠补充

场上交互 HUD 的停靠点新增一条显示规则：

1. 目标全部在我方场上时，面板整体上移，避免挡住我方备战区。
2. 目标全部在对方场上时，面板整体下移，避免挡住对方备战区。
3. 目标同时涉及双方或无法判断时，保持居中。

这条规则仍然只改 `BattleScene` 的 UI 呈现，不改 effect step 和底层结算。
