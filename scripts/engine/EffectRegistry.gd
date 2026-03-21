## 效果注册表 - 将所有 effect_id（API 返回的 MD5 哈希）映射到对应的效果类实例
## 并向 EffectProcessor 完成注册。
## 训练家卡/道具/竞技场/特殊能量通过固定 effect_id 注册；
## 宝可梦卡通过特性名/招式名动态匹配注册。
class_name EffectRegistry
extends RefCounted

const AttackDefenderAttackLockNextTurnEffect = preload("res://scripts/effects/pokemon_effects/AttackDefenderAttackLockNextTurn.gd")
const EffectHisuianHeavyBallEffect = preload("res://scripts/effects/trainer_effects/EffectHisuianHeavyBall.gd")
const EffectRecoverBasicEnergyEffect = preload("res://scripts/effects/trainer_effects/EffectRecoverBasicEnergy.gd")
const EffectSearchBasicEnergyEffect = preload("res://scripts/effects/trainer_effects/EffectSearchBasicEnergy.gd")
const AbilityStarPortalEffect = preload("res://scripts/effects/pokemon_effects/AbilityStarPortal.gd")
const AbilityBonusDrawIfActiveEffect = preload("res://scripts/effects/pokemon_effects/AbilityBonusDrawIfActive.gd")
const AbilityAttachFromDeckEffect = preload("res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd")
const AttackSearchDeckToHandEffect = preload("res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd")
const AttackCoinFlipMultiplierEffect = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipMultiplier.gd")
const AttackDiscardBasicEnergyFromHandDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackDiscardBasicEnergyFromHandDamage.gd")
const AttackLookTopPickHandRestLostZoneEffect = preload("res://scripts/effects/pokemon_effects/AttackLookTopPickHandRestLostZone.gd")
const AttackSearchDeckToTopEffect = preload("res://scripts/effects/pokemon_effects/AttackSearchDeckToTop.gd")
const EffectRoxanneEffect = preload("res://scripts/effects/trainer_effects/EffectRoxanne.gd")
const EffectCylleneEffect = preload("res://scripts/effects/trainer_effects/EffectCyllene.gd")
const EffectTrekkingShoesEffect = preload("res://scripts/effects/trainer_effects/EffectTrekkingShoes.gd")
const EffectPokemonCatcherEffect = preload("res://scripts/effects/trainer_effects/EffectPokemonCatcher.gd")
const EffectEnergySwitchEffect = preload("res://scripts/effects/trainer_effects/EffectEnergySwitch.gd")
const EffectNightStretcherEffect = preload("res://scripts/effects/trainer_effects/EffectNightStretcher.gd")
const EffectUnfairStampEffect = preload("res://scripts/effects/trainer_effects/EffectUnfairStamp.gd")
const EffectCarmineEffect = preload("res://scripts/effects/trainer_effects/EffectCarmine.gd")
const AbilityMoveOpponentDamageCountersEffect = preload("res://scripts/effects/pokemon_effects/AbilityMoveOpponentDamageCounters.gd")
const AbilityBenchDamageOnPlayEffect = preload("res://scripts/effects/pokemon_effects/AbilityBenchDamageOnPlay.gd")
const AbilityPrizeCountColorlessReductionEffect = preload("res://scripts/effects/pokemon_effects/AbilityPrizeCountColorlessReduction.gd")
const AttackCoinFlipApplyStatusEffect = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipApplyStatus.gd")
const AbilitySelfHealVSTAREffect = preload("res://scripts/effects/pokemon_effects/AbilitySelfHealVSTAR.gd")
const AbilityMillDeckRecoverToHandEffect = preload("res://scripts/effects/pokemon_effects/AbilityMillDeckRecoverToHand.gd")
const AttackMillAndAttachAllEnergyEffect = preload("res://scripts/effects/pokemon_effects/AttackMillAndAttachAllEnergy.gd")
const AttackOpponentHandCountDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackOpponentHandCountDamage.gd")
const AttackAttachBasicEnergyFromDiscardEffect = preload("res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromDiscard.gd")
const AttackMillOpponentDeckEffect = preload("res://scripts/effects/pokemon_effects/AttackMillOpponentDeck.gd")
const AttackDiscardHandDrawCardsEffect = preload("res://scripts/effects/pokemon_effects/AttackDiscardHandDrawCards.gd")
const AttackDiscardBasicEnergyFromFieldDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackDiscardBasicEnergyFromFieldDamage.gd")
const AbilityAttachBasicEnergyFromHandDrawEffect = preload("res://scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandDraw.gd")
const AbilityLookTopToHandEffect = preload("res://scripts/effects/pokemon_effects/AbilityLookTopToHand.gd")
const AbilityDrawIfKnockoutLastTurnEffect = preload("res://scripts/effects/pokemon_effects/AbilityDrawIfKnockoutLastTurn.gd")
const AttackReviveFromDiscardToBenchEffect = preload("res://scripts/effects/pokemon_effects/AttackReviveFromDiscardToBench.gd")
const AbilitySelfKnockoutDamageCountersEffect = preload("res://scripts/effects/pokemon_effects/AbilitySelfKnockoutDamageCounters.gd")
const AttackReduceDamageNextTurnEffect = preload("res://scripts/effects/pokemon_effects/AttackReduceDamageNextTurn.gd")
const AttackActiveEnergyCountDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackActiveEnergyCountDamage.gd")
const AttackAnyTargetDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackAnyTargetDamage.gd")
const AttackKODefenderIfHasSpecialEnergyEffect = preload("res://scripts/effects/pokemon_effects/AttackKODefenderIfHasSpecialEnergy.gd")
const AttackMillSelfDeckEffect = preload("res://scripts/effects/pokemon_effects/AttackMillSelfDeck.gd")
const EffectTempleOfSinnohEffect = preload("res://scripts/effects/stadium_effects/EffectTempleOfSinnoh.gd")
const EffectGravityMountainEffect = preload("res://scripts/effects/stadium_effects/EffectGravityMountain.gd")
const EffectJammingTowerEffect = preload("res://scripts/effects/stadium_effects/EffectJammingTower.gd")
const EffectSparklingCrystalEffect = preload("res://scripts/effects/tool_effects/EffectSparklingCrystal.gd")
const EffectLegacyEnergyEffect = preload("res://scripts/effects/energy_effects/EffectLegacyEnergy.gd")
const EffectMelaEffect = preload("res://scripts/effects/trainer_effects/EffectMela.gd")
const EffectSadasVitalityEffect = preload("res://scripts/effects/trainer_effects/EffectSadasVitality.gd")
const AttackDefenderRetreatLockNextTurnEffect = preload("res://scripts/effects/pokemon_effects/AttackDefenderRetreatLockNextTurn.gd")
const AttackReturnEnergyThenBenchDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackReturnEnergyThenBenchDamage.gd")
const AbilityPreventDamageFromAttackersWithAbilitiesEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromAttackersWithAbilities.gd")
const AttackDistributedBenchCountersEffect = preload("res://scripts/effects/pokemon_effects/AttackDistributedBenchCounters.gd")
const AttackUseDiscardDragonAttackEffect = preload("res://scripts/effects/pokemon_effects/AttackUseDiscardDragonAttack.gd")
const AttackIgnoreWeaknessResistanceAndEffectsEffect = preload("res://scripts/effects/pokemon_effects/AttackIgnoreWeaknessResistanceAndEffects.gd")
const EffectTMDevolutionEffect = preload("res://scripts/effects/trainer_effects/EffectTMDevolution.gd")
const AbilityDiscardDrawAnyEffect = preload("res://scripts/effects/pokemon_effects/AbilityDiscardDrawAny.gd")
const AbilityPsychicEmbraceEffect = preload("res://scripts/effects/pokemon_effects/AbilityPsychicEmbrace.gd")
const AttackClearOwnStatusEffect = preload("res://scripts/effects/pokemon_effects/AttackClearOwnStatus.gd")
const AbilityMoveDamageCountersToOpponentEffect = preload("res://scripts/effects/pokemon_effects/AbilityMoveDamageCountersToOpponent.gd")
const AttackSelfDamageCounterTargetDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterTargetDamage.gd")
const AttackSelfDamageCounterMultiplierEffect = preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterMultiplier.gd")
const AttackSwitchSelfToBenchEffect = preload("res://scripts/effects/pokemon_effects/AttackSwitchSelfToBench.gd")
const AbilityBasicLockEffect = preload("res://scripts/effects/pokemon_effects/AbilityBasicLock.gd")
const AttackDiscardDefenderToolEffect = preload("res://scripts/effects/pokemon_effects/AttackDiscardDefenderTool.gd")
const EffectSecretBoxEffect = preload("res://scripts/effects/trainer_effects/EffectSecretBox.gd")
const EffectArtazonEffect = preload("res://scripts/effects/stadium_effects/EffectArtazon.gd")
const AttackTMEvolutionEffect = preload("res://scripts/effects/pokemon_effects/AttackTMEvolution.gd")


