# PTCG Train 卡牌特性与技能实现框架

## 1. 总体架构

本项目的卡牌效果系统采用**四层架构**，将数据、逻辑、注册、执行清晰分离：

```
+--------------------------------------------+
|  UI 层 (BattleScene)                       |
|  收集玩家交互选择 -> 传递 targets 给引擎   |
+--------------------------------------------+
|  引擎层 (EffectProcessor / DamageCalculator)|
|  查询效果 -> 计算修正 -> 调度执行          |
+--------------------------------------------+
|  注册层 (EffectRegistry)                   |
|  effect_id -> 效果实例映射、集中注册       |
+--------------------------------------------+
|  效果层 (BaseEffect 及其子类)              |
|  每种效果的具体实现脚本                     |
+--------------------------------------------+
```

### 1.1 核心原则

- **effect_id 主键制**：API 返回的 MD5 哈希 `effect_id` 是效果注册的唯一标识。拥有相同 `effect_id` 的卡牌共用同一份效果实现（如不同系列的"博士的研究"）。
- **参数化复用**：相同模式的效果使用同一个类，通过构造函数参数区分行为（如 `EffectDrawCards(7, true)` = 弃手抽7，`EffectDrawCards(3, false)` = 直接抽3）。
- **双注册表机制**：
  - `register_effect(effect_id, effect)`：注册非攻击类效果（训练家、特性、道具、竞技场、特殊能量）。
  - `register_attack_effect(effect_id, effect)`：注册招式附加效果，一张卡可注册多个。

### 1.2 关键数据模型

| 类名 | 职责 | 位置 |
|------|------|------|
| `CardData` | 卡牌静态数据（名称、类型、HP、招式、特性等） | `scripts/data/CardData.gd` |
| `CardInstance` | 游戏中一张具体卡牌的实例（关联 CardData + 归属玩家） | `scripts/data/CardInstance.gd` |
| `PokemonSlot` | 场上一只宝可梦的完整状态（进化栈、能量、道具、伤害、状态） | `scripts/data/PokemonSlot.gd` |
| `GameState` | 完整对战状态（双方玩家、回合数、竞技场、阶段） | `scripts/data/GameState.gd` |
| `PlayerState` | 单个玩家状态（牌库、手牌、弃牌区、奖赏卡、场上宝可梦） | `scripts/data/PlayerState.gd` |

### 1.3 卡牌数据结构

一张宝可梦卡的 `CardData` 包含：

```
CardData
|-- name / name_en        # 中文/英文名
|-- card_type             # Pokemon / Item / Supporter / Tool / Stadium / Basic Energy / Special Energy
|-- mechanic              # ex / V / VSTAR / VMAX / Radiant / 空
|-- effect_id             # 效果唯一标识(MD5 哈希)
|-- energy_type           # 属性: R/W/G/L/P/F/D/M/N/C
|-- stage                 # Basic / Stage 1 / Stage 2
|-- hp                    # 生命值
|-- attacks[]             # 招式列表
|   +-- {name, text, cost, damage, is_vstar_power}
|-- abilities[]           # 特性列表
|   +-- {name, text}
|-- weakness / resistance # 弱点/抗性
+-- retreat_cost          # 撤退费用
```

---

## 2. 效果类型与生命周期

### 2.1 六大效果类型

| 类型 | 触发时机 | 注册方式 | 持续性 | 目录 |
|------|----------|----------|--------|------|
| 训练家（物品/支援者） | 从手牌使用时一次性执行 | `register_effect()` | 一次性 | `trainer_effects/` |
| 宝可梦招式附加效果 | 攻击伤害结算后触发 | `register_attack_effect()` | 一次性 | `pokemon_effects/Attack*.gd` |
| 宝可梦特性效果 | 玩家主动使用或被动查询 | `register_effect()` | 回合内/持续 | `pokemon_effects/Ability*.gd` |
| 道具持续效果 | 附着在宝可梦上，被动查询 | `register_effect()` | 持续 | `tool_effects/` |
| 竞技场持续效果 | 放置在场上，被动查询 | `register_effect()` | 持续 | `stadium_effects/` |
| 特殊能量持续效果 | 附着在宝可梦上，被动查询 | `register_effect()` | 持续 | `energy_effects/` |

### 2.2 效果执行流程

#### 训练家卡执行流程

```
玩家使用手牌 → BattleScene 调用 effect.get_interaction_steps()
→ 弹出交互对话框收集选择 → 整理为 targets[]
→ EffectProcessor.execute_card_effect(card, targets, state)
→ effect.can_execute() 校验 → effect.execute() 执行
```

#### 攻击结算流程

