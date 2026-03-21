# PTCG Train - 宝可梦集换式卡牌练牌模拟器 设计文档

## 1. 项目概述

### 1.1 项目目标
开发一款基于 Godot 引擎的简体中文 PTCG（Pokemon Trading Card Game）练牌模拟器，支持本地双人操控和 AI 对战两种模式，帮助玩家高效练习卡组策略。

### 1.2 核心特性
- **卡组管理**：从 tcg.mik.moe 导入卡组，本地持久化存储
- **规则引擎**：完整实现 PTCG 标准赛制规则
- **双模式对战**：玩家操控双方 / 玩家 vs AI
- **简洁界面**：清晰的场地布局和操作交互
- **快速练牌**：优化操作流程，减少不必要等待

### 1.3 技术选型
| 组件 | 技术 |
|------|------|
| 游戏引擎 | Godot 4.x (GDScript) |
| 数据存储 | JSON 本地文件 |
| 网络请求 | HTTPRequest 节点 |
| AI 引擎 | 基于规则的决策树 + 蒙特卡洛树搜索(MCTS) |

---

## 2. 游戏规则引擎（基于 pokemon.cn 官方规则）

### 2.1 卡牌类型系统

#### 2.1.1 宝可梦卡 (Pokemon)
```
属性:
  - name: String          # 卡牌名（如"小火龙"）
  - hp: int               # 生命值
  - energy_type: String   # 属性类型 (R/W/G/L/P/F/D/M/N/C)
  - stage: String         # 进化状态 (Basic/Stage 1/Stage 2)
  - evolves_from: String  # 进化来源（空字符串表示基础）
  - attacks: Array[Attack]  # 招式列表
  - ability: Array[Ability] # 特性列表
  - weakness: {energy: String, value: String}  # 弱点（如 {W, ×2}）
  - resistance: {energy: String, value: String} | null  # 抗性
  - retreat_cost: int     # 撤退所需能量数
  - mechanic: String|null # 特殊机制 (ex/V/VSTAR/VMAX/Radiant 等)
  - label: String|null    # 标签
```

**属性类型对照表：**
| 代码 | 属性 | 图标颜色 |
|------|------|----------|
| R | 火 | 红 |
| W | 水 | 蓝 |
| G | 草 | 绿 |
| L | 雷 | 黄 |
| P | 超 | 紫 |
| F | 斗 | 棕 |
| D | 恶 | 黑 |
| M | 钢 | 银 |
| N | 龙 | 金 |
| C | 无色 | 白 |

**招式结构：**
```
Attack:
  - name: String      # 招式名（如"烧光"）
  - cost: String      # 能量消耗（如"RR"表示2个火能量）
  - damage: String    # 基础伤害值（如"30"，可为空）
  - text: String      # 效果说明文字
  - is_vstar_power: bool  # 是否为VSTAR力量
```

**特性结构：**
```
Ability:
  - name: String   # 特性名
  - text: String   # 效果说明
```

**进化规则：**
- 基础宝可梦可直接从手牌放置于场上
- 1阶进化宝可梦需叠放于对应的基础宝可梦上
- 2阶进化宝可梦需叠放于对应的1阶进化宝可梦上
- 刚放上场的宝可梦当回合不可进化
- 刚完成进化的宝可梦当回合不可继续进化
- 先攻玩家首回合不可进化

**特殊宝可梦规则：**
| 类型 | 昏厥时对手获取奖赏卡数 | 特殊规则 |
|------|----------------------|---------|
| 普通宝可梦 | 1 | 无 |
| 宝可梦ex | 2 | 名称含"ex"，与同名非ex互为不同卡 |
| 宝可梦V | 2 | 名称含"V"，属于基础宝可梦 |
| 宝可梦VSTAR | 2 | 从V进化，VSTAR力量一局仅用一次 |
| 宝可梦VMAX | 3 | 从V进化 |
| 光辉宝可梦 | 1 | 一套卡组仅限1张光辉宝可梦 |

#### 2.1.2 能量卡 (Energy)
```
基本能量卡 (Basic Energy):
  - 火、水、草、雷、超、斗、恶、钢、龙 共9种
  - 卡组中数量不限

特殊能量卡 (Special Energy):
  - 具有额外效果的能量卡
  - 同名最多4张
```

#### 2.1.3 训练家卡 (Trainer)

**物品卡 (Item)：**
- 每回合使用数量无限制
- 使用后执行效果，放入弃牌区

**宝可梦道具卡 (Tool)：**
- 附着于宝可梦身上
- 1只宝可梦最多附着1张道具卡
- 使用数量无限制

**支援者卡 (Supporter)：**
- 每回合仅能使用1张
- 先攻玩家首回合不可使用
- 使用后放入弃牌区

**竞技场卡 (Stadium)：**
- 每回合最多使出1张
- 放置于场上，对双方生效
- 新竞技场替换旧竞技场（旧的放入持有者弃牌区）
- 不可使出与场上同名的竞技场

#### 2.1.4 ACE SPEC 卡
- 一套卡组中仅能放入1张ACE SPEC卡

### 2.2 场地区域

```
┌─────────────────────────────────────┐
│  [奖赏卡区]  [战斗场]  [牌库]      │  <- 对手区域
│              [备战区(最多5只)]       │
│              [竞技场]               │  <- 共用区域
│              [备战区(最多5只)]       │
│  [奖赏卡区]  [战斗场]  [牌库]      │  <- 己方区域
│         [弃牌区]         [手牌]     │
└─────────────────────────────────────┘
```

| 区域 | 说明 | 可见性 |
|------|------|--------|
| 牌库 | 卡组反面朝上放置 | 非公开（双方均不可随意查看） |
| 战斗场 | 当前战斗宝可梦 | 公开 |
| 备战区 | 后备宝可梦（最多5只） | 公开 |
| 奖赏卡 | 6张反面朝上 | 非公开 |
| 弃牌区 | 已使用/昏厥的卡牌 | 公开 |
| 手牌 | 玩家手中卡牌 | 仅持有者可见 |

### 2.3 对战流程

#### 2.3.1 对战准备
```
1. 猜拳决定先攻/后攻（模拟器中随机或由玩家选择）
2. 双方洗牌，将卡组反面朝上放于牌库
3. 从牌库顶抽7张作为初始手牌
4. 从手牌中选择1张基础宝可梦反面放于战斗场
5. 可选择将其他基础宝可梦反面放于备战区（最多5只）
6. 从牌库顶取6张反面作为奖赏卡
7. 双方翻开场上宝可梦，先攻方开始回合

若手牌无基础宝可梦（Mulligan）：
  - 公开手牌给对手确认
  - 将手牌全部放回牌库重新洗牌
  - 重新抽7张手牌
  - 每次Mulligan，对手可选择额外抽1张（可不抽）
  - 双方都无基础宝可梦则都重来
```

