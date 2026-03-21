# 卡牌效果实现文档

## 1. 架构概述

### 1.1 效果系统核心原则
- **effect_id 唯一映射**：每张卡的 `effect_id`（API 返回的哈希字符串）对应唯一的效果实现
- **参数化通用效果类**：相同模式的效果使用同一个类，通过构造函数参数区分
- **EffectRegistry 统一注册**：所有 effect_id → 效果实例的映射在 `EffectRegistry.gd` 中集中注册
- **EffectProcessor 运行时查询**：持续效果（道具/竞技场/特殊能量/特性）由 EffectProcessor 在伤害计算/撤退时动态查询

### 1.2 效果类型分类

| 类型 | 触发时机 | 注册方式 | 基类 |
|------|----------|----------|------|
| 训练家卡（物品/支援者） | 手牌使用时 | `register_effect()` | BaseEffect |
| 招式附加效果 | 攻击结算后 | `register_attack_effect()` | BaseEffect |
| 特性效果 | 玩家主动使用 | `register_effect()` | BaseEffect |
| 道具持续效果 | 查询时被动读取 | `register_effect()` | EffectToolXxx |
| 竞技场持续效果 | 查询时被动读取 | `register_effect()` | EffectStadiumXxx |
| 特殊能量持续效果 | 查询时被动读取 | `register_effect()` | EffectSpecialEnergyXxx |

### 1.3 已有通用效果类

#### 训练家效果 (`scripts/effects/trainer_effects/`)
| 类名 | 参数 | 功能 |
|------|------|------|
| EffectDrawCards | draw_count, discard_hand_first | 抽N张/弃手抽N张 |
| EffectShuffleDrawCards | draw_count, draw_by_prizes, affect_opponent | 洗手抽牌/按奖赏卡数抽 |
| EffectSearchDeck | search_count, discard_cost, card_type_filter | 检索牌库 |
| EffectSwitchPokemon | target_player("self"/"opponent"/"both") | 替换宝可梦 |
| EffectHeal | heal_amount, heal_all, discard_energy_cost | 治疗伤害 |

#### 招式附加效果 (`scripts/effects/pokemon_effects/`)
| 类名 | 参数 | 功能 |
|------|------|------|
| EffectDiscardEnergy | discard_count, energy_type_filter | 弃能量 |
| EffectApplyStatus | status_name, require_coin | 施加状态 |
| EffectCoinFlipDamage | damage_per_heads, coin_count, flip_until_tails | 投币伤害 |
| EffectSelfDamage | self_damage | 自伤/反作用 |
| EffectBenchDamage | bench_damage, target_all, target_side | 备战区伤害 |
| AbilityDrawCard | draw_count | 抽卡特性 |
| AbilityDamageModifier | modifier_amount, modifier_type, self_only | 伤害修正特性 |

#### 持续效果
| 类名 | 参数 | 功能 |
|------|------|------|
| EffectDoubleColorless | provides_count | 提供N个无色能量 |
| EffectSpecialEnergyOnAttach | heal_amount, draw_count | 附着时触发 |
| EffectSpecialEnergyModifier | damage_modifier, retreat_modifier, energy_type, energy_count | 持续修正 |
| EffectStadiumDraw | draw_count | 竞技场抽卡 |
| EffectStadiumDamageModifier | modifier_amount, modifier_type, pokemon_filter, owner_only | 竞技场伤害修正 |
| EffectStadiumRetreatModifier | retreat_modifier, pokemon_filter | 竞技场撤退修正 |
| EffectToolDamageModifier | damage_modifier, modifier_type, target_filter | 道具伤害修正 |
| EffectToolRetreatModifier | retreat_modifier | 道具撤退修正 |
| EffectToolHPModifier | hp_modifier, disable_ability | 道具HP修正 |