```
玩家选择招式 → BattleScene 收集招式交互步骤
→ DamageCalculator.calculate_damage()
  |-- 基础伤害(招式 damage 字段)
  |-- + attack_modifier(招式效果的 get_damage_bonus)
  |-- + attacker_modifier(特性/道具/竞技场/能量的攻击加成)
  |-- x 弱点倍率
  |-- - 抗性减免
  +-- + defender_modifier(特性/道具/竞技场/能量的防御减免)
→ 结算伤害 → EffectProcessor.execute_attack_effect()
→ 依次执行所有 register_attack_effect 注册的效果
```

#### 特性使用流程

```
玩家点击特性 → EffectProcessor.can_use_ability() 校验
→ effect.get_interaction_steps() 收集交互
→ EffectProcessor.execute_ability_effect()
→ effect.execute_ability(pokemon, ability_index, targets, state)
```

### 2.3 持续效果查询机制

道具、竞技场、特殊能量的持续效果不在使用时一次性执行，而是由 `EffectProcessor` 在以下时机**被动查询**：

| 查询时机 | 方法 | 作用 |
|----------|------|------|
| 攻击伤害计算 | `get_attacker_modifier()` / `get_defender_modifier()` | 叠加所有攻防修正值 |
| 撤退费用计算 | `get_retreat_cost_modifier()` | 叠加撤退修正 |
| HP 计算 | `get_hp_modifier()` | 叠加 HP 修正 |
| 能量类型/数量查询 | `get_energy_type()` / `get_energy_colorless_count()` | 特殊能量的类型覆盖 |
| 特性是否被禁用 | `is_ability_disabled()` | 道具/竞技场是否屏蔽特性 |
| 特殊能量是否被压制 | `is_special_energy_suppressed()` | 竞技场是否压制特殊能量效果 |

---

## 3. BaseEffect 基类接口

所有效果脚本继承 `BaseEffect`（位于 `scripts/effects/BaseEffect.gd`），核心接口如下：

| 方法 | 用途 | 调用方 |
|------|------|--------|
| `get_interaction_steps(card, state)` | 描述此效果需要的玩家交互步骤 | BattleScene |
| `get_attack_interaction_steps(card, attack, state)` | 描述招式附加效果的交互步骤 | BattleScene |
| `can_execute(card, state) → bool` | 校验效果是否可以执行 | EffectProcessor |
| `execute(card, targets, state)` | 执行训练家卡/特殊能量效果 | EffectProcessor |
| `execute_attack(attacker, defender, attack_index, state)` | 执行招式附加效果 | EffectProcessor |
| `execute_ability(pokemon, ability_index, targets, state)` | 执行特性效果 | EffectProcessor |
| `get_description() → String` | 获取效果描述文本 | UI |

### 3.1 交互步骤协议

每个交互步骤是一个 Dictionary：

```gdscript
{
    "id": "step_id",              # 步骤标识（用于从 context 中读取结果）
    "title": "选择目标",           # 显示给玩家的标题
    "items": [...],               # 可选项列表（CardInstance / PokemonSlot 等）
    "labels": [...],              # 可选项的显示文字
    "min_select": 1,              # 最少选择数量
    "max_select": 3,              # 最多选择数量
    "allow_cancel": true,         # 是否允许取消
}
```

**分配型步骤**（如从牌库选能量分配到宝可梦）使用扩展协议：

```gdscript
{
    "ui_mode": "card_assignment",
    "source_items": [...],         # 可被分配的源（如能量卡）
    "source_labels": [...],
    "target_items": [...],         # 分配目标（如宝可梦槽位）
    "target_labels": [...],
    "min_select": 0,
    "max_select": 3,
}
```

---

## 4. 效果注册机制

### 4.1 静态注册（训练家/道具/竞技场/特殊能量）

在 `EffectRegistry.register_all()` 中通过硬编码 `effect_id` 注册：

```gdscript
# 例：高级球
processor.register_effect("a337ed34a45e63c6d21d98c3d8e0cb6e", EffectUltraBall.new())
```

### 4.2 动态注册（宝可梦卡）

宝可梦卡在构建牌库时通过 `EffectRegistry.register_pokemon_card()` 动态注册。注册逻辑分两步：

1. **按特性名称匹配**：`_get_ability_effect(ability_name)` 根据中文特性名返回对应效果实例。
2. **按招式名称匹配**：`_get_attack_effects(attack_name)` 根据中文招式名返回效果实例列表。

对于需要精确参数控制的卡牌，在 `_register_pokemon_effect_overrides()` 中按 `effect_id` 硬编码注册。

### 4.3 注册示例

以喷火龙ex为例：

