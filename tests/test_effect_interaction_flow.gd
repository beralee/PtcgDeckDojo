## Effect interaction flow tests
class_name TestEffectInteractionFlow
extends TestBase

const AbilityGustFromBenchEffect = preload("res://scripts/effects/pokemon_effects/AbilityGustFromBench.gd")


func _make_basic_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	effect_id: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	cd.effect_id = effect_id
	cd.attacks = [{"name": "Test Attack", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	return cd


func _make_trainer_data(name: String, card_type: String, effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	cd.effect_id = effect_id
	return cd


func _make_manual_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	return gsm


func test_attach_special_energy_triggers_on_attach_effect() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Active", "C", 60), 0))
	active_slot.status_conditions["asleep"] = true
	active_slot.status_conditions["paralyzed"] = true
	active_slot.status_conditions["confused"] = true
	player.active_pokemon = active_slot

	var energy_cd := CardData.new()
	energy_cd.name = "Therapeutic Energy"
	energy_cd.card_type = "Special Energy"
	energy_cd.energy_provides = "C"
	energy_cd.effect_id = "2c65697c2aceac4e6a1f85f810fa386f"
	var energy := CardInstance.create(energy_cd, 0)
	player.hand.append(energy)

	var result: bool = gsm.attach_energy(0, energy, active_slot)
	return run_checks([
		assert_true(result, "Special Energy attach should succeed"),
		assert_false(active_slot.status_conditions["asleep"], "Therapeutic Energy should clear asleep"),
		assert_false(active_slot.status_conditions["paralyzed"], "Therapeutic Energy should clear paralyzed"),
		assert_false(active_slot.status_conditions["confused"], "Therapeutic Energy should clear confused"),
	])


func test_attach_jet_energy_switches_benched_pokemon_active() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Old Active", "C", 90), 0))
	player.active_pokemon = active_slot

	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Jet Target", "C", 110), 0))
	player.bench.append(bench_slot)

	var energy_cd := CardData.new()
	energy_cd.name = "Jet Energy"
	energy_cd.card_type = "Special Energy"
	energy_cd.energy_provides = "C"
	energy_cd.effect_id = "1323733f19cc04e54090b39bc1a393b8"
	var energy := CardInstance.create(energy_cd, 0)
	player.hand.append(energy)

	var result: bool = gsm.attach_energy(0, energy, bench_slot)
	return run_checks([
		assert_true(result, "Jet Energy attach should succeed"),
		assert_eq(player.active_pokemon, bench_slot, "Jet Energy should switch the attached Benched Pokemon to Active"),
		assert_true(active_slot in player.bench, "The previous Active Pokemon should move to the Bench"),
		assert_eq(bench_slot.attached_energy.size(), 1, "Jet Energy should remain attached after the switch"),
	])


func test_play_stadium_triggers_on_play_effect() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Active", "R", 80), 0))
	player.active_pokemon = active_slot

	for i: int in 5:
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Bench%d" % i, "W", 70), 0))
		player.bench.append(bench_slot)
		var opponent_bench_slot := PokemonSlot.new()
		opponent_bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("OppBench%d" % i, "W", 70), 1))
		opponent.bench.append(opponent_bench_slot)

	var stadium := CardInstance.create(_make_trainer_data("Collapsed Stadium", "Stadium", "fb3628071280487676f79281696ffbd9"), 0)
	player.hand.append(stadium)
	var chosen_player_slot: PokemonSlot = player.bench[1]
	var chosen_opponent_slot: PokemonSlot = opponent.bench[3]
	var chosen_player_card: CardInstance = chosen_player_slot.get_top_card()
	var chosen_opponent_card: CardInstance = chosen_opponent_slot.get_top_card()

	var result: bool = gsm.play_stadium(0, stadium, [{
		"collapsed_stadium_discard_p0": [chosen_player_slot],
		"collapsed_stadium_discard_p1": [chosen_opponent_slot],
	}])
	return run_checks([
		assert_true(result, "Stadium play should succeed"),
		assert_eq(player.bench.size(), 4, "Collapsed Stadium should trim the current player's bench to four"),
		assert_eq(opponent.bench.size(), 4, "Collapsed Stadium should trim the opponent's bench to four"),
		assert_true(chosen_player_card in player.discard_pile, "Collapsed Stadium should discard the chosen bench Pokemon for the current player"),
		assert_true(chosen_opponent_card in opponent.discard_pile, "Collapsed Stadium should discard the chosen bench Pokemon for the opponent"),
		assert_eq(gsm.game_state.stadium_card, stadium, "Stadium should remain in play"),
	])


func test_use_stadium_effect_executes_for_current_turn_player() -> String:
	var gsm := _make_manual_gsm()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	player.deck.clear()
	opponent.deck.clear()
	player.hand.clear()
	opponent.hand.clear()
	player.deck.append(CardInstance.create(_make_trainer_data("Tool A", "Tool"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("Tool B", "Tool"), 0))

	var stadium := CardInstance.create(_make_trainer_data("Town Store", "Stadium", "13b3caaa408a85dfd1e2a5ad797e8b8a"), 1)
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 1

	var effect: BaseEffect = gsm.effect_processor.get_effect(stadium.card_data.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium, gsm.game_state)
	var items: Array = steps[0].get("items", [])
	var chosen_tool: CardInstance = items[1] as CardInstance if items.size() > 1 else items[0] as CardInstance

	var first_use: bool = gsm.use_stadium_effect(0, [{
		"town_store_tool": [chosen_tool],
	}])
	var second_use_same_turn: bool = gsm.use_stadium_effect(0)

	return run_checks([
		assert_true(first_use, "Current turn player should be able to use the Stadium effect"),
		assert_true(chosen_tool in player.hand, "Town Store should search the selected Tool for the current turn player"),
		assert_false(chosen_tool in opponent.hand, "Stadium owner should not receive the searched Tool on the opponent's turn"),
		assert_false(second_use_same_turn, "A Stadium effect should not be reusable by the same player in the same turn"),
	])


func test_stadium_effect_can_be_used_again_on_later_turn() -> String:
	var gsm := _make_manual_gsm()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[0]
	player.deck.clear()
	player.hand.clear()
	player.deck.append(CardInstance.create(_make_trainer_data("Tool A", "Tool"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("Tool B", "Tool"), 0))

	var stadium := CardInstance.create(_make_trainer_data("Town Store", "Stadium", "13b3caaa408a85dfd1e2a5ad797e8b8a"), 0)
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 0

	var first_tool: CardInstance = player.deck[0]
	var first_use: bool = gsm.use_stadium_effect(0, [{
		"town_store_tool": [first_tool],
	}])

	gsm.game_state.turn_number = 4
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN

	var second_tool: CardInstance = player.deck[0]
	var second_use: bool = gsm.use_stadium_effect(0, [{
		"town_store_tool": [second_tool],
	}])

	return run_checks([
		assert_true(first_use, "Stadium effect should work on the current turn"),
		assert_true(second_use, "Stadium effect should be reusable on a later turn"),
		assert_eq(player.hand.size(), 2, "Both turns should be able to search one Tool each"),
	])


func test_stadium_effect_stays_limited_after_stadium_replacement_same_turn() -> String:
	var gsm := _make_manual_gsm()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_trainer_data("Tool A", "Tool"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("Tool B", "Tool"), 0))

	var first_stadium := CardInstance.create(_make_trainer_data("Town Store", "Stadium", "13b3caaa408a85dfd1e2a5ad797e8b8a"), 0)
	gsm.game_state.stadium_card = first_stadium
	gsm.game_state.stadium_owner_index = 0

	var first_use: bool = gsm.use_stadium_effect(0, [{
		"town_store_tool": [player.deck[0]],
	}])

	var second_stadium := CardInstance.create(_make_trainer_data("Town Store", "Stadium", "13b3caaa408a85dfd1e2a5ad797e8b8a"), 0)
	gsm.game_state.stadium_card = second_stadium
	gsm.game_state.stadium_owner_index = 0

	var second_use_same_turn: bool = gsm.use_stadium_effect(0, [{
		"town_store_tool": [player.deck[0]],
	}])

	return run_checks([
		assert_true(first_use, "First stadium use on the turn should succeed"),
		assert_false(second_use_same_turn, "Replacing the stadium should not grant another use in the same turn"),
		assert_eq(player.hand.size(), 1, "Only one Tool should be searched on that turn"),
	])


func test_cached_pokemon_card_registers_dynamic_effects() -> String:
	var gsm := GameStateMachine.new()
	var cached_card: CardData = CardDatabase.get_card("CSV6C", "042")
	if cached_card != null:
		gsm.effect_processor.register_pokemon_card(cached_card)

	return run_checks([
		assert_not_null(cached_card, "Cached card should be retrievable from CardDatabase"),
		assert_true(gsm.effect_processor.has_effect(cached_card.effect_id), "Cached card should auto-register ability effects"),
		assert_true(gsm.effect_processor.has_attack_effect(cached_card.effect_id), "Cached card should auto-register attack effects"),
	])


func test_use_ability_executes_active_ability() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var pokemon_cd := _make_basic_pokemon_data("Ability User", "L", 120, "Basic", "test_active_ability")
	pokemon_cd.abilities = [{"name": "Step", "text": ""}]
	gsm.effect_processor.register_effect("test_active_ability", AbilityThunderousCharge.new())

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(pokemon_cd, 0))
	player.active_pokemon = active_slot
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("Drawn Card", "C", 60), 0))

	var result: bool = gsm.use_ability(0, active_slot, 0)
	return run_checks([
		assert_true(result, "Active ability should execute"),
		assert_eq(player.hand.size(), 1, "Ability should draw one card"),
		assert_true(active_slot.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == AbilityThunderousCharge.USED_FLAG_TYPE), "Ability use should leave a once-per-turn flag"),
	])