## ==================== 主入口 ====================

## 注册所有已知卡牌效果到 EffectProcessor
## 包含：物品卡、支援者卡、道具、竞技场、特殊能量
static func register_all(processor: EffectProcessor) -> void:
	_register_items(processor)
	_register_supporters(processor)
	_register_tools(processor)
	_register_stadiums(processor)
	_register_special_energies(processor)


## 根据宝可梦卡牌数据注册其特性效果和招式附加效果
## 通过特性名称和招式名称进行匹配，无需硬编码 effect_id
static func register_pokemon_card(processor: EffectProcessor, card: CardData) -> void:
	var eid: String = card.effect_id
	if eid == "":
		return

	# 注册特性效果
	for ability: Dictionary in card.abilities:
		var ability_name: String = ability.get("name", "")
		if ability_name == "":
			continue
		var ability_effect: BaseEffect = _get_ability_effect(ability_name)
		if ability_effect != null:
			processor.register_effect(eid, ability_effect)

	# 注册招式附加效果
	for attack: Dictionary in card.attacks:
		var attack_name: String = attack.get("name", "")
		if attack_name == "":
			continue
		var attack_effects: Array = _get_attack_effects(attack_name)
		for fx: BaseEffect in attack_effects:
			processor.register_attack_effect(eid, fx)

	_register_pokemon_effect_overrides(processor, eid)


