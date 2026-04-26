class_name TestImportedTournamentCards
extends TestBase

const IMPORTED_CARD_PATHS := [
	"res://data/bundled_user/cards/CS6.5C_033.json",
	"res://data/bundled_user/cards/CS5DC_111.json",
	"res://data/bundled_user/cards/CSV1C_126.json",
	"res://data/bundled_user/cards/CSV7C_170.json",
	"res://data/bundled_user/cards/CS6aC_073.json",
	"res://data/bundled_user/cards/CS6.5C_064.json",
	"res://data/bundled_user/cards/CSV8C_177.json",
	"res://data/bundled_user/cards/CSV2C_126.json",
	"res://data/bundled_user/cards/CS5bC_125.json",
	"res://data/bundled_user/cards/CS6.5C_029.json",
	"res://data/bundled_user/cards/CSV7C_036.json",
	"res://data/bundled_user/cards/CSV7C_038.json",
	"res://data/bundled_user/cards/CSV7C_175.json",
	"res://data/bundled_user/cards/CSV7C_132.json",
	"res://data/bundled_user/cards/CSVH1C_050.json",
	"res://data/bundled_user/cards/CSV2C_111.json",
	"res://data/bundled_user/cards/CS5aC_104.json",
	"res://data/bundled_user/cards/CSV3C_031.json",
	"res://data/bundled_user/cards/CSV4C_117.json",
]


func test_imported_cards_exist_and_sandy_shocks_is_ancient() -> String:
	var checks: Array[String] = []
	for path: String in IMPORTED_CARD_PATHS:
		checks.append(assert_true(FileAccess.file_exists(path), "%s should be bundled" % path))
	var sandy := _load_card("res://data/bundled_user/cards/CSV7C_132.json")
	checks.append(assert_not_null(sandy, "Sandy Shocks card data should load"))
	checks.append(assert_true(sandy.is_ancient_pokemon(), "Sandy Shocks should be tagged Ancient"))
	return run_checks(checks)


func test_imported_static_trainer_tool_stadium_effects_are_registered() -> String:
	var processor := EffectProcessor.new()
	return run_checks([
		assert_not_null(processor.get_effect("a13ba21d54c2f0e8ea4f7d5b2ca37380"), "Dusk Ball should be registered"),
		assert_not_null(processor.get_effect("23ee27488d0c1317557a3106a1fc7db3"), "Enhanced Hammer should be registered"),
		assert_not_null(processor.get_effect("5ad6b7f0c1b9da35cd0d284de31b65a3"), "Letter of Encouragement should be registered"),
		assert_not_null(processor.get_effect("1b9696068a599e81c705bcb3648f0213"), "Roseanne's Backup should be registered"),
		assert_not_null(processor.get_effect("56a847e3573ccf9a991205169463218f"), "Emergency Jelly should be registered"),
		assert_not_null(processor.get_effect("3f2231d269066792b860d31b568aaf2a"), "Luxurious Cape should be registered"),
		assert_not_null(processor.get_effect("ed39476ac2c269054525ab0b0f79d58c"), "Mesagoza should be registered"),
		assert_not_null(processor.get_effect("2027b11b9630f8c24d2fdf19130a7111"), "Moonlit Hill should be registered"),
	])