#### 2.3.2 回合结构
```
回合开始:
  ├── 必须: 从牌库抽1张（牌库为空则败北）
  ├── 自由操作（顺序任意，可交叉执行）:
  │   ├── [1次] 从手牌将1张能量卡附着于己方宝可梦
  │   ├── [不限] 从手牌放置基础宝可梦至备战区
  │   ├── [不限] 使用物品卡
  │   ├── [1次] 使用支援者卡
  │   ├── [不限/1次] 使出竞技场卡（每回合1张）
  │   ├── [不限] 进化宝可梦
  │   ├── [不限] 使用宝可梦特性（按特性说明）
  │   └── [1次] 将战斗宝可梦撤退至备战区
  └── 回合结束:
      ├── 选项A: 使用战斗宝可梦的招式 → 回合结束
      ├── 选项B: 宣告回合结束（不使用招式）
      └── 宝可梦检查（回合结束后执行）

先攻玩家首回合限制:
  - 不可使用招式
  - 不可使用支援者卡
```

#### 2.3.3 招式使用
```
条件检查:
  1. 战斗宝可梦身上附着的能量 >= 招式消耗
     - 指定属性能量必须匹配
     - 无色(C)消耗可用任意属性能量支付
  2. 宝可梦未处于睡眠/麻痹状态
  3. 若处于混乱状态，需投币（正面正常使用，反面失败并自伤30）

伤害计算流程:
  1. 基础招式伤害
  2. ±招式自身效果修正（如"投币正面+30"）
  3. ±攻击方身上效果修正（道具、训练家效果等）
  4. ×弱点倍率（攻击方属性=防守方弱点属性时，伤害×2）
  5. -抗性减少（攻击方属性=防守方抗性属性时，伤害-N）
  6. ±防守方身上效果修正
  7. 最终伤害 < 0 则视为 0

注: 使用招式不消耗能量（能量保持附着状态）
```

#### 2.3.4 撤退机制
```
条件:
  - 每回合1次机会
  - 备战区有宝可梦
  - 弃置战斗宝可梦身上的能量（数量=撤退所需能量，属性不限）
  - 未处于睡眠/麻痹状态

效果:
  - 战斗宝可梦移至备战区
  - 选择1只备战宝可梦移至战斗场
  - 保留身上剩余能量和伤害指示物
  - 消除所有特殊状态和附加效果
```

#### 2.3.5 宝可梦昏厥
```
触发: 宝可梦剩余HP <= 0
处理:
  1. 昏厥的宝可梦及其身上所有卡牌（能量、道具）放入弃牌区
  2. 对手拿取相应数量的奖赏卡加入手牌
  3. 若昏厥的是战斗宝可梦，持有者必须选择1只备战宝可梦放入战斗场
  4. 若持有者无备战宝可梦可派出，对手获胜
```

#### 2.3.6 胜利条件
1. **拿完奖赏卡**：先拿完自己6张奖赏卡的玩家获胜
2. **对手无宝可梦**：对手战斗宝可梦昏厥且备战区无宝可梦
3. **对手牌库耗尽**：对手回合开始时牌库无卡可抽
4. **对手投降**

### 2.4 宝可梦检查与特殊状态

#### 2.4.1 宝可梦检查（每回合结束后执行）
检查顺序：
1. 中毒伤害
2. 灼伤伤害 + 投币判定
3. 睡眠投币判定
4. 麻痹恢复判定
5. 特性/训练家卡的宝可梦检查效果
6. HP <= 0 的宝可梦昏厥处理

#### 2.4.2 特殊状态详细

| 状态 | 效果 | 恢复方式 | 叠加规则 |
|------|------|----------|----------|
| 中毒 | 每次检查放1个10伤害指示物 | 回备战区/进化/特定效果 | 可与任意状态叠加 |
| 灼伤 | 每次检查放2个10伤害指示物，投币正面则恢复 | 投币正面/回备战区/进化/特定效果 | 可与任意状态叠加 |
| 睡眠 | 不可使用招式和撤退，检查时投币正面恢复 | 投币正面/回备战区/进化/特定效果 | 被麻痹/混乱替代 |
| 麻痹 | 下一回合不可使用招式和撤退，下一回合检查时恢复 | 经过一次己方回合检查/回备战区/进化/特定效果 | 被睡眠/混乱替代 |
| 混乱 | 使用招式前投币，反面则失败并自伤30，可撤退 | 回备战区/进化/特定效果 | 被睡眠/麻痹替代 |

**状态互斥关系：**
- 睡眠、麻痹、混乱三者互斥（新状态替代旧状态）
- 中毒、灼伤独立，可与任何状态叠加

---

## 3. 卡组管理模块

### 3.1 数据源：tcg.mik.moe API

#### 3.1.1 API 接口

所有接口均为 POST 请求，Content-Type: application/json

**卡组详情接口：**
```
POST https://tcg.mik.moe/api/v3/deck/detail
Body: {"deckId": <int>}

Response:
{
  "code": 200,
  "data": {
    "cards": [
      {
        "setCode": "151C",       // 系列代码
        "cardIndex": "004",      // 卡牌序号
        "cardName": "小火龙",     // 卡牌名称
        "rarity": "C",           // 稀有度
        "effectId": "xxx",       // 效果唯一ID
        "cardType": "Pokemon",   // 卡牌类型
        "yorenCode": "P004",     // 游人代码
        "is": ["Basic"],         // 标签数组
        "setCodeEn": "PAF",      // 英文系列代码
        "cardIndexEn": "7",      // 英文卡牌序号
        "nameEn": "Charmander",  // 英文名
        "count": 3               // 数量
      },
      ...
    ],
    "deckCode": "xxx",         // 卡组代码
    "variant": {               // 卡组变体信息
      "deckId": 0,
      "variantIcon": ["subsitute"],
      "variantId": 1,
      "variantName": "其他"
    }
  },
  "msg": "OK."
}
```

**卡牌详情接口：**
```
POST https://tcg.mik.moe/api/v3/card/card-detail
Body: {"setCode": "151C", "cardIndex": "004"}

Response:
{
  "code": 200,
  "data": {
    "name": "小火龙",
    "cardType": "Pokemon",         // Pokemon|Item|Supporter|Tool|Stadium|Basic Energy|Special Energy
    "mechanic": null,              // ex|V|VSTAR|VMAX|null
    "label": null,
    "description": "...",          // 卡牌效果描述文本
    "yorenCode": "P004",
    "pokemonAttr": {               // 仅宝可梦卡有此字段
      "energyType": "R",
      "stage": "Basic",            // Basic|Stage 1|Stage 2
      "hp": 70,
      "ability": [],               // 特性列表
      "ancientTrait": "",
      "weakness": {"energy": "W", "value": "×2"},
      "resistance": null,
      "retreatCost": 1,
      "attack": [
        {
          "name": "烧光",
          "text": "将场上的竞技场放于弃牌区。",
          "cost": "R",             // 能量消耗编码
          "damage": "",            // 伤害值（可为空）
          "isVStarPower": false
        },
        {
          "name": "吐火",
          "text": "",
          "cost": "RR",
          "damage": "30",
          "isVStarPower": false
        }
      ],
      "evolvesFrom": ""            // 进化来源（空=基础）
    },
    "setCode": "151C",
    "cardIndex": "004",
    "artist": "GIDORA",
    "rarity": "C",
    "releaseDate": "2025-01-17T00:00:00+08:00",
    "regulationMark": "G",
    "effectId": "xxx",
    "regulationLegal": {
      "standard": true,
      "expanded": true
    },
    "effectSameCards": [...],      // 同效果卡牌列表
    "setCodeEn": "PAF",
    "cardIndexEn": "7",
    "nameEn": "Charmander"
  },
  "msg": "OK."
}
```

