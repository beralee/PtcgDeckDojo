class_name TestGardevoirShellLock
extends TestBase

const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	return DeckStrategyGardevoirScript.new()


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.abilities.clear()
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy_cd(pname: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = card_type
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_player(pi: int = 0) -> PlayerState:
	var p := PlayerState.new()
	p.player_index = pi
	return p


func _make_game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := _make_player(pi)
		p.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi), pi)
		gs.players.append(p)
	return gs


func test_setup_prefers_ralts_over_scream_tail_and_munkidori_when_shell_is_thin() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0))
	var strategy := _new_strategy()
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	return assert_eq(active_name, DeckStrategyGardevoirScript.RALTS, "When the shell is thin, opening setup should prefer Ralts over Scream Tail or Munkidori")


func test_setup_prefers_ralts_over_flutter_mane_and_klefki_when_available() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.KLEFKI, "Basic", "M", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name := str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	return assert_eq(active_name, DeckStrategyGardevoirScript.RALTS, "Opening setup should now prefer Ralts over control basics because TM shell setup is the primary line")


func test_setup_uses_tm_carrier_active_when_two_ralts_are_available_for_backline() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var bench_indices: Array = choice.get("bench_hand_indices", [])
	var active_name := str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	var bench_names: Array[String] = []
	for idx_variant: Variant in bench_indices:
		var idx: int = int(idx_variant)
		if idx >= 0 and idx < player.hand.size():
			bench_names.append(str(player.hand[idx].card_data.name))
	var ok := active_name == DeckStrategyGardevoirScript.FLUTTER_MANE and bench_names.size() >= 2 and bench_names[0] == DeckStrategyGardevoirScript.RALTS and bench_names[1] == DeckStrategyGardevoirScript.RALTS
	return assert_true(ok, "When two Ralts are already available, the active should prefer a TM carrier while both Ralts stay on the bench for evolution (active=%s bench=%s)" % [active_name, str(bench_names)])


func test_dark_attach_to_munkidori_stays_negative_before_shell_is_online() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0), "target_slot": player.bench[0]},
		gs,
		0
	)
	return assert_true(score < 0.0, "Darkness Energy should stay negative on Munkidori before the Gardevoir shell is online (got %f)" % score)


func test_scream_tail_bench_stays_negative_before_shell_is_online() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0)
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Scream Tail should stay negative before the shell is online (got %f)" % score)


func test_radiant_greninja_bench_stays_negative_before_first_gardevoir_ex_online() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RADIANT_GRENINJA, "Basic", "W", 130), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Radiant Greninja should stay negative until the first Gardevoir ex is actually online (got %f)" % score)


func test_munkidori_bench_stays_negative_before_first_gardevoir_ex_online() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Munkidori should stay negative until the first Gardevoir ex is online (got %f)" % score)


func test_scream_tail_bench_stays_negative_until_first_gardevoir_ex_online() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Scream Tail should stay negative until the first Gardevoir ex is online (got %f)" % score)


func test_artazon_stays_low_after_two_ralts_are_already_on_board() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)},
		gs,
		0
	)
	return assert_true(score <= 20.0, "Artazon should cool off once two Ralts are already on board (got %f)" % score)


func test_nest_ball_turns_negative_once_two_ralts_are_already_on_board() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NEST_BALL), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Nest Ball should cool off once two Ralts are already on board and shell search should pivot to first Gardevoir ex instead (got %f)" % score)


func test_night_stretcher_stays_low_early_without_live_recovery_need() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 20.0, "Night Stretcher should stay low early without a real recovery need (got %f)" % score)


func test_tm_evolution_cools_off_once_first_gardevoir_is_online_even_without_kirlia() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0),
			"target_slot": player.active_pokemon
		},
		gs,
		0
	)
	return assert_true(score <= 20.0, "TM Evolution should cool off once the first Gardevoir ex is online, even if no Kirlia remains (got %f)" % score)


func test_munkidori_is_not_treated_as_required_shell_piece_after_stage2_shell_establishes() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA), 0)
	var drifloon := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.bench.append(drifloon)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)},
		gs,
		0
	)
	return assert_true(score <= 40.0, "Munkidori should stop being treated like a required shell body once a stage2 shell and attacker already exist (got %f)" % score)


func test_munkidori_stays_negative_until_a_real_attacker_exists_after_first_gardevoir() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var munkidori_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)},
		gs,
		0
	)
	var drifloon_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(munkidori_score < 0.0, "Munkidori should stay negative right after the first Gardevoir ex if no real attacker exists yet (got %f)" % munkidori_score),
		assert_true(drifloon_score > munkidori_score, "A real attacker should outrank Munkidori immediately after the first Gardevoir ex lands"),
	])


func test_boss_orders_stays_low_without_immediate_scream_tail_window() -> String:
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Weak Target", "Basic", "C", 40), 1))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BOSSS_ORDERS, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0, "Boss's Orders should stay low without an immediate Scream Tail bench-KO window (got %f)" % score)


func test_heavy_ball_recovers_second_ralts_as_real_shell_action() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var score: float = strategy.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.HISUIAN_HEAVY_BALL), 0),
			"targets": [{"chosen_prize_basic": [CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)]}],
		},
		gs,
		0
	)
	return assert_true(score >= 200.0, "Heavy Ball should become a real shell action when it recovers the missing second Ralts from prizes (got %f)" % score)


func test_shell_lock_stays_active_until_first_gardevoir_ex_even_with_double_kirlia() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var strategy := _new_strategy()
	var scream_tail_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)},
		gs,
		0
	)
	return assert_true(scream_tail_score < 0.0, "Shell lock should stay active until the first Gardevoir ex is online, even if two Kirlia are already on board (got %f)" % scream_tail_score)


func test_ultra_ball_outranks_secret_box_once_kirlia_is_online_but_first_gardevoir_ex_is_missing() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	var strategy := _new_strategy()
	var ultra_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0)},
		gs,
		0
	)
	var secret_box_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SECRET_BOX), 0)},
		gs,
		0
	)
	return assert_true(ultra_score > secret_box_score, "Once Kirlia is online but the first Gardevoir ex is missing, Ultra Ball should outrank Secret Box (ultra=%f secret=%f)" % [ultra_score, secret_box_score])


func test_search_item_prefers_ultra_ball_over_setup_items_once_kirlia_is_online() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var items := [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SECRET_BOX), 0),
	]
	var strategy := _new_strategy()
	var picked: Variant = strategy.pick_search_item(items, gs, 0)
	var picked_name := str((picked as CardInstance).card_data.name) if picked is CardInstance else ""
	return assert_eq(picked_name, DeckStrategyGardevoirScript.ULTRA_BALL, "Search should hard-pivot to Ultra Ball once Kirlia is online and the first Gardevoir ex is missing")


func test_night_stretcher_becomes_primary_recovery_when_it_recovers_first_gardevoir_ex() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA), 0))
	var items := [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
	]
	var strategy := _new_strategy()
	var picked: Variant = strategy.pick_search_item(items, gs, 0)
	var picked_name := str((picked as CardInstance).card_data.name) if picked is CardInstance else ""
	return assert_eq(picked_name, DeckStrategyGardevoirScript.NIGHT_STRETCHER, "If the first Gardevoir ex is already in discard and Kirlia is online, recovery should outrank broader setup items")