```gdscript
# 特性"烈炎支配"通过名称自动匹配注册
"烈炎支配":
    return AbilityAttachFromDeckEffect.new("R", 3, "own", true, false)

# 招式"燃烧黑暗"通过名称自动匹配注册
"燃烧黑暗":
    return [AttackPrizeCountDamage.new(30)]
```

---

## 5. 通用效果类库

### 5.1 训练家通用效果

| 效果类 | 构造参数 | 功能 | 使用卡牌示例 |
|--------|----------|------|-------------|
| `EffectDrawCards` | `(draw_count, discard_hand_first)` | 抽 N 张（可选先弃全部手牌） | 博士的研究(7,true) |
| `EffectShuffleDrawCards` | `(draw_count, draw_by_prizes, affect_opponent)` | 洗回手牌后抽 N 张 | 裁判(4,false,true) |
| `EffectSearchDeck` | `(search_count, discard_cost, card_type_filter)` | 从牌库检索指定类型卡牌 | 大师球(1,0,"Pokemon") |
| `EffectSwitchPokemon` | `(target_player)` | 替换战斗宝可梦 | 宝可梦交替("self") |
| `EffectLookTopCards` | `(look_count, card_type_filter)` | 查看牌库顶 N 张选 1 张 | 超级球(7,"Pokemon") |

### 5.2 招式附加效果通用类

| 效果类 | 构造参数 | 功能 | 使用卡牌示例 |
|--------|----------|------|-------------|
| `EffectDiscardEnergy` | `(count, energy_type)` | 弃掉自身能量 | 喷火龙ex·炎爆(1,"R") |
| `EffectApplyStatus` | `(status, require_coin, attack_idx)` | 施加异常状态 | 毒、烧伤等 |
| `EffectCoinFlipDamage` | `(damage, coin_count, until_tails)` | 投币追加伤害 | 长尾粉碎(90,1,false) |
| `EffectSelfDamage` | `(damage, attack_idx)` | 自伤/反作用力 | 各种反伤招式 |
| `EffectBenchDamage` | `(damage, target_all, target_side)` | 备战区范围伤害 | 各种溅射招式 |
| `AttackSelfLockNextTurn` | 无 | 下回合锁定此招式 | 炎爆、棱镜利刃、光子引爆 |
| `AttackBenchSnipe` | `(damage, count, self_dmg, atk_idx)` | 对备战区精确伤害 | 月光手里剑(90,2,0) |
| `AttackPrizeCountDamage` | `(damage_per_prize)` | 按对手已拿奖赏追加伤害 | 燃烧黑暗(30) |
| `AttackSearchAndAttach` | `(type, count, mode, top_n, target, tag)` | 检索能量附着 | 三重蓄能、巅峰加速 |

### 5.3 持续效果通用类

| 效果类 | 构造参数 | 功能 | 使用卡牌示例 |
|--------|----------|------|-------------|
| `EffectToolConditionalDamage` | `(bonus, condition)` | 条件攻击加成 | 极限腰带(50,"ex") |
| `EffectToolHPModifier` | `(hp_mod, disable_ability)` | HP 修正 | 勇气护符(50,false) |
| `EffectToolRetreatModifier` | `(retreat_mod)` | 撤退费用修正 | 各类减撤退道具 |
| `EffectStadiumDamageModifier` | `(amount, type, filter, owner_only)` | 竞技场伤害修正 | Full Metal Lab(-30,"defense","M") |
| `EffectSpecialEnergyModifier` | `(dmg_mod, retreat_mod, type, count)` | 特殊能量持续修正 | 双重涡轮能量(-20,0,"C",2) |

---

## 6. 常用卡牌效果实现表

以下选取当前主流环境中最常用的卡牌，列出其特性/招式的具体内容和当前实现状态。

### 6.1 宝可梦卡

#### 喷火龙ex（Charizard ex）

| 项目 | 内容 |
|------|------|
| **类型** | 火属性 · Stage 2 · ex |
| **HP** | 330 |
| **弱点/抗性** | 水 ×2 / 无 |
| **撤退费用** | 2 |

| 技能类型 | 名称 | 描述 | 费用 | 伤害 | 效果类 | 实现状态 |
|----------|------|------|------|------|--------|----------|
| 特性 | 烈炎支配 | 进化时从牌库选最多3张火能量附着到己方宝可梦 | - | - | `AbilityAttachFromDeck("R",3,"own",true,false)` | 已实现，含交互 |
| 招式 | 燃烧黑暗 | 对手每拿走1张奖赏卡，伤害+30 | RRC | 180+ | `AttackPrizeCountDamage(30)` | 已实现 |

---

#### 梦幻ex（Mew ex）