**卡牌搜索接口：**
```
POST https://tcg.mik.moe/api/v3/card/card-basic-search
Body: {"query": "小火龙", "page": 1, "size": 20}
```

**卡牌图片URL规则：**
```
https://tcg.mik.moe/cards/{setCode}/{cardIndex}  -> 卡牌页面
卡牌图片：需要从页面中解析，或按 setCodeEn/cardIndexEn 从其他图片CDN获取
```

#### 3.1.2 卡牌类型映射 (cardType)
| API值 | 中文 | 类别 |
|-------|------|------|
| Pokemon | 宝可梦卡 | 宝可梦 |
| Item | 物品卡 | 训练家 |
| Supporter | 支援者卡 | 训练家 |
| Tool | 宝可梦道具卡 | 训练家 |
| Stadium | 竞技场卡 | 训练家 |
| Basic Energy | 基本能量卡 | 能量 |
| Special Energy | 特殊能量卡 | 能量 |

### 3.2 本地数据结构

#### 3.2.1 卡组存储格式
```json
// user_data/decks/<deck_id>.json
{
  "id": 574793,
  "name": "喷火龙ex",
  "source_url": "https://tcg.mik.moe/decks/list/574793",
  "import_date": "2026-03-12T10:00:00",
  "variant_name": "其他",
  "deck_code": "xxx",
  "cards": [
    {
      "set_code": "151C",
      "card_index": "004",
      "count": 3,
      "card_type": "Pokemon",
      "name": "小火龙"
    }
  ],
  "total_cards": 60
}
```

#### 3.2.2 卡牌缓存格式
```json
// user_data/cards/<set_code>_<card_index>.json
{
  "name": "小火龙",
  "card_type": "Pokemon",
  "mechanic": null,
  "description": "...",
  "pokemon_attr": {
    "energy_type": "R",
    "stage": "Basic",
    "hp": 70,
    "ability": [],
    "weakness": {"energy": "W", "value": "×2"},
    "resistance": null,
    "retreat_cost": 1,
    "attacks": [
      {
        "name": "烧光",
        "text": "将场上的竞技场放于弃牌区。",
        "cost": "R",
        "damage": "",
        "is_vstar_power": false
      }
    ],
    "evolves_from": ""
  },
  "set_code": "151C",
  "card_index": "004",
  "set_code_en": "PAF",
  "card_index_en": "7",
  "name_en": "Charmander",
  "rarity": "C",
  "regulation_mark": "G",
  "effect_id": "xxx",
  "artist": "GIDORA",
  "is_tags": ["Basic"]
}
```

### 3.3 卡组管理功能

| 功能 | 描述 |
|------|------|
| 导入卡组 | 输入 tcg.mik.moe 卡组链接，解析 deckId，通过 API 获取卡组数据 |
| 下载卡牌详情 | 遍历卡组中所有卡牌，逐一获取卡牌详细信息并缓存 |
| 浏览卡组列表 | 展示所有已导入的卡组 |
| 查看卡组详情 | 展示卡组内所有卡牌及其详细信息 |
| 删除卡组 | 删除本地卡组数据（不删卡牌缓存） |
| 卡组验证 | 检查卡组合法性（60张、同名最多4张等） |

### 3.4 导入流程
```
用户输入链接 -> 解析URL提取deckId
  -> POST /api/v3/deck/detail {deckId}
  -> 获取卡组卡牌列表
  -> 逐张 POST /api/v3/card/card-detail {setCode, cardIndex}
  -> 本地缓存卡牌数据
  -> 保存卡组文件
  -> 校验: 总数60张, 同名<=4张, ACE SPEC<=1张, 光辉宝可梦<=1张
```

---

## 4. 游戏引擎架构

### 4.1 整体架构

```
┌──────────────────────────────────────────────┐
│                 表现层 (UI)                    │
│  MainMenu | DeckManager | BattleScene | ...  │
├──────────────────────────────────────────────┤
│                 控制层                         │
│  InputController | AIController              │
├──────────────────────────────────────────────┤
│                 规则引擎                       │
│  GameStateMachine | RuleValidator            │
│  DamageCalculator | EffectProcessor          │
├──────────────────────────────────────────────┤
│                 数据层                         │
│  GameState | CardDatabase | DeckManager      │
└──────────────────────────────────────────────┘
```

### 4.2 核心类设计

#### 4.2.1 GameState（游戏状态）
```gdscript
class_name GameState

# 玩家数据
var players: Array[PlayerState] = []  # [player_0, player_1]
var current_player_index: int = 0
var turn_number: int = 0
var first_player_index: int = 0

# 场地
var stadium_card: CardInstance = null
var stadium_owner_index: int = -1

# 游戏阶段
var phase: GamePhase = GamePhase.SETUP

# 回合内状态追踪
var energy_attached_this_turn: bool = false
var supporter_used_this_turn: bool = false
var stadium_played_this_turn: bool = false
var retreat_used_this_turn: bool = false
var vstar_power_used: Array[bool] = [false, false]

enum GamePhase {
    SETUP,           # 对战准备
    DRAW,            # 抽牌阶段
    MAIN,            # 主阶段（自由操作）
    ATTACK,          # 攻击阶段
    POKEMON_CHECK,   # 宝可梦检查
    BETWEEN_TURNS,   # 回合间
    KNOCKOUT_REPLACE, # 昏厥后替换宝可梦
    GAME_OVER        # 游戏结束
}
```

#### 4.2.2 PlayerState（玩家状态）
```gdscript
class_name PlayerState

var player_index: int
var deck: Array[CardInstance] = []        # 牌库
var hand: Array[CardInstance] = []        # 手牌
var prizes: Array[CardInstance] = []      # 奖赏卡
var discard_pile: Array[CardInstance] = [] # 弃牌区
var active_pokemon: PokemonSlot = null    # 战斗宝可梦
var bench: Array[PokemonSlot] = []        # 备战区（最多5个槽位）
```

#### 4.2.3 PokemonSlot（宝可梦槽位）
```gdscript
class_name PokemonSlot

var pokemon_stack: Array[CardInstance] = []  # 进化链（底部为基础）
var attached_energy: Array[CardInstance] = [] # 附着能量
var attached_tool: CardInstance = null        # 附着道具
var damage_counters: int = 0                  # 伤害指示物（10的倍数）
var status_conditions: Dictionary = {
    "poisoned": false,
    "burned": false,
    "asleep": false,
    "paralyzed": false,
    "confused": false
}
var turn_played: int = -1       # 放上场的回合（用于进化判定）
var turn_evolved: int = -1      # 最近进化的回合
var effects: Array[Effect] = [] # 附加效果列表

# 计算属性
func get_top_card() -> CardInstance:
    return pokemon_stack.back()

func get_current_hp() -> int:
    return get_top_card().card_data.pokemon_attr.hp - damage_counters

func get_name() -> String:
    return get_top_card().card_data.name

func get_energy_type() -> String:
    return get_top_card().card_data.pokemon_attr.energy_type

func get_remaining_hp() -> int:
    return max(0, get_top_card().card_data.pokemon_attr.hp - damage_counters)

func is_knocked_out() -> bool:
    return get_remaining_hp() <= 0
```

