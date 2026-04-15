class_name TestGardevoirMiraidonTraceRegressions
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


func test_boss_orders_low_without_immediate_attack_window() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Weak Target", "Basic", "C", 40), 1))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BOSSS_ORDERS, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0, "Boss should stay low without an immediate attack window (got %f)" % score)


func test_counter_catcher_low_without_immediate_attack_window() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Weak Target", "Basic", "C", 40), 1))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.COUNTER_CATCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0, "Counter Catcher should stay low without an immediate attack window (got %f)" % score)


func test_iono_low_when_shell_fragile_and_hand_is_not_stuck() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Potion"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Switch"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 20.0, "Iono should stay low when shell is still fragile and hand is fine (got %f)" % score)


func test_heavy_ball_low_when_other_shell_search_exists() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.HISUIAN_HEAVY_BALL), 0)},
		gs,
		0
	)
	return assert_true(score <= 20.0, "Heavy Ball should stay low when other shell search already exists (got %f)" % score)


func test_heavy_ball_high_when_it_recovers_missing_ralts_from_prizes() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.HISUIAN_HEAVY_BALL), 0),
			"targets": [{"chosen_prize_basic": [CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)]}],
		},
		gs,
		0
	)
	return assert_true(score >= 200.0, "Heavy Ball should become a real shell action when it directly recovers the missing first Ralts from prizes (got %f)" % score)


func test_artazon_low_without_searchable_basic_targets() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.deck.append(CardInstance.create(_make_trainer_cd("Potion"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Switch"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0, "Artazon should stay low without searchable basics in deck (got %f)" % score)