static func _register_pokemon_effect_overrides(processor: EffectProcessor, effect_id: String) -> void:
	match effect_id:
		"9d268c8f6262a80a57c6e645d7c9a18f":
			processor.register_attack_effect(effect_id, EffectSelfDamage.new(10))
		"47676dfc37415cfdf3b3992b1de64141":
			processor.register_attack_effect(effect_id, AttackDefenderAttackLockNextTurnEffect.new("evolved_only"))
		"720fd5ca597f96db0f5f00d3ac16febb":
			processor.register_effect(effect_id, AbilityStarPortalEffect.new())
			processor.register_attack_effect(effect_id, AttackBenchCountDamage.new(20, "both"))
		"63cf95979c653e65cbd502a4c0d3fbdd":
			processor.register_attack_effect(effect_id, AttackSearchDeckToHandEffect.new(1, "Stadium"))
			processor.register_attack_effect(effect_id, AttackSelfLockNextTurn.new())
		"8bcc42363d38245b8b408cfaafa1ba30":
			processor.register_attack_effect(effect_id, AttackCoinFlipMultiplierEffect.new(20))
		"07f01f4f21033a1bbc058e4af555420a":
			processor.register_effect(effect_id, AbilityBonusDrawIfActiveEffect.new())
			processor.register_attack_effect(effect_id, AttackDiscardBasicEnergyFromHandDamageEffect.new(50))
		"74b83ef8987d072950dfe3bde3364d87":
			processor.register_effect(effect_id, AbilityBenchDamageOnPlayEffect.new(10, 2))
		"f2afef80b13b8f6a071facbcade0251c":
			processor.register_effect(effect_id, AbilityPrizeCountColorlessReductionEffect.new("Blood Moon"))
			processor.register_attack_effect(effect_id, AttackSelfLockNextTurn.new())
		"8c23889e3e58324f3d58029f72379fac":
			processor.register_attack_effect(effect_id, AttackCoinFlipApplyStatusEffect.new("confused"))
		"c3ada06b5a60fb63228d9f704109718b":
			processor.register_effect(effect_id, AbilitySelfHealVSTAREffect.new())
			processor.register_attack_effect(effect_id, AttackReduceDamageNextTurnEffect.new(80))
		"90c9e117fa846938024ae15eb859f1b6":
			processor.register_attack_effect(effect_id, AttackMillAndAttachAllEnergyEffect.new(3, 0))
			processor.register_attack_effect(effect_id, AttackBenchSnipe.new(30, 1, 0, 1))
		"749d2f12d33057c8cc20e52c1b11bcbf":
			processor.register_effect(effect_id, AbilityMillDeckRecoverToHandEffect.new(7, 2, true))
			processor.register_attack_effect(effect_id, AttackUseDiscardDragonAttackEffect.new(processor))
		"68244d82147e13bb7d77116ffedf6162":
			processor.register_effect(effect_id, AbilityMoveOpponentDamageCountersEffect.new())
			processor.register_attack_effect(effect_id, AttackOpponentHandCountDamageEffect.new(20))
		"5fbf2a43fe0f6df85dd1b7eb420ac678":
			processor.register_attack_effect(effect_id, AttackAttachBasicEnergyFromDiscardEffect.new("M", 2))
		"29f94ee004e4c312dbea4a7930d33544":
			processor.register_attack_effect(effect_id, AttackMillOpponentDeckEffect.new(1, 0))
			processor.register_attack_effect(effect_id, EffectSelfDamage.new(90, 1))
			processor.register_attack_effect(effect_id, EffectApplyStatus.new("burned", false, 1))
		"e96bb407c5f18bb9eec55487e70395fd":
			processor.register_attack_effect(effect_id, AttackDiscardHandDrawCardsEffect.new(6, 0))
			processor.register_attack_effect(effect_id, AttackDiscardBasicEnergyFromFieldDamageEffect.new(70, 1))
		"4e13cd08de3b6d141ce8e2f09d17a3a4":
			processor.register_effect(effect_id, AbilityLookTopToHandEffect.new(2, "", false, false, true))
		"1ceeba6dac51ccc19833c5a513fe3fc6":
			processor.register_effect(effect_id, AbilityLookTopToHandEffect.new(6, "Supporter", true, true, false))
		"ab6c3357e2b8a8385a68da738f41e0c1":
			processor.register_effect(effect_id, AbilityDrawIfKnockoutLastTurnEffect.new(3, "fezandipiti"))
			processor.register_attack_effect(effect_id, AttackAnyTargetDamageEffect.new(100))
		"ce6db179c3d166130e7a637581da3aa2":
			# 渡魂：从弃牌区选择最多3张「夜巡灵」放到备战区
			processor.register_attack_effect(effect_id, AttackReviveFromDiscardToBenchEffect.new(3, "夜巡灵"))
		"ad031124df2ede62f945220fbbd680b3":
			processor.register_effect(effect_id, AbilitySelfKnockoutDamageCountersEffect.new(5))
		"2a4178f21ba2bf13285bbb43ecaaa472":
			processor.register_effect(effect_id, AbilitySelfKnockoutDamageCountersEffect.new(13))
			processor.register_attack_effect(effect_id, AttackDefenderRetreatLockNextTurnEffect.new(0))
		"14cf8080c35f652fe13a579f1b50542a":
			processor.register_attack_effect(effect_id, AttackDefenderRetreatLockNextTurnEffect.new(0))
			processor.register_attack_effect(effect_id, AttackReturnEnergyThenBenchDamageEffect.new(120, 1))
		"4f25f668ee0ab45c68f6954324c73003":
			processor.register_effect(effect_id, AbilityPreventDamageFromAttackersWithAbilitiesEffect.new())
			processor.register_attack_effect(effect_id, AttackIgnoreWeaknessResistanceAndEffectsEffect.new(0))
		"52a205820de799a53a689f23cbeb8622":
			processor.register_attack_effect(effect_id, AttackDistributedBenchCountersEffect.new(60, 1))
		"e45788bd7d9ffec5b3da3730d2dc806f":
			processor.register_attack_effect(effect_id, AttackKODefenderIfHasSpecialEnergyEffect.new(0))
			processor.register_attack_effect(effect_id, AttackMillSelfDeckEffect.new(3, 1))
		"409898a79b38fe8ca279e7bdaf4fd52e":
			processor.register_effect(effect_id, AbilityAttachBasicEnergyFromHandDrawEffect.new("G", 1))
			processor.register_attack_effect(effect_id, AttackActiveEnergyCountDamageEffect.new(30))


## ==================== 物品卡注册（register_effect）====================

static func _register_items(processor: EffectProcessor) -> void:
	# 反击捕捉器
	processor.register_effect("06bc00d5dcec33898dc6db2e4c4d10ec", EffectCounterCatcher.new())
	# 巢穴球
	processor.register_effect("1af63a7e2cb7a79215474ad8db8fd8fd", EffectNestBall.new())
	# 清除古龙水
	processor.register_effect("66b2f1d77328b6578b1bf0d58d98f66b", EffectCancelCologne.new())
	# 放逐吸尘器
	processor.register_effect("8f655fea1f90164bfbccb7a95c223e17", EffectLostVacuum.new())
	# 高级球
	processor.register_effect("a337ed34a45e63c6d21d98c3d8e0cb6e", EffectUltraBall.new())
	# 朋友手册
	processor.register_effect("a47d5a8ed00e14a2146fc511745d23b5", EffectPalPad.new())
	# 厉害钓竿
	processor.register_effect("c9c948169525fbb3dce70c477ec7a90a", EffectSuperRod.new())
	# 神奇糖果
	processor.register_effect("d3891abcfe3277c8811cde06741d3236", EffectRareCandy.new())
	# 友好宝芬
	processor.register_effect("f866dfee26cd6b0dbbb52b74438d0a59", EffectBuddyPoffin.new())
	# 宝可装置3.0：查看顶部7张，选1张支援者加入手牌
	processor.register_effect("768b545a38fccd5e265093b5adce10af", EffectLookTopCards.new(7, "Supporter"))
	# 超级球：查看顶部7张，选1张宝可梦加入手牌
	processor.register_effect("1838e8afe529b519a57dd8bbd307905a", EffectLookTopCards.new(7, "Pokemon"))
	# 捕获香氛
	processor.register_effect("7cd68d9e286b78a7f9c799fce24a7d6c", EffectCapturingAroma.new())
	# 宝可梦交替：切换己方战斗宝可梦
	processor.register_effect("7c0b20e121c9d0e0d2d8a43524f7494e", EffectSwitchPokemon.new("self"))
	# 顶尖捕捉器
	processor.register_effect("4ec261453212280d0eb03ed8254ca97f", EffectPrimeCatcher.new())
	# 大师球：搜索牌库任意1只宝可梦
	processor.register_effect("30e7c440d69817592656f5b44e444111", EffectSearchDeck.new(1, 0, "Pokemon"))
	# 电气发生器
	processor.register_effect("2234845fbc2e11ab95587e1b393bb318", EffectElectricGenerator.new())
	# 高科技雷达
	processor.register_effect("8b0d4f541f256d67f0757efe4fc8b407", EffectTechnoRadar.new())
	# 交替推车
	processor.register_effect("8342fe3eeec6f897f3271be1aa26a412", EffectSwitchCart.new())
	# Hisuian Heavy Ball
	processor.register_effect("2f68195255c863293be4fad262bf23d2", EffectHisuianHeavyBallEffect.new())
	# Superior Energy Retrieval
	processor.register_effect("ff7e5670880217816bcf5d34388624cd", EffectRecoverBasicEnergyEffect.new(4, 2))
	# Earthen Vessel
	processor.register_effect("e366f56ecd3f805a28294109a1a37453", EffectSearchBasicEnergyEffect.new(2, 1))
	# Energy Retrieval
	processor.register_effect("8538726d6cdfad2fa3ca5f4b462c12c5", EffectRecoverBasicEnergyEffect.new(2, 0))
	# Trekking Shoes
	processor.register_effect("70d14b4a5a9c15581b8a0c8dfd325717", EffectTrekkingShoesEffect.new())
	# TM: Devolution
	processor.register_effect("e228e825c541ce80e2507c557cb506c3", EffectTMDevolutionEffect.new())
	# 秘密箱
	processor.register_effect("e92a86246f44351d023bd4fa271089aa", EffectSecretBoxEffect.new())
	# Unfair Stamp
	processor.register_effect("d324e01179ab048ed023bf4a20bf658d", EffectUnfairStampEffect.new())
	# Night Stretcher
	processor.register_effect("3e6f1daf545dfed48d0588dd50792a2e", EffectNightStretcherEffect.new())
	# Pokemon Catcher
	processor.register_effect("3a6d419769778b40091e69fbd76737ec", EffectPokemonCatcherEffect.new())
	# Energy Switch
	processor.register_effect("294212d9c02dc0acb886a7ef01ebeac4", EffectEnergySwitchEffect.new())


## ==================== 支援者卡注册（register_effect）====================

static func _register_supporters(processor: EffectProcessor) -> void:
	# 派帕
	processor.register_effect("5bdbc985f9aa2e6f248b53f6f35d1d37", EffectArven.new())
	# 弗图博士的剧本
	processor.register_effect("73d5f46ecf3a6d71b23ce7bc1a28d4f4", EffectProfTuro.new())
	# 老大的指令
	processor.register_effect("8e1fa2c9018db938084c94c7c970d419", EffectBossOrders.new())
	# 奇树
	processor.register_effect("af514f82d182aeae5327b2c360df703d", EffectIono.new())
	# 博士的研究：弃掉手牌，摸7张
	processor.register_effect("aecd80ca2722885c3d062a2255346f3e", EffectDrawCards.new(7, true))
	# 裁判：双方将手牌洗入牌库，各摸4张
	processor.register_effect("0a9bdf265647461dd5c6c827ffc19e61", EffectShuffleDrawCards.new(4, false, true))
	# 暗码迷的解读
	processor.register_effect("1b5fc2ed2bce98ef93457881c05354e2", EffectCiphermaniac.new())
	# 捩木
	processor.register_effect("05b9dc8ee5c16c46da20f47a04907856", EffectThorton.new())
	# 莎莉娜
	processor.register_effect("d83b170c43c0ade1f81c817c4488d5db", EffectSerena.new())
	# 吉尼亚
	processor.register_effect("a8a2b27c2641d8d7212fc887ca032e4c", EffectJacq.new())
	# 珠贝
	processor.register_effect("4f53ab6bf158fd1a8869ae037f4a0d6d", EffectIrida.new())
	# Roxanne
	processor.register_effect("889c893f76d8be0261cd53daad5e3c11", EffectRoxanneEffect.new())
	# Cyllene
	processor.register_effect("e5c317e428f0cfd885b53d4d058b5d5b", EffectCylleneEffect.new())
	# Mela
	processor.register_effect("f9162d9c9d98c74523257f17dcb6053b", EffectMelaEffect.new())
	# Professor Sada's Vitality
	processor.register_effect("651276c51911345aa091c1c7b87f3f4f", EffectSadasVitalityEffect.new())
	# Carmine
	processor.register_effect("8150af4062192998497e376ad931bea4", EffectCarmineEffect.new())


## ==================== 道具卡注册（register_effect）====================

static func _register_tools(processor: EffectProcessor) -> void:
	# 极限腰带：对ex伤害+50
	processor.register_effect("2e07a9870350b611a3d21ab2053dfa2a", EffectToolConditionalDamage.new(50, "ex"))
	# 森林封印石（VSTAR特技：搜索牌库任意2张卡）
	processor.register_effect("9fa9943ccda36f417ac3cb675177c216", AbilityVSTARSearch.new())
	# 不服输头带：对奖励牌数多的对手伤害+30
	processor.register_effect("e242d711feffd98f3fbb5c511d00d667", EffectToolConditionalDamage.new(30, "prize_behind"))
	# 讲究腰带：对V宝可梦伤害+30
	processor.register_effect("36939b241f51e497487feb52e0ea8994", EffectToolConditionalDamage.new(30, "V"))
	# 勇气护符：HP+50，不禁用特性
	processor.register_effect("d1c2f018a644e662f2b6895fdfc29281", EffectToolHPModifier.new(50, false))
	# 驱劲能量 未来（道具：给未来宝可梦的招式增益）
	processor.register_effect("54920a273edba38ce45f3bc8f6e8ff25", EffectToolFutureBoost.new())
	# 沉重接力棒
	processor.register_effect("770c741043025f241dbd81422cb8987d", EffectToolHeavyBaton.new())
	# 紧急滑板
	processor.register_effect("0b4cc131a19862f92acf71494f29a0ed", EffectToolRescueBoard.new())
	# Sparkling Crystal
	processor.register_effect("12164ed03296d2df4ef6d0fa8b5f8aae", EffectSparklingCrystalEffect.new())
	# 招式学习器 进化
	processor.register_effect("43386015be5c073ba2e5b9d3692ece3f", AttackTMEvolutionEffect.new(2))


## ==================== 竞技场卡注册（register_effect）====================

static func _register_stadiums(processor: EffectProcessor) -> void:
	# 崩塌的竞技场
	processor.register_effect("fb3628071280487676f79281696ffbd9", EffectCollapsedStadium.new())
	# 放逐市
	processor.register_effect("7f4e493ec0d852a5bb31c02bdbdb2c4e", EffectLostCity.new())
	# 城镇百货
	processor.register_effect("13b3caaa408a85dfd1e2a5ad797e8b8a", EffectTownStore.new())
	# Full Metal Lab
	processor.register_effect("59e1e1faa3ceb8c3ae801979a499532e", EffectStadiumDamageModifier.new(-30, "defense", "M"))
	# Temple of Sinnoh
	processor.register_effect("53864b068a4a1e8dce3c53c884b67efa", EffectTempleOfSinnohEffect.new())
	# Gravity Mountain
	processor.register_effect("aee486132c2ba880232a477fe0fe7a03", EffectGravityMountainEffect.new())
	# Jamming Tower
	processor.register_effect("4e16157bfa88a41e823d058a732df8e0", EffectJammingTowerEffect.new())
	# 深钵镇
	processor.register_effect("c117bea3cc758d46430d6bef11062a56", EffectArtazonEffect.new())


## ==================== 特殊能量注册（register_effect）====================

static func _register_special_energies(processor: EffectProcessor) -> void:
	# 双重涡轮能量：提供2个无色能量，伤害-20
	processor.register_effect("9c04dd0addf56a7b2c88476bc8e45c0e", EffectSpecialEnergyModifier.new(-20, 0, "C", 2))
	# 喷射能量
	processor.register_effect("1323733f19cc04e54090b39bc1a393b8", EffectJetEnergy.new())
	# 治疗能量
	processor.register_effect("2c65697c2aceac4e6a1f85f810fa386f", EffectTherapeuticEnergy.new())
	# V防守能量
	processor.register_effect("88bf9902f1d769a667bbd3939fc757de", EffectVGuardEnergy.new())
	# 馈赠能量
	processor.register_effect("dbb3f3d2ef2f3372bc8b21336e6c9bc6", EffectGiftEnergy.new())
	# 薄雾能量
	processor.register_effect("fb0948c721db1f31767aa6cf0c2ea692", EffectMistEnergy.new())
	# Legacy Energy
	processor.register_effect("6f31b7241a181631016466e561f148f3", EffectLegacyEnergyEffect.new())


## ==================== 特性名称 → 效果实例映射 ====================