#### 4.2.4 CardInstance（卡牌实例）
```gdscript
class_name CardInstance

var instance_id: int          # 唯一实例ID
var card_data: CardData       # 引用卡牌静态数据
var owner_index: int          # 所属玩家
var face_up: bool = false     # 是否正面朝上
```

#### 4.2.5 CardData（卡牌静态数据）
```gdscript
class_name CardData extends Resource

@export var name: String
@export var card_type: String     # Pokemon/Item/Supporter/Tool/Stadium/Basic Energy/Special Energy
@export var mechanic: String      # ex/V/VSTAR/VMAX/Radiant/null
@export var description: String
@export var set_code: String
@export var card_index: String
@export var effect_id: String
@export var rarity: String
@export var regulation_mark: String
@export var is_tags: Array[String]

# 宝可梦专属属性
@export var pokemon_attr: PokemonAttribute  # null for non-pokemon

# 能量属性
@export var energy_provides: String  # 提供的能量类型（能量卡用）
```

### 4.3 规则引擎

#### 4.3.1 GameStateMachine（状态机）
```gdscript
class_name GameStateMachine

var game_state: GameState
var rule_validator: RuleValidator
var damage_calculator: DamageCalculator
var effect_processor: EffectProcessor
var action_log: Array[GameAction] = []

# 游戏流程控制
func start_game(deck_1: DeckData, deck_2: DeckData) -> void
func start_turn() -> void
func end_turn() -> void
func perform_pokemon_check() -> void
func check_win_condition() -> int  # -1=无, 0=P1胜, 1=P2胜

# 玩家操作
func draw_card(player: int) -> CardInstance
func attach_energy(player: int, energy: CardInstance, target: PokemonSlot) -> bool
func play_basic_pokemon(player: int, card: CardInstance, to_bench: bool) -> bool
func evolve_pokemon(player: int, evolution: CardInstance, target: PokemonSlot) -> bool
func play_trainer(player: int, card: CardInstance, targets: Array) -> bool
func use_ability(player: int, pokemon: PokemonSlot) -> bool
func retreat(player: int, energy_to_discard: Array[CardInstance]) -> bool
func use_attack(player: int, attack_index: int) -> void
func pass_turn(player: int) -> void
```

#### 4.3.2 RuleValidator（规则验证器）
```gdscript
class_name RuleValidator

func can_attach_energy(state: GameState, player: int) -> bool:
    return not state.energy_attached_this_turn

func can_play_supporter(state: GameState, player: int) -> bool:
    if state.supporter_used_this_turn:
        return false
    # 先攻首回合不可使用支援者
    if state.turn_number == 1 and player == state.first_player_index:
        return false
    return true

func can_evolve(state: GameState, pokemon: PokemonSlot, evolution: CardInstance) -> bool:
    # 首回合不可进化
    if state.turn_number <= 1:
        return false
    # 刚放上场不可进化
    if pokemon.turn_played == state.turn_number:
        return false
    # 本回合已进化不可继续进化
    if pokemon.turn_evolved == state.turn_number:
        return false
    # 进化链匹配检查
    var top_name = pokemon.get_name()
    var evolves_from = evolution.card_data.pokemon_attr.evolves_from
    return top_name == evolves_from

func can_retreat(state: GameState, player: int) -> bool:
    if state.retreat_used_this_turn:
        return false
    var active = state.players[player].active_pokemon
    if active == null:
        return false
    if active.status_conditions["asleep"] or active.status_conditions["paralyzed"]:
        return false
    if state.players[player].bench.is_empty():
        return false
    return true

func can_use_attack(state: GameState, player: int, attack_index: int) -> bool:
    # 先攻首回合不可攻击
    if state.turn_number == 1 and player == state.first_player_index:
        return false
    var active = state.players[player].active_pokemon
    if active == null:
        return false
    if active.status_conditions["asleep"] or active.status_conditions["paralyzed"]:
        return false
    var attack = active.get_top_card().card_data.pokemon_attr.attacks[attack_index]
    return has_enough_energy(active, attack.cost)

func has_enough_energy(pokemon: PokemonSlot, cost: String) -> bool:
    var required := {}
    for c in cost:
        required[c] = required.get(c, 0) + 1
    var available := {}
    for energy in pokemon.attached_energy:
        var e_type = energy.card_data.energy_provides
        available[e_type] = available.get(e_type, 0) + 1
    # 先满足指定属性，再用剩余满足无色
    var colorless_needed = required.get("C", 0)
    var total_remaining = 0
    for key in available:
        var used = required.get(key, 0)
        if available[key] < used:
            return false
        total_remaining += available[key] - used
    return total_remaining >= colorless_needed

func can_play_stadium(state: GameState, player: int, card: CardInstance) -> bool:
    if state.stadium_played_this_turn:
        return false
    # 不可使出同名竞技场
    if state.stadium_card != null and state.stadium_card.card_data.name == card.card_data.name:
        return false
    return true
```

#### 4.3.3 DamageCalculator（伤害计算器）
```gdscript
class_name DamageCalculator

func calculate_damage(
    attacker: PokemonSlot,
    defender: PokemonSlot,
    attack: AttackData,
    game_state: GameState
) -> int:
    # 1. 基础伤害
    var base_damage = parse_damage(attack.damage)
    if base_damage == 0 and attack.damage == "":
        return 0  # 无伤害招式

    # 2. 招式效果修正（如+30、×2等需由EffectProcessor处理）
    var attack_modifier = effect_processor.get_attack_damage_modifier(
        attacker, defender, attack, game_state
    )
    base_damage += attack_modifier

    # 3. 攻击方效果修正（道具、训练家效果等）
    var attacker_modifier = effect_processor.get_attacker_modifier(
        attacker, game_state
    )
    base_damage += attacker_modifier

    # 4. 弱点计算
    var weakness = defender.get_top_card().card_data.pokemon_attr.weakness
    if weakness != null and weakness.energy == attacker.get_energy_type():
        base_damage = apply_weakness(base_damage, weakness.value)

    # 5. 抗性计算
    var resistance = defender.get_top_card().card_data.pokemon_attr.resistance
    if resistance != null and resistance.energy == attacker.get_energy_type():
        base_damage = apply_resistance(base_damage, resistance.value)

    # 6. 防守方效果修正
    var defender_modifier = effect_processor.get_defender_modifier(
        defender, game_state
    )
    base_damage += defender_modifier

    return max(0, base_damage)

func apply_weakness(damage: int, value: String) -> int:
    if "×" in value:
        var multiplier = int(value.replace("×", ""))
        return damage * multiplier
    elif "+" in value:
        var addition = int(value.replace("+", ""))
        return damage + addition
    return damage

func apply_resistance(damage: int, value: String) -> int:
    if "-" in value:
        var reduction = int(value.replace("-", ""))
        return damage - reduction
    return damage

func parse_damage(damage_str: String) -> int:
    # 处理如 "30", "30+", "30×", "10×" 等格式
    var cleaned = damage_str.strip_edges()
    if cleaned == "":
        return 0
    cleaned = cleaned.replace("+", "").replace("×", "").replace("-", "")
    if cleaned.is_valid_int():
        return int(cleaned)
    return 0
```

#### 4.3.4 EffectProcessor（效果处理器）

这是整个引擎最复杂的部分，需要处理每张卡牌的独特效果。

```gdscript
class_name EffectProcessor

# 效果注册表 - 通过 effect_id 映射到具体效果实现
var effect_registry: Dictionary = {}

func _init():
    _register_all_effects()

# 注册所有已知卡牌效果
func _register_all_effects():
    # 每种效果通过 effect_id 注册
    # 相同 effectId 的卡牌共享同一效果实现
    pass

# 效果执行接口
func execute_card_effect(card: CardInstance, targets: Array, state: GameState) -> void:
    var effect_id = card.card_data.effect_id
    if effect_registry.has(effect_id):
        effect_registry[effect_id].execute(card, targets, state)

func execute_attack_effect(attacker: PokemonSlot, attack_index: int, state: GameState) -> void:
    pass

func execute_ability_effect(pokemon: PokemonSlot, state: GameState) -> void:
    pass

# 持续效果查询
func get_attack_damage_modifier(attacker, defender, attack, state) -> int:
    return 0

func get_attacker_modifier(attacker, state) -> int:
    return 0

func get_defender_modifier(defender, state) -> int:
    return 0
```

**效果脚本系统设计：**

为了支持每张卡牌的独特能力，采用脚本化效果系统：

```
res://effects/
  ├── base_effect.gd           # 效果基类
  ├── pokemon_effects/
  │   ├── effect_burn_stadium.gd  # 烧光（弃置竞技场）
  │   ├── effect_coin_flip_damage.gd  # 投币附加伤害
  │   ├── effect_bench_damage.gd    # 对备战区造成伤害
  │   ├── effect_discard_energy.gd  # 弃置能量
  │   ├── effect_draw_cards.gd      # 抽卡
  │   ├── effect_heal.gd            # 治疗
  │   ├── effect_status_poison.gd   # 中毒效果
  │   ├── effect_status_burn.gd     # 灼伤效果
  │   ├── effect_status_sleep.gd    # 睡眠效果
  │   ├── effect_status_paralyze.gd # 麻痹效果
  │   ├── effect_status_confuse.gd  # 混乱效果
  │   └── ...
  ├── trainer_effects/
  │   ├── effect_search_deck.gd     # 检索牌库
  │   ├── effect_draw_n.gd          # 抽N张
  │   ├── effect_switch_pokemon.gd  # 替换宝可梦
  │   └── ...
  ├── ability_effects/
  │   ├── effect_ability_draw.gd    # 抽卡特性
  │   ├── effect_ability_search.gd  # 检索特性
  │   └── ...
  └── energy_effects/
      └── effect_special_energy.gd  # 特殊能量效果
```

**效果基类：**
```gdscript
class_name BaseEffect extends RefCounted

# 效果需要的目标选择类型
enum TargetType {
    NONE,              # 无需选择
    OWN_POKEMON,       # 选己方宝可梦
    OPP_POKEMON,       # 选对方宝可梦
    ANY_POKEMON,       # 选任意宝可梦
    OWN_BENCH,         # 选己方备战宝可梦
    OPP_BENCH,         # 选对方备战宝可梦
    HAND_CARD,         # 选手牌
    DECK_CARD,         # 选牌库中的卡
    ENERGY_ON_POKEMON, # 选宝可梦上的能量
    COIN_FLIP,         # 需要投币
    PLAYER_CHOICE      # 玩家自由选择
}

func get_target_type() -> TargetType:
    return TargetType.NONE

func can_execute(card: CardInstance, state: GameState) -> bool:
    return true

func execute(card: CardInstance, targets: Array, state: GameState) -> void:
    pass

func get_description() -> String:
    return ""
```

**效果交互流程（当前实现约定）：**
```
BattleScene 点击训练家卡
  -> 读取 EffectProcessor 中注册的 BaseEffect
  -> 调用 get_interaction_steps(card, state)
  -> UI 顺序弹出牌库 / 手牌 / 弃牌区 / 备战区选择框
  -> 收集结果为 targets[0] = Dictionary
  -> GameStateMachine.play_trainer(player, card, targets)
  -> EffectProcessor.execute_card_effect(card, targets, state)
  -> 具体效果脚本按玩家选择执行
```

这套流程用于替代“自动选择第一张合法卡/第一个合法目标”的临时实现，优先覆盖球类、目标型支援者、回收/检索类训练家卡。

**效果解析引擎（用于自动解析卡牌文本生成效果）：**
```gdscript
class_name EffectParser

# 已知效果模式匹配
var patterns: Array[Dictionary] = [
    {"regex": "将场上的竞技场放于弃牌区", "effect": "burn_stadium"},
    {"regex": "从自己的牌库抽(\\d+)张", "effect": "draw_cards", "param": "count"},
    {"regex": "投掷1次硬币.*正面.*?(\\d+)", "effect": "coin_flip_damage"},
    {"regex": "选择对手的(\\d+)只.*?(\\d+)点伤害", "effect": "bench_snipe"},
    {"regex": "中毒", "effect": "apply_poison"},
    {"regex": "灼伤", "effect": "apply_burn"},
    {"regex": "睡眠", "effect": "apply_sleep"},
    {"regex": "麻痹", "effect": "apply_paralyze"},
    {"regex": "混乱", "effect": "apply_confuse"},
    {"regex": "治疗.*?(\\d+)点伤害", "effect": "heal"},
    # ... 更多模式
]

func parse_effect_text(text: String) -> Array[BaseEffect]:
    var effects: Array[BaseEffect] = []
    for pattern in patterns:
        var regex = RegEx.new()
        regex.compile(pattern.regex)
        var result = regex.search(text)
        if result:
            effects.append(create_effect(pattern.effect, result))
    return effects
```

### 4.4 投币系统
```gdscript
class_name CoinFlipper

signal coin_flipped(result: bool)  # true=正面, false=反面

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func flip() -> bool:
    rng.randomize()
    var result = rng.randi_range(0, 1) == 1
    coin_flipped.emit(result)
    return result

func flip_multiple(count: int) -> Array[bool]:
    var results: Array[bool] = []
    for i in count:
        results.append(flip())
    return results
```

### 4.5 动作日志系统
```gdscript
class_name GameAction

enum ActionType {
    DRAW_CARD,
    PLAY_POKEMON,
    EVOLVE,
    ATTACH_ENERGY,
    PLAY_TRAINER,
    USE_ABILITY,
    RETREAT,
    ATTACK,
    KNOCKOUT,
    TAKE_PRIZE,
    STATUS_APPLIED,
    STATUS_REMOVED,
    COIN_FLIP,
    POKEMON_CHECK,
    TURN_START,
    TURN_END,
    GAME_START,
    GAME_END
}

var action_type: ActionType
var player_index: int
var data: Dictionary  # 具体数据
var timestamp: int
```

---

## 5. AI 系统

### 5.1 AI 架构

```
┌──────────────────────────────┐
│        AIController          │
├──────────────────────────────┤
│  StrategyEvaluator           │ <- 局势评估
│  ActionGenerator             │ <- 合法操作生成
│  DecisionMaker               │ <- 决策引擎
│    ├── RuleBasedStrategy     │ <- 基于规则的策略
│    └── MCTSStrategy          │ <- 蒙特卡洛树搜索（进阶）
└──────────────────────────────┘
```

### 5.2 AI 决策流程
```
1. 生成所有合法操作列表
2. 评估当前局势分数
3. 对每个操作:
   a. 模拟执行
   b. 评估执行后局势分数
   c. 计算收益
4. 选择收益最高的操作
5. 重复直到选择结束回合/使用招式
```

### 5.3 局势评估函数
```gdscript
class_name StrategyEvaluator

func evaluate_state(state: GameState, player_index: int) -> float:
    var score: float = 0.0
    var me = state.players[player_index]
    var opp = state.players[1 - player_index]

    # 奖赏卡进度（已拿的奖赏卡数量）
    score += (6 - me.prizes.size()) * 100.0

    # 对手奖赏卡进度
    score -= (6 - opp.prizes.size()) * 100.0

    # 战斗宝可梦HP
    if me.active_pokemon:
        score += me.active_pokemon.get_remaining_hp() * 0.5
    if opp.active_pokemon:
        score -= opp.active_pokemon.get_remaining_hp() * 0.3

    # 备战区数量和质量
    score += me.bench.size() * 20.0
    score -= opp.bench.size() * 15.0

    # 手牌数量
    score += me.hand.size() * 5.0

    # 牌库剩余
    score += me.deck.size() * 1.0
    score -= (60 - opp.deck.size()) * 0.5

    # 能量附着
    for slot in [me.active_pokemon] + me.bench:
        if slot:
            score += slot.attached_energy.size() * 8.0

    # 进化完成度
    for slot in [me.active_pokemon] + me.bench:
        if slot:
            score += slot.pokemon_stack.size() * 15.0

    # 击杀威胁（能否一击击倒对手战斗宝可梦）
    if me.active_pokemon and opp.active_pokemon:
        for i in me.active_pokemon.get_top_card().card_data.pokemon_attr.attacks.size():
            var potential = _estimate_attack_damage(me.active_pokemon, opp.active_pokemon, i, state)
            if potential >= opp.active_pokemon.get_remaining_hp():
                score += 80.0
                break

    return score

func _estimate_attack_damage(attacker, defender, attack_index, state) -> int:
    # 简化版伤害估算
    var attack = attacker.get_top_card().card_data.pokemon_attr.attacks[attack_index]
    var damage = DamageCalculator.new().parse_damage(attack.damage)
    # 弱点
    var weakness = defender.get_top_card().card_data.pokemon_attr.weakness
    if weakness and weakness.energy == attacker.get_energy_type():
        damage *= 2
    return damage
```

### 5.4 AI 操作优先级
```
高优先级:
  1. 放置基础宝可梦到备战区（如果备战区空）
  2. 进化可以立即攻击的宝可梦
  3. 附着关键能量
  4. 使用支援者卡（抽卡/检索）
  5. 使用必要的物品卡

中优先级:
  6. 进化其他宝可梦
  7. 使用宝可梦道具
  8. 使用竞技场卡
  9. 放置更多基础宝可梦

低优先级:
  10. 多余的物品卡使用
  11. 撤退（仅在必要时）

最终动作:
  12. 使用招式攻击
  13. 结束回合
```

### 5.5 AI 难度等级
| 等级 | 策略 | 描述 |
|------|------|------|
| 简单 | 随机选择合法操作 | 新手练习用 |
| 普通 | 基于规则的优先级策略 | 按照固定优先级执行 |
| 困难 | 规则 + 局势评估 | 评估每步收益后选最优 |
| 专家 | MCTS + 深度评估 | 搜索多步后续并评估 |

---

## 6. 用户界面设计

### 6.1 场景结构
```
scenes/
  ├── main_menu/
  │   └── MainMenu.tscn          # 主菜单
  ├── deck_manager/
  │   ├── DeckManager.tscn       # 卡组管理主界面
  │   ├── DeckImport.tscn        # 卡组导入弹窗
  │   ├── DeckViewer.tscn        # 卡组详情查看
  │   └── CardDetail.tscn        # 单卡详情弹窗
  ├── battle_setup/
  │   └── BattleSetup.tscn       # 对战设置（选卡组、选模式）
  └── battle/
      ├── BattleScene.tscn       # 对战主场景
      ├── PlayerField.tscn       # 单方场地
      ├── PokemonSlotUI.tscn     # 宝可梦槽位UI
      ├── HandArea.tscn          # 手牌区域
      ├── CardUI.tscn            # 卡牌UI
      ├── DamageOverlay.tscn     # 伤害显示
      ├── CoinFlipDialog.tscn    # 投币动画
      ├── TargetSelector.tscn    # 目标选择器
      └── ActionLog.tscn         # 操作日志面板
```

### 6.2 主菜单
```
┌────────────────────────────┐
│                            │
│     PTCG Train             │
│     宝可梦卡牌练牌器        │
│                            │
│     [ 开始对战 ]           │
│     [ 卡组管理 ]           │
│     [ 设置    ]            │
│     [ 退出    ]            │
│                            │
└────────────────────────────┘
```

### 6.3 卡组管理界面
```
┌────────────────────────────────────────────┐
│  卡组管理                        [+导入]   │
├────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ 喷火龙ex │ │ 古来道场 │ │ 梦幻ex   │  │
│  │ 60张     │ │ 60张     │ │ 60张     │  │
│  │ [查看]   │ │ [查看]   │ │ [查看]   │  │
│  │ [删除]   │ │ [删除]   │ │ [删除]   │  │
│  └──────────┘ └──────────┘ └──────────┘  │
│                                            │
│  [返回主菜单]                              │
└────────────────────────────────────────────┘
```

### 6.4 对战设置界面
```
┌────────────────────────────────────────────┐
│  对战设置                                   │
├────────────────────────────────────────────┤
│                                            │
│  模式: (●)双人操控  (○)AI对战              │
│                                            │
│  玩家1卡组: [ 喷火龙ex     ▼ ]            │
│  玩家2卡组: [ 古来道场     ▼ ]            │
│                                            │
│  AI难度:   [ 普通         ▼ ]  (AI模式)   │
│                                            │
│  先攻选择: (●)随机  (○)玩家1  (○)玩家2    │
│                                            │
│         [ 开始对战 ]                       │
│         [ 返回 ]                           │
└────────────────────────────────────────────┘
```