### 1.4 效果交互框架
- `BaseEffect.get_interaction_steps(card, state)`：效果脚本描述自己需要的玩家选择步骤。
- 每个步骤由 `id/title/items/labels/min_select/max_select/allow_cancel` 组成。
- 需要“多张资源反复分配到多个目标”的效果，统一使用 `ui_mode = "card_assignment"`。
- `BattleScene` 按步骤顺序弹窗收集玩家选择，再把结果整理成 `targets[0] = Dictionary`。
- 效果脚本通过 `BaseEffect.get_interaction_context(targets)` 读取玩家选择结果。
- 未迁移到交互框架的效果仍保留自动选择第一合法目标的降级逻辑，确保游戏可继续运行。

`card_assignment` 步骤协议：
- `source_items/source_labels`：可被分配的卡牌列表，例如牌库中的火能量、弃牌区中的水能量。
- `target_items/target_labels`：可接受分配的目标列表，例如己方所有宝可梦、己方水属性宝可梦。
- `min_select/max_select`：最少/最多完成多少次“卡牌 -> 目标”的分配。
- `BattleScene` 允许玩家重复执行“选 1 张源卡 -> 点 1 个目标”直到确认，结果写回为 `[{source, target}, ...]`。
- 同一目标可接收多次分配，不同源卡也可分散给多个目标；同一张源卡只能被分配一次。

当前已接入该框架的高频训练家卡：
- 高级球
- 巢穴球
- 友好宝芬
- 老大的指令
- 反击捕捉器
- 顶尖捕捉器
- 朋友手册
- 厉害钓竿
- 派帕
- 珠贝
- 吉尼亚
- 神奇糖果

---

## 2. 需要新增的效果类

以下效果无法用现有通用类直接表达，需要新建专用类：

### 2.1 训练家效果（新增）
| 类名 | 用途 | 使用卡牌 |
|------|------|----------|
| EffectCounterCatcher | 奖赏卡多时拉对手备战 | 反击捕捉器 |
| EffectLostVacuum | 弃1手牌，移除道具/竞技场到放逐区 | 放逐吸尘器 |
| EffectPalPad | 弃牌区支援者放回牌库 | 朋友手册 |
| EffectSuperRod | 弃牌区宝可梦/能量放回牌库 | 厉害钓竿 |
| EffectRareCandy | 跳阶进化 | 神奇糖果 |
| EffectBuddyPoffin | 检索HP≤70基础宝可梦到备战区 | 友好宝芬 |
| EffectLookTopCards | 查看牌库顶N张选1张 | 宝可装置3.0/超级球/大师球 |
| EffectCapturingAroma | 投币决定检索进化/基础宝可梦 | 捕获香氛 |
| EffectPrimeCatcher | 双方各换宝可梦 | 顶尖捕捉器 |
| EffectElectricGenerator | 牌库顶5张选雷能量附着 | 电气发生器 |
| EffectTechnoRadar | 弃1手牌检索未来宝可梦 | 高科技雷达 |
| EffectSwitchCart | 替换基础战斗宝可梦，治疗30 | 交替推车 |
| EffectCancelCologne | 消除对手战斗宝可梦特性 | 清除古龙水 |
| EffectNestBall | 检索基础宝可梦到备战区 | 巢穴球 |
| EffectUltraBall | 弃2手牌检索任意宝可梦 | 高级球 |

### 2.2 支援者效果（新增）
| 类名 | 用途 | 使用卡牌 |
|------|------|----------|
| EffectArven | 检索物品+道具各1 | 派帕 |
| EffectProfTuro | 回收己方宝可梦到手牌 | 弗图博士的剧本 |
| EffectBossOrders | 拉对手备战宝可梦 | 老大的指令 |
| EffectIono | 双方洗手按奖赏卡数抽 | 奇树 |
| EffectProfResearch | 弃手抽7 | 博士的研究 |
| EffectJudge | 双方洗手各抽4 | 裁判 |
| EffectCiphermaniac | 牌库选2张放顶 | 暗码迷的解读 |
| EffectThorton | 弃牌区基础宝可梦替换场上 | 捩木 |
| EffectSerena | 二选一：弃牌抽到5/拉V | 莎莉娜 |
| EffectJacq | 检索进化宝可梦 | 吉尼亚 |
| EffectIrida | 检索水宝可梦+物品 | 珠贝 |