| 项目 | 内容 |
|------|------|
| **类型** | 超属性 · Basic · ex |
| **HP** | 180 |
| **弱点/抗性** | 恶 ×2 / 无 |
| **撤退费用** | 1 |

| 技能类型 | 名称 | 描述 | 费用 | 伤害 | 效果类 | 实现状态 |
|----------|------|------|------|------|--------|----------|
| 特性 | 再起动 | 每回合1次，抽牌直到手牌达3张 | - | - | `AbilityDrawToN(3)` | 已实现 |
| 招式 | 基因侵入 | 复制对手战斗宝可梦的1个招式并使用 | CC | - | `AttackCopyAttack` | 已实现（简化版，自动复制第1个招式） |

---

#### 大比鸟ex（Pidgeot ex）

| 项目 | 内容 |
|------|------|
| **类型** | 无色属性 · Stage 2 · ex |
| **HP** | 280 |
| **弱点/抗性** | 雷 ×2 / 斗 -30 |
| **撤退费用** | 1 |

| 技能类型 | 名称 | 描述 | 费用 | 伤害 | 效果类 | 实现状态 |
|----------|------|------|------|------|--------|----------|
| 特性 | 音速搜索 | 每回合1次，从牌库选1张任意卡加入手牌 | - | - | `AbilitySearchAny(1,true)` | 已实现，含交互 |
| 招式 | 狂风呼啸 | 可选择弃掉场上竞技场卡 | CCC | 120 | `AttackOptionalDiscardStadium` | 已实现 |

---

#### 密勒顿ex（Miraidon ex）

| 项目 | 内容 |
|------|------|
| **类型** | 雷属性 · Basic · ex |
| **HP** | 220 |
| **弱点/抗性** | 斗 ×2 / 无 |
| **撤退费用** | 1 |

| 技能类型 | 名称 | 描述 | 费用 | 伤害 | 效果类 | 实现状态 |
|----------|------|------|------|------|--------|----------|
| 特性 | 串联装置 | 每回合1次，搜索最多2只雷系基础宝可梦放到备战区 | - | - | `AbilitySearchPokemonToBench("L",2)` | 已实现 |
| 招式 | 光子引爆 | 下回合无法使用此招式 | LLC | 220 | `AttackSelfLockNextTurn` | 已实现 |

---

#### 骑拉帝纳VSTAR（Giratina VSTAR）

| 项目 | 内容 |
|------|------|
| **类型** | 龙属性 · VSTAR |
| **HP** | 280 |
| **弱点/抗性** | 无 / 无 |
| **撤退费用** | 2 |

| 技能类型 | 名称 | 描述 | 费用 | 伤害 | 效果类 | 实现状态 |
|----------|------|------|------|------|--------|----------|
| 招式 | 放逐冲击 | 将自身3张能量放入放逐区，造成280伤害 | GPWC | 280 | `AttackLostZoneEnergy(3,true)` | 已实现（自动选择能量） |
| VSTAR力量 | 星耀安魂曲 | 若放逐区≥10张牌，KO对方战斗宝可梦 | GPWC | - | `AttackLostZoneKO` | 已实现 |

---

#### 阿尔宙斯VSTAR（Arceus VSTAR）

| 项目 | 内容 |
|------|------|
| **类型** | 无色属性 · VSTAR |
| **HP** | 280 |
| **弱点/抗性** | 斗 ×2 / 无 |
| **撤退费用** | 2 |

| 技能类型 | 名称 | 描述 | 费用 | 伤害 | 效果类 | 实现状态 |
|----------|------|------|------|------|--------|----------|
| VSTAR力量(特性) | 星耀诞生 | 从牌库选择最多2张任意卡加入手牌（每局1次） | - | - | `AbilitySearchAny(2,true,true)` | 已实现，含交互 |
| 招式 | 三重新星 | 从牌库检索能量附着到V宝可梦 | CCC | 200 | `AttackSearchAttachToV` | 已实现 |

---

#### 铁头壳ex（Iron Hands ex）

| 项目 | 内容 |
|------|------|
| **类型** | 雷属性 · Basic · ex · Future |
| **HP** | 230 |

| 技能类型 | 名称 | 描述 | 费用 | 伤害 | 效果类 | 实现状态 |
|----------|------|------|------|------|--------|----------|
| 招式 | 双刃 | 对备战区1只宝可梦120伤害，自身受30反伤 | LLCC | 120 | `AttackBenchSnipe(120,1,30)` | 已实现 |
| 招式 | 多谢款待 | 击倒时额外获取1张奖赏卡 | LLCC | 120 | `AttackExtraPrize(1)` | 已实现 |

---