func test_pokemon_effect_id_overrides_register_attack_and_ability_effects() -> String:
	var processor := EffectProcessor.new()
	var cards := [
		_load_card("res://data/bundled_user/cards/CS6.5C_033.json"),
		_load_card("res://data/bundled_user/cards/CS5DC_111.json"),
		_load_card("res://data/bundled_user/cards/CSV7C_170.json"),
		_load_card("res://data/bundled_user/cards/CS6aC_073.json"),
		_load_card("res://data/bundled_user/cards/CS6.5C_029.json"),
		_load_card("res://data/bundled_user/cards/CSV7C_038.json"),
		_load_card("res://data/bundled_user/cards/CSV7C_132.json"),
		_load_card("res://data/bundled_user/cards/CSV3C_031.json"),
		_load_card("res://data/bundled_user/cards/CSV7C_147.json"),
	]
	for card: CardData in cards:
		processor.register_pokemon_card(card)
	return run_checks([
		assert_true(processor.has_attack_effect("5a56387211377cf56bfeb12751a5eed3"), "Cresselia attack effect should register"),
		assert_not_null(processor.get_effect("32f943010bf08cb6046c0bcc64e1d7b8"), "Wyrdeer ability should register"),
		assert_true(processor.has_attack_effect("683af7fe3f0a254c5de433dfae8e1562"), "Minccino sweep should register"),
		assert_true(processor.has_attack_effect("73e3252852acd5361a563d7f88aef367"), "Zeraora bonus should register"),
		assert_true(processor.has_attack_effect("5a6897e20f399a4a0e2403f06a0c3e55"), "Ralts lock should register"),
		assert_not_null(processor.get_effect("15eb5f310fd523c4c468e4519e30ae70"), "Blaziken ability should register"),
		assert_true(processor.has_attack_effect("0d7ccbc99ac0f5108c6c7d7d5506f64b"), "Sandy Shocks attack should register"),
		assert_true(processor.has_attack_effect("2f6f444122be1e8d9af6c5a134f66572"), "Chi-Yu attacks should register"),
		assert_true(processor.get_effect("daab918dc820662c599221a8a1d85114") is AbilityMetalMaker, "Metang Metal Maker should register by effect_id"),
	])


func test_enhanced_hammer_discards_only_opponent_special_energy() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var opponent := state.players[1]
	var opp_active := _make_slot(_pokemon("Opponent", "C", 100), 1)
	var special_energy := CardInstance.create(_energy("Special", "C", "Special Energy"), 1)
	var basic_energy := CardInstance.create(_energy("Basic", "C"), 1)
	opp_active.attached_energy.append(special_energy)
	opp_active.attached_energy.append(basic_energy)
	opponent.active_pokemon = opp_active
	var hammer := CardInstance.create(_trainer("Enhanced Hammer", "Item", "23ee27488d0c1317557a3106a1fc7db3"), 0)
	processor.execute_card_effect(hammer, [{"enhanced_hammer_energy": [special_energy]}], state)
	return run_checks([
		assert_false(special_energy in opp_active.attached_energy, "Special Energy should be discarded"),
		assert_true(basic_energy in opp_active.attached_energy, "Basic Energy should remain attached"),
		assert_true(special_energy in opponent.discard_pile, "Discarded Special Energy should enter opponent discard"),
	])


func test_luxurious_cape_adds_hp_and_extra_prize_only_to_non_rulebox() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var basic_slot := _make_slot(_pokemon("Basic", "C", 100), 0)
	var cape := CardInstance.create(_trainer("Luxurious Cape", "Tool", "3f2231d269066792b860d31b568aaf2a"), 0)
	basic_slot.attached_tool = cape
	var ex_data := _pokemon("Rulebox", "C", 100)
	ex_data.mechanic = "ex"
	var ex_slot := _make_slot(ex_data, 0)
	ex_slot.attached_tool = CardInstance.create(_trainer("Luxurious Cape", "Tool", "3f2231d269066792b860d31b568aaf2a"), 0)
	return run_checks([
		assert_eq(processor.get_hp_modifier(basic_slot, state), 100, "Cape should give non-rulebox Pokemon +100 HP"),
		assert_eq(processor.get_knockout_prize_modifier(basic_slot, state), 1, "Cape should add 1 prize on KO"),
		assert_eq(processor.get_hp_modifier(ex_slot, state), 0, "Cape should not affect rulebox Pokemon"),
		assert_eq(processor.get_knockout_prize_modifier(ex_slot, state), 0, "Cape should not add prizes for rulebox Pokemon"),
	])