### 2.3 宝可梦特性效果（新增）
| 类名 | 用途 | 使用卡牌 |
|------|------|----------|
| AbilityBenchProtect | 备战区免伤 | 玛纳霏(浪花水帘) |
| AbilityOnBenchEnter | 放置时触发检索 | 霓虹鱼V(夜光信号), 铁斑叶ex(快速游标) |
| AbilityEndTurnDraw | 使用后回合结束，抽卡 | 洛托姆V(快速充电) |
| AbilityConditionalDefense | 条件减伤 | 藏玛然特(金属之盾) |
| AbilitySearchAny | 检索任意卡 | 大比鸟ex(音速搜索), 阿尔宙斯VSTAR(星耀诞生) |
| AbilityDrawToN | 抽到N张 | 梦幻ex(再起动), 大尾狸(勤奋门牙) |
| AbilityReduceAttackCost | 减少招式能量消耗 | 光辉喷火龙(振奋之心) |
| AbilityAttachFromDeck | 从牌库附着能量 | 喷火龙ex(烈炎支配), 始祖大鸟(原始涡轮), 金属怪(金属制造者), 密勒顿ex(串联装置) |
| AbilityDisableOpponentAbility | 消除对手特性 | 振翼发(暗夜振翼) |
| AbilityDiscardDraw | 弃能量抽卡 | 光辉甲贺忍蛙(隐藏牌) |
| AbilityFirstTurnDraw | 首回合弃手抽牌 | 怒鹦哥ex(英武重抽) |
| AbilityShuffleHandDraw | 洗手抽1 | 贪心栗鼠(巢穴藏身) |
| AbilityBenchImmuneDamage | 备战区时免伤 | 大牙狸(毫不在意) |
| AbilityIgnoreEffects | 不受招式效果影响 | 火恐龙(闪焰之幕), 卡比兽(无畏脂肪) |
| AbilityGustFromBench | 备战区时拉对手宝可梦 | 铁包袱(强力吹风机) |
| AbilityFutureDamageBoost | 未来宝可梦攻击+N | 铁头壳ex(蔚蓝指令) |
| AbilityVSTARSearch | VSTAR力量检索 | 森林封印石(星耀炼金术) |
| AbilityVSTARSummon | VSTAR力量召唤弃牌区 | 洛奇亚VSTAR(星耀汇聚) |
| AbilityLightningBoost | 雷基础宝可梦攻击+N | 闪电鸟(电气象征) |
| AbilityVReduceDamage | 减少V宝可梦伤害 | 光辉沙奈朵(慈爱帘幕) |

### 2.4 宝可梦招式效果（新增）
许多宝可梦有带附加效果的招式，需要自定义实现：

