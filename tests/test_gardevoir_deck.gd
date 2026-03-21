## 沙奈朵卡组全卡效果测试 - 测试驱动开发
class_name TestGardevoirDeck
extends TestBase

const AbilityDiscardDraw = preload("res://scripts/effects/pokemon_effects/AbilityDiscardDraw.gd")
const AbilityDisableOpponentAbility = preload("res://scripts/effects/pokemon_effects/AbilityDisableOpponentAbility.gd")
const AttackBenchDamageCounters = preload("res://scripts/effects/pokemon_effects/AttackBenchDamageCounters.gd")
const EffectApplyStatus = preload("res://scripts/effects/pokemon_effects/EffectApplyStatus.gd")
const AbilityDiscardDrawAny = preload("res://scripts/effects/pokemon_effects/AbilityDiscardDrawAny.gd")
const AbilityPsychicEmbrace = preload("res://scripts/effects/pokemon_effects/AbilityPsychicEmbrace.gd")
const AttackClearOwnStatus = preload("res://scripts/effects/pokemon_effects/AttackClearOwnStatus.gd")
const AbilityMoveDamageCountersToOpponent = preload("res://scripts/effects/pokemon_effects/AbilityMoveDamageCountersToOpponent.gd")
const AttackSelfDamageCounterTargetDamage = preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterTargetDamage.gd")
const AttackSelfDamageCounterMultiplier = preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterMultiplier.gd")
const AttackSwitchSelfToBench = preload("res://scripts/effects/pokemon_effects/AttackSwitchSelfToBench.gd")
const AbilityBasicLock = preload("res://scripts/effects/pokemon_effects/AbilityBasicLock.gd")
const AttackDiscardDefenderTool = preload("res://scripts/effects/pokemon_effects/AttackDiscardDefenderTool.gd")
const EffectSecretBox = preload("res://scripts/effects/trainer_effects/EffectSecretBox.gd")
const EffectArtazon = preload("res://scripts/effects/stadium_effects/EffectArtazon.gd")
const AttackTMEvolution = preload("res://scripts/effects/pokemon_effects/AttackTMEvolution.gd")


func _make_basic_pokemon_data(
	pname: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	effect_id: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	cd.attacks = [{"name": "Test Attack", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	return cd


func _make_trainer_data(pname: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _make_energy_data(pname: String, energy_type: String, card_type: String = "Basic Energy", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = card_type
	cd.energy_provides = energy_type
	cd.effect_id = effect_id
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi

		var active_cd := _make_basic_pokemon_data("Active%d" % pi, "P", 120)
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(active_cd, pi))
		active.turn_played = 0
		player.active_pokemon = active

		for bi: int in 2:
			var bench_cd := _make_basic_pokemon_data("Bench%d_%d" % [pi, bi], "P", 90)
			var bench := PokemonSlot.new()
			bench.pokemon_stack.append(CardInstance.create(bench_cd, pi))
			bench.turn_played = 0
			player.bench.append(bench)

		for hi: int in 3:
			player.hand.append(CardInstance.create(_make_basic_pokemon_data("Hand%d_%d" % [pi, hi], "C", 60), pi))

		for di: int in 6:
			player.deck.append(CardInstance.create(_make_basic_pokemon_data("Deck%d_%d" % [pi, di], "C", 60), pi))

		for pri: int in 3:
			player.prizes.append(CardInstance.create(_make_basic_pokemon_data("Prize%d_%d" % [pi, pri], "C", 50), pi))

		state.players.append(player)

	return state


## ==================== 振翼发 飞来横祸 伤害指示物修正 ====================

func test_flutter_mane_bench_damage_counters_is_20_not_120() -> String:
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	var opp := state.players[1]
	# 飞来横祸应放置2个伤害指示物（=20），不是120
	var effect := AttackBenchDamageCounters.new(20)
	effect.execute_attack(attacker, opp.active_pokemon, 0, state)
	var total_bench_damage: int = 0
	for slot: PokemonSlot in opp.bench:
		total_bench_damage += slot.damage_counters
	return run_checks([
		assert_eq(total_bench_damage, 20, "飞来横祸应放置20伤害（2个指示物），不是120"),
	])


## ==================== 奇鲁莉安 精炼 ====================

func test_kirlia_refine_discard_any_card_draw_2() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	# 手牌放一张宝可梦卡（非能量）
	var hand_card := CardInstance.create(_make_basic_pokemon_data("DiscardMe", "P"), 0)
	player.hand.append(hand_card)
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Draw_%d" % i, "C"), 0))

	var effect := AbilityDiscardDrawAny.new(2)
	# 通过交互上下文选择弃置非能量卡
	effect.execute_ability(player.active_pokemon, 0, [{"discard_card": [hand_card]}], state)

	return run_checks([
		assert_eq(player.hand.size(), 2, "精炼：弃1张任意手牌后应摸2张"),
		assert_eq(player.discard_pile.size(), 1, "精炼：弃的卡应进入弃牌区"),
		assert_false(effect.can_use_ability(player.active_pokemon, state), "精炼：每回合只能用1次"),
	])


func test_kirlia_refine_can_discard_energy_too() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	var energy_card := CardInstance.create(_make_energy_data("基本超能量", "P"), 0)
	player.hand.append(energy_card)
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Draw_%d" % i, "C"), 0))

	var effect := AbilityDiscardDrawAny.new(2)
	effect.execute_ability(player.active_pokemon, 0, [{"discard_card": [energy_card]}], state)

	return run_checks([
		assert_eq(player.hand.size(), 2, "精炼：也能弃能量牌"),
	])


func test_kirlia_refine_empty_hand_cannot_use() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()

	var effect := AbilityDiscardDrawAny.new(2)
	return run_checks([
		assert_false(effect.can_use_ability(player.active_pokemon, state), "精炼：手牌为空不能使用"),
	])


## ==================== 沙奈朵ex 精神拥抱 ====================

func test_gardevoir_psychic_embrace_attach_energy_place_counters() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	# 创建超属性宝可梦
	var gardevoir_cd := _make_basic_pokemon_data("沙奈朵ex", "P", 310, "Stage 2", "ex", "bd134d7d84e9f1a837a74b061fcb5f40")
	gardevoir_cd.abilities = [{"name": "精神拥抱"}]
	var gardevoir_slot := _make_slot(gardevoir_cd, 0)
	player.active_pokemon = gardevoir_slot
	# 弃牌区放超能量
	var psy_energy := CardInstance.create(_make_energy_data("基本超能量", "P"), 0)
	player.discard_pile.append(psy_energy)
	# 备战区放超属性宝可梦作为目标
	var target_cd := _make_basic_pokemon_data("TargetPsy", "P", 200)
	var target_slot := _make_slot(target_cd, 0)
	player.bench.clear()
	player.bench.append(target_slot)

	var effect := AbilityPsychicEmbrace.new()
	effect.execute_ability(gardevoir_slot, 0, [{
		"embrace_energy": [psy_energy],
		"embrace_target": [target_slot],
	}], state)

	return run_checks([
		assert_eq(target_slot.attached_energy.size(), 1, "精神拥抱：应将超能量附着到目标"),
		assert_eq(target_slot.damage_counters, 20, "精神拥抱：被附着宝可梦应放置2个伤害指示物（20）"),
		assert_eq(player.discard_pile.size(), 0, "精神拥抱：能量应从弃牌区移出"),
	])


func test_gardevoir_psychic_embrace_cannot_ko_target() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var gardevoir_cd := _make_basic_pokemon_data("沙奈朵ex", "P", 310, "Stage 2", "ex")
	gardevoir_cd.abilities = [{"name": "精神拥抱"}]
	var gardevoir_slot := _make_slot(gardevoir_cd, 0)
	player.active_pokemon = gardevoir_slot
	# 目标宝可梦HP70，已受60伤（剩10HP），再放20会KO
	var target_cd := _make_basic_pokemon_data("WeakPsy", "P", 70)
	var target_slot := _make_slot(target_cd, 0)
	target_slot.damage_counters = 60
	player.bench.clear()
	player.bench.append(target_slot)
	var psy_energy := CardInstance.create(_make_energy_data("基本超能量", "P"), 0)
	player.discard_pile.append(psy_energy)

	var effect := AbilityPsychicEmbrace.new()
	var can_use := effect.can_use_embrace_on_target(target_slot)

	return run_checks([
		assert_false(can_use, "精神拥抱：不能对放置指示物后会昏厥的宝可梦使用"),
	])


func test_gardevoir_psychic_embrace_unlimited_uses() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var gardevoir_cd := _make_basic_pokemon_data("沙奈朵ex", "P", 310, "Stage 2", "ex")
	gardevoir_cd.abilities = [{"name": "精神拥抱"}]
	var gardevoir_slot := _make_slot(gardevoir_cd, 0)
	player.active_pokemon = gardevoir_slot
	var target_cd := _make_basic_pokemon_data("TargetPsy", "P", 200)
	var target_slot := _make_slot(target_cd, 0)
	player.bench.clear()
	player.bench.append(target_slot)
	# 放2张能量
	for i: int in 2:
		player.discard_pile.append(CardInstance.create(_make_energy_data("超能量_%d" % i, "P"), 0))

	var effect := AbilityPsychicEmbrace.new()
	# 第一次使用
	var e1 := player.discard_pile[0]
	effect.execute_ability(gardevoir_slot, 0, [{"embrace_energy": [e1], "embrace_target": [target_slot]}], state)
	# 第二次使用（应该仍然可以）
	var can_second := effect.can_use_ability(gardevoir_slot, state)

	return run_checks([
		assert_true(can_second, "精神拥抱：应该可以在同一回合多次使用"),
		assert_eq(target_slot.attached_energy.size(), 1, "精神拥抱：第一次附着应成功"),
	])


func test_gardevoir_psychic_embrace_only_psychic_target() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var gardevoir_cd := _make_basic_pokemon_data("沙奈朵ex", "P", 310, "Stage 2", "ex")
	gardevoir_cd.abilities = [{"name": "精神拥抱"}]
	var gardevoir_slot := _make_slot(gardevoir_cd, 0)
	player.active_pokemon = gardevoir_slot
	# 备战区放非超属性宝可梦
	var fire_cd := _make_basic_pokemon_data("FirePoke", "R", 200)
	var fire_slot := _make_slot(fire_cd, 0)
	player.bench.clear()
	player.bench.append(fire_slot)
	player.discard_pile.append(CardInstance.create(_make_energy_data("基本超能量", "P"), 0))

	var effect := AbilityPsychicEmbrace.new()
	var steps := effect.get_interaction_steps(gardevoir_slot.get_top_card(), state)
	# 交互步骤中的目标列表不应包含非超属性宝可梦
	var target_step: Dictionary = {}
	for step: Dictionary in steps:
		if step.get("id", "") == "embrace_target":
			target_step = step
	var has_fire := false
	if not target_step.is_empty():
		for item: Variant in target_step.get("items", []):
			if item is PokemonSlot and item == fire_slot:
				has_fire = true

	return run_checks([
		assert_false(has_fire, "精神拥抱：非超属性宝可梦不能作为目标"),
	])


## ==================== 沙奈朵ex 奇迹之力 ====================

func test_gardevoir_miracle_force_clears_status() -> String:
	var state := _make_state()
	var attacker_cd := _make_basic_pokemon_data("沙奈朵ex", "P", 310, "Stage 2", "ex")
	var attacker := _make_slot(attacker_cd, 0)
	state.players[0].active_pokemon = attacker
	attacker.set_status("poisoned", true)
	attacker.set_status("confused", true)
	var defender := state.players[1].active_pokemon

	var effect := AttackClearOwnStatus.new()
	effect.execute_attack(attacker, defender, 0, state)

	return run_checks([
		assert_false(attacker.status_conditions.get("poisoned", false), "奇迹之力：应清除中毒"),
		assert_false(attacker.status_conditions.get("confused", false), "奇迹之力：应清除混乱"),
	])


## ==================== 愿增猿 亢奋脑力 ====================

func test_munkidori_move_damage_counters() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opp: PlayerState = state.players[1]
	# 创建愿增猿，附着恶能量
	var munki_cd := _make_basic_pokemon_data("愿增猿", "P", 110, "Basic", "", "66fee12502043db7d92b97b0d62b0f59")
	munki_cd.abilities = [{"name": "亢奋脑力"}]
	var munki_slot := _make_slot(munki_cd, 0)
	munki_slot.attached_energy.append(CardInstance.create(_make_energy_data("基本恶能量", "D"), 0))
	player.bench.clear()
	player.bench.append(munki_slot)
	# 己方战斗宝可梦放3个指示物
	player.active_pokemon.damage_counters = 30
	# 对手战斗宝可梦作为目标
	var opp_active := opp.active_pokemon

	var effect := AbilityMoveDamageCountersToOpponent.new(3)
	effect.execute_ability(munki_slot, 0, [{
		"source_pokemon": [player.active_pokemon],
		"target_pokemon": [opp_active],
		"counter_count": [3],
	}], state)

	return run_checks([
		assert_eq(player.active_pokemon.damage_counters, 0, "亢奋脑力：己方宝可梦伤害指示物应减少"),
		assert_eq(opp_active.damage_counters, 30, "亢奋脑力：对手宝可梦伤害指示物应增加"),
	])


func test_munkidori_requires_dark_energy() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var munki_cd := _make_basic_pokemon_data("愿增猿", "P", 110)
	munki_cd.abilities = [{"name": "亢奋脑力"}]
	var munki_slot := _make_slot(munki_cd, 0)
	# 不附着恶能量
	player.active_pokemon = munki_slot
	player.active_pokemon.damage_counters = 30

	var effect := AbilityMoveDamageCountersToOpponent.new(3)
	return run_checks([
		assert_false(effect.can_use_ability(munki_slot, state), "亢奋脑力：没有恶能量时不能使用"),
	])


## ==================== 愿增猿 精神幻觉 ====================

func test_munkidori_psychic_phantasm_confuses() -> String:
	var state := _make_state()
	var attacker := _make_slot(_make_basic_pokemon_data("愿增猿", "P", 110), 0)
	state.players[0].active_pokemon = attacker
	var defender := state.players[1].active_pokemon

	var effect := EffectApplyStatus.new("confused", false)
	effect.execute_attack(attacker, defender, 0, state)

	return run_checks([
		assert_true(defender.status_conditions.get("confused", false), "精神幻觉：应使对手混乱"),
	])


## ==================== 吼叫尾 凶暴吼叫 ====================

func test_scream_tail_howling_scream_damage_by_counters() -> String:
	var state := _make_state()
	var opp: PlayerState = state.players[1]
	var attacker_cd := _make_basic_pokemon_data("吼叫尾", "P", 90)
	var attacker := _make_slot(attacker_cd, 0)
	attacker.damage_counters = 50  # 5个指示物
	state.players[0].active_pokemon = attacker
	# 选择对手备战区宝可梦为目标
	var target := opp.bench[0]

	var effect := AttackSelfDamageCounterTargetDamage.new(20)
	effect.set_attack_interaction_context([{"target_pokemon": [target]}])
	effect.execute_attack(attacker, opp.active_pokemon, 1, state)
	effect.clear_attack_interaction_context()

	# 5个指示物 x 20 = 100伤害
	return run_checks([
		assert_eq(target.damage_counters, 100, "凶暴吼叫：5指示物 x 20 = 100伤害到目标"),
	])


func test_scream_tail_no_counters_no_damage() -> String:
	var state := _make_state()
	var attacker := _make_slot(_make_basic_pokemon_data("吼叫尾", "P", 90), 0)
	attacker.damage_counters = 0
	state.players[0].active_pokemon = attacker
	var target := state.players[1].bench[0]

	var effect := AttackSelfDamageCounterTargetDamage.new(20)
	effect.set_attack_interaction_context([{"target_pokemon": [target]}])
	effect.execute_attack(attacker, state.players[1].active_pokemon, 1, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(target.damage_counters, 0, "凶暴吼叫：无指示物则伤害为0"),
	])


## ==================== 飘飘球 气球炸弹 ====================

func test_drifloon_balloon_bomb_damage_by_counters() -> String:
	var state := _make_state()
	var attacker := _make_slot(_make_basic_pokemon_data("飘飘球", "P", 70), 0)
	attacker.damage_counters = 40  # 4个指示物
	state.players[0].active_pokemon = attacker
	var defender := state.players[1].active_pokemon

	var effect := AttackSelfDamageCounterMultiplier.new(30)
	var bonus: int = effect.get_damage_bonus(attacker, state)

	# 4个指示物 x 30 = 120伤害加值
	return run_checks([
		assert_eq(bonus, 120, "气球炸弹：4指示物 x 30 = 120伤害加值"),
	])


## ==================== 拉鲁拉丝 瞬移破坏 ====================

func test_ralts_teleport_break_switches_self() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var attacker := _make_slot(_make_basic_pokemon_data("拉鲁拉丝", "P", 70), 0)
	player.active_pokemon = attacker
	var bench_mon := player.bench[0]

	var effect := AttackSwitchSelfToBench.new()
	effect.set_attack_interaction_context([{"switch_target": [bench_mon]}])
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(player.active_pokemon, bench_mon, "瞬移破坏：应与备战区宝可梦交换"),
		assert_true(attacker in player.bench, "瞬移破坏：原战斗宝可梦应在备战区"),
	])


func test_ralts_teleport_break_no_bench_no_switch() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var attacker := _make_slot(_make_basic_pokemon_data("拉鲁拉丝", "P", 70), 0)
	player.active_pokemon = attacker
	player.bench.clear()

	var effect := AttackSwitchSelfToBench.new()
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_eq(player.active_pokemon, attacker, "瞬移破坏：无备战区时不切换"),
	])


## ==================== 钥圈儿 恶作剧之锁 ====================

func test_klefki_mischievous_lock_disables_basic_abilities() -> String:
	var state := _make_state()
	# 钥圈儿在战斗场
	var klefki_cd := _make_basic_pokemon_data("钥圈儿", "P", 70)
	klefki_cd.abilities = [{"name": "恶作剧之锁"}]
	var klefki := _make_slot(klefki_cd, 0)
	state.players[0].active_pokemon = klefki

	# 对方战斗场有基础宝可梦
	var opp_basic_cd := _make_basic_pokemon_data("OppBasic", "R", 100)
	opp_basic_cd.abilities = [{"name": "某特性"}]
	state.players[1].active_pokemon = _make_slot(opp_basic_cd, 1)

	# 进化宝可梦不应受影响
	var opp_evolved_cd := _make_basic_pokemon_data("OppEvolved", "R", 100, "Stage 1")
	opp_evolved_cd.abilities = [{"name": "进化特性"}]
	state.players[1].bench.clear()
	state.players[1].bench.append(_make_slot(opp_evolved_cd, 1))

	var basic_disabled := AbilityBasicLock.is_basic_abilities_disabled(state, klefki)
	return run_checks([
		assert_true(basic_disabled, "恶作剧之锁：钥圈儿在场时基础宝可梦特性应被无效化"),
	])


## ==================== 钥圈儿 狙落 ====================

func test_klefki_snipe_discard_tool() -> String:
	var state := _make_state()
	var attacker := _make_slot(_make_basic_pokemon_data("钥圈儿", "P", 70), 0)
	state.players[0].active_pokemon = attacker
	var defender := state.players[1].active_pokemon
	var tool_cd := _make_trainer_data("讲究腰带", "Tool")
	defender.attached_tool = CardInstance.create(tool_cd, 1)

	var effect := AttackDiscardDefenderTool.new()
	effect.execute_attack(attacker, defender, 0, state)

	return run_checks([
		assert_eq(defender.attached_tool, null, "狙落：应弃掉对手战斗宝可梦的道具"),
		assert_eq(state.players[1].discard_pile.size(), 1, "狙落：道具应进入弃牌区"),
	])


## ==================== 秘密箱 Secret Box ====================

func test_secret_box_discard_3_search_4_types() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	# 手牌放4张（弃3张+秘密箱自己）
	for i: int in 4:
		player.hand.append(CardInstance.create(_make_basic_pokemon_data("Hand_%d" % i, "C"), 0))
	# 牌库放各类型卡
	var item := CardInstance.create(_make_trainer_data("巢穴球", "Item"), 0)
	var tool := CardInstance.create(_make_trainer_data("讲究腰带", "Tool"), 0)
	var supporter := CardInstance.create(_make_trainer_data("奇树", "Supporter"), 0)
	var stadium := CardInstance.create(_make_trainer_data("深钵镇", "Stadium"), 0)
	player.deck.append(item)
	player.deck.append(tool)
	player.deck.append(supporter)
	player.deck.append(stadium)
	for i: int in 4:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Filler_%d" % i, "C"), 0))

	# 秘密箱的card
	var box_card := CardInstance.create(_make_trainer_data("秘密箱", "Item", "e92a86246f44351d023bd4fa271089aa"), 0)

	var effect := EffectSecretBox.new()
	# 弃3张手牌
	var discard_targets: Array = [player.hand[0], player.hand[1], player.hand[2]]
	effect.execute(box_card, [{
		"discard_cards": discard_targets,
		"search_item": [item],
		"search_tool": [tool],
		"search_supporter": [supporter],
		"search_stadium": [stadium],
	}], state)

	return run_checks([
		assert_eq(player.discard_pile.size(), 3, "秘密箱：应弃掉3张手牌"),
		assert_true(item in player.hand, "秘密箱：应从牌库找到物品卡"),
		assert_true(tool in player.hand, "秘密箱：应从牌库找到道具卡"),
		assert_true(supporter in player.hand, "秘密箱：应从牌库找到支援者卡"),
		assert_true(stadium in player.hand, "秘密箱：应从牌库找到竞技场卡"),
	])


func test_secret_box_cannot_use_with_less_than_3_hand_cards() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	# 只有2张手牌（不够弃3张）
	for i: int in 2:
		player.hand.append(CardInstance.create(_make_basic_pokemon_data("Hand_%d" % i, "C"), 0))
	var box_card := CardInstance.create(_make_trainer_data("秘密箱", "Item", "e92a86246f44351d023bd4fa271089aa"), 0)
	var effect := EffectSecretBox.new()
	return run_checks([
		assert_false(effect.can_execute(box_card, state), "秘密箱：手牌不足3张时不能使用"),
	])


## ==================== 深钵镇 Artazon ====================

func test_artazon_search_basic_non_rule_to_bench() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	player.deck.clear()
	var basic_cd := _make_basic_pokemon_data("拉鲁拉丝", "P", 70)
	var basic_card := CardInstance.create(basic_cd, 0)
	player.deck.append(basic_card)
	# ex/V宝可梦不应出现在可选列表
	var ex_cd := _make_basic_pokemon_data("SomeEx", "P", 200, "Basic", "ex")
	player.deck.append(CardInstance.create(ex_cd, 0))
	for i: int in 3:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Filler_%d" % i, "C"), 0))

	var stadium_card := CardInstance.create(_make_trainer_data("深钵镇", "Stadium", "c117bea3cc758d46430d6bef11062a56"), 0)
	var effect := EffectArtazon.new()
	effect.execute(stadium_card, [{"artazon_pokemon": [basic_card]}], state)

	return run_checks([
		assert_eq(player.bench.size(), 1, "深钵镇：应放1只基础宝可梦到备战区"),
		assert_eq(player.bench[0].get_pokemon_name(), "拉鲁拉丝", "深钵镇：放置的应是选择的宝可梦"),
	])


func test_artazon_excludes_rule_box_pokemon() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	# 只放ex宝可梦
	var ex_cd := _make_basic_pokemon_data("SomeEx", "P", 200, "Basic", "ex")
	player.deck.append(CardInstance.create(ex_cd, 0))
	var v_cd := _make_basic_pokemon_data("SomeV", "P", 200, "Basic", "V")
	player.deck.append(CardInstance.create(v_cd, 0))

	var stadium_card := CardInstance.create(_make_trainer_data("深钵镇", "Stadium"), 0)
	var effect := EffectArtazon.new()
	return run_checks([
		assert_false(effect.can_execute(stadium_card, state), "深钵镇：牌库无非规则基础宝可梦时不可使用"),
	])


## ==================== 招式学习器 进化 TM: Evolution ====================

func test_tm_evolution_grants_attack() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var attacker := player.active_pokemon
	# 附着TM进化道具
	var tm_cd := _make_trainer_data("招式学习器 进化", "Tool", "43386015be5c073ba2e5b9d3692ece3f")
	attacker.attached_tool = CardInstance.create(tm_cd, 0)

	var effect := AttackTMEvolution.new(2)
	var granted := effect.get_granted_attacks(attacker, state)

	return run_checks([
		assert_eq(granted.size(), 1, "TM进化：应提供1个赋予招式"),
		assert_eq(granted[0].get("name", ""), "进化", "TM进化：招式名应为「进化」"),
		assert_eq(granted[0].get("cost", ""), "C", "TM进化：费用应为[C]"),
	])