func test_iron_bundle_gust_from_bench_keeps_current_turn_after_opponent_choice() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]

	var gust_cd := _make_basic_pokemon_data("铁包袱", "W", 120, "Basic", "test_iron_bundle_gust")
	gust_cd.abilities = [{"name": "强力吹风机", "text": ""}]
	gsm.effect_processor.register_effect("test_iron_bundle_gust", AbilityGustFromBenchEffect.new())

	var player_active := PokemonSlot.new()
	player_active.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Player Active", "C", 120), 0))
	player.active_pokemon = player_active

	var gust_slot := PokemonSlot.new()
	gust_slot.pokemon_stack.append(CardInstance.create(gust_cd, 0))
	player.bench.append(gust_slot)

	var opponent_active := PokemonSlot.new()
	opponent_active.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Opponent Active", "R", 110), 1))
	opponent.active_pokemon = opponent_active

	var chosen_bench := PokemonSlot.new()
	chosen_bench.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Chosen Bench", "G", 90), 1))
	opponent.bench.append(chosen_bench)

	var other_bench := PokemonSlot.new()
	other_bench.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Other Bench", "L", 90), 1))
	opponent.bench.append(other_bench)

	var used: bool = gsm.use_ability(0, gust_slot, 0, [{
		"opponent_bench_target": [chosen_bench],
	}])

	return run_checks([
		assert_true(used, "强力吹风机应能正常结算"),
		assert_eq(gsm.game_state.current_player_index, 0, "对手选择换上的宝可梦后仍应是我方回合"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "强力吹风机结算后应回到我方主阶段"),
		assert_eq(opponent.active_pokemon, chosen_bench, "应由对手选中的备战宝可梦上到战斗场"),
		assert_true(opponent_active in opponent.bench, "对手原战斗宝可梦应回到备战区"),
		assert_false(gust_slot in player.bench, "铁包袱结算后应离开备战区"),
		assert_true(player.discard_pile.any(func(c: CardInstance) -> bool: return c.card_data.name == "铁包袱"), "铁包袱应进入弃牌区"),
	])


func test_iron_bundle_gust_from_bench_cannot_be_used_on_opponent_turn() -> String:
	var gsm := _make_manual_gsm()
	gsm.game_state.current_player_index = 1
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]

	var gust_cd := _make_basic_pokemon_data("铁包袱", "W", 120, "Basic", "test_iron_bundle_gust_turn_gate")
	gust_cd.abilities = [{"name": "强力吹风机", "text": ""}]
	gsm.effect_processor.register_effect("test_iron_bundle_gust_turn_gate", AbilityGustFromBenchEffect.new())

	var player_active := PokemonSlot.new()
	player_active.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Player Active", "C", 120), 0))
	player.active_pokemon = player_active

	var gust_slot := PokemonSlot.new()
	gust_slot.pokemon_stack.append(CardInstance.create(gust_cd, 0))
	player.bench.append(gust_slot)

	var opponent_active := PokemonSlot.new()
	opponent_active.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Opponent Active", "R", 110), 1))
	opponent.active_pokemon = opponent_active

	var opponent_bench := PokemonSlot.new()
	opponent_bench.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Opponent Bench", "G", 90), 1))
	opponent.bench.append(opponent_bench)

	var used: bool = gsm.use_ability(0, gust_slot, 0, [{
		"opponent_bench_target": [opponent_bench],
	}])

	return run_checks([
		assert_false(used, "强力吹风机不应能在对手回合发动"),
		assert_eq(gsm.game_state.current_player_index, 1, "失败后当前回合归属不应改变"),
		assert_eq(opponent.active_pokemon, opponent_active, "失败后对手战斗宝可梦不应被替换"),
		assert_true(gust_slot in player.bench, "失败后铁包袱应仍在备战区"),
	])


func test_use_attack_discard_basic_energy_from_hand_respects_selected_cards() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var defender_player: PlayerState = gsm.game_state.players[1]

	var attacker_cd := _make_basic_pokemon_data("Gholdengo ex", "M", 260, "Basic", "gholdengo_test")
	attacker_cd.attacks = [{"name": "Make It Rain", "cost": "MMC", "damage": "50", "text": "", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_energy_data("Metal Energy A", "M"), 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_energy_data("Metal Energy B", "M"), 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_energy_data("Colorless Energy", "C"), 0))
	player.active_pokemon = attacker_slot

	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Defender", "W", 200), 1))
	defender_player.active_pokemon = defender_slot

	player.hand.clear()
	var chosen_a := CardInstance.create(_make_energy_data("Chosen A", "M"), 0)
	var chosen_b := CardInstance.create(_make_energy_data("Chosen B", "M"), 0)
	var unchosen := CardInstance.create(_make_energy_data("Unchosen", "M"), 0)
	player.hand.append(chosen_a)
	player.hand.append(chosen_b)
	player.hand.append(unchosen)
	gsm.effect_processor.register_attack_effect("gholdengo_test", AttackDiscardBasicEnergyFromHandDamage.new(50))

	var result: bool = gsm.use_attack(0, 0, [{
		"discard_basic_energy": [chosen_a, chosen_b],
	}])

	return run_checks([
		assert_true(result, "Attack should resolve with selected discard cards"),
		assert_true(chosen_a in player.discard_pile and chosen_b in player.discard_pile, "Selected basic energy should be discarded"),
		assert_true(unchosen in player.hand, "Unselected basic energy should remain in hand"),
		assert_eq(defender_slot.damage_counters, 100, "Damage should scale only with the selected discard count"),
	])


func test_use_attack_read_wind_draw_respects_selected_hand_card() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var defender_player: PlayerState = gsm.game_state.players[1]

	var attacker_cd := _make_basic_pokemon_data("Lugia V", "C", 220, "Basic", "d8e735158b27693de9d70f883d84f5a2")
	attacker_cd.attacks = [{"name": "读风", "cost": "C", "damage": "", "text": "", "is_vstar_power": false}]
	gsm.effect_processor.register_pokemon_card(attacker_cd)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_energy_data("Colorless Energy", "C"), 0))
	player.active_pokemon = attacker_slot

	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Defender", "W", 200), 1))
	defender_player.active_pokemon = defender_slot

	player.hand.clear()
	player.discard_pile.clear()
	player.deck.clear()
	var chosen := CardInstance.create(_make_basic_pokemon_data("Chosen Discard", "C"), 0)
	var unchosen := CardInstance.create(_make_basic_pokemon_data("Keep In Hand", "C"), 0)
	player.hand.append_array([chosen, unchosen])
	for i: int in 3:
		player.deck.append(CardInstance.create(_make_basic_pokemon_data("Draw %d" % i, "C"), 0))

	var result: bool = gsm.use_attack(0, 0, [{
		"discard_card": [chosen],
	}])

	return run_checks([
		assert_true(result, "Read the Wind should resolve with the selected hand card"),
		assert_true(chosen in player.discard_pile, "Read the Wind should discard the selected hand card"),
		assert_true(unchosen in player.hand, "Read the Wind should keep unselected hand cards"),
		assert_false(unchosen in player.discard_pile, "Read the Wind should not discard an unselected hand card"),
		assert_eq(player.hand.size(), 4, "Read the Wind should end with the remaining hand plus three drawn cards"),
	])