| 类名 | 用途 | 使用卡牌 |
|------|------|----------|
| AttackSearchAndAttach | 检索能量并附着 | 阿尔宙斯V(三重蓄能), 密勒顿(巅峰加速) |
| AttackCopyAttack | 复制对手招式 | 梦幻ex(基因侵入) |
| AttackScrapShort | 放逐道具追加伤害 | 洛托姆V(废品短路) |
| AttackRevengeBonus | 上回合昏厥追加伤害 | 藏玛然特(报仇) |
| AttackSelfSleep | 自身陷入睡眠 | 卡比兽(轰隆鼾声) |
| AttackCallForFamily | 检索基础宝可梦到备战区 | 泡沫栗鼠(呼朋引伴) |
| AttackReturnToDeck | 自身回牌库 | 霓虹鱼V(水流回转) |
| AttackDiscardEnergyMultiDamage | 弃雷能量×倍伤害 | 雷丘V(强劲电光) |
| AttackBenchCountDamage | 备战区数量追加伤害 | 雷公V(雷电回旋曲) |
| AttackPrizeDamageBonus | 对手奖赏卡追加伤害 | 喷火龙ex(燃烧黑暗) |
| AttackExtraPrize | 击倒多拿奖赏卡 | 铁臂膀ex(多谢款待) |
| AttackBenchSnipe | 对备战区精确伤害 | 铁头壳ex(双刃), 光辉甲贺忍蛙(月光手里剑) |
| AttackLostZoneEnergy | 弃能量到放逐区 | 骑拉帝纳VSTAR(放逐冲击) |
| AttackLostZoneKO | 放逐区满直接击倒 | 骑拉帝纳VSTAR(星耀安魂曲) |
| AttackSearchAttachToV | 检索能量附着于V | 阿尔宙斯VSTAR(三重新星) |
| AttackOptionalDiscardStadium | 可选弃置竞技场 | 大比鸟ex(狂风呼啸), 洛奇亚V(气旋俯冲), 洛奇亚VSTAR(风暴俯冲) |
| AttackTopDeckSearch | 看牌库顶选卡 | 骑拉帝纳V(深渊探求), 铁哑铃(磁力抬升) |
| AttackEnergyCountDamage | 按能量数追加伤害 | 起源帝牙卢卡VSTAR(金属爆破), 光辉沙奈朵(精神强念) |
| AttackSelfLockNextTurn | 下回合不可使用招式 | 光辉喷火龙(炎爆), 铁斑叶ex(棱镜利刃), 密勒顿ex(光子引爆) |
| AttackDrawTo7 | 抽到7张 | 皮宝宝(握握抽取) |
| AttackDiscardStadium | 弃置竞技场 | 小火龙151C(烧光) |
| AttackCoinFlipOrFail | 投币失败则招式无效 | 大牙狸(终结门牙), 大尾狸(长尾粉碎) |
| AttackDiscardEnergyFromSelf | 弃自身能量 | 怒鹦哥ex(鼓足干劲) |
| AttackReadWindDraw | 弃1手牌抽3 | 洛奇亚V(读风) |
| AttackSpecialEnergyMultiDamage | 按特殊能量数×伤害 | 奇诺栗鼠(特殊滚动) |
| AttackBenchDamageCounters | 放置伤害指示物到备战区 | 振翼发(飞来横祸) |
| AttackVSTARExtraTurn | VSTAR力量额外回合 | 起源帝牙卢卡VSTAR(星耀时刻) |
| AttackIgnoreDefenderEffects | 无视防守方效果 | 骑拉帝纳V(撕裂) |

### 2.5 道具效果（新增）
| 类名 | 用途 | 使用卡牌 |
|------|------|----------|
| EffectToolConditionalDamage | 条件伤害加成 | 不服输头带(奖赏卡多+30), 极限腰带(对ex+50), 讲究腰带(对V+30) |
| EffectToolFutureBoost | 未来宝可梦撤退0+攻击+20 | 驱劲能量 未来 |
| EffectToolHeavyBaton | 昏厥时转移能量 | 沉重接力棒 |
| EffectToolRescueBoard | 撤退-1/HP≤30撤退0 | 紧急滑板 |
| EffectToolVSTARAbility | 赋予VSTAR力量特性 | 森林封印石 |

### 2.6 特殊能量效果（新增）
| 类名 | 用途 | 使用卡牌 |
|------|------|----------|
| EffectTherapeuticEnergy | 免疫睡眠/麻痹/混乱 | 治疗能量 |
| EffectVGuardEnergy | V宝可梦伤害-30 | V防守能量 |
| EffectGiftEnergy | 昏厥时抽到7 | 馈赠能量 |
| EffectMistEnergy | 免疫对手招式效果 | 薄雾能量 |
| EffectJetEnergy | 附着时换到战斗场 | 喷射能量 |

---

## 3. effect_id 映射表