#### 光辉甲贺忍蛙（Radiant Greninja）

| 项目 | 内容 |
|------|------|
| **类型** | 水属性 · Basic · Radiant |
| **HP** | 130 |

| 技能类型 | 名称 | 描述 | 费用 | 伤害 | 效果类 | 实现状态 |
|----------|------|------|------|------|--------|----------|
| 特性 | 隐藏牌 | 每回合1次，弃1张能量从牌库抽2张 | - | - | `AbilityDiscardDraw` | 已实现 |
| 招式 | 月光手里剑 | 对备战区2只宝可梦各90伤害 | WCC | - | `AttackBenchSnipe(90,2,0)` | 已实现 |

#### 铁包袱（Iron Bundle）

| 项目 | 内容 |
|------|------|
| **类型** | 水属性 · Basic · Future |
| **HP** | 120 |

| 技能类型 | 名称 | 描述 | 费用 | 伤害 | 效果类 | 实现状态 |
|----------|------|------|------|------|--------|----------|
| 特性 | 强力吹风机 | 在备战区时每回合1次，将对手战斗与备战宝可梦互换（对手选择），然后自身弃置 | - | - | `AbilityGustFromBench` | 已实现，含交互 |

> **实现细节**：`AbilityGustFromBench` 限制仅备战区宝可梦可使用（`pokemon not in player.bench` 时返回 false），通过 `USED_KEY` 标记限制每回合1次。交互步骤列出对手所有备战宝可梦由对手选择，使用后将自身及所有附属卡牌放入弃牌区。

---

### 6.2 训练家卡

| 卡牌名 | 类型 | 效果描述 | 效果类 | 实现状态 |
|--------|------|----------|--------|----------|
| 博士的研究 | 支援者 | 弃掉手牌，抽7张 | `EffectDrawCards(7,true)` | 已实现 |
| 奇树(Iono) | 支援者 | 双方洗手牌入库，按奖赏卡剩余数抽牌 | `EffectIono` | 已实现，含交互 |
| 老大的指令 | 支援者 | 选择对手1只备战宝可梦与战斗宝可梦互换 | `EffectBossOrders` | 已实现，含交互 |
| 裁判 | 支援者 | 双方洗手牌入库，各抽4张 | `EffectShuffleDrawCards(4,false,true)` | 已实现 |
| 莎莉娜 | 支援者 | 二选一：弃3张抽到5 / 将对方V拉到战斗位 | `EffectSerena` | 已实现 |
| 派帕 | 支援者 | 检索1张物品+1张道具 | `EffectArven` | 已实现，含交互 |
| 珠贝 | 支援者 | 检索1只水宝可梦+1张物品 | `EffectIrida` | 已实现，含交互 |
| 高级球 | 物品 | 弃2张手牌，检索任意1只宝可梦 | `EffectUltraBall` | 已实现，含交互 |
| 巢穴球 | 物品 | 检索1只基础宝可梦放到备战区 | `EffectNestBall` | 已实现，含交互 |
| 友好宝芬 | 物品 | 检索最多2只HP≤70的基础宝可梦到备战区 | `EffectBuddyPoffin` | 已实现，含交互 |
| 神奇糖果 | 物品 | 跳过Stage 1直接进化为Stage 2 | `EffectRareCandy` | 已实现，含交互 |
| 顶尖捕捉器 | 物品(ACE) | 双方各选1只备战宝可梦与战斗宝可梦互换 | `EffectPrimeCatcher` | 已实现，含交互 |
| 放逐吸尘器 | 物品 | 弃1张手牌，移除道具或竞技场到放逐区 | `EffectLostVacuum` | 已实现 |
| 厉害钓竿 | 物品 | 弃牌区最多3张宝可梦/能量洗回牌库 | `EffectSuperRod` | 已实现，含交互 |
| 电气发生器 | 物品 | 查看牌库顶5张，选雷能量附着到备战区 | `EffectElectricGenerator` | 已实现 |
| 宝可梦捕捉器 | 物品 | 投币正面：选对手1只备战宝可梦换到战斗场 | `EffectPokemonCatcher` | 已实现，含交互 |
| 黑夜魔灵 | 物品 | 从弃牌区选1张宝可梦或基本能量加入手牌，或将基础宝可梦直接放到备战区 | `EffectNightStretcher` | 已实现，含交互 |
| 能量转移 | 物品 | 将己方1只宝可梦上的1张基本能量转移到另1只宝可梦上 | `EffectEnergySwitch` | 已实现，含交互 |

### 6.3 道具卡

| 卡牌名 | 效果描述 | 效果类 | 实现状态 |
|--------|----------|--------|----------|
| 极限腰带 | 对ex宝可梦攻击+50 | `EffectToolConditionalDamage(50,"ex")` | 已实现 |
| 不服输头带 | 奖赏卡落后时攻击+30 | `EffectToolConditionalDamage(30,"prize_behind")` | 已实现 |
| 讲究腰带 | 对V宝可梦攻击+30 | `EffectToolConditionalDamage(30,"V")` | 已实现 |
| 勇气护符 | HP+50 | `EffectToolHPModifier(50,false)` | 已实现 |
| 森林封印石 | 赋予VSTAR力量：搜索任意2张卡 | `AbilityVSTARSearch` | 已实现，含交互 |
| 驱劲能量 未来 | 未来宝可梦撤退-0、攻击+20 | `EffectToolFutureBoost` | 已实现 |
| 沉重接力棒 | 昏厥时转移基本能量 | `EffectToolHeavyBaton` | 已实现 |
| 紧急滑板 | 撤退-1（HP≤120时撤退0） | `EffectToolRescueBoard` | 已实现 |
| 璀璨结晶 | 附着的太晶宝可梦招式费用-1 | `EffectSparklingCrystal` | 已实现 |

### 6.4 竞技场卡

| 卡牌名 | 效果描述 | 效果类 | 实现状态 |
|--------|----------|--------|----------|
| 崩塌的竞技场 | 双方备战区上限减为3 | `EffectCollapsedStadium` | 已实现 |
| 放逐市 | 昏厥的宝可梦进入放逐区 | `EffectLostCity` | 已实现 |
| 城镇百货 | 每回合1次，搜索道具/物品 | `EffectTownStore` | 已实现 |
| Full Metal Lab | 钢属性宝可梦受到伤害-30 | `EffectStadiumDamageModifier(-30,"defense","M")` | 已实现 |
| 干扰之塔 | 压制所有宝可梦道具效果 | `EffectJammingTower` | 已实现 |
| 神奥神殿 | 压制所有特殊能量效果 | `EffectTempleOfSinnoh` | 已实现 |

### 6.5 特殊能量卡

| 卡牌名 | 效果描述 | 效果类 | 实现状态 |
|--------|----------|--------|----------|
| 双重涡轮能量 | 提供2个无色能量，攻击-20 | `EffectSpecialEnergyModifier(-20,0,"C",2)` | 已实现 |
| 喷射能量 | 附着时可替换到战斗位 | `EffectJetEnergy` | 已实现 |
| 治疗能量 | 免疫异常状态 | `EffectTherapeuticEnergy` | 已实现 |
| V防守能量 | V宝可梦受到伤害-30 | `EffectVGuardEnergy` | 已实现 |
| 馈赠能量 | 附着的宝可梦昏厥时抽牌至7张 | `EffectGiftEnergy` | 已实现 |
| 薄雾能量 | 免疫对手招式效果 | `EffectMistEnergy` | 已实现 |
| 传承能量 | 提供任意类型能量（限V） | `EffectLegacyEnergy` | 已实现 |

### 6.6 重点卡牌实现细节

#### 璀璨结晶（Sparkling Crystal）

- **类型**：宝可梦道具（ACE SPEC）
- **effect_id**：`12164ed03296d2df4ef6d0fa8b5f8aae`
- **效果**：附着的太晶（Tera）宝可梦的招式费用减少1个任意能量。
- **效果类**：`EffectSparklingCrystal`（`tool_effects/EffectSparklingCrystal.gd`）
- **实现方式**：通过 `get_attack_any_cost_modifier()` 被 `EffectProcessor.get_attack_any_cost_modifier()` 被动查询。检查宝可梦的 `ancient_trait == "Tera"` 条件，满足时返回 `-1`。费用校验时由 `RuleValidator._get_all_any_cost_removals()` 枚举所有可能的移除组合，只要有任一组合满足当前能量即判定可用。
- **交互**：无需玩家交互（纯持续效果）。
- **已修复bug**：原实现中 `_remove_any_cost_symbols()` 硬编码优先移除非C字符，导致对于多属性费用（如多龙巴鲁托ex的幻影潜袭 RP）玩家无法选择移除哪个属性。例如只附着1个火能量时，代码固定移除R剩P，判定能量不足。修复后枚举所有移除组合（移除R剩P、移除P剩R），任一满足即可。

#### 宝可梦捕捉器（Pokemon Catcher）

- **类型**：物品卡
- **effect_id**：`3a6d419769778b40091e69fbd76737ec`
- **效果**：投币1次。若正面，选择对手1只备战宝可梦与战斗宝可梦互换。
- **效果类**：`EffectPokemonCatcher`（`trainer_effects/EffectPokemonCatcher.gd`）
- **实现方式**：`get_interaction_steps()` 中先投币，正面时才生成备战宝可梦选择步骤；反面时返回空步骤列表（效果直接结束）。`execute()` 中也有投币状态校验确保一致性。
- **交互**：含交互 — 投币正面时弹出对手备战宝可梦选择列表。

#### 黑夜魔灵（Night Stretcher）

- **类型**：物品卡
- **effect_id**：`3e6f1daf545dfed48d0588dd50792a2e`
- **效果**：从弃牌区选择1张宝可梦或基本能量卡加入手牌；若选择的是基础宝可梦，也可以直接放到备战区。
- **效果类**：`EffectNightStretcher`（`trainer_effects/EffectNightStretcher.gd`）
- **实现方式**：`get_interaction_steps()` 遍历弃牌区，对每张宝可梦生成"加入手牌"选项，对基础宝可梦额外生成"放到备战区"选项，对基本能量生成"加入手牌"选项。每个选项是一个 `{mode, card}` 字典，玩家选择后在 `execute()` 中根据 mode 分支执行。
- **交互**：含交互 — 合并了目标选择和操作模式（手牌/备战区）为一步选择。

#### 能量转移（Energy Switch）

- **类型**：物品卡
- **effect_id**：`294212d9c02dc0acb886a7ef01ebeac4`
- **效果**：将己方1只宝可梦上的1张基本能量转移到另1只己方宝可梦上。
- **效果类**：`EffectEnergySwitch`（`trainer_effects/EffectEnergySwitch.gd`）
- **实现方式**：`get_interaction_steps()` 返回3个顺序步骤：(1)选择源宝可梦、(2)选择该宝可梦上的基本能量、(3)选择目标宝可梦。`can_execute()` 校验场上至少有2只宝可梦且至少有1张基本能量。`execute()` 中校验源和目标不同后，从源的 `attached_energy` 移除并添加到目标的 `attached_energy`。
- **交互**：含交互 — 3步顺序选择（源宝可梦→能量→目标宝可梦）。

#### 铁包袱（Iron Bundle）— 特性：强力吹风机

- **类型**：宝可梦（水属性 · Basic · Future）
- **效果**：在备战区时，每回合1次，将对手的战斗宝可梦与备战宝可梦互换（由对手选择），然后将自身及所有卡牌放入弃牌区。
- **效果类**：`AbilityGustFromBench`（`pokemon_effects/AbilityGustFromBench.gd`）
- **实现方式**：`can_use_ability()` 检查3个条件：(1)自身在备战区（`pokemon not in player.bench` 时返回 false）、(2)对手备战区非空、(3)本回合未使用过（通过 `USED_KEY` 效果标记判定）。使用后在 `pokemon.effects` 中追加回合标记。交互步骤列出对手所有备战宝可梦，`execute_ability()` 将选定目标与对手战斗宝可梦互换，然后将自身及所有卡牌放入弃牌区。
- **交互**：含交互 — 选择对手1只备战宝可梦。

---

## 7. 新增效果的实现指南

### 7.1 添加训练家卡效果

1. 在 `scripts/effects/trainer_effects/` 下新建脚本，继承 `BaseEffect`。
2. 实现 `get_interaction_steps()` 描述交互需求。
3. 实现 `can_execute()` 校验使用条件。
4. 实现 `execute()` 执行逻辑。
5. 在 `EffectRegistry._register_items()` 或 `_register_supporters()` 中注册 `effect_id → 实例` 映射。

### 7.2 添加宝可梦特性效果

1. 在 `scripts/effects/pokemon_effects/` 下新建 `Ability*.gd`，继承 `BaseEffect`。
2. 实现 `can_use_ability(pokemon, state) → bool`。
3. 实现 `get_interaction_steps()` 或 `execute_ability()`。
4. 在 `EffectRegistry._get_ability_effect()` 的 match 分支中添加特性名称映射。

### 7.3 添加招式附加效果

1. 在 `scripts/effects/pokemon_effects/` 下新建 `Attack*.gd`，继承 `BaseEffect`。
2. 实现 `execute_attack(attacker, defender, attack_index, state)`。
3. 如需伤害修正，实现 `get_damage_bonus(attacker, state) → int`。
4. 如需绑定特定招式索引，实现 `applies_to_attack_index(attack_index) → bool`。
5. 在 `EffectRegistry._get_attack_effects()` 的 match 分支中添加招式名称映射，或在 `_register_pokemon_effect_overrides()` 中按 `effect_id` 硬编码注册。

### 7.4 添加持续效果

道具、竞技场、特殊能量的持续效果需要在 `EffectProcessor` 的查询方法中被正确调用。实现时需注意：