func test_wyrdeer_moves_any_energy_to_self_only_after_bench_to_active() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var player := state.players[0]
	var wyrdeer_card := _load_card("res://data/bundled_user/cards/CS5DC_111.json")
	processor.register_pokemon_card(wyrdeer_card)
	var wyrdeer := _make_slot(wyrdeer_card, 0)
	var benched := _make_slot(_pokemon("Bench", "C", 100), 0)
	var energy := CardInstance.create(_energy("Energy", "C"), 0)
	benched.attached_energy.append(energy)
	player.active_pokemon = wyrdeer
	player.bench.append(benched)
	var before_mark: bool = processor.can_use_ability(wyrdeer, state, 0)
	wyrdeer.mark_entered_active_from_bench(state.turn_number)
	var after_mark: bool = processor.execute_ability_effect(wyrdeer, 0, [{"wyrdeer_energy_to_self": [energy]}], state)
	return run_checks([
		assert_false(before_mark, "Wyrdeer ability should require entering Active from Bench this turn"),
		assert_true(after_mark, "Wyrdeer ability should resolve after bench-to-active marker"),
		assert_true(energy in wyrdeer.attached_energy, "Selected Energy should move to Wyrdeer"),
		assert_false(energy in benched.attached_energy, "Selected Energy should leave source Pokemon"),
	])


func test_sandy_shocks_bonus_applies_to_first_attack_only_and_ignores_weakness() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var sandy_card := _load_card("res://data/bundled_user/cards/CSV7C_132.json")
	processor.register_pokemon_card(sandy_card)
	var sandy := _make_slot(sandy_card, 0)
	sandy.attached_energy.append(CardInstance.create(_energy("Fighting A", "F"), 0))
	sandy.attached_energy.append(CardInstance.create(_energy("Fighting B", "F"), 0))
	sandy.attached_energy.append(CardInstance.create(_energy("Fighting C", "F"), 0))
	state.players[0].active_pokemon = sandy
	var first_attack: Dictionary = sandy_card.attacks[0]
	var second_attack: Dictionary = sandy_card.attacks[1]
	return run_checks([
		assert_eq(processor.get_attack_damage_modifier(sandy, null, first_attack, state), 70, "Magnetic Burst should gain +70 with 3 field Energy"),
		assert_eq(processor.get_attack_damage_modifier(sandy, null, second_attack, state), 0, "Power Gem should not gain Magnetic Burst bonus"),
		assert_true(processor.attack_ignores_weakness(sandy, 0, state), "Magnetic Burst should ignore Weakness"),
		assert_false(processor.attack_ignores_weakness(sandy, 1, state), "Power Gem should not ignore Weakness"),
	])