### 6.5 对战主界面
```
┌──────────────────────────────────────────────────────────┐
│ [对手手牌: 7张]            [对手牌库: 47]  [对手弃牌: 0] │
│ ┌──────────────────────────────────────────────────────┐ │
│ │  [奖赏x6]  [备战1] [备战2] [备战3] [备战4] [备战5]  │ │
│ │            ┌─────────────┐                           │ │
│ │            │  对手战斗    │                           │ │
│ │            │  宝可梦      │                           │ │
│ │            └─────────────┘                           │ │
│ ├──────────────────[竞技场卡]───────────────────────────┤ │
│ │            ┌─────────────┐                           │ │
│ │            │  己方战斗    │                           │ │
│ │            │  宝可梦      │                           │ │
│ │            └─────────────┘                           │ │
│ │  [奖赏x6]  [备战1] [备战2] [备战3] [备战4] [备战5]  │ │
│ └──────────────────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────────────────┐ │
│ │  [手牌区域 - 可滚动]                                  │ │
│ └──────────────────────────────────────────────────────┘ │
│ [己方牌库: 47] [己方弃牌: 0] [招式] [撤退] [结束回合]   │
│                               [操作日志面板]              │
└──────────────────────────────────────────────────────────┘
```

### 6.6 宝可梦槽位详情（点击展开）
```
┌──────────────────────────┐
│  小火龙 HP: 70           │
│  [████████████] 70/70    │
│                          │
│  属性: 火  阶段: 基础    │
│  弱点: 水×2  抗性: 无    │
│  撤退: 1                 │
│                          │
│  能量: [火][火]          │
│  道具: 无                │
│  状态: 正常              │
│                          │
│  招式1: 烧光 [火]       │
│    将场上竞技场放弃牌区  │
│                          │
│  招式2: 吐火 [火][火]   │
│    30伤害                │
│                          │
│  [使用招式1] [使用招式2] │
└──────────────────────────┘
```

### 6.7 操作交互设计

| 操作 | 交互方式 |
|------|----------|
| 放置基础宝可梦 | 从手牌拖拽到备战区/战斗场 |
| 进化宝可梦 | 从手牌拖拽到对应宝可梦上 |
| 附着能量 | 从手牌拖拽能量到宝可梦上 |
| 使用训练家卡 | 双击手牌中的训练家卡 |
| 使用招式 | 点击战斗宝可梦 → 选择招式按钮 |
| 撤退 | 点击撤退按钮 → 选择弃置能量 → 选择替换宝可梦 |
| 使用特性 | 点击宝可梦 → 点击特性按钮 |
| 查看卡牌详情 | 右键点击/长按卡牌 |
| 查看弃牌区 | 点击弃牌区展开 |
| 查看牌库数量 | 鼠标悬停牌库区域 |
| 结束回合 | 点击"结束回合"按钮 |

---

## 7. 项目文件结构

```
ptcgtrain/
├── project.godot
├── design_document.md
├── assets/
│   ├── fonts/                    # 中文字体
│   ├── icons/                    # UI图标
│   │   ├── energy/               # 能量类型图标
│   │   │   ├── fire.png
│   │   │   ├── water.png
│   │   │   ├── grass.png
│   │   │   ├── lightning.png
│   │   │   ├── psychic.png
│   │   │   ├── fighting.png
│   │   │   ├── dark.png
│   │   │   ├── metal.png
│   │   │   ├── dragon.png
│   │   │   └── colorless.png
│   │   ├── status/               # 状态图标
│   │   │   ├── poisoned.png
│   │   │   ├── burned.png
│   │   │   ├── asleep.png
│   │   │   ├── paralyzed.png
│   │   │   └── confused.png
│   │   └── ui/                   # 通用UI图标
│   ├── textures/                 # 纹理素材
│   │   ├── card_back.png         # 卡背
│   │   ├── field_bg.png          # 场地背景
│   │   └── coin/                 # 投币动画帧
│   └── audio/                    # 音效（可选）
├── scenes/                       # 场景文件
│   ├── main_menu/
│   ├── deck_manager/
│   ├── battle_setup/
│   └── battle/
├── scripts/                      # 脚本文件
│   ├── autoload/                 # 自动加载
│   │   ├── GameManager.gd        # 全局游戏管理器
│   │   └── CardDatabase.gd       # 全局卡牌数据库
│   ├── data/                     # 数据模型
│   │   ├── CardData.gd
│   │   ├── DeckData.gd
│   │   ├── CardInstance.gd
│   │   ├── PokemonSlot.gd
│   │   ├── PlayerState.gd
│   │   └── GameState.gd
│   ├── engine/                   # 规则引擎
│   │   ├── GameStateMachine.gd
│   │   ├── RuleValidator.gd
│   │   ├── DamageCalculator.gd
│   │   ├── EffectProcessor.gd
│   │   ├── EffectParser.gd
│   │   ├── CoinFlipper.gd
│   │   └── GameAction.gd
│   ├── effects/                  # 效果脚本
│   │   ├── base_effect.gd
│   │   ├── pokemon_effects/
│   │   ├── trainer_effects/
│   │   ├── ability_effects/
│   │   └── energy_effects/
│   ├── ai/                       # AI系统
│   │   ├── AIController.gd
│   │   ├── ActionGenerator.gd
│   │   ├── StrategyEvaluator.gd
│   │   └── DecisionMaker.gd
│   ├── network/                  # 网络请求
│   │   └── DeckImporter.gd
│   └── ui/                       # UI控制脚本
│       ├── BattleUI.gd
│       ├── CardUI.gd
│       ├── HandArea.gd
│       ├── PokemonSlotUI.gd
│       └── ActionLogUI.gd
└── user_data/                    # 用户数据（运行时生成）
    ├── decks/                    # 卡组JSON
    ├── cards/                    # 卡牌缓存JSON
    └── settings.json             # 用户设置
```

---

## 8. 开发计划

### Phase 1: 基础架构 ✅ 已完成
- [x] Godot 项目初始化
- [x] 数据模型类实现 (CardData, DeckData, CardInstance, PokemonSlot, PlayerState, GameState)
- [x] 卡组导入模块 (DeckImporter + tcg.mik.moe API调用)
- [x] 本地卡牌数据库 (CardDatabase autoload，JSON持久化)
- [x] 卡组管理UI (DeckManager，自定义ImportPanel，支持进度显示)
- [x] 主菜单、对战设置界面占位
- [x] 测试框架 (TestRunner + TestBase)

### Phase 2: 规则引擎核心 ✅ 已完成
- [x] 游戏状态机 (GameStateMachine)：对战准备、回合流转、Mulligan、胜负判定
- [x] 规则验证器 (RuleValidator)：附能量、支援者、进化、撤退、攻击、先攻限制
- [x] 伤害计算器 (DamageCalculator)：弱点/抗性/修正/归零
- [x] 投币系统 (CoinFlipper)
- [x] 操作记录 (GameAction)
- [x] 效果处理器框架 (EffectProcessor + BaseEffect)
- [x] 特殊状态系统（中毒/灼伤/睡眠/麻痹/混乱，宝可梦检查）
- [x] 引擎核心单元测试 (test_rule_validator, test_damage_calculator, test_game_state_machine, test_coin_flipper)