- 伤害修正类效果实现 `get_attack_modifier()` / `get_defense_modifier()` 等。
- 撤退修正类效果实现 `get_retreat_cost_modifier()`。
- HP 修正类效果实现 `get_hp_modifier()`。
- 竞技场全局压制效果实现 `suppresses_special_energy_effects()` 或 `suppresses_tool_effects()`。

---

## 8. 统计概览

截至当前版本，已实现效果的分类统计：

| 分类 | 已注册数量 | 效果脚本数 |
|------|-----------|-----------|
| 物品卡 | 22 | 22 |
| 支援者卡 | 16 | 16 |
| 道具卡 | 9 | 9 |
| 竞技场卡 | 7 | 7 |
| 特殊能量卡 | 7 | 7 |
| 宝可梦特性 | ~35 | 35+ |
| 宝可梦招式效果 | ~50 | 50+ |
| **合计** | **~146** | **~146** |

其中已接入完整交互框架（非自动选择）的效果约占60%以上，剩余部分仍使用自动选择第一合法目标的降级逻辑。

---

## 9. Bug 发现方法论与反思

### 9.1 当前验证模式的局限

在 2026-03 批次的卡牌审核中，我们尝试通过以下流程发现 bug：

1. 读取效果类源码，理解实现逻辑
2. 读取卡牌描述文本（本地 JSON 缓存）
3. 对比描述与实现是否一致
4. 通过现有测试用例验证

这套流程成功发现了**铁包袱**（3个bug）和**黑夜魔灵**（1个bug）的问题，但**漏掉了璀璨结晶的bug**。

### 9.2 漏检原因分析

璀璨结晶的 bug 具有以下特征，使其难以被上述流程捕获：

| 维度 | 铁包袱/黑夜魔灵的 bug | 璀璨结晶的 bug |
|------|----------------------|---------------|
| bug 位置 | 效果类自身 | 效果类正确，bug 在下游消费者（RuleValidator） |
| 描述 vs 代码 | 直接矛盾（如"备战区"写成了"战斗位"） | 效果类忠实返回 -1，描述完全匹配 |
| 单元测试 | 测试了效果类的输入输出 | 测试只验证 modifier 返回值，未测试实际攻击判定 |
| 发现方式 | 读代码即可发现 | 必须构造特定能量组合 + 多属性费用场景才能触发 |

**核心问题**：审核只关注了"效果类本身是否正确实现了卡牌描述"，没有追踪效果值在整条链路中是如何被消费的。璀璨结晶的效果类（返回 -1）完美正确，但 RuleValidator 消费这个 -1 时使用了硬编码的移除策略，在多属性费用场景下产生了错误行为。

### 9.3 改进方向

为避免类似遗漏，效果验证应遵循以下原则：

**原则一：端到端测试优先于单元测试**

不应只测试"效果类返回了正确的 modifier"，还应测试"带着这个效果，实际游戏场景是否能正确执行"。对于持续效果尤其如此——它们的值需要经过 EffectProcessor -> RuleValidator/DamageCalculator 等多层消费。

```
反例：assert_eq(modifier, -1)        -- 只验证效果类输出
正例：assert_true(can_use_attack(...)) -- 验证端到端行为
```

**原则二：用真实卡牌构造边界场景**

审核卡牌时，应从实际使用该卡牌的牌组出发，构造边界能量组合：
- 璀璨结晶 + 多龙巴鲁托ex（RP 费用）：只有 R / 只有 P / R+P 都有
- 璀璨结晶 + 太晶水宝可梦（WCC 费用）：只有 1C / 只有 1W
- 任何"减少任意属性"的效果 + 多属性费用招式

**原则三：关注"选择权"类效果**

"任意属性"、"从 N 张中选 M 张"、"由对手选择"——这类涉及选择权的效果，最容易在代码中被简化为"自动选第一个"或"硬编码优先级"。审核时应特别关注：

- 卡牌描述是否暗示了玩家选择权？
- 代码是否给予了对应的选择自由度？
- 自动选择的降级逻辑是否覆盖了所有合法选择？

**原则四：追踪跨层数据流**

效果类返回一个修正值后，要追踪这个值的完整消费路径：

```
EffectSparklingCrystal.get_attack_any_cost_modifier() -> -1
  -> EffectProcessor.get_attack_any_cost_modifier() 汇总
    -> RuleValidator.get_attack_unusable_reason() 消费
      -> _remove_any_cost_symbols() / _get_all_any_cost_removals() 实际移除
        -> has_enough_energy() 最终判定
```

只审核第一层是不够的，必须验证每一层的处理逻辑都正确。