func test_interaction_cards_expose_choice_steps_before_execution() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	state.last_knockout_turn_against[0] = state.turn_number - 1
	var player := state.players[0]
	player.deck.append(CardInstance.create(_pokemon("Deck Pokemon", "C", 80), 0))
	player.deck.append(CardInstance.create(_energy("Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_pokemon("Discard Pokemon", "C", 80), 0))
	player.discard_pile.append(CardInstance.create(_trainer("Discard Tool", "Tool"), 0))
	player.discard_pile.append(CardInstance.create(_trainer("Discard Stadium", "Stadium"), 0))
	player.discard_pile.append(CardInstance.create(_energy("Discard Energy", "P"), 0))
	player.hand.append(CardInstance.create(_energy("Hand Psychic", "P"), 0))

	var dusk_ball := CardInstance.create(_trainer("Dusk Ball", "Item", "a13ba21d54c2f0e8ea4f7d5b2ca37380"), 0)
	var letter := CardInstance.create(_trainer("Letter", "Item", "5ad6b7f0c1b9da35cd0d284de31b65a3"), 0)
	var roseanne := CardInstance.create(_trainer("Roseanne", "Supporter", "1b9696068a599e81c705bcb3648f0213"), 0)
	var moonlit := CardInstance.create(_trainer("Moonlit Hill", "Stadium", "2027b11b9630f8c24d2fdf19130a7111"), 0)
	var dusk_effect := processor.get_effect(dusk_ball.card_data.effect_id)
	var letter_effect := processor.get_effect(letter.card_data.effect_id)
	var roseanne_effect := processor.get_effect(roseanne.card_data.effect_id)
	var moonlit_effect := processor.get_effect(moonlit.card_data.effect_id)
	return run_checks([
		assert_true(not dusk_effect.get_interaction_steps(dusk_ball, state).is_empty(), "Dusk Ball should ask which bottom-card Pokemon to take"),
		assert_true(not letter_effect.get_interaction_steps(letter, state).is_empty(), "Letter of Encouragement should ask which Basic Energy to take"),
		assert_true(not roseanne_effect.get_interaction_steps(roseanne, state).is_empty(), "Roseanne's Backup should ask which discard cards to return"),
		assert_true(not moonlit_effect.get_interaction_steps(moonlit, state).is_empty(), "Moonlit Hill should ask which Psychic Energy to discard"),
	])


func test_headless_trainer_entry_waits_for_enhanced_hammer_choice() -> String:
	var gsm := _make_gsm()
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var opp_active := _make_slot(_pokemon("Opponent", "C", 100), 1)
	var special_energy := CardInstance.create(_energy("Special", "C", "Special Energy"), 1)
	opp_active.attached_energy.append(special_energy)
	opponent.active_pokemon = opp_active
	var hammer := CardInstance.create(_trainer("Enhanced Hammer", "Item", "23ee27488d0c1317557a3106a1fc7db3"), 0)
	player.hand.append(hammer)
	var started: bool = bool(bridge.call("_try_play_trainer_with_interaction", 0, hammer))
	var result := run_checks([
		assert_true(started, "Enhanced Hammer should start an interaction"),
		assert_eq(bridge.get_pending_prompt_type(), "effect_interaction", "Enhanced Hammer should wait for target selection"),
		assert_true(hammer in player.hand, "Enhanced Hammer should not leave hand before selection resolves"),
		assert_true(special_energy in opp_active.attached_energy, "Special Energy should not be discarded before selection resolves"),
	])
	bridge.free()
	return result


func test_headless_stadium_entry_waits_for_moonlit_hill_choice() -> String:
	var gsm := _make_gsm()
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var player := gsm.game_state.players[0]
	var active := _make_slot(_pokemon("Active", "P", 100), 0)
	active.damage_counters = 50
	player.active_pokemon = active
	var energy := CardInstance.create(_energy("Psychic Energy", "P"), 0)
	player.hand.append(energy)
	gsm.game_state.stadium_card = CardInstance.create(_trainer("Moonlit Hill", "Stadium", "2027b11b9630f8c24d2fdf19130a7111"), 0)
	gsm.game_state.stadium_owner_index = 0
	var started: bool = bool(bridge.call("_try_use_stadium_with_interaction", 0))
	var result := run_checks([
		assert_true(started, "Moonlit Hill should start an interaction"),
		assert_eq(bridge.get_pending_prompt_type(), "effect_interaction", "Moonlit Hill should wait for Energy selection"),
		assert_true(energy in player.hand, "Psychic Energy should remain in hand before selection resolves"),
		assert_eq(active.damage_counters, 50, "Moonlit Hill should not heal before selection resolves"),
	])
	bridge.free()
	return result


func test_headless_ability_entry_waits_for_blaziken_energy_assignment() -> String:
	var gsm := _make_gsm()
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var player := gsm.game_state.players[0]
	var blaziken_card := _load_card("res://data/bundled_user/cards/CSV7C_038.json")
	gsm.effect_processor.register_pokemon_card(blaziken_card)
	var blaziken := _make_slot(blaziken_card, 0)
	player.active_pokemon = blaziken
	var energy := CardInstance.create(_energy("Fire Energy", "R"), 0)
	player.discard_pile.append(energy)
	var started: bool = bool(bridge.call("_try_use_ability_with_interaction", 0, blaziken, 0))
	var result := run_checks([
		assert_true(started, "Blaziken ex should start an Energy assignment interaction"),
		assert_eq(bridge.get_pending_prompt_type(), "effect_interaction", "Blaziken ex should wait for assignment selection"),
		assert_true(energy in player.discard_pile, "Energy should remain in discard before selection resolves"),
		assert_false(energy in blaziken.attached_energy, "Energy should not attach before selection resolves"),
	])
	bridge.free()
	return result


func test_metang_metal_maker_exposes_and_respects_assignment_choice() -> String:
	var state := _make_state()
	var player := state.players[0]
	var metang_card := _load_card("res://data/bundled_user/cards/CSV7C_147.json")
	var metang := _make_slot(metang_card, 0)
	var bench := _make_slot(_pokemon("Bench", "C", 100), 0)
	player.active_pokemon = metang
	player.bench.append(bench)
	player.deck.clear()
	var metal_a := CardInstance.create(_energy("Metal A", "M"), 0)
	var other := CardInstance.create(_trainer("Other", "Item"), 0)
	var metal_b := CardInstance.create(_energy("Metal B", "M"), 0)
	player.deck.append(metal_a)
	player.deck.append(other)
	player.deck.append(metal_b)

	var effect := AbilityMetalMaker.new(4, "M")
	var steps := effect.get_interaction_steps(metang.get_top_card(), state)
	var ctx := {
		AbilityMetalMaker.ASSIGNMENT_STEP_ID: [
			{"source": metal_b, "target": bench},
		],
	}
	effect.execute_ability(metang, 0, [ctx], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Metal Maker should expose one assignment step"),
		assert_eq(str(steps[0].get("ui_mode", "")), "card_assignment", "Metal Maker should use assignment UI"),
		assert_eq((steps[0].get("source_items", []) as Array).size(), 2, "Metal Maker should offer matching top-deck Metal Energy"),
		assert_eq((steps[0].get("target_items", []) as Array).size(), 2, "Metal Maker should allow assigning to any own Pokemon"),
		assert_true(metal_b in bench.attached_energy, "Selected Metal Energy should attach to the selected Pokemon"),
		assert_false(metal_a in metang.attached_energy, "Unselected Metal Energy should not be auto-attached"),
		assert_true(metal_a in player.deck, "Unselected Metal Energy should return to deck bottom group"),
		assert_true(other in player.deck, "Other viewed cards should return to deck bottom group"),
		assert_false(effect.can_use_ability(metang, state), "Metal Maker should be marked used after resolution"),
	])


func test_headless_ability_entry_waits_for_metang_metal_maker_choice() -> String:
	var gsm := _make_gsm()
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var player := gsm.game_state.players[0]
	var metang_card := _load_card("res://data/bundled_user/cards/CSV7C_147.json")
	gsm.effect_processor.register_pokemon_card(metang_card)
	var metang := _make_slot(metang_card, 0)
	player.active_pokemon = metang
	player.bench.append(_make_slot(_pokemon("Bench", "C", 100), 0))
	var metal_energy := CardInstance.create(_energy("Metal Energy", "M"), 0)
	player.deck.append(metal_energy)
	player.deck.append(CardInstance.create(_trainer("Other", "Item"), 0))
	var started: bool = bool(bridge.call("_try_use_ability_with_interaction", 0, metang, 0))
	var result := run_checks([
		assert_true(started, "Metang should start a Metal Maker assignment interaction"),
		assert_eq(bridge.get_pending_prompt_type(), "effect_interaction", "Metang should wait for assignment choice"),
		assert_true(metal_energy in player.deck, "Metal Energy should remain in deck before assignment resolves"),
		assert_false(metal_energy in metang.attached_energy, "Metal Energy should not auto-attach before choice"),
	])
	bridge.free()
	return result


func test_headless_attack_entry_waits_for_target_or_assignment_choice() -> String:
	var checks: Array[String] = []
	checks.append(_assert_attack_interaction_waits_for_cresselia_choice())
	checks.append(_assert_attack_interaction_waits_for_ralts_choice())
	checks.append(_assert_attack_interaction_waits_for_chi_yu_assignment())
	return run_checks(checks)


func _load_card(path: String) -> CardData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK or json.data is not Dictionary:
		return null
	return CardData.from_dict(json.data)


func _assert_attack_interaction_waits_for_cresselia_choice() -> String:
	var gsm := _make_gsm()
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var cresselia_card := _load_card("res://data/bundled_user/cards/CS6.5C_033.json")
	gsm.effect_processor.register_pokemon_card(cresselia_card)
	var cresselia := _make_slot(cresselia_card, 0)
	cresselia.attached_energy.append(CardInstance.create(_energy("Psychic Energy", "P"), 0))
	cresselia.damage_counters = 40
	gsm.game_state.players[0].active_pokemon = cresselia
	var defender := _make_slot(_pokemon("Defender", "C", 120), 1)
	var opp_bench := _make_slot(_pokemon("Opponent Bench", "C", 120), 1)
	gsm.game_state.players[1].active_pokemon = defender
	gsm.game_state.players[1].bench.append(opp_bench)
	var started: bool = bool(bridge.call("_try_use_attack_with_interaction", 0, cresselia, 0))
	var result := run_checks([
		assert_true(started, "Cresselia should start target selection"),
		assert_eq(bridge.get_pending_prompt_type(), "effect_interaction", "Cresselia should wait for opponent target choice"),
		assert_eq(cresselia.damage_counters, 40, "Cresselia should not move damage before target choice"),
		assert_eq(defender.damage_counters, 0, "Opponent Active should not receive fallback damage before choice"),
	])
	bridge.free()
	return result


func _assert_attack_interaction_waits_for_ralts_choice() -> String:
	var gsm := _make_gsm()
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var ralts_card := _load_card("res://data/bundled_user/cards/CS6.5C_029.json")
	gsm.effect_processor.register_pokemon_card(ralts_card)
	var ralts := _make_slot(ralts_card, 0)
	ralts.attached_energy.append(CardInstance.create(_energy("Psychic Energy", "P"), 0))
	gsm.game_state.players[0].active_pokemon = ralts
	var defender_data := _pokemon("Defender", "C", 120)
	defender_data.attacks = [
		{"name": "First", "cost": "C", "damage": "10", "text": ""},
		{"name": "Second", "cost": "C", "damage": "20", "text": ""},
	]
	var defender := _make_slot(defender_data, 1)
	gsm.game_state.players[1].active_pokemon = defender
	var started: bool = bool(bridge.call("_try_use_attack_with_interaction", 0, ralts, 0))
	var result := run_checks([
		assert_true(started, "Ralts should start attack-name selection"),
		assert_eq(bridge.get_pending_prompt_type(), "effect_interaction", "Ralts should wait for attack-name choice"),
		assert_eq(defender.effects.size(), 0, "Ralts should not fallback-lock the first attack before choice"),
	])
	bridge.free()
	return result


func _assert_attack_interaction_waits_for_chi_yu_assignment() -> String:
	var gsm := _make_gsm()
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var chi_yu_card := _load_card("res://data/bundled_user/cards/CSV3C_031.json")
	gsm.effect_processor.register_pokemon_card(chi_yu_card)
	var chi_yu := _make_slot(chi_yu_card, 0)
	chi_yu.attached_energy.append(CardInstance.create(_energy("Fire A", "R"), 0))
	chi_yu.attached_energy.append(CardInstance.create(_energy("Fire B", "R"), 0))
	gsm.game_state.players[0].active_pokemon = chi_yu
	var bench := _make_slot(_pokemon("Bench", "R", 100), 0)
	gsm.game_state.players[0].bench.append(bench)
	var deck_energy := CardInstance.create(_energy("Deck Fire", "R"), 0)
	gsm.game_state.players[0].deck.append(deck_energy)
	gsm.game_state.players[1].active_pokemon = _make_slot(_pokemon("Defender", "C", 120), 1)
	var started: bool = bool(bridge.call("_try_use_attack_with_interaction", 0, chi_yu, 1))
	var result := run_checks([
		assert_true(started, "Chi-Yu ex should start Energy assignment"),
		assert_eq(bridge.get_pending_prompt_type(), "effect_interaction", "Chi-Yu ex should wait for assignment choice"),
		assert_true(deck_energy in gsm.game_state.players[0].deck, "Fire Energy should remain in deck before assignment resolves"),
		assert_false(deck_energy in bench.attached_energy, "Fire Energy should not attach before assignment resolves"),
	])
	bridge.free()
	return result


func _make_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 4
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.bind_game_state_machine(gsm)
	return gsm


func _make_slot(card_data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	return slot


func _pokemon(name: String, energy_type: String, hp: int, stage: String = "Basic") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.attacks = [{"name": "Attack", "cost": "C", "damage": "10", "text": ""}]
	return cd


func _trainer(name: String, card_type: String, effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _energy(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd
