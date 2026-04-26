class_name TestGardevoirStrategyChurn
extends TestBase

const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")

const GARDEVOIR_SET := "CSV2C"
const GARDEVOIR_INDEX := "055"
const KIRLIA_SET := "CS6.5C"
const KIRLIA_INDEX := "030"
const RALTS_SET := "CSV2C"
const RALTS_INDEX := "053"
const DRIFLOON_SET := "CSV2C"
const DRIFLOON_INDEX := "060"
const MUNKIDORI_SET := "CSV8C"
const MUNKIDORI_INDEX := "094"
const FLUTTER_MANE_SET := "CSV7C"
const FLUTTER_MANE_INDEX := "109"
const POFFIN_SET := "CSV7C"
const POFFIN_INDEX := "177"
const TM_EVOLUTION_SET := "CSV5C"
const TM_EVOLUTION_INDEX := "119"


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	return DeckStrategyGardevoirScript.new()


func _make_energy_cd(name: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(name: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_scream_tail_cd() -> CardData:
	var cd := CardData.new()
	cd.name = DeckStrategyGardevoirScript.SCREAM_TAIL
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = "P"
	cd.hp = 90
	cd.attacks = [
		{"name": "Scream Tail Attack", "cost": "PC", "damage": "", "text": "", "is_vstar_power": false},
	]
	return cd


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
		p.active_pokemon = _make_slot(_make_placeholder_pokemon("Active%d" % pi), pi)
		gs.players.append(p)
	return gs


func _make_placeholder_pokemon(name: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = "C"
	cd.hp = 100
	return cd


func _make_named_pokemon(name: String, name_en: String, hp: int = 100) -> CardData:
	var cd := _make_placeholder_pokemon(name)
	cd.name_en = name_en
	cd.hp = hp
	return cd


func _fill_prizes(player: PlayerState, count: int) -> void:
	for i: int in count:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize%d" % i), player.player_index))


func _require_card(set_code: String, card_index: String) -> CardData:
	var card_data: CardData = CardDatabase.get_card(set_code, card_index)
	assert_not_null(card_data, "Expected CardDatabase to provide %s/%s" % [set_code, card_index])
	return card_data


func _build_online_shell_state() -> GameState:
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0))
	return gs


func _build_online_shell_with_late_tm_state() -> GameState:
	var gs := _make_game_state(10)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.bench.append(drifloon)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_online_shell_with_mid_tm_state() -> GameState:
	var gs := _build_online_shell_with_late_tm_state()
	gs.turn_number = 6
	return gs


func _build_transition_shell_without_munkidori_state() -> GameState:
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_online_shell_with_recovery_bait_state() -> GameState:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic D", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic E", "P"), 0))
	return gs


func _build_scream_tail_attack_ready_push_state() -> GameState:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_scream_tail_manual_psychic_push_state() -> GameState:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Colorless A", "C"), 0))
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_drifloon_manual_psychic_push_state() -> GameState:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 20
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_online_shell_without_attacker_state() -> GameState:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_first_gardevoir_without_kirlia_state() -> GameState:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_first_gardevoir_without_kirlia_with_attacker_in_discard_state() -> GameState:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic D", "P"), 0))
	return gs


func _build_first_gardevoir_without_kirlia_with_bench_handoff_targets_state() -> GameState:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var player := gs.players[0]
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.bench.append(_make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic D", "P"), 0))
	return gs


func _build_online_shell_without_attacker_vs_weak_bench_state() -> GameState:
	var gs := _build_online_shell_without_attacker_state()
	var opponent := gs.players[1]
	opponent.bench.append(_make_slot(_make_placeholder_pokemon("Pidgey"), 1))
	opponent.bench[0].pokemon_stack[0].card_data.hp = 60
	return gs


func _build_unready_attack_shell_vs_weak_bench_state() -> GameState:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var opponent := gs.players[1]
	opponent.bench.append(_make_slot(_make_placeholder_pokemon("Pidgey"), 1))
	opponent.bench[0].pokemon_stack[0].card_data.hp = 60
	return gs


func _build_online_shell_with_unready_attacker_body_state() -> GameState:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	return gs


func _build_charizard_online_shell_with_unready_attacker_body_state() -> GameState:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var opponent := gs.players[1]
	opponent.active_pokemon = _make_slot(_make_named_pokemon("喷火龙ex", "Charizard ex", 330), 1)
	opponent.bench.append(_make_slot(_make_named_pokemon("波波", "Pidgey", 60), 1))
	return gs


func _build_online_shell_with_attacker_in_discard_state() -> GameState:
	var gs := _build_online_shell_without_attacker_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	player.deck.append(CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0))
	return gs


func _build_online_shell_with_support_only_in_discard_state() -> GameState:
	var gs := _build_online_shell_without_attacker_state()
	var player := gs.players[0]
	var manaphy := _make_placeholder_pokemon(DeckStrategyGardevoirScript.MANAPHY)
	manaphy.energy_type = "W"
	manaphy.hp = 70
	player.discard_pile.append(CardInstance.create(manaphy, 0))
	return gs


func _build_deck_out_pressure_attack_ready_state(deck_count: int = 4) -> GameState:
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler A"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler B"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler C"), 0))
	for i: int in deck_count:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck%d" % i), 0))
	_fill_prizes(player, 3)
	_fill_prizes(opponent, 4)
	return gs


