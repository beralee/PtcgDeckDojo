# 2026-03 Missing Card Batch Implementation Plan

## 1. Scope

This batch is based on the latest local card audit after re-importing decks.

Current audit gap:
- Registry failures: 37
- Smoke failures: 0
- Verification gaps: 37

Target:
- Implement every currently imported missing card
- Add semantic regression coverage for each new effect family
- Keep `BattleScene.gd` and test files free of encoding regressions


## 2. Missing Card Inventory

### 2.1 Trainer Cards

Items / Tools / Stadiums / Supporters:
- `CS5.5C_065` Roxanne / 杜娟
- `CS5DC_140` Cyllene / 星月
- `CS5bC_128` Temple of Sinnoh / 神奥神殿
- `CS6.5C_063` Trekking Shoes / 健行鞋
- `CSV5C_120` TM: Devolution / 招式学习器 退化
- `CSV5C_127` Mela / 梅洛可
- `CSV6C_121` Professor Sada's Vitality / 奥琳博士的气魄
- `CSV7C_201` Gravity Mountain / 重力山
- `CSV8C_173` Unfair Stamp / 不公印章
- `CSV8C_183` Night Stretcher / 夜间担架
- `CSV8C_186` Sparkling Crystal / 璀璨结晶
- `CSV8C_199` Carmine / 丹瑜
- `CSV8C_203` Jamming Tower / 阻碍之塔
- `CSV8C_207` Legacy Energy / 遗赠能量
- `CSVH1C_047` Pokemon Catcher / 宝可梦捕捉器
- `CSVH1aC_008` Energy Switch / 能量转移

### 2.2 Pokemon Abilities

- `CS5.5C_053` Hisuian Goodra VSTAR / 洗翠 黏美龙VSTAR
- `CS6.5C_055` Regidrago VSTAR / 雷吉铎拉戈VSTAR
- `CS6bC_028` Radiant Alakazam / 光辉胡地
- `CSV1C_079` Hawlucha / 摔角鹰人
- `CSV8C_028` Teal Mask Ogerpon ex / 厄诡椪 碧草面具ex
- `CSV8C_082` Dusclops / 彷徨夜灵
- `CSV8C_083` Dusknoir / 黑夜魔灵
- `CSV8C_121` Cornerstone Mask Ogerpon ex / 厄诡椪 础石面具ex
- `CSV8C_135` Fezandipiti ex / 吉雉鸡ex
- `CSV8C_158` Drakloak / 多龙奇
- `CSV8C_160` Tatsugiri / 米立龙
- `CSV8C_172` Bloodmoon Ursaluna ex / 月月熊 赫月ex

### 2.3 Pokemon Attacks

- `CS5.5C_032` Duskull / 夜巡灵
- `CS6.5C_054` Regidrago V / 雷吉铎拉戈V
- `CSNC_008` Origin Dialga V / 起源帝牙卢卡V
- `CSV6C_082` Slither Wing / 爬地翅
- `CSV7C_154` Raging Bolt ex / 猛雷鼓ex
- `CSV8C_067` Wellspring Mask Ogerpon ex / 厄诡椪 水井面具ex
- `CSV8C_081` Duskull / 夜巡灵
- `CSV8C_153` Haxorus / 双斧战龙
- `CSV8C_159` Dragapult ex / 多龙巴鲁托ex


## 3. Family Mapping

### 3.1 Reuse Existing Families

These should reuse or lightly extend existing effects:
- Roxanne: extend `EffectShuffleDrawCards`
- Trekking Shoes: extend `EffectLookTopCards`
- Mela: extend `AbilityAttachFromDeck` style selection plus draw
- Sada's Vitality: extend multi-attach from discard + draw
- Unfair Stamp: reuse shuffle-draw family with activation condition
- Night Stretcher: reuse recovery family with broader target filter
- Pokemon Catcher: reuse coin flip + gust family
- Energy Switch: reuse assignment UI and energy movement family
- Hisuian Goodra VSTAR: reuse VSTAR activated ability family
- Bloodmoon Ursaluna ex: reuse `AbilityReduceAttackCost`
- Dragapult ex: reuse bench damage counters family

### 3.2 New Generic Families Needed

These justify new reusable effect classes:
- `EffectCoinFlipDiscardToTop`: Cyllene
- `EffectTempleOfSinnoh`: global special-energy override
- `EffectTMDevolution`: tool-granted attack that devolves opposing Pokemon
- `EffectMela`: attach Fire from discard to one of your Pokemon, then draw
- `EffectSadasVitality`: attach up to 2 basic Energy from discard to Ancient Pokemon, then draw 3
- `EffectGravityMountain`: global Stage 2 attack-cost modifier
- `EffectJammingTower`: global tool-text suppression
- `EffectLegacyEnergy`: global extra-prize reduction once per game
- `AbilityMoveOpponentDamageCounters`: Radiant Alakazam
- `AbilityBenchDamageOnPlay`: Hawlucha
- `AbilityConditionalDrawFromActive`: Tatsugiri
- `AbilitySelfKnockoutDamageCounters`: Dusclops / Dusknoir family
- `AbilityOgerponTealDance`: attach Grass from hand to self, then draw
- `AbilityFezandipitiRefill`: recovery draw after own Pokemon was KO'd
- `AttackMillAndAttachAllEnergy`: Regidrago V
- `AttackAncientEnergyDiscardDamage`: Raging Bolt ex
- `AttackBenchCounterPlacement`: Dragapult ex
- `AttackToolOrItemLock`: Haxorus if raw text confirms lock family