### 3.1 训练家 - 物品卡
| effect_id | 卡牌名 | 效果类 | 构造参数 |
|-----------|--------|--------|----------|
| `06bc00d5dcec33898dc6db2e4c4d10ec` | 反击捕捉器 | EffectCounterCatcher | - |
| `1af63a7e2cb7a79215474ad8db8fd8fd` | 巢穴球 | EffectNestBall | - |
| `66b2f1d77328b6578b1bf0d58d98f66b` | 清除古龙水 | EffectCancelCologne | - |
| `8f655fea1f90164bfbccb7a95c223e17` | 放逐吸尘器 | EffectLostVacuum | - |
| `a337ed34a45e63c6d21d98c3d8e0cb6e` | 高级球 | EffectUltraBall | - |
| `a47d5a8ed00e14a2146fc511745d23b5` | 朋友手册 | EffectPalPad | - |
| `c9c948169525fbb3dce70c477ec7a90a` | 厉害钓竿 | EffectSuperRod | - |
| `d3891abcfe3277c8811cde06741d3236` | 神奇糖果 | EffectRareCandy | - |
| `f866dfee26cd6b0dbbb52b74438d0a59` | 友好宝芬 | EffectBuddyPoffin | - |
| `768b545a38fccd5e265093b5adce10af` | 宝可装置3.0 | EffectLookTopCards | 7, "Supporter" |
| `1838e8afe529b519a57dd8bbd307905a` | 超级球 | EffectLookTopCards | 7, "Pokemon" |
| `7cd68d9e286b78a7f9c799fce24a7d6c` | 捕获香氛 | EffectCapturingAroma | - |
| `7c0b20e121c9d0e0d2d8a43524f7494e` | 宝可梦交替 | EffectSwitchPokemon | "self" |
| `4ec261453212280d0eb03ed8254ca97f` | 顶尖捕捉器 | EffectPrimeCatcher | - |
| `30e7c440d69817592656f5b44e444111` | 大师球 | EffectSearchDeck | 1, 0, "Pokemon" |
| `2234845fbc2e11ab95587e1b393bb318` | 电气发生器 | EffectElectricGenerator | - |
| `8b0d4f541f256d67f0757efe4fc8b407` | 高科技雷达 | EffectTechnoRadar | - |
| `8342fe3eeec6f897f3271be1aa26a412` | 交替推车 | EffectSwitchCart | - |

### 3.2 训练家 - 支援者卡
| effect_id | 卡牌名 | 效果类 | 构造参数 |
|-----------|--------|--------|----------|
| `5bdbc985f9aa2e6f248b53f6f35d1d37` | 派帕 | EffectArven | - |
| `73d5f46ecf3a6d71b23ce7bc1a28d4f4` | 弗图博士的剧本 | EffectProfTuro | - |
| `8e1fa2c9018db938084c94c7c970d419` | 老大的指令 | EffectBossOrders | - |
| `af514f82d182aeae5327b2c360df703d` | 奇树 | EffectIono | - |
| `aecd80ca2722885c3d062a2255346f3e` | 博士的研究 | EffectDrawCards | 7, true |
| `0a9bdf265647461dd5c6c827ffc19e61` | 裁判 | EffectShuffleDrawCards | 4, false, true |
| `1b5fc2ed2bce98ef93457881c05354e2` | 暗码迷的解读 | EffectCiphermaniac | - |
| `05b9dc8ee5c16c46da20f47a04907856` | 捩木 | EffectThorton | - |
| `d83b170c43c0ade1f81c817c4488d5db` | 莎莉娜 | EffectSerena | - |
| `a8a2b27c2641d8d7212fc887ca032e4c` | 吉尼亚 | EffectSearchDeck | 2, 0, "Evolution" |
| `4f53ab6bf158fd1a8869ae037f4a0d6d` | 珠贝 | EffectIrida | - |

### 3.3 宝可梦道具
| effect_id | 卡牌名 | 效果类 | 构造参数 |
|-----------|--------|--------|----------|
| `2e07a9870350b611a3d21ab2053dfa2a` | 极限腰带 | EffectToolConditionalDamage | 50, "ex" |
| `9fa9943ccda36f417ac3cb675177c216` | 森林封印石 | EffectToolVSTARAbility | - |
| `e242d711feffd98f3fbb5c511d00d667` | 不服输头带 | EffectToolConditionalDamage | 30, "prize_behind" |
| `36939b241f51e497487feb52e0ea8994` | 讲究腰带 | EffectToolConditionalDamage | 30, "V" |
| `d1c2f018a644e662f2b6895fdfc29281` | 勇气护符 | EffectToolHPModifier | 50, false |
| `54920a273edba38ce45f3bc8f6e8ff25` | 驱劲能量 未来 | EffectToolFutureBoost | - |
| `770c741043025f241dbd81422cb8987d` | 沉重接力棒 | EffectToolHeavyBaton | - |
| `0b4cc131a19862f92acf71494f29a0ed` | 紧急滑板 | EffectToolRescueBoard | - |

### 3.4 竞技场
| effect_id | 卡牌名 | 效果类 | 构造参数 |
|-----------|--------|--------|----------|
| `fb3628071280487676f79281696ffbd9` | 崩塌的竞技场 | EffectCollapsedStadium | - |
| `7f4e493ec0d852a5bb31c02bdbdb2c4e` | 放逐市 | EffectLostCity | - |
| `13b3caaa408a85dfd1e2a5ad797e8b8a` | 城镇百货 | EffectTownStore | - |

### 3.5 特殊能量
| effect_id | 卡牌名 | 效果类 | 构造参数 |
|-----------|--------|--------|----------|
| `9c04dd0addf56a7b2c88476bc8e45c0e` | 双重涡轮能量 | EffectDoubleColorless+EffectSpecialEnergyModifier | 2, -20 |
| `1323733f19cc04e54090b39bc1a393b8` | 喷射能量 | EffectJetEnergy | - |
| `2c65697c2aceac4e6a1f85f810fa386f` | 治疗能量 | EffectTherapeuticEnergy | - |
| `88bf9902f1d769a667bbd3939fc757de` | V防守能量 | EffectVGuardEnergy | - |
| `dbb3f3d2ef2f3372bc8b21336e6c9bc6` | 馈赠能量 | EffectGiftEnergy | - |
| `fb0948c721db1f31767aa6cf0c2ea692` | 薄雾能量 | EffectMistEnergy | - |

### 3.6 宝可梦（按 effect_id）
详见各宝可梦独立效果实现部分。每张宝可梦的招式和特性在 EffectRegistry 中同时注册 `register_effect()` 和 `register_attack_effect()`。

---

## 4. 实现优先级

### Phase 4A: 训练家卡（已可用通用类+新增专用类）
1. 物品卡 18 种 → 大部分需新建类
2. 支援者 11 种 → 部分可复用 EffectDrawCards/EffectShuffleDrawCards

### Phase 4B: 道具 + 竞技场 + 特殊能量（持续效果）
3. 道具 8 种 → 需增强 EffectProcessor 查询
4. 竞技场 3 种 → 需要特殊处理
5. 特殊能量 6 种 → 需要附着时和持续效果

### Phase 4C: 宝可梦特性 + 招式
6. 特性 ~25 种 → 复杂度最高
7. 招式附加效果 ~30 种 → 数量最多

---

## 5. 简化策略

由于许多效果涉及玩家交互选择（选目标、选卡牌），在当前阶段采用以下简化：
- **检索牌库**：自动选择第一个匹配的卡（后续UI可以添加选择界面）
- **选择弃牌**：自动选择手牌末尾的卡
- **选择备战区目标**：自动选择第一个槽位
- **选择能量附着目标**：自动附着到战斗宝可梦
- 所有简化操作标记 `# TODO: 需要UI交互` 以便后续替换

这样可以让效果引擎完整运行，玩家可以在双人操控模式下手动操作实际选择。

更新说明：
- 部分高频训练家卡已迁移到通用交互框架，不再走“自动选择第一项”的简化逻辑。
- 尚未迁移的效果继续使用本节的临时策略。
- 2026-03 起，喷火龙 ex 的“烈炎支配”和帕路奇亚 VSTAR 的“星星传送”已经统一迁移到 `card_assignment`，不再各自维护单独的多步 UI。
---

## 6. 2026-03 Interaction Update
- `BattleScene` now calls `effect.can_execute(card, state)` before opening trainer interaction dialogs.
- `GameStateMachine._build_deck()` now registers Pokemon ability and attack effects while building decks.
- `GameStateMachine.attach_energy()` now triggers on-attach Special Energy effects.
- `GameStateMachine.play_stadium()` now triggers stadium enter-play effects.
- Tests now cover trainer interaction step generation, dynamic Pokemon effect registration, Special Energy attach triggers, and stadium enter-play triggers.

## 7. Card Audit Automation
- `tests/CardCatalogAudit.gd` scans every cached card under `user://cards/`, validates registry coverage, and runs a generic smoke scenario for each supported card type.
- The audit uses real cached cards plus a deterministic fixture state so trainer items, supporters, tools, stadiums, special energies, abilities, and scripted attacks are exercised without manual clicking.
- Current audit output is written to `user://logs/card_audit_latest.txt`.
- The audit now also writes `user://logs/card_status_matrix_latest.txt`, which classifies every cached card across four states: `registry`, `implementation`, `interaction`, and `verification`.
- `tests/test_card_catalog_audit.gd` fails only on real registry gaps or smoke failures; cards with no custom effect logic are reported as `SKIP`.
- Headless entry point:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

- `tests/TestRunner.gd` now auto-quits in headless mode, so the command can be used in CI or local batch verification.

## 8. Test Layers
- `Registration`: checks that cards and dynamic Pokemon effects are actually wired into `EffectRegistry` / `EffectProcessor`.
- `Semantic`: checks that the effect changes game state correctly, instead of merely not crashing.
- `Interaction`: checks that any effect requiring player choice implements `get_interaction_steps()` and returns the expected selectable targets.
- `Flow`: checks that complete in-game sequences still advance correctly through setup, evolution, attack, knockout, replacement, and turn handoff.

## 9. Status Matrix
- `registry=ok/missing/n/a`: whether the card can be resolved to a live effect implementation.
- `implementation=ok/broken/blocked/n/a`: whether the effect passes smoke execution once registered.
- `interaction=present/missing/none/n/a`: whether required player-facing interaction steps exist, or a script still contains a UI TODO marker.
- `verification=covered/gap`: whether the card has explicit test coverage beyond the catalog smoke audit, based on effect script or card-name references in the test suite.

## 10. Skill Integration

## 11. Tool-Granted Attack Flow
- Some tools grant a temporary attack instead of only changing numbers. This path is now treated as a first-class effect flow.
- `EffectProcessor.get_granted_attacks(slot, state)` exposes granted attacks for the active Pokemon.
- `EffectProcessor.get_granted_attack_interaction_steps(slot, attack, state)` lets the tool effect describe any required player choices.
- `GameStateMachine.use_granted_attack(player_index, slot, attack, targets)` executes the granted attack with the same turn, phase, and energy checks used by normal attacks.
- `BattleScene` surfaces granted attacks inside the normal Pokemon action menu, so the player does not need a separate UI mode for tool attacks.
- Interactive granted attacks reuse the same step-based collection pipeline already used by trainer cards, abilities, stadium actions, and scripted attacks.

Current validated example:
- `TM: Devolution` grants `退化`, can be selected from the active Pokemon action dialog, resolves through the generic interaction pipeline, and is discarded at end of turn.
- The local skill at `.codex/skills/ptcg-card-audit/` is the standard entry point for the full card-validation workflow.
- Use it when bulk-verifying card behavior, interpreting `card_audit_latest.txt`, checking `card_status_matrix_latest.txt`, or closing coverage gaps after card-effect changes.
- The expected validation loop is: run `scripts/run_card_audit.ps1`, inspect both reports, fix logic and tests, then re-run until the audit and status matrix are both green.
- Semantic regression coverage should prefer reusable family tests in `tests/test_card_semantic_matrix.gd`, with narrower suites added only when a card family needs dedicated fixtures.