func _build_online_shell_attack_ready_state() -> GameState:
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var opponent := gs.players[1]
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness A", "D"), 0))
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_trainer_cd("DeckLive%d" % i), 0))
	_fill_prizes(player, 3)
	_fill_prizes(opponent, 4)
	return gs


func _build_online_shell_with_ready_drifloon_vs_weak_bench_state() -> GameState:
	var gs := _build_online_shell_state()
	var opponent := gs.players[1]
	opponent.bench.append(_make_slot(_make_placeholder_pokemon("Pidgey"), 1))
	opponent.bench[0].pokemon_stack[0].card_data.hp = 60
	return gs


func _build_early_artazon_opening_state() -> GameState:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_scream_tail_cd(), 0)
	player.bench.clear()
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0))
	return gs


func test_refinement_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var kirlia_slot: PokemonSlot = player.bench[1]
	player.hand.append(CardInstance.create(_make_trainer_cd("Potion"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Nest Ball"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Darkness A", "D"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": kirlia_slot, "ability_index": 0},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and Drifloon is already attack-ready, Refinement should cool off draw churn (got %f)" % score)


func test_buddy_buddy_poffin_shuts_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0)},
		gs,
		0
	)
	return assert_true(score <= 20.0,
		"Once Gardevoir shell and a ready attacker are online, Buddy-Buddy Poffin should stop acting like a live setup card (got %f)" % score)


func test_extra_flutter_mane_bench_shuts_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(FLUTTER_MANE_SET, FLUTTER_MANE_INDEX), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once the shell is online, extra control basics like Flutter Mane should stop taking bench space (got %f)" % score)


func test_first_munkidori_bench_cools_off_once_transition_shell_is_online() -> String:
	var gs := _build_transition_shell_without_munkidori_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	return assert_true(score <= 30.0,
		"Once Gardevoir shell is online and a live attacker already exists, first Munkidori should cool off instead of taking a full development turn (got %f)" % score)


func test_dark_attach_to_munkidori_cools_off_once_transition_shell_is_online() -> String:
	var gs := _build_transition_shell_without_munkidori_state()
	var player := gs.players[0]
	var munkidori := _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(munkidori)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0),
			"target_slot": munkidori,
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once transition shell is online and Drifloon is already live, first Darkness attachment to Munkidori should cool off unless a real conversion window exists (got %f)" % score)


func test_tm_evolution_attach_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_late_tm_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_require_card(TM_EVOLUTION_SET, TM_EVOLUTION_INDEX), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and a ready attacker already exists, late TM Evolution attachment should cool off (got %f)" % score)


func test_tm_evolution_granted_attack_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_late_tm_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "granted_attack",
			"source_slot": player.active_pokemon,
			"granted_attack_data": {"name": "Evolution"},
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and a ready attacker already exists, late TM Evolution attack should stop outranking conversion lines (got %f)" % score)


func test_tm_evolution_attach_cools_off_in_midgame_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_mid_tm_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_require_card(TM_EVOLUTION_SET, TM_EVOLUTION_INDEX), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and a ready attacker already exists, midgame TM Evolution attachment should also cool off instead of stealing the turn (got %f)" % score)


func test_tm_evolution_granted_attack_cools_off_in_midgame_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_mid_tm_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "granted_attack",
			"source_slot": player.active_pokemon,
			"granted_attack_data": {"name": "Evolution"},
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and a ready attacker already exists, midgame TM Evolution attack should cool off instead of outranking conversion lines (got %f)" % score)


func test_tm_evolution_cools_off_in_late_shell_even_without_ready_attacker() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_require_card(TM_EVOLUTION_SET, TM_EVOLUTION_INDEX), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var attack_score: float = s.score_action_absolute(
		{
			"kind": "granted_attack",
			"source_slot": player.active_pokemon,
			"granted_attack_data": {"name": "Evolution"},
		},
		gs,
		0
	)
	var ok := attach_score <= 50.0 and attack_score <= 50.0
	return assert_true(ok,
		"Once Gardevoir shell is online in late game, TM Evolution should cool off even without a ready attacker (attach=%f attack=%f)" % [attach_score, attack_score])


func test_night_stretcher_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_recovery_bait_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 100.0,
		"Once the shell is online and recovery is not urgent, Night Stretcher should cool off instead of outranking conversion (got %f)" % score)


func test_super_rod_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_with_recovery_bait_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SUPER_ROD), 0)},
		gs,
		0
	)
	return assert_true(score <= 100.0,
		"Once the shell is online and discard fuel is already healthy, Super Rod should cool off instead of churning resources (got %f)" % score)


func test_prof_turo_cools_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.PROF_TURO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell is online and there is no urgent EX rescue, Professor Turo should not outrank conversion just because energies can be dumped (got %f)" % score)


func test_dark_energy_can_finish_active_scream_tail_attack() -> String:
	var gs := _build_scream_tail_attack_ready_push_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score >= 200.0,
		"When active Scream Tail is one colorless short, Darkness Energy should be allowed to finish the attack instead of being hard-forbidden (got %f)" % score)


func test_tm_evolution_should_not_outrank_finishing_active_scream_tail_attack() -> String:
	var gs := _build_scream_tail_attack_ready_push_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var dark_attach: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var tm_attach: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(dark_attach >= tm_attach,
		"When active Scream Tail can be made attack-ready immediately, TM Evolution should not outrank the direct attack setup line (dark=%f tm=%f)" % [dark_attach, tm_attach])