func test_tm_evolution_evolves_bench_pokemon() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	# 备战区放基础宝可梦
	var basic_cd := _make_basic_pokemon_data("拉鲁拉丝", "P", 70, "Basic", "", "27246a1e79cd8b4f7d965cf2b41b5089")
	var basic_slot := _make_slot(basic_cd, 0)
	basic_slot.turn_played = 0
	player.bench.clear()
	player.bench.append(basic_slot)
	# 牌库放进化形
	var evo_cd := _make_basic_pokemon_data("奇鲁莉安", "P", 80, "Stage 1")
	evo_cd.evolves_from = "拉鲁拉丝"
	var evo_card := CardInstance.create(evo_cd, 0)
	player.deck.clear()
	player.deck.append(evo_card)
	for i: int in 3:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Filler_%d" % i, "C"), 0))

	var attack_data := {"id": "tm_evolution", "name": "进化", "cost": "C", "damage": "", "text": ""}
	var effect := AttackTMEvolution.new(2)
	effect.execute_granted_attack(player.active_pokemon, attack_data, state, [{"evolution_bench": [basic_slot]}])

	return run_checks([
		assert_eq(basic_slot.pokemon_stack.size(), 2, "TM进化：应将进化卡放到备战宝可梦上"),
		assert_eq(basic_slot.get_pokemon_name(), "奇鲁莉安", "TM进化：进化后应显示奇鲁莉安"),
	])


func test_tm_evolution_discards_at_end_of_turn() -> String:
	var effect := AttackTMEvolution.new(2)
	var slot := _make_slot(_make_basic_pokemon_data("Test", "P", 100), 0)
	var state := _make_state()
	return run_checks([
		assert_true(effect.discard_at_end_of_turn(slot, state), "TM进化：应在回合结束时弃置"),
	])


## ==================== 注册完整性检查 ====================

func test_gardevoir_deck_all_effect_ids_registered() -> String:
	var processor := EffectProcessor.new()
	EffectRegistry.register_all(processor)

	# 非宝可梦卡 effect_id 检查
	var item_ids: Array[String] = [
		"e92a86246f44351d023bd4fa271089aa",  # 秘密箱
	]
	var stadium_ids: Array[String] = [
		"c117bea3cc758d46430d6bef11062a56",  # 深钵镇
	]
	var tool_ids: Array[String] = [
		"43386015be5c073ba2e5b9d3692ece3f",  # TM: Evolution
	]

	var checks: Array[String] = []
	for eid: String in item_ids:
		checks.append(assert_true(processor.get_effect(eid) != null, "物品卡 %s 应已注册" % eid))
	for eid: String in stadium_ids:
		checks.append(assert_true(processor.get_effect(eid) != null, "竞技场 %s 应已注册" % eid))
	for eid: String in tool_ids:
		checks.append(assert_true(processor.get_effect(eid) != null, "道具 %s 应已注册" % eid))

	return run_checks(checks)