## 根据特性名称返回对应的效果实例，未知特性返回 null
static func _get_ability_effect(ability_name: String) -> BaseEffect:
	match ability_name:
		"浪花水帘":
			return AbilityBenchProtect.new()
		"再起动":
			return AbilityDrawToN.new(3)
		"勤奋门牙":
			return AbilityDrawToN.new(5)
		"音速搜索":
			return AbilitySearchAny.new(1, false)
		"星耀诞生":
			# VSTAR 特技：搜索牌库最多2张任意卡
			return AbilitySearchAny.new(2, true)
		"烈炎支配":
			# 进化时可从牌库附加最多3个火能量
			return AbilityAttachFromDeckEffect.new("R", 3, "own", true, false)
		"原始涡轮":
			# 每回合一次：从牌库附加1张特殊能量
			return AbilityAttachFromDeckEffect.new("Special Energy", 2, "own_one", false, true)
		"夜光信号":
			# 进入备战区时：搜索支援者卡加入手牌
			return AbilityOnBenchEnter.new("search_supporter")
		"快速游标":
			# 进入备战区时：切换己方战斗宝可梦
			return AbilityOnBenchEnter.new("rush_in")
		"快速充电":
			# 回合结束时摸3张
			return AbilityEndTurnDraw.new(3)
		"隐藏牌":
			# 丢弃手牌换取摸牌
			return AbilityDiscardDraw.new()
		"英武重抽":
			# 先手第一回合额外摸牌
			return AbilityFirstTurnDraw.new()
		"巢穴藏身":
			# 将手牌洗入牌库后摸牌
			return AbilityShuffleHandDraw.new()
		"串联装置":
			# 搜索最多2只闪电系基础宝可梦放到备战区
			return AbilitySearchPokemonToBench.new("L", 2)
		"金属制造者":
			return AbilityMetalMaker.new()
		"星耀汇聚":
			# VSTAR 特技：特殊召唤
			return AbilityVSTARSummon.new()
		"毫不在意":
			# 备战区宝可梦免疫对方效果
			return AbilityBenchImmune.new()
		"闪焰之幕":
			# 忽略对方效果
			return AbilityIgnoreEffects.new()
		"无畏脂肪":
			# 忽略对方效果
			return AbilityIgnoreEffects.new()
		"强力吹风机":
			# 将对方备战区宝可梦调至战斗位
			return AbilityGustFromBench.new()
		"蔚蓝指令":
			# 未来宝可梦伤害提升
			return AbilityFutureDamageBoost.new()
		"暗夜振翼":
			# 禁用对方特性
			return AbilityDisableOpponentAbility.new()
		"电气象征":
			# 闪电属性伤害加成
			return AbilityLightningBoost.new()
		"慈爱帘幕":
			# 降低V宝可梦受到的伤害
			return AbilityVReduceDamage.new()
		"振奋之心":
			# 降低招式能量费用
			return AbilityReduceAttackCost.new()
		"金属之盾":
			# 满足条件时减伤
			return AbilityConditionalDefense.new()
		"瞬步":
			# 迅雷充电
			return AbilityThunderousCharge.new()
		"精炼":
			# 奇鲁莉安：弃1张任意手牌，抽2张
			return AbilityDiscardDrawAnyEffect.new(2)
		"精神拥抱":
			# 沙奈朵ex：从弃牌区附着超能量+放置2个伤害指示物
			return AbilityPsychicEmbraceEffect.new()
		"亢奋脑力":
			# 愿增猿：转移己方宝可梦伤害指示物到对手
			return AbilityMoveDamageCountersToOpponentEffect.new(3)
		"恶作剧之锁":
			# 钥圈儿：双方基础宝可梦特性无效化
			return AbilityBasicLockEffect.new()
		_:
			return null


## ==================== 招式名称 → 效果实例列表映射 ====================