func test_tm_evolution_granted_attack_should_not_outrank_finishing_active_scream_tail_attack() -> String:
	var gs := _build_scream_tail_attack_ready_push_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var dark_attach: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	var tm_attack: float = s.score_action_absolute(
		{
			"kind": "granted_attack",
			"source_slot": player.active_pokemon,
			"granted_attack_data": {"name": "Evolution"},
		},
		gs,
		0
	)
	return assert_true(dark_attach >= tm_attack,
		"When active Scream Tail is one attachment away from attacking, TM Evolution's granted attack should not steal the turn (dark=%f tm_attack=%f)" % [dark_attach, tm_attack])


func test_manual_psychic_attach_can_finish_active_drifloon_attack() -> String:
	var gs := _build_drifloon_manual_psychic_push_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_energy",
			"card": CardInstance.create(_make_energy_cd("Psychic B", "P"), 0),
			"target_slot": player.active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score > 0.0,
		"When active Drifloon is one attachment away from attacking and no attacker is ready, manual Psychic attachment should stay online instead of being treated as dead tempo (got %f)" % score)


func test_search_priority_prefers_rebuilding_attacker_over_support_piece_once_shell_is_online() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var drifloon := CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var munkidori := CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	var all_items: Array = [munkidori, drifloon]
	var step := {"id": "buddy_poffin_pokemon"}
	var context := {"game_state": gs, "player_index": 0, "all_items": all_items}
	var drifloon_score: float = s.score_interaction_target(drifloon, step, context)
	var munkidori_score: float = s.score_interaction_target(munkidori, step, context)
	return assert_true(drifloon_score > munkidori_score,
		"Once the shell is online but no attacker remains on board, search effects should prefer rebuilding Drifloon over another support piece (drifloon=%f munkidori=%f)" % [drifloon_score, munkidori_score])


func test_nest_ball_prioritizes_first_attacker_body_rebuild_once_stage2_shell_is_online() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var nest_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NEST_BALL), 0)},
		gs,
		0
	)
	var stretcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(nest_score > stretcher_score,
		"Once the stage2 shell is online but no attacker body exists, Nest Ball should outrank blind Night Stretcher lines (nest=%f stretcher=%f)" % [nest_score, stretcher_score])


func test_turn_plan_switches_to_rebuild_attacker_once_stage2_shell_is_online_without_attacker_body() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "rebuild_attacker", "Once the stage2 shell is online but no attacker body exists, the turn intent should switch to rebuild_attacker"),
		assert_true(bool(plan.get("flags", {}).get("shell_online", false)), "Stage2 shell should be marked online in the rebuild-attacker window"),
	])


func test_first_gardevoir_online_without_kirlia_still_switches_to_rebuild_attacker() -> String:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "rebuild_attacker", "Once the first Gardevoir ex is online but no attacker body exists yet, intent should still pivot to rebuild_attacker even without Kirlia"),
		assert_true(bool(plan.get("flags", {}).get("has_gardevoir_ex", false)), "The rebuild-attacker window should recognize the first Gardevoir ex as online"),
	])


func test_night_stretcher_stays_low_when_first_attacker_body_is_missing_but_no_attacker_is_in_discard() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the stage2 shell is online but no attacker is in discard, Night Stretcher should stay low and let the deck rebuild a fresh attacker body first (got %f)" % score)


func test_night_stretcher_stays_low_when_only_support_target_is_in_discard() -> String:
	var gs := _build_online_shell_with_support_only_in_discard_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the online shell only has support bodies like Manaphy in discard, Night Stretcher should stay low instead of stealing the turn (got %f)" % score)


func test_bench_priority_prefers_rebuilding_attacker_over_ralts_once_shell_is_online() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var drifloon_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)},
		gs,
		0
	)
	var ralts_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)},
		gs,
		0
	)
	var munkidori_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	var ok := drifloon_score > ralts_score and drifloon_score > munkidori_score and ralts_score <= 20.0 and munkidori_score <= 20.0
	return assert_true(ok,
		"Once the shell is online but no attacker remains, hand benching should rebuild Drifloon while cooling off Ralts and Munkidori (drifloon=%f ralts=%f munkidori=%f)" % [drifloon_score, ralts_score, munkidori_score])


func test_first_gardevoir_online_without_kirlia_still_prefers_rebuilding_attacker_over_ralts() -> String:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var s := _new_strategy()
	var drifloon_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)},
		gs,
		0
	)
	var ralts_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)},
		gs,
		0
	)
	return assert_true(drifloon_score > ralts_score,
		"Even with only the first Gardevoir ex online, attacker rebuild should outrank extra Ralts padding (drifloon=%f ralts=%f)" % [drifloon_score, ralts_score])


func test_first_gardevoir_online_without_kirlia_search_still_prefers_attacker_rebuild_over_ralts() -> String:
	var gs := _build_first_gardevoir_without_kirlia_state()
	var s := _new_strategy()
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var ralts_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(drifloon_score > ralts_score,
		"Even with only the first Gardevoir ex online, search routing should still prefer rebuilding a real attacker over another Ralts (drifloon=%f ralts=%f)" % [drifloon_score, ralts_score])


func test_first_gardevoir_online_without_kirlia_night_stretcher_prefers_attacker_rebuild() -> String:
	var gs := _build_first_gardevoir_without_kirlia_with_attacker_in_discard_state()
	var s := _new_strategy()
	var action_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	var drifloon_score: float = s._score_night_stretcher_choice_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		gs,
		0
	)
	var ralts_score: float = s._score_night_stretcher_choice_target(
		CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
		gs,
		0
	)
	return run_checks([
		assert_true(action_score >= 200.0, "Once the first Gardevoir ex is online and fuel exists, Night Stretcher should become a real attacker rebuild action even without Kirlia (got %f)" % action_score),
		assert_true(drifloon_score > ralts_score, "Night Stretcher target routing should prefer Drifloon rebuild over extra Ralts padding once the first Gardevoir ex is online (drifloon=%f ralts=%f)" % [drifloon_score, ralts_score]),
	])


func test_first_gardevoir_online_without_kirlia_handoff_prefers_attacker_body_over_ralts() -> String:
	var gs := _build_first_gardevoir_without_kirlia_with_bench_handoff_targets_state()
	var player := gs.players[0]
	var s := _new_strategy()
	var drifloon_slot: PokemonSlot = null
	var ralts_slot: PokemonSlot = null
	for slot: PokemonSlot in player.bench:
		if slot.get_pokemon_name() == DeckStrategyGardevoirScript.DRIFLOON:
			drifloon_slot = slot
		elif slot.get_pokemon_name() == DeckStrategyGardevoirScript.RALTS and ralts_slot == null:
			ralts_slot = slot
	var context := {"game_state": gs, "player_index": 0}
	var drifloon_score: float = s._score_handoff_target(drifloon_slot, "pivot_target", context)
	var ralts_score: float = s._score_handoff_target(ralts_slot, "pivot_target", context)
	return assert_true(drifloon_score > ralts_score,
		"Once the first Gardevoir ex is online, handoff routing should prefer the attacker body over extra Ralts padding even without Kirlia (drifloon=%f ralts=%f)" % [drifloon_score, ralts_score])


func test_first_gardevoir_online_without_kirlia_post_stage2_handoff_live_with_attacker_body_and_fuel() -> String:
	var gs := _build_first_gardevoir_without_kirlia_with_bench_handoff_targets_state()
	var s := _new_strategy()
	return assert_true(
		s._post_stage2_handoff_live(gs, gs.players[0], 0),
		"Once the first Gardevoir ex is online, an attacker body exists, and discard fuel is ready, post-stage2 handoff should already be live even without Kirlia"
	)


func test_rebuild_attacker_closed_loop_uses_bridge_target_as_owner_once_first_gardevoir_is_online() -> String:
	var gs := _build_first_gardevoir_without_kirlia_with_attacker_in_discard_state()
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	var contract: Dictionary = s.build_turn_contract(gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "rebuild_attacker_closed_loop", "First Gardevoir online plus attacker-in-discard fuel should enter rebuild_attacker_closed_loop"),
		assert_eq(str(plan.get("targets", {}).get("primary_attacker_name", "")), DeckStrategyGardevoirScript.DRIFLOON, "Closed-loop rebuild should treat the bridge attacker as the primary attacker target"),
		assert_eq(str(plan.get("targets", {}).get("pivot_target_name", "")), DeckStrategyGardevoirScript.DRIFLOON, "Closed-loop rebuild should pivot toward the bridge attacker instead of Gardevoir ex"),
		assert_eq(str(contract.get("owner", {}).get("turn_owner_name", "")), DeckStrategyGardevoirScript.DRIFLOON, "Closed-loop rebuild contract owner should move onto the bridge attacker"),
	])


func test_ralts_bench_cools_off_once_online_shell_already_has_an_unready_attacker_body() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var ralts_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0)},
		gs,
		0
	)
	var munkidori_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(ralts_score <= 20.0, "Once the shell is online and an attacker body already exists, extra Ralts should cool off instead of rebuilding more shell (got %f)" % ralts_score),
		assert_true(munkidori_score <= 20.0, "Once the shell is online and an attacker body already exists, first Munkidori should also stay cooled off (got %f)" % munkidori_score),
	])


func test_support_basics_turn_negative_once_stage2_shell_has_attacker_body() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var flutter_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(FLUTTER_MANE_SET, FLUTTER_MANE_INDEX), 0)},
		gs,
		0
	)
	var munkidori_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(flutter_score < 0.0, "Once Gardevoir ex is online and an attacker body exists, Flutter Mane should stop padding the bench (got %f)" % flutter_score),
		assert_true(munkidori_score < 0.0, "Once Gardevoir ex is online and an attacker body exists, Munkidori should stay off the bench until a real conversion window exists (got %f)" % munkidori_score),
	])


func test_night_stretcher_outranks_poffin_and_heavy_ball_when_online_shell_needs_attacker_recovery() -> String:
	var gs := _build_online_shell_with_attacker_in_discard_state()
	var s := _new_strategy()
	var stretcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	var poffin_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0)},
		gs,
		0
	)
	var heavy_ball_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.HISUIAN_HEAVY_BALL), 0)},
		gs,
		0
	)
	var ok := stretcher_score > poffin_score and stretcher_score > heavy_ball_score and stretcher_score >= 250.0
	return assert_true(ok,
		"Once the shell is online but no ready attacker exists and one is sitting in discard, Night Stretcher should outrank Poffin/Heavy Ball recovery filler (stretcher=%f poffin=%f heavy=%f)" % [stretcher_score, poffin_score, heavy_ball_score])


func test_night_stretcher_cools_off_when_unready_attacker_body_already_exists() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	var s := _new_strategy()
	var stretcher_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	return assert_true(stretcher_score <= 100.0,
		"When an unready attacker body already exists on board, Night Stretcher should cool off instead of acting like urgent recovery just because another attacker is in discard (got %f)" % stretcher_score)


func test_night_stretcher_choice_prefers_real_attacker_over_munkidori_in_transition_shell() -> String:
	var gs := _build_online_shell_with_attacker_in_discard_state()
	var player := gs.players[0]
	player.discard_pile.clear()
	player.discard_pile.append(CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0))
	var munkidori_cd := _make_placeholder_pokemon(DeckStrategyGardevoirScript.MUNKIDORI)
	munkidori_cd.energy_type = "D"
	munkidori_cd.hp = 110
	player.discard_pile.append(CardInstance.create(munkidori_cd, 0))
	var s := _new_strategy()
	var drifloon: CardInstance = player.discard_pile[0]
	var munkidori: CardInstance = player.discard_pile[1]
	var drifloon_score: float = s.score_interaction_target(drifloon, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	var munkidori_score: float = s.score_interaction_target(munkidori, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	return assert_true(drifloon_score > munkidori_score,
		"Night Stretcher should prefer rebuilding a real attacker over recovering Munkidori in transition-shell states (drifloon=%f munkidori=%f)" % [drifloon_score, munkidori_score])


func test_night_stretcher_choice_prefers_real_attacker_over_manaphy_in_transition_shell() -> String:
	var gs := _build_online_shell_with_attacker_in_discard_state()
	var player := gs.players[0]
	var manaphy := _make_placeholder_pokemon(DeckStrategyGardevoirScript.MANAPHY)
	manaphy.energy_type = "W"
	manaphy.hp = 70
	player.discard_pile.append(CardInstance.create(manaphy, 0))
	var s := _new_strategy()
	var drifloon: CardInstance = player.discard_pile[0]
	var manaphy_card: CardInstance = player.discard_pile[1]
	var drifloon_score: float = s.score_interaction_target(drifloon, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	var manaphy_score: float = s.score_interaction_target(manaphy_card, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	return assert_true(drifloon_score > manaphy_score,
		"Night Stretcher should prefer rebuilding a real attacker over recovering Manaphy in transition-shell states (drifloon=%f manaphy=%f)" % [drifloon_score, manaphy_score])


func test_night_stretcher_choice_prefers_first_gardevoir_over_munkidori_when_stage2_missing() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.discard_pile.append(CardInstance.create(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	var munkidori_cd := _make_placeholder_pokemon(DeckStrategyGardevoirScript.MUNKIDORI)
	munkidori_cd.energy_type = "D"
	munkidori_cd.hp = 110
	player.discard_pile.append(CardInstance.create(munkidori_cd, 0))
	var s := _new_strategy()
	var gardevoir: CardInstance = player.discard_pile[0]
	var munkidori: CardInstance = player.discard_pile[1]
	var gardevoir_score: float = s.score_interaction_target(gardevoir, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	var munkidori_score: float = s.score_interaction_target(munkidori, {"id": "night_stretcher_choice"}, {"game_state": gs, "player_index": 0})
	return assert_true(gardevoir_score > munkidori_score,
		"Night Stretcher should prefer the first Gardevoir ex over Munkidori while the stage2 shell is still missing (gard=%f munk=%f)" % [gardevoir_score, munkidori_score])


func test_iono_stays_low_while_first_gardevoir_is_still_missing() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler A"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler B"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"While the first Gardevoir ex is still missing, Iono should stay low instead of interrupting shell completion (got %f)" % score)


func test_prof_turo_stays_low_while_first_gardevoir_is_still_missing() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.PROF_TURO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"While the first Gardevoir ex is still missing, Professor Turo should stay low instead of stealing the rebuild turn (got %f)" % score)


func test_refinement_shuts_off_under_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[1],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the deck is almost empty and an attacker is already online, Kirlia's Refinement should shut off instead of spending more deck (got %f)" % score)


func test_iono_shuts_off_under_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var iono_card: CardInstance = player.hand[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": iono_card,
			"targets": [],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When the deck is under deck-out pressure and an attacker is already ready, Iono should shut off instead of burning more draws (got %f)" % score)


func test_refinement_shuts_off_under_moderate_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state(8)
	var s := _new_strategy()
	var player := gs.players[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[1],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When only eight cards remain and an attacker is already online, Kirlia's Refinement should already cool off to avoid self-decking (got %f)" % score)


func test_iono_shuts_off_under_moderate_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state(8)
	var s := _new_strategy()
	var player := gs.players[0]
	var iono_card: CardInstance = player.hand[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": iono_card,
			"targets": [],
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When only eight cards remain and an attacker is already online, Iono should stop burning deck on redraw churn (got %f)" % score)


func test_iono_shuts_off_once_shell_and_attacker_are_online_without_real_comeback_need() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var iono_card: CardInstance = player.hand[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": iono_card,
			"targets": [],
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"Once the shell and a ready attacker are already online, Iono should cool off to a low score unless the game truly needs a comeback reset (got %f)" % score)


func test_iono_shuts_off_with_stable_hand_once_shell_and_attacker_are_online_even_if_behind() -> String:
	var gs := _build_online_shell_state()
	var player := gs.players[0]
	var opponent := gs.players[1]
	player.hand.clear()
	player.prizes.clear()
	opponent.prizes.clear()
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler A"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler B"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Filler C"), 0))
	_fill_prizes(player, 4)
	_fill_prizes(opponent, 3)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Even when slightly behind, Iono should stay off once the shell and a ready attacker are online and the hand is stable (got %f)" % score)


func test_radiant_greninja_bench_shuts_off_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_basic_to_bench",
			"card": CardInstance.create(_make_placeholder_pokemon(DeckStrategyGardevoirScript.RADIANT_GRENINJA), 0),
		},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Radiant Greninja should stay off once the shell and a ready attacker are already online, instead of burning a bench slot for late churn (got %f)" % score)


func test_ralts_bench_shuts_off_under_moderate_deck_out_pressure_once_attack_is_ready() -> String:
	var gs := _build_deck_out_pressure_attack_ready_state(8)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_basic_to_bench",
			"card": CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
		},
		gs,
		0
	)
	return assert_true(score <= 50.0,
		"When only eight cards remain and an attacker is already online, rebuilding another Ralts line should cool off instead of outranking conversion (got %f)" % score)


func test_artazon_scores_as_live_opening_stadium_in_absolute_strategy_path() -> String:
	var gs := _build_early_artazon_opening_state()
	var s := _new_strategy()
	var player := gs.players[0]
	var stadium_card: CardInstance = player.hand[0]
	var score: float = s.score_action_absolute(
		{
			"kind": "play_stadium",
			"card": stadium_card,
			"targets": [],
		},
		gs,
		0
	)
	return assert_true(score >= 200.0,
		"Artazon should be treated as a live early-game setup action in the absolute strategy path instead of falling through to zero (got %f)" % score)


func test_super_rod_stays_negative_during_shell_lock_without_real_recovery_targets() -> String:
	var gs := _build_shell_lock_with_empty_night_stretcher_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SUPER_ROD), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"During shell lock, Super Rod should stay negative if it is not actually recovering a core shell piece or attacker (got %f)" % score)


func test_manaphy_bench_stays_negative_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_basic_to_bench",
			"card": CardInstance.create(_make_placeholder_pokemon(DeckStrategyGardevoirScript.MANAPHY), 0),
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Manaphy should stay off once the shell and a ready attacker are already online instead of stealing a bench slot from conversion (got %f)" % score)


func test_munkidori_ability_turns_negative_without_immediate_ko_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	player.bench.append(_make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0))
	player.bench[2].attached_energy.append(CardInstance.create(_make_energy_cd("Darkness A", "D"), 0))
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[2],
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once the shell and a ready attacker are already online, Munkidori should not spend turns moving damage unless it can immediately convert into a KO (got %f)" % score)


func test_munkidori_ability_stays_negative_when_total_damage_exceeds_hp_but_single_use_cannot_ko() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var player := gs.players[0]
	player.active_pokemon.damage_counters = 40
	player.bench.append(_make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0))
	player.bench[2].attached_energy.append(CardInstance.create(_make_energy_cd("Darkness A", "D"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_placeholder_pokemon("Tight Target"), 1)
	gs.players[1].active_pokemon.pokemon_stack[0].card_data.hp = 40
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": player.bench[2],
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Munkidori should stay negative when the board has 40 damage total but a single ability use can only move 30 damage (got %f)" % score)


func test_buddy_buddy_poffin_turns_negative_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_require_card(POFFIN_SET, POFFIN_INDEX), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once the shell and a ready attacker are online, Buddy-Buddy Poffin should be actively worse than ending turn or attacking (got %f)" % score)


func test_one_energy_attacker_body_is_not_counted_as_ready_attacker() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	player.bench[2].attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	var s := _new_strategy()
	return assert_eq(s._count_ready_attackers(player), 0, "A one-energy Drifloon body should not be counted as a ready attacker")


func test_boss_orders_stays_low_when_only_one_energy_attacker_body_exists() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	player.bench[2].attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	gs.players[1].bench.append(_make_slot(_make_placeholder_pokemon("Weak Target"), 1))
	gs.players[1].bench[0].pokemon_stack[0].card_data.hp = 60
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BOSSS_ORDERS, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Boss should stay low when the only bench attacker body has one energy and cannot actually attack this turn (got %f)" % score)


func test_psychic_embrace_cools_off_under_deck_out_pressure_when_ready_attacker_cannot_pivot() -> String:
	var gs := _make_game_state(14)
	var player := gs.players[0]
	var gardevoir := _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	gardevoir.get_card_data().retreat_cost = 2
	player.active_pokemon = gardevoir
	var kirlia := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	player.bench.append(kirlia)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	player.bench.append(drifloon)
	player.deck.append(CardInstance.create(_make_trainer_cd("LastDeckCard"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic C", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic D", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic E", "P"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": player.active_pokemon},
		gs,
		0
	)
	return assert_true(score <= 80.0,
		"Under deck-out pressure, extra Psychic Embrace should cool off when a ready attacker exists but the active Pokemon cannot pivot this turn (got %f)" % score)


func test_arven_turns_negative_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once the shell and a ready attacker are online, Arven should stop spending full supporter turns on setup cards (got %f)" % score)




func _make_radiant_greninja_cd() -> CardData:
	var cd := CardData.new()
	cd.name = DeckStrategyGardevoirScript.RADIANT_GRENINJA
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = "W"
	cd.hp = 130
	cd.abilities = [
		{"name": "Concealed Cards", "effect_type": "Concealed Cards"},
	]
	return cd


func _build_shell_lock_with_greninja_and_search_state() -> GameState:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_radiant_greninja_cd(), 0)
	player.bench.clear()
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Fuel", "P"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0))
	return gs


func _build_shell_lock_with_empty_night_stretcher_state() -> GameState:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0)
	player.bench.clear()
	return gs


func test_radiant_greninja_concealed_cards_waits_while_shell_lock_and_search_are_available() -> String:
	var gs := _build_shell_lock_with_greninja_and_search_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "use_ability",
			"source_slot": gs.players[0].active_pokemon,
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"During shell lock, Radiant Greninja should wait if shell search is already available in hand instead of discarding early fuel for churn (got %f)" % score)


func test_night_stretcher_stays_negative_when_shell_lock_is_active_without_real_recovery_targets() -> String:
	var gs := _build_shell_lock_with_empty_night_stretcher_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "play_trainer",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0),
		},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Night Stretcher should stay negative during shell lock when discard does not contain a meaningful recovery target (got %f)" % score)


func test_artazon_turns_negative_once_shell_and_attacker_are_online() -> String:
	var gs := _build_online_shell_attack_ready_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"Once the shell and a ready attacker are online, Artazon should shut off instead of padding the board (got %f)" % score)


func test_charizard_rebuild_lock_turns_munkidori_bench_and_dark_attach_negative() -> String:
	var gs := _build_charizard_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var bench_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)},
		gs,
		0
	)
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0), "target_slot": gs.players[0].active_pokemon},
		gs,
		0
	)
	return run_checks([
		assert_true(bench_score < 0.0, "Into Charizard, Munkidori should stay off the bench once the stage2 shell and an attacker body are already online (got %f)" % bench_score),
		assert_true(attach_score < 0.0, "Into Charizard, manual Darkness attachment into Munkidori should stay negative unless it immediately converts a KO (got %f)" % attach_score),
	])


func test_charizard_rebuild_lock_turns_artazon_and_heavy_ball_negative() -> String:
	var gs := _build_charizard_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var artazon_score: float = s.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)},
		gs,
		0
	)
	var heavy_ball_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.HISUIAN_HEAVY_BALL), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(artazon_score < 0.0, "Into Charizard, Artazon should cool off once the stage2 shell and an attacker body are already online (got %f)" % artazon_score),
		assert_true(heavy_ball_score < 0.0, "Into Charizard, Heavy Ball should also cool off in the same rebuild-lock window (got %f)" % heavy_ball_score),
	])


func test_charizard_rebuild_lock_cools_off_extra_ralts_search() -> String:
	var gs := _build_charizard_online_shell_with_unready_attacker_body_state()
	var s := _new_strategy()
	var ralts_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(RALTS_SET, RALTS_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(ralts_score < drifloon_score,
		"Into Charizard, once the shell and an attacker body are online, extra Ralts search should cool off below attacker-line search (ralts=%f drifloon=%f)" % [ralts_score, drifloon_score])


func test_search_priority_prefers_scream_tail_into_weak_bench_targets() -> String:
	var gs := _build_online_shell_without_attacker_vs_weak_bench_state()
	var s := _new_strategy()
	var scream_tail_score: float = s.score_interaction_target(
		CardInstance.create(_make_scream_tail_cd(), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(scream_tail_score > drifloon_score,
		"When the opponent exposes weak bench targets, rebuilding Scream Tail should outrank Drifloon to pressure those prizes (scream=%f drifloon=%f)" % [scream_tail_score, drifloon_score])


func test_embrace_prefers_scream_tail_when_extra_counter_unlocks_bench_prize() -> String:
	var gs := _build_online_shell_without_attacker_vs_weak_bench_state()
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	scream_tail.damage_counters = 20
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	drifloon.damage_counters = 20
	player.bench.append(scream_tail)
	player.bench.append(drifloon)
	var s := _new_strategy()
	var picked: Variant = s.pick_embrace_target([scream_tail, drifloon], gs, 0)
	return assert_true(picked == scream_tail,
		"When one extra Embrace lets Scream Tail pick off a weak bench target, it should outrank Drifloon as the embrace target")


func test_psychic_embrace_turns_negative_when_stage2_shell_is_online_but_no_attacker_body_exists() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic B", "P"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": player.bench[0]},
		gs,
		0
	)
	return assert_true(score < 0.0,
		"Once Gardevoir ex is online but no attacker body exists on board, Psychic Embrace should stay negative and let the turn rebuild a real attacker first (got %f)" % score)


func test_embrace_target_never_falls_back_to_dead_slot() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	var dead_ralts := _make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0)
	dead_ralts.damage_counters = 70
	player.bench.append(dead_ralts)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	var s := _new_strategy()
	var picked: Variant = s.pick_embrace_target([dead_ralts, player.bench[2]], gs, 0)
	return assert_true(picked == player.bench[2],
		"Psychic Embrace should never fall back to a dead shell slot when a live attacker body exists")


func test_bench_priority_prefers_scream_tail_even_with_ready_attacker_when_weak_bench_is_exposed() -> String:
	var gs := _build_online_shell_with_ready_drifloon_vs_weak_bench_state()
	var s := _new_strategy()
	var scream_tail_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_scream_tail_cd(), 0)},
		gs,
		0
	)
	var drifloon_score: float = s.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)},
		gs,
		0
	)
	return assert_true(scream_tail_score > drifloon_score,
		"When a ready attacker is already online but the opponent exposes weak bench prizes, adding Scream Tail should outrank another generic attacker body (scream=%f drifloon=%f)" % [scream_tail_score, drifloon_score])