## 4. Engine Changes Required

### 4.1 Tool-Granted Attacks

`TM: Devolution` cannot be modeled as a passive tool modifier.
Required work:
- add support for tool-granted attacks in `EffectProcessor`
- surface granted attacks in `BattleScene` action menu
- allow `GameStateMachine` to execute a granted attack with its own effect handler

This should be implemented generically, not only for one tool.

### 4.2 Global Continuous Overrides

Two new global rule layers are needed:
- `Temple of Sinnoh`: all Special Energy provide only one Colorless and lose other effects
- `Jamming Tower`: all Pokemon Tools lose their effects

These must hook into:
- energy type / colorless count queries
- tool modifier queries
- granted ability / granted attack queries
- damage / retreat / HP modification paths

### 4.3 Prize Modification

`Legacy Energy` needs a once-per-game prize reduction on knockout.
Required:
- add a dedicated per-player or per-card consumed marker
- integrate at knockout prize calculation time
- ensure it stacks safely with existing `extra_prize` markers without corruption


## 5. Test Strategy

### 5.1 Audit Gate

Do not weaken `CardCatalogAudit`.
Expected path:
1. Add implementations
2. Add semantic coverage
3. Let audit naturally go green

### 5.2 Semantic Matrix Additions

Add or extend tests for the following families:
- conditional supporter activation
- discard-to-top coin flip recovery
- global special-energy suppression
- global tool suppression
- discard-to-attach with draw
- ancient-targeted attachment
- bench damage-counter movement
- self-KO abilities with counter placement
- tool-granted attacks
- attack-cost reduction from opponent prize count
- prize reduction on knockout

### 5.3 Dedicated Regression Tests

Add focused tests when a family is risky:
- Temple of Sinnoh
- Jamming Tower
- Legacy Energy
- TM: Devolution
- Raging Bolt ex
- Dragapult ex
- Dusknoir line


## 6. Implementation Order

Order is chosen to maximize reuse and keep the suite runnable:

1. Supporters and simple Items
- Roxanne
- Cyllene
- Trekking Shoes
- Pokemon Catcher
- Energy Switch
- Night Stretcher
- Carmine

2. Continuous rule cards
- Temple of Sinnoh
- Gravity Mountain
- Jamming Tower
- Sparkling Crystal
- Legacy Energy

3. Simple ability / attack families
- Duskull confusion attack
- Hawlucha on-bench damage counters
- Radiant Alakazam damage-counter movement
- Bloodmoon Ursaluna ex attack-cost reduction
- Tatsugiri supporter search

4. Medium interaction cards
- Mela
- Sada's Vitality
- Regidrago V
- Regidrago VSTAR
- Origin Dialga V
- Slither Wing
- Raging Bolt ex

5. Ogerpon and Dusknoir batch
- Teal Mask Ogerpon ex
- Wellspring Mask Ogerpon ex
- Cornerstone Mask Ogerpon ex
- Duskull / Dusclops / Dusknoir
- Dragapult ex
- Haxorus
- Fezandipiti ex

6. Tool-granted attack
- TM: Devolution


## 7. UTF-8 and Source Safety

This batch must obey the current source safety red line:
- all new docs and scripts are UTF-8
- no mojibake copied from raw cache files into source
- no bulk replace on `BattleScene.gd` without immediate syntax check
- run headless suite after each family batch


## 8. Done Criteria

This batch is only done when:
- `TestRunner.tscn` passes
- `CardCatalogAudit` reports zero registry failures
- `CardCatalogAudit` reports zero verification gaps for imported scripted cards
- no source encoding audit failures remain


## 9. Completion Notes

Status as of 2026-03-15:
- `TestRunner.tscn`: green
- `CardCatalogAudit`: `Registry failures = 0`, `Smoke failures = 0`, `Interaction gaps = 0`, `Verification gaps = 0`
- Current imported cache baseline: `144` cached cards across `10` imported decks

Delivered rule layers from this batch:
- tool-granted attacks are supported end-to-end in `EffectProcessor`, `GameStateMachine`, and `BattleScene`
- stadium-based suppression now affects both special-energy behavior and tool-granted behavior
- prize reduction and HP override layers are resolved through the shared processor APIs
- multi-step attack interactions now reuse the same step-driven UI contract as trainer and ability effects

TDD notes:
- every new effect family in this batch has at least one semantic regression test
- the catalog audit remains the release gate and was not weakened to pass this batch
- `BattleScene.gd` changes were kept incremental to avoid encoding regressions