func test_first_turn_draw_ability_works_on_second_players_first_turn() -> String:
	var gsm := _make_manual_gsm()
	gsm.game_state.first_player_index = 0
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[1]
	player.hand.clear()
	player.deck.clear()

	var pokemon_cd := _make_basic_pokemon_data("Squawkabilly ex", "C", 160, "Basic", "test_first_turn_draw")
	pokemon_cd.abilities = [{"name": "英武重抽", "text": ""}]
	gsm.effect_processor.register_effect("test_first_turn_draw", AbilityFirstTurnDraw.new(6))

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(pokemon_cd, 1))
	player.active_pokemon = active_slot

	for i: int in 3:
		player.hand.append(CardInstance.create(_make_trainer_data("Hand%d" % i, "Item"), 1))
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_trainer_data("Draw%d" % i, "Item"), 1))

	var result: bool = gsm.use_ability(1, active_slot, 0)
	return run_checks([
		assert_true(result, "Squawkabilly ex should be able to use its Ability on its controller's first turn"),
		assert_eq(player.hand.size(), 6, "The Ability should redraw to six cards"),
		assert_eq(player.discard_pile.size(), 3, "The original hand should be discarded"),
		assert_true(active_slot.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == AbilityFirstTurnDraw.USED_KEY), "The Ability should mark itself as used"),
	])


func test_setup_complete_sets_prizes_without_adding_to_hand() -> String:
	var gsm := _make_manual_gsm()
	for pi: int in 2:
		var player: PlayerState = gsm.game_state.players[pi]
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("SetupActive%d" % pi, "C", 60), pi))
		player.active_pokemon = active_slot
		for i: int in 10:
			player.deck.append(CardInstance.create(_make_basic_pokemon_data("Deck%d_%d" % [pi, i], "C", 60), pi))
		for i: int in 3:
			player.hand.append(CardInstance.create(_make_basic_pokemon_data("Hand%d_%d" % [pi, i], "C", 60), pi))

	var p0_hand_before: int = gsm.game_state.players[0].hand.size()
	var p1_hand_before: int = gsm.game_state.players[1].hand.size()
	var result: bool = gsm.setup_complete(0)

	return run_checks([
		assert_true(result, "Setup should complete when both players have an Active Pokemon"),
		assert_eq(gsm.game_state.players[0].prizes.size(), 6, "Player 0 should have 6 prize cards"),
		assert_eq(gsm.game_state.players[1].prizes.size(), 6, "Player 1 should have 6 prize cards"),
		assert_eq(gsm.game_state.players[0].hand.size(), p0_hand_before + 1, "First player hand should only increase by the opening draw"),
		assert_eq(gsm.game_state.players[1].hand.size(), p1_hand_before, "Second player hand should not gain prize cards"),
	])


func test_rare_candy_can_be_played_multiple_times_in_one_match() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Charmander A", "R", 70), 0))
	active_slot.turn_played = 0
	player.active_pokemon = active_slot

	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Charmander B", "R", 70), 0))
	bench_slot.turn_played = 0
	player.bench.append(bench_slot)

	var stage1_a := _make_basic_pokemon_data("Charmeleon A", "R", 90, "Stage 1")
	stage1_a.evolves_from = "Charmander A"
	player.deck.append(CardInstance.create(stage1_a, 0))

	var stage1_b := _make_basic_pokemon_data("Charmeleon B", "R", 90, "Stage 1")
	stage1_b.evolves_from = "Charmander B"
	player.deck.append(CardInstance.create(stage1_b, 0))

	var stage2_a_cd := _make_basic_pokemon_data("Charizard ex A", "R", 330, "Stage 2")
	stage2_a_cd.evolves_from = "Charmeleon A"
	var stage2_a := CardInstance.create(stage2_a_cd, 0)

	var stage2_b_cd := _make_basic_pokemon_data("Charizard ex B", "R", 330, "Stage 2")
	stage2_b_cd.evolves_from = "Charmeleon B"
	var stage2_b := CardInstance.create(stage2_b_cd, 0)

	var candy1 := CardInstance.create(_make_trainer_data("Rare Candy 1", "Item", "d3891abcfe3277c8811cde06741d3236"), 0)
	var candy2 := CardInstance.create(_make_trainer_data("Rare Candy 2", "Item", "d3891abcfe3277c8811cde06741d3236"), 0)
	player.hand.append_array([stage2_a, stage2_b, candy1, candy2])

	var first_use := gsm.play_trainer(0, candy1, [{
		"stage2_card": [stage2_a],
		"target_pokemon": [active_slot],
	}])
	var second_use := gsm.play_trainer(0, candy2, [{
		"stage2_card": [stage2_b],
		"target_pokemon": [bench_slot],
	}])

	return run_checks([
		assert_true(first_use, "First Rare Candy should resolve successfully"),
		assert_true(second_use, "Second Rare Candy should also resolve successfully in the same match"),
		assert_eq(active_slot.get_pokemon_name(), "Charizard ex A", "Active target should evolve with the first Rare Candy"),
		assert_eq(bench_slot.get_pokemon_name(), "Charizard ex B", "Bench target should evolve with the second Rare Candy"),
		assert_eq(player.discard_pile.size(), 2, "Both Rare Candy cards should end up in the discard pile"),
	])