func test_search_priority_prefers_scream_tail_even_with_ready_attacker_when_weak_bench_is_exposed() -> String:
	var gs := _build_online_shell_with_ready_drifloon_vs_weak_bench_state()
	var s := _new_strategy()
	var scream_tail_score: float = s.score_interaction_target(
		CardInstance.create(_make_scream_tail_cd(), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	var drifloon_score: float = s.score_interaction_target(
		CardInstance.create(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0),
		{"id": "search_pokemon"},
		{"game_state": gs, "player_index": 0}
	)
	return assert_true(scream_tail_score > drifloon_score,
		"When a ready attacker is already online but the opponent exposes weak bench prizes, search should still prefer Scream Tail over another generic attacker body (scream=%f drifloon=%f)" % [scream_tail_score, drifloon_score])


func test_boss_orders_stays_low_when_no_same_turn_gust_attack_exists_even_if_weak_bench_is_exposed() -> String:
	var gs := _build_unready_attack_shell_vs_weak_bench_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BOSSS_ORDERS, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When no same-turn gust attack exists yet, Boss's Orders should stay low even if the opponent exposes a weak bench target (got %f)" % score)


func test_counter_catcher_stays_low_when_no_same_turn_gust_attack_exists_even_if_weak_bench_is_exposed() -> String:
	var gs := _build_unready_attack_shell_vs_weak_bench_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.COUNTER_CATCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0,
		"When no same-turn gust attack exists yet, Counter Catcher should stay low even if the opponent exposes a weak bench target (got %f)" % score)


func test_manual_attach_psychic_bridges_benched_drifloon_once_stage2_shell_is_online() -> String:
	var gs := _build_online_shell_with_unready_attacker_body_state()
	var player := gs.players[0]
	player.bench.clear()
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	drifloon.damage_counters = 20
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.bench.append(drifloon)
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Psychic B", "P"), 0), "target_slot": drifloon},
		gs,
		0
	)
	var end_turn_score: float = s.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(attach_score > 0.0, "Once the stage2 shell is online but no attacker is ready, manual attach should help bridge benched Drifloon (got %f)" % attach_score),
		assert_true(attach_score > end_turn_score, "Bridging benched Drifloon should outrank passing the turn (attach=%f end=%f)" % [attach_score, end_turn_score]),
	])


func test_manual_attach_dark_bridges_benched_scream_tail_once_stage2_shell_is_online() -> String:
	var gs := _build_online_shell_without_attacker_vs_weak_bench_state()
	var player := gs.players[0]
	player.bench.clear()
	player.active_pokemon = _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.bench.append(scream_tail)
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Darkness A", "D"), 0), "target_slot": scream_tail},
		gs,
		0
	)
	return assert_true(attach_score >= 500.0,
		"When the stage2 shell is online and Scream Tail is one Dark Energy short of a bench prize line, manual Dark attach should become a real bridge action (got %f)" % attach_score)


func test_handoff_prefers_scream_tail_owner_into_weak_bench_transition_shell() -> String:
	var gs := _build_online_shell_without_attacker_vs_weak_bench_state()
	var s := _new_strategy()
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var kirlia := _make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0)
	var munkidori := _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	var scream_send_out: float = s.score_handoff_target(scream_tail, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var drifloon_send_out: float = s.score_handoff_target(drifloon, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var kirlia_send_out: float = s.score_handoff_target(kirlia, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var munkidori_send_out: float = s.score_handoff_target(munkidori, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var scream_switch: float = s.score_handoff_target(scream_tail, {"id": "self_switch_target"}, {"game_state": gs, "player_index": 0})
	var drifloon_switch: float = s.score_handoff_target(drifloon, {"id": "self_switch_target"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(scream_send_out > drifloon_send_out,
			"When weak bench prizes are exposed, send_out should hand off to Scream Tail before Drifloon (scream=%f drifloon=%f)" % [scream_send_out, drifloon_send_out]),
		assert_true(scream_send_out > kirlia_send_out,
			"When weak bench prizes are exposed, send_out should hand off to Scream Tail before shell pieces like Kirlia (scream=%f kirlia=%f)" % [scream_send_out, kirlia_send_out]),
		assert_true(scream_send_out > munkidori_send_out,
			"When weak bench prizes are exposed, send_out should hand off to Scream Tail before Munkidori (scream=%f munkidori=%f)" % [scream_send_out, munkidori_send_out]),
		assert_true(scream_switch > drifloon_switch,
			"Switch-like handoffs should agree with send_out and keep attack ownership on Scream Tail in the weak-bench transition window (scream=%f drifloon=%f)" % [scream_switch, drifloon_switch]),
	])


func test_handoff_prefers_drifloon_owner_when_no_weak_bench_window_exists() -> String:
	var gs := _build_online_shell_without_attacker_state()
	var s := _new_strategy()
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	var drifloon := _make_slot(_require_card(DRIFLOON_SET, DRIFLOON_INDEX), 0)
	var munkidori := _make_slot(_require_card(MUNKIDORI_SET, MUNKIDORI_INDEX), 0)
	var drifloon_send_out: float = s.score_handoff_target(drifloon, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var scream_send_out: float = s.score_handoff_target(scream_tail, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var munkidori_send_out: float = s.score_handoff_target(munkidori, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(drifloon_send_out > scream_send_out,
			"Without a weak-bench prize window, send_out should hand off to Drifloon before Scream Tail (drifloon=%f scream=%f)" % [drifloon_send_out, scream_send_out]),
		assert_true(drifloon_send_out > munkidori_send_out,
			"Without a weak-bench prize window, send_out should hand off to Drifloon before Munkidori (drifloon=%f munkidori=%f)" % [drifloon_send_out, munkidori_send_out]),
	])