## 根据招式名称返回对应的效果实例数组（可能包含多个效果）
## 返回空数组表示该招式无附加效果
static func _get_attack_effects(attack_name: String) -> Array:
	match attack_name:
		"三重蓄能":
			# 从牌库搜索3张能量附加到V宝可梦
			return [AttackSearchAndAttach.new("", 3, "deck_search", 0, "v_only")]
		"巅峰加速":
			# 查看顶部5张，将其中最多3个闪电能量附加到备战区
			return [AttackSearchAndAttach.new("", 2, "deck_search", 0, "any", CardData.FUTURE_TAG)]
		"基因侵入":
			# 复制对方的招式
			return [AttackCopyAttack.new()]
		"废品短路":
			return [AttackScrapShort.new(40)]
		"燃烧黑暗":
			# 喷火龙ex：基础180，按对手已拿走的奖赏卡数额外+30/张
			return [AttackPrizeCountDamage.new(30)]
		"炎爆":
			# 弃掉1个火能量，下回合无法使用此招式
			return [
				EffectDiscardEnergy.new(1, "R"),
				AttackSelfLockNextTurn.new()
			]
		"棱镜利刃":
			# 下回合无法使用此招式
			return [AttackSelfLockNextTurn.new()]
		"光子引爆":
			# 下回合无法使用此招式
			return [AttackSelfLockNextTurn.new()]
		"轰隆鼾声":
			# 使用后自身进入睡眠状态
			return [AttackSelfSleep.new()]
		"呼朋引伴":
			# 从牌库搜索最多2只基础宝可梦放到备战区
			return [AttackCallForFamily.new(2)]
		"水流回转":
			# 攻击后返回牌库
			return [AttackReturnToDeck.new()]
		"强劲电光":
			# 弃掉闪电能量，每个额外+60伤害（内部处理弃牌）
			return [AttackDiscardEnergyMultiDamage.new("L", 60)]
		"雷电回旋曲":
			# 双方备战区每只宝可梦+20伤害
			return [AttackBenchCountDamage.new(20, "both")]
		"多谢款待":
			# 额外获取1张奖励牌
			return [AttackExtraPrize.new(1)]
		"放逐冲击":
			# 将自身场上2个能量放入放逐区
			return [AttackLostZoneEnergy.new(2, true, true)]
		"星耀安魂曲":
			# VSTAR 特技：放逐区KO效果
			return [AttackLostZoneKO.new()]
		"星耀时刻":
			# VSTAR 特技：额外回合
			return [AttackVSTARExtraTurn.new()]
		"握握抽取":
			# 摸牌至手牌7张
			return [AttackDrawTo7.new()]
		"月光手里剑":
			# 对备战区2只宝可梦各90伤害，战斗宝可梦0伤害
			return [AttackBenchSnipe.new(90, 2, 0)]
		"双刃":
			# 对备战区1只宝可梦120伤害，自身受30反伤
			return [AttackBenchSnipe.new(120, 1, 30)]
		"狂风呼啸":
			# 可选择弃掉竞技场
			return [AttackOptionalDiscardStadium.new()]
		"气旋俯冲":
			# 可选择弃掉竞技场
			return [AttackOptionalDiscardStadium.new()]
		"风暴俯冲":
			# 可选择弃掉竞技场
			return [AttackOptionalDiscardStadium.new()]
		"深渊探求":
			# 查看牌库顶部4张，选2张加入手牌，其余放逐
			return [AttackLookTopPickHandRestLostZoneEffect.new(4, 2)]
		"磁力抬升":
			# 从牌库搜索1张牌，洗牌后将其放回牌库顶
			return [AttackSearchDeckToTopEffect.new(1)]
		"金属爆破":
			# 己方场上每个金属能量+40伤害
			return [AttackEnergyCountDamage.new("M", 40, true)]
		"精神强念":
			# 对方宝可梦身上每个超能量+50伤害
			return [AttackEnergyCountDamage.new("P", 50, false)]
		"烧光":
			# 弃掉竞技场
			return [AttackDiscardStadium.new()]
		"终结门牙":
			# 投币背面则此招式无效果
			return [AttackCoinFlipOrFail.new(60, "no_damage")]
		"长尾粉碎":
			# 投币正面则额外+90伤害
			return [EffectCoinFlipDamage.new(90, 1, false)]
		"鼓足干劲":
			# 弃掉1张能量（类型不限），内部处理
			return [AttackDiscardEnergyFromSelf.new(1, "")]
		"读风":
			# 攻击后摸牌
			return [AttackReadWindDraw.new()]
		"特殊滚动":
			# 己方身上每张特殊能量+70伤害
			return [AttackSpecialEnergyMultiDamage.new(70)]
		"飞来横祸":
			# 在对方备战区宝可梦上放置2个伤害指示物（20HP）
			return [AttackBenchDamageCounters.new(20)]
		"撕裂":
			# 无视防守方效果
			return [AttackIgnoreDefenderEffects.new()]
		"报仇":
			# 己方有宝可梦昏厥时额外+120伤害
			return [AttackRevengeBonus.new(120)]
		"三重新星":
			# 从牌库搜索能量附加到V宝可梦
			return [AttackSearchAttachToV.new()]
		"瞬移破坏":
			# 拉鲁拉丝：造成伤害后与备战宝可梦交换
			return [AttackSwitchSelfToBenchEffect.new()]
		"凶暴吼叫":
			# 吼叫尾：自身伤害指示物数x20伤害到目标
			return [AttackSelfDamageCounterTargetDamageEffect.new(20)]
		"气球炸弹":
			# 飘飘球：自身伤害指示物数x30伤害
			return [AttackSelfDamageCounterMultiplierEffect.new(30)]
		"狙落":
			# 钥圈儿：弃掉对手战斗宝可梦道具
			return [AttackDiscardDefenderToolEffect.new()]
		"精神幻觉":
			# 愿增猿：60伤害+混乱
			return [EffectApplyStatus.new("confused", false)]
		"奇迹之力":
			# 沙奈朵ex：190伤害+清除自身状态
			return [AttackClearOwnStatusEffect.new()]
		_:
			return []


## ==================== 调试统计 ====================

## 返回各分类已注册的效果数量，用于调试和覆盖率检查
## 返回格式：{ "items": int, "supporters": int, "tools": int, "stadiums": int, "energies": int }
static func get_registered_count() -> Dictionary:
	# 物品卡数量（硬编码，与 _register_items 保持同步）
	var items_count: int = 23
	# 支援者卡数量（硬编码，与 _register_supporters 保持同步）
	var supporters_count: int = 11
	# 道具数量（硬编码，与 _register_tools 保持同步）
	var tools_count: int = 9
	# 竞技场数量（硬编码，与 _register_stadiums 保持同步）
	var stadiums_count: int = 5
	# 特殊能量数量（硬编码，与 _register_special_energies 保持同步）
	var energies_count: int = 6

	return {
		"items": items_count,
		"supporters": supporters_count,
		"tools": tools_count,
		"stadiums": stadiums_count,
		"energies": energies_count,
		"total_static": items_count + supporters_count + tools_count + stadiums_count + energies_count
	}