### Phase 3: 对战UI — 最小可运行版本 ✅ 已完成
> 目标：能完整跑通一局对战，点击操作，无需拖拽和动画

- [x] BattleScene 重写：接入 GameStateMachine，管理对战生命周期
- [x] 对战准备流程UI：选战斗宝可梦、选备战区、Mulligan弹窗
- [x] PlayerField：双方场地布局（奖赏区/战斗场/备战区/弃牌区/牌库）
- [x] PokemonSlotUI：宝可梦槽位（名称/HP条/能量数/状态/可点击）
- [x] HandArea：手牌区域（卡牌列表，点击选择）
- [x] CardUI：卡牌显示（名称/类型/简要信息）
- [x] 操作面板：结束回合、撤退按钮，招式选择弹窗
- [x] 操作日志面板 (ActionLog)
- [x] 投币结果弹窗（文字显示，连接 CoinFlipper.coin_flipped 信号）
- [x] 视角切换（双人模式下换手提示）
- [x] 弃牌区查看弹窗（点击弃牌区数字展开查看）
- [x] 卡牌详情弹窗（右键点击手牌/场上宝可梦查看完整信息）

### Phase 4: 效果系统（当前阶段）
> 目标：实现足够多的卡牌效果让游戏真正可玩

- [x] 效果注册表增强（批量注册、招式附加效果注册、伤害修正查询）
- [x] 通用训练家效果：EffectDrawCards（抽卡/弃手抽牌）、EffectShuffleDrawCards（洗手抽牌/按奖赏抽牌）
- [x] 通用训练家效果：EffectSearchDeck（牌库检索）、EffectSwitchPokemon（替换宝可梦）、EffectHeal（治疗）
- [x] 招式附加效果：EffectDiscardEnergy（弃能量）、EffectApplyStatus（施加状态）、EffectCoinFlipDamage（投币伤害）
- [x] 招式附加效果：EffectSelfDamage（自伤）、EffectBenchDamage（备战区伤害）
- [x] 特性效果：AbilityDrawCard（抽卡特性）、AbilityDamageModifier（伤害修正特性）
- [x] 效果系统单元测试（30+项测试覆盖所有效果）
- [x] 特殊能量效果：EffectDoubleColorless、EffectSpecialEnergyModifier（攻击/撤退修正）、EffectSpecialEnergyOnAttach（附着触发）
- [x] 竞技场卡效果：EffectStadiumDraw、EffectStadiumDamageModifier、EffectStadiumRetreatModifier
- [x] 宝可梦道具效果：EffectToolDamageModifier、EffectToolRetreatModifier、EffectToolHPModifier
- [x] EffectProcessor 持续效果综合查询（攻击/防御/撤退/HP修正、能量提供量、特性禁用）
- [x] 效果覆盖率统计工具（EffectCoverageReport）
- [x] 持续效果单元测试（25+项测试覆盖竞技场/道具/特殊能量叠加）
- [ ] 具体卡牌 effect_id 与通用效果的映射注册

### Phase 5: 双人模式完善
- [ ] 视角切换确认弹窗（"请将设备交给对方"）
- [ ] 手牌隐藏/显示控制（切换视角时隐藏己方手牌）
- [ ] 完整双人对战流程测试

### Phase 6: AI系统
- [ ] 合法操作生成器 (ActionGenerator)
- [ ] 局势评估函数 (StrategyEvaluator)
- [ ] 基于规则的AI策略（按优先级执行操作）
- [ ] AI操作执行控制器 (AIController)
- [ ] AI难度等级（简单/普通/困难）

### Phase 7: 打磨优化
- [ ] 卡牌效果覆盖率提升
- [ ] UI动画与视觉反馈（拖拽、伤害数字飘出等）
- [ ] 音效集成（可选）
- [ ] Bug修复与平衡调整
- [ ] 性能优化

---

## 9. 关键技术点

### 9.1 卡牌效果的可扩展性
- 使用 effect_id 作为唯一标识，同效果卡牌共享实现
- 新卡牌可通过添加效果脚本支持，无需修改引擎核心
- 效果文本解析器可自动处理部分简单效果
- 复杂效果需手动编写脚本

### 9.2 对战重放与撤销
- GameAction 日志记录所有操作
- 可实现操作回退（练牌场景下有用）
- 可实现对战回放

### 9.3 双人模式隐私控制
- 切换玩家时自动隐藏手牌
- 奖赏卡始终反面
- 牌库始终反面
- 提供"切换视角"确认弹窗

### 9.4 性能考虑
- 卡牌图片按需加载，使用缓存
- 效果脚本预编译
- AI计算在后台线程（避免UI卡顿）

---

## 10. 附录

### 10.1 能量消耗编码说明
招式消耗字段 `cost` 使用能量类型缩写拼接：
- `"R"` = 1个火能量
- `"RR"` = 2个火能量
- `"RC"` = 1个火能量 + 1个任意能量
- `"RRCC"` = 2个火能量 + 2个任意能量
- `""` = 无消耗

### 10.2 卡牌标签说明 (is_tags)
| 标签 | 含义 |
|------|------|
| Basic | 基础宝可梦 |
| Stage 1 | 1阶进化 |
| Stage 2 | 2阶进化 |
| ex | 宝可梦ex |
| V | 宝可梦V |
| VSTAR | 宝可梦VSTAR |
| VMAX | 宝可梦VMAX |
| Radiant | 光辉宝可梦 |
| ACE SPEC | ACE SPEC卡 |
| Future | 未来标签 |
| Ancient | 古代标签 |

### 10.3 参考资料
- 官方规则: https://www.pokemon.cn/tcg-rules-howtoplay
- 卡组/卡牌数据: https://tcg.mik.moe
- 进阶规则PDF: https://image.pokemon.com.cn/wp-content/uploads/2025/11/tcg-pdf-basic_rules08.pdf
---

## 11. Interaction Flow Update
- Trainer-card interactions now use a generic flow: pre-check `can_execute`, gather `get_interaction_steps()`, then execute with `targets[0]` as a selection context dictionary.
- High-frequency search and gust cards should use this interaction flow instead of auto-selecting the first legal target.
- Multi-target energy distribution now uses a reusable `card_assignment` interaction mode in `BattleScene`, where players can repeatedly assign one source card to one target until they confirm.
- `烈炎支配` and `星星传送` should both use the same `card_assignment` mode instead of separate per-card UI logic.
- Dynamic Pokemon effect registration now happens during deck construction.
- Special Energy attach triggers and stadium enter-play triggers are expected to run immediately through `GameStateMachine`.

## 12. Automation Update
- A card-catalog audit runner now exists at `tests/CardCatalogAudit.gd`.
- Scope:
  - load every cached card from `user://cards/`
  - verify static/dynamic effect registration
  - run a generic smoke execution path for supported card types
  - emit a persistent report to `user://logs/card_audit_latest.txt`
- The normal `tests/TestRunner.tscn` suite now includes this audit, so one headless run covers both unit tests and broad card-effect smoke coverage.