func test_rare_candy_play_trainer_evolves_froakie_into_greninja_ex_without_stage1_reference() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var froakie_cd: CardData = CardDatabase.get_card("CSV2C", "028")
	var greninja_cd: CardData = CardDatabase.get_card("CSV7C", "123")
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(froakie_cd, 0))
	active_slot.turn_played = 0
	player.active_pokemon = active_slot

	var greninja := CardInstance.create(greninja_cd, 0)
	var candy := CardInstance.create(_make_trainer_data("Rare Candy", "Item", "d3891abcfe3277c8811cde06741d3236"), 0)
	player.hand.append_array([greninja, candy])

	var result := gsm.play_trainer(0, candy, [{
		"stage2_card": [greninja],
		"target_pokemon": [active_slot],
	}])

	return run_checks([
		assert_not_null(froakie_cd, "CSV2C_028 should exist in the card database"),
		assert_not_null(greninja_cd, "CSV7C_123 should exist in the card database"),
		assert_true(result, "Rare Candy should resolve for the Froakie to Greninja ex line"),
		assert_eq(active_slot.get_pokemon_name(), greninja_cd.name, "Rare Candy should evolve Froakie directly into Greninja ex"),
		assert_true(candy in player.discard_pile, "Rare Candy should be discarded after resolving"),
		assert_false(greninja in player.hand, "Greninja ex should leave the hand after evolving"),
	])


func test_supporters_generate_interaction_steps() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.deck.clear()
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("Water Pokemon", "W", 90), 0))
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("Evolution Pokemon", "G", 120, "Stage 1"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("Item Card", "Item"), 0))
	player.deck.append(CardInstance.create(_make_trainer_data("Tool Card", "Tool"), 0))

	var arven_steps: Array[Dictionary] = EffectArven.new().get_interaction_steps(
		CardInstance.create(_make_trainer_data("Arven", "Supporter"), 0),
		gsm.game_state
	)
	var irida_steps: Array[Dictionary] = EffectIrida.new().get_interaction_steps(
		CardInstance.create(_make_trainer_data("Irida", "Supporter"), 0),
		gsm.game_state
	)
	var jacq_steps: Array[Dictionary] = EffectJacq.new().get_interaction_steps(
		CardInstance.create(_make_trainer_data("Jacq", "Supporter"), 0),
		gsm.game_state
	)

	return run_checks([
		assert_eq(arven_steps.size(), 2, "Arven should create item and tool selection steps"),
		assert_eq(str(arven_steps[0].get("id", "")), "search_item", "Arven first step should be item search"),
		assert_eq(irida_steps.size(), 2, "Irida should create Water Pokemon and Item steps"),
		assert_eq(str(irida_steps[0].get("id", "")), "water_pokemon", "Irida first step should be Water Pokemon search"),
		assert_eq(jacq_steps.size(), 1, "Jacq should create one search step"),
		assert_eq(int(jacq_steps[0].get("max_select", 0)), 1, "Jacq max select should match the available evolution count"),
	])


func test_ultra_ball_requires_two_card_multiselect_step() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()

	var ultra_ball := CardInstance.create(_make_trainer_data("Ultra Ball", "Item", "a337ed34a45e63c6d21d98c3d8e0cb6e"), 0)
	player.hand.append(ultra_ball)
	player.hand.append(CardInstance.create(_make_trainer_data("Discard A", "Item"), 0))
	player.hand.append(CardInstance.create(_make_trainer_data("Discard B", "Item"), 0))
	player.deck.append(CardInstance.create(_make_basic_pokemon_data("Search Target", "L", 120), 0))

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	var discard_items: Array = steps[0].get("items", [])
	return run_checks([
		assert_eq(steps.size(), 2, "Ultra Ball should create discard and search steps"),
		assert_eq(str(steps[0].get("id", "")), "discard_cards", "Ultra Ball first step should discard cards"),
		assert_eq(int(steps[0].get("min_select", 0)), 2, "Ultra Ball should require discarding exactly 2 cards"),
		assert_eq(int(steps[0].get("max_select", 0)), 2, "Ultra Ball should allow selecting exactly 2 cards"),
		assert_eq(discard_items.size(), 2, "Ultra Ball discard step should exclude the Ultra Ball card itself"),
	])
