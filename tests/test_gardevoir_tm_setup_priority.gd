class_name TestGardevoirTmSetupPriority
extends TestBase

const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const GARDEVOIR_SET := "CSV2C"
const GARDEVOIR_INDEX := "055"
const KIRLIA_SET := "CS6.5C"
const KIRLIA_INDEX := "030"
const RALTS_SET := "CSV2C"
const RALTS_INDEX := "053"


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	return DeckStrategyGardevoirScript.new()


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	evolves_from: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	return cd


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


func _make_greninja_cd() -> CardData:
	var cd := _make_pokemon_cd(DeckStrategyGardevoirScript.RADIANT_GRENINJA, "Basic", "W", 130)
	cd.abilities = [{"name": "隐藏牌"}]
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


func _require_card(set_code: String, card_index: String) -> CardData:
	var card_data: CardData = CardDatabase.get_card(set_code, card_index)
	assert_not_null(card_data, "Expected CardDatabase to provide %s/%s" % [set_code, card_index])
	return card_data


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


func _add_tm_future_targets(player: PlayerState) -> void:
	player.deck.append(CardInstance.create(_make_pokemon_cd(
		DeckStrategyGardevoirScript.KIRLIA,
		"Stage 1",
		"P",
		80,
		DeckStrategyGardevoirScript.RALTS
	), 0))


func _add_tm_access(player: PlayerState) -> void:
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))


func test_arven_prefers_poffin_and_tm_when_shell_needs_two_ralts() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0))
	var items := [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
	]
	var tools := [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0),
	]
	var s := _new_strategy()
	var picked_item: Variant = s.pick_search_item(items, gs, 0)
	var picked_tool: Variant = s.pick_search_tool(tools, gs, 0)
	var item_ok := picked_item is CardInstance and str((picked_item as CardInstance).card_data.name) == DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN
	var tool_ok := picked_tool is CardInstance and str((picked_tool as CardInstance).card_data.name) == DeckStrategyGardevoirScript.TM_EVOLUTION
	return assert_true(item_ok and tool_ok, "Arven should prioritize Poffin + TM Evolution when the early shell still needs two Ralts")


func test_arven_prefers_earthen_vessel_when_tm_setup_lacks_energy() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0))
	_add_tm_access(player)
	var items := [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
	]
	var s := _new_strategy()
	var picked_item: Variant = s.pick_search_item(items, gs, 0)
	var item_ok := picked_item is CardInstance and str((picked_item as CardInstance).card_data.name) == DeckStrategyGardevoirScript.EARTHEN_VESSEL
	return assert_true(item_ok, "Arven should prioritize Earthen Vessel when TM setup has targets but lacks attack payment")


func test_arven_prefers_ultra_ball_over_vessel_when_tm_is_gone_and_first_kirlia_is_missing() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var items := [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
	]
	var s := _new_strategy()
	var picked_item: Variant = s.pick_search_item(items, gs, 0)
	var item_ok := picked_item is CardInstance and str((picked_item as CardInstance).card_data.name) == DeckStrategyGardevoirScript.ULTRA_BALL
	return assert_true(item_ok, "Once TM is no longer accessible and the first Kirlia is still missing, Arven should stop prioritizing Earthen Vessel over Ultra Ball")


func test_arven_does_not_fetch_tm_as_primary_tool_when_only_one_tm_target_exists_and_no_shell_search_remains() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var tools := [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0),
	]
	var s := _new_strategy()
	var picked_tool: Variant = s.pick_search_tool(tools, gs, 0)
	var tool_ok := picked_tool is CardInstance and str((picked_tool as CardInstance).card_data.name) == DeckStrategyGardevoirScript.BRAVERY_CHARM
	return assert_true(tool_ok, "When only one TM target exists and there is no way to widen the shell this turn, Arven should not default to TM Evolution")


func test_attach_energy_prioritizes_active_to_enable_tm_evolution() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	_add_tm_future_targets(player)
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	var s := _new_strategy()
	var active_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var bench_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.bench[0]},
		gs, 0
	)
	return assert_true(active_score > bench_score and active_score >= 700.0, "Manual attach should prioritize the active Pokemon to enable TM Evolution")


func test_opening_setup_prefers_flutter_mane_over_munkidori_once_two_ralts_are_available_and_tm_bridge_is_live() -> String:
	var player := _make_player(0)
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	var s := _new_strategy()
	var plan: Dictionary = s.plan_opening_setup(player)
	var active_index: int = int(plan.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_index].card_data.name) if active_index >= 0 else ""
	return assert_true(active_name == DeckStrategyGardevoirScript.FLUTTER_MANE,
		"When Flutter Mane is available with two Ralts and the TM bridge is live, opening setup should prefer Flutter Mane over Munkidori as the TM shell carrier")


func test_opening_setup_prefers_ralts_over_flutter_mane_when_two_ralts_exist_but_tm_bridge_is_not_live() -> String:
	var player := _make_player(0)
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var plan: Dictionary = s.plan_opening_setup(player)
	var active_index: int = int(plan.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_index].card_data.name) if active_index >= 0 else ""
	return assert_true(active_name == DeckStrategyGardevoirScript.RALTS,
		"When two Ralts are already available but the TM bridge is not live, opening setup should keep Ralts active instead of defaulting to Flutter Mane")


func test_opening_setup_prefers_klefki_bridge_only_when_tm_setup_is_live() -> String:
	var player := _make_player(0)
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.KLEFKI), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0))
	var s := _new_strategy()
	var plan: Dictionary = s.plan_opening_setup(player)
	var active_index: int = int(plan.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_index].card_data.name) if active_index >= 0 else ""
	return assert_true(active_name == DeckStrategyGardevoirScript.KLEFKI,
		"When the TM bridge is live through Arven plus energy, opening setup should allow Klefki to act as the bridge active")


func test_attach_energy_keeps_tm_setup_priority_alive_past_turn_two_if_shell_is_still_offline() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	_add_tm_future_targets(player)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	var s := _new_strategy()
	var active_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	return assert_true(active_score >= 700.0, "TM setup should stay top-priority after turn two while the shell is still offline and TM access is live (got %f)" % active_score)


func test_attach_energy_precharges_active_tm_carrier_once_two_ralts_are_online_even_before_tm_is_found() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	_add_tm_future_targets(player)
	_add_tm_access(player)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0))
	var s := _new_strategy()
	var active_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var bench_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.bench[0]},
		gs, 0
	)
	return assert_true(active_score > bench_score and active_score >= 200.0, "Once two Ralts are already online and TM is still reachable through Arven, the active pivot should be pre-charged for TM Evolution even before TM is found (got %f vs %f)" % [active_score, bench_score])


func test_attach_energy_precharges_active_ralts_tm_carrier_once_two_ralts_are_online() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	_add_tm_future_targets(player)
	_add_tm_access(player)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0))
	var s := _new_strategy()
	var active_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var bench_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0), "target_slot": player.bench[0]},
		gs, 0
	)
	return assert_true(active_score > bench_score and active_score >= 200.0, "Once two Ralts are already online and TM remains reachable, active Ralts should also be pre-charged for a future TM Evolution turn even with non-Psychic energy (got %f vs %f)" % [active_score, bench_score])


func test_attach_energy_does_not_fake_tm_precharge_when_tm_is_no_longer_accessible() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var active_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	return assert_true(active_score <= 0.0, "If no TM is in hand, active, or reachable through search, manual attach should not keep pretending a TM precharge line exists (got %f)" % active_score)


func test_attach_energy_stays_negative_into_dead_stage2_slots() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 90, DeckStrategyGardevoirScript.RALTS), 0)
	var dead_gardevoir := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA), 0)
	dead_gardevoir.damage_counters = 310
	player.bench.append(dead_gardevoir)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": dead_gardevoir},
		gs,
		0
	)
	return assert_true(score <= -200.0, "Dead stage2 slots should not remain valid manual attach targets (got %f)" % score)


func test_first_gardevoir_emergency_manual_attach_stays_negative_on_active_kirlia_once_fuel_exists() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 90, DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 90, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	return assert_true(score <= -200.0, "Once first-Gardevoir emergency already has fuel online, active Kirlia should not keep absorbing manual energy (got %f)" % score)


func test_attach_tool_tm_can_be_preloaded_early_even_before_energy_is_found() -> String:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var active_score: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	return assert_true(active_score >= 150.0, "Early TM Evolution should stay attachable on the active carrier even before energy is found (got %f)" % active_score)


func test_tm_attach_does_not_outrank_only_shell_progress_when_zero_shell_bodies_are_online() -> String:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_scream_tail_cd(), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MANAPHY, "Basic", "W", 70), 0))
	var s := _new_strategy()
	var tm_score: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	var artazon_score: float = s.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)},
		gs,
		0
	)
	return assert_true(artazon_score > tm_score, "When zero shell bodies are online, the only shell-progress action should outrank preloading TM on an off-plan active (got %f vs %f)" % [artazon_score, tm_score])


func test_tm_setup_active_munkidori_can_be_used_as_a_fallback_tm_shell_carrier() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	var s := _new_strategy()
	var active_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var tm_attach_score: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var tm_attack_score: float = s.score_action_absolute(
		{"kind": "granted_attack", "granted_attack_data": {"name": "Evolution"}},
		gs, 0
	)
	return run_checks([
		assert_true(active_score > 0.0, "Active Munkidori should remain a fallback TM shell carrier when no better pivot is already active (got %f)" % active_score),
		assert_true(tm_attach_score > 0.0, "TM Evolution should stay playable on active Munkidori as a fallback shell carrier (got %f)" % tm_attach_score),
		assert_true(tm_attack_score > 0.0, "TM Evolution attack should remain live on active Munkidori as a fallback shell carrier (got %f)" % tm_attack_score),
	])


func test_iono_refills_after_tm_shell_when_double_kirlia_is_online_and_fuel_is_low() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Switch"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd("Ultra Ball"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.IONO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score >= 250.0, "Iono should become a real refill action after the TM shell turn when double Kirlia is online and psychic fuel is still low (got %f)" % score)


func test_greninja_hidden_cards_becomes_top_fuel_action_in_post_tm_refill_window() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var greninja := _make_slot(_make_greninja_cd(), 0)
	player.bench.append(greninja)
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": greninja},
		gs,
		0
	)
	return assert_true(score >= 520.0, "Greninja should be strongly preferred as a fuel action in the post-TM refill window (got %f)" % score)


func test_shell_lock_delays_active_scream_tail_attach_while_shell_search_is_still_live() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_scream_tail_cd(), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0))
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var poffin_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0)},
		gs, 0
	)
	return run_checks([
		assert_true(attach_score < 0.0, "While the shell is still missing bodies and Poffin can complete it, active Scream Tail should not get early attack energy (got %f)" % attach_score),
		assert_true(poffin_score > attach_score, "Completing the shell should outrank investing into active Scream Tail while shell search remains live (poffin=%f attach=%f)" % [poffin_score, attach_score]),
	])


func test_shell_lock_delays_active_drifloon_attach_while_shell_search_is_still_live() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var drifloon := _make_slot(_require_card("CSV2C", "060"), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	drifloon.damage_counters = 20
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0))
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy 2", "P"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	return assert_true(attach_score < 0.0,
		"While the shell is still missing bodies and Poffin can complete it, active Drifloon should delay attack energy investment (got %f)" % attach_score)


func test_tm_evolution_attack_is_top_priority_early() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "granted_attack", "granted_attack_data": {"name": "Evolution"}},
		gs, 0
	)
	return assert_true(score >= 850.0, "TM Evolution attack should be top priority early when the setup is live (got %f)" % score)


func test_tm_evolution_live_discourages_retreating_tm_carrier_even_into_ready_attacker() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.active_pokemon.pokemon_stack.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var drifloon := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.bench.append(drifloon)
	var s := _new_strategy()
	var retreat_score: float = s.score_action_absolute(
		{"kind": "retreat", "bench_target": drifloon},
		gs, 0
	)
	var tm_attack_score: float = s.score_action_absolute(
		{"kind": "granted_attack", "granted_attack_data": {"name": "Evolution"}},
		gs, 0
	)
	return run_checks([
		assert_true(retreat_score < 0.0, "A live TM Evolution carrier should not retreat away from a Kirlia + Ralts bench setup"),
		assert_true(tm_attack_score > retreat_score, "TM Evolution attack should outrank retreat when the live setup is online"),
	])


func test_tm_evolution_attach_turns_negative_once_stage2_shell_is_online() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_scream_tail_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	return assert_true(score < 0.0,
		"TM Evolution should turn negative once the first stage2 shell is already online (got %f)" % score)


func test_tm_evolution_granted_attack_turns_negative_once_stage2_shell_is_online() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_scream_tail_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic A", "P"), 0))
	player.active_pokemon.pokemon_stack.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_require_card(KIRLIA_SET, KIRLIA_INDEX), 0))
	player.bench.append(_make_slot(_require_card(RALTS_SET, RALTS_INDEX), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "granted_attack", "granted_attack_data": {"name": "Evolution"}},
		gs, 0
	)
	return assert_true(score < 0.0,
		"TM Evolution granted attack should cool off once the stage2 shell is already online (got %f)" % score)


func test_radiant_greninja_stays_positive_with_psychic_pitch_once_two_ralts_are_online() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var greninja := _make_slot(_make_greninja_cd(), 0)
	player.bench.append(greninja)
	player.hand.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": greninja},
		gs, 0
	)
	return assert_true(score >= 400.0, "Once two Ralts are online, Radiant Greninja should stay strongly positive as a Psychic discard engine even if shell search remains in hand (got %f)" % score)


func test_first_gardevoir_emergency_keeps_vessel_live_after_double_kirlia_when_fuel_is_missing() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var poffin_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0)},
		gs, 0
	)
	var vessel_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0)},
		gs, 0
	)
	return run_checks([
		assert_true(poffin_score < 0.0, "Once double Kirlia are online and the first Gardevoir ex is still missing, Poffin should cool off hard (got %f)" % poffin_score),
		assert_true(vessel_score >= 260.0, "Once double Kirlia are online and the first Gardevoir ex is still missing with low psychic fuel, Earthen Vessel should stay live (got %f)" % vessel_score),
	])


func test_first_gardevoir_emergency_keeps_vessel_live_with_kirlia_plus_ralts_shell_when_fuel_is_missing() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var poffin_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0)},
		gs, 0
	)
	var vessel_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0)},
		gs, 0
	)
	var picked_item: Variant = s.pick_search_item([
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
	], gs, 0)
	var item_ok := picked_item is CardInstance and str((picked_item as CardInstance).card_data.name) == DeckStrategyGardevoirScript.ULTRA_BALL
	return run_checks([
		assert_true(poffin_score < 0.0, "Once a Kirlia+Ralts shell is online and the first Gardevoir ex is still missing, Poffin should cool off hard (got %f)" % poffin_score),
		assert_true(vessel_score >= 240.0, "Once a Kirlia+Ralts shell is online and the first Gardevoir ex is still missing with low psychic fuel, Earthen Vessel should stay live (got %f)" % vessel_score),
		assert_true(item_ok, "Kirlia+Ralts first-Gardevoir emergency should prefer Ultra Ball over filler search items"),
	])


func test_arven_prefers_ultra_ball_over_poffin_and_vessel_during_first_gardevoir_emergency() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var items := [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0),
	]
	var s := _new_strategy()
	var picked_item: Variant = s.pick_search_item(items, gs, 0)
	var item_ok := picked_item is CardInstance and str((picked_item as CardInstance).card_data.name) == DeckStrategyGardevoirScript.ULTRA_BALL
	return assert_true(item_ok,
		"During the first-Gardevoir emergency, Arven/item search should prioritize Ultra Ball over Poffin or Vessel")


func test_pick_search_item_prefers_ultra_ball_before_shell_fillers_once_first_gardevoir_is_missing() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var items := [
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0),
		CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0),
	]
	var s := _new_strategy()
	var picked_item: Variant = s.pick_search_item(items, gs, 0)
	var item_ok := picked_item is CardInstance and str((picked_item as CardInstance).card_data.name) == DeckStrategyGardevoirScript.ULTRA_BALL
	return assert_true(item_ok,
		"Once a Kirlia is online and the first Gardevoir ex is still missing, search should prioritize Ultra Ball before shell fillers")


func test_first_gardevoir_missing_with_single_kirlia_cools_off_poffin_and_vessel() -> String:
	var gs := _make_game_state(4)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var poffin_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0)},
		gs, 0
	)
	var vessel_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.EARTHEN_VESSEL), 0)},
		gs, 0
	)
	return run_checks([
		assert_true(poffin_score <= 40.0, "With a Kirlia already online and first Gardevoir ex missing, Poffin should cool off relative to stage-2 search (got %f)" % poffin_score),
		assert_true(vessel_score < 0.0, "With a Kirlia already online and first Gardevoir ex missing, Earthen Vessel should cool off (got %f)" % vessel_score),
	])


func test_stage2_handoff_cools_off_poffin_and_nest_ball_once_attacker_body_and_discard_fuel_exist() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0)
	var drifloon := _make_slot(_require_card("CSV2C", "060"), 0)
	player.bench.append(drifloon)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy 2", "P"), 0))
	var s := _new_strategy()
	var poffin_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0)},
		gs, 0
	)
	var nest_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NEST_BALL), 0)},
		gs, 0
	)
	return run_checks([
		assert_true(poffin_score < 0.0, "Once Gardevoir ex is online, an attacker body exists, and discard fuel is stocked, Poffin should cool off (got %f)" % poffin_score),
		assert_true(nest_score < 0.0, "Once Gardevoir ex is online, an attacker body exists, and discard fuel is stocked, Nest Ball should cool off (got %f)" % nest_score),
	])


func test_tm_setup_discard_protects_tm_and_arven_while_shell_is_offline() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RADIANT_GRENINJA, "Basic", "W", 130), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var tm := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	var arven := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARVEN, "Supporter"), 0)
	var dark := CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0)
	var stretcher := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)
	var tm_score: int = s.get_discard_priority_contextual(tm, gs, 0)
	var arven_score: int = s.get_discard_priority_contextual(arven, gs, 0)
	var dark_score: int = s.get_discard_priority_contextual(dark, gs, 0)
	var stretcher_score: int = s.get_discard_priority_contextual(stretcher, gs, 0)
	return run_checks([
		assert_true(tm_score < dark_score, "TM Evolution should be protected from discard while shell setup is live"),
		assert_true(tm_score < stretcher_score, "TM Evolution should stay below filler recovery cards in shell lock"),
		assert_true(arven_score < dark_score, "Arven should be preserved while shell lock still needs TM setup"),
	])


func test_tm_setup_discard_keeps_ultra_ball_below_energy_when_shell_lock_is_live() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RADIANT_GRENINJA, "Basic", "W", 130), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var ultra := CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0)
	var psychic := CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0)
	var ultra_score: int = s.get_discard_priority_contextual(ultra, gs, 0)
	var psychic_score: int = s.get_discard_priority_contextual(psychic, gs, 0)
	return assert_true(ultra_score < psychic_score, "During shell lock, Ultra Ball should stay below discard-fuel energy so TM lines do not eat their own shell search")


func test_buddy_buddy_poffin_turns_negative_once_two_ralts_and_tm_line_are_live() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Once two Ralts are already benched and TM Evolution is live, extra Buddy-Buddy Poffin should turn negative (got %f)" % score)


func test_bravery_charm_stays_negative_during_shell_lock_even_on_attackers() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var drifloon := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0)
	player.bench.append(drifloon)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{
			"kind": "attach_tool",
			"card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BRAVERY_CHARM, "Tool"), 0),
			"target_slot": drifloon,
		},
		gs,
		0
	)
	return assert_true(score < 0.0, "Bravery Charm should stay negative during shell lock because TM shell setup still outranks it (got %f)" % score)


func test_search_pokemon_prefers_first_gardevoir_ex_over_third_ralts_after_tm_shell_lands() -> String:
	var gs := _make_game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RADIANT_GRENINJA, "Basic", "W", 130), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var gardevoir := CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA), 0)
	var ralts := CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0)
	var gardevoir_score: float = s.score_interaction_target(gardevoir, {"id": "search_pokemon"}, {"game_state": gs, "player_index": 0})
	var ralts_score: float = s.score_interaction_target(ralts, {"id": "search_pokemon"}, {"game_state": gs, "player_index": 0})
	return assert_true(gardevoir_score > ralts_score, "Once two Kirlia are online, search should prefer the first Gardevoir ex over a third Ralts (gard=%f ralts=%f)" % [gardevoir_score, ralts_score])


func test_search_pokemon_rejects_third_ralts_once_two_shell_bodies_are_already_online() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.FLUTTER_MANE, "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var s := _new_strategy()
	var ralts := CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0)
	var ralts_score: float = s.score_interaction_target(ralts, {"id": "search_pokemon"}, {"game_state": gs, "player_index": 0})
	return assert_true(ralts_score < 0.0, "Once two shell bodies are already online, search should reject a third Ralts instead of spending more setup on it (got %f)" % ralts_score)


func test_tm_evolution_cools_off_when_double_kirlia_are_online_but_first_gardevoir_is_missing() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	var attack_score: float = s.score_action_absolute(
		{"kind": "granted_attack", "granted_attack_data": {"name": "Evolution"}},
		gs,
		0
	)
	var ok := attach_score <= 20.0 and attack_score <= 20.0
	return assert_true(ok, "When two Kirlia are already online but the first Gardevoir ex is still missing, TM Evolution should cool off to let first-stage2 search take priority (attach=%f attack=%f)" % [attach_score, attack_score])


func test_tm_setup_energy_cools_off_when_double_kirlia_are_online_but_first_gardevoir_is_missing() -> String:
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	var s := _new_strategy()
	var dark_attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	var psychic_attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	return run_checks([
		assert_true(dark_attach_score < 0.0, "Once two Kirlia are already online and the first Gardevoir ex is still missing, TM carrier energy should cool off instead of feeding active Kirlia with Darkness Energy (got %f)" % dark_attach_score),
		assert_true(psychic_attach_score < 0.0, "Once two Kirlia are already online and the first Gardevoir ex is still missing, TM carrier energy should cool off instead of feeding active Kirlia with Psychic Energy (got %f)" % psychic_attach_score),
	])


func test_tm_setup_energy_cools_off_on_active_kirlia_even_before_second_kirlia_if_first_gardevoir_is_missing() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	var s := _new_strategy()
	var psychic_attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	return assert_true(psychic_attach_score < 0.0, "Active Kirlia should not keep receiving TM setup energy while the first Gardevoir ex is still missing (got %f)" % psychic_attach_score)


func test_transition_shell_kirlia_active_does_not_take_tm_as_fake_attacker() -> String:
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0))
	var s := _new_strategy()
	var tm_attach_score: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var tm_attack_score: float = s.score_action_absolute(
		{"kind": "granted_attack", "granted_attack_data": {"name": "Evolution"}},
		gs, 0
	)
	return run_checks([
		assert_true(tm_attach_score < 0.0, "Active Kirlia should not take TM Evolution as a fake midgame attacker (got %f)" % tm_attach_score),
		assert_true(tm_attack_score < 0.0, "Active Kirlia should not fire TM Evolution once the deck is in transition-shell handoff (got %f)" % tm_attack_score),
	])


func test_transition_shell_kirlia_active_does_not_take_manual_energy_as_fake_attacker() -> String:
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_require_card(GARDEVOIR_SET, GARDEVOIR_INDEX), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0))
	var s := _new_strategy()
	var kirlia_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var drifloon_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.bench[1]},
		gs, 0
	)
	return run_checks([
		assert_true(kirlia_score < 0.0, "Active Kirlia should not absorb manual energy in transition-shell turns (got %f)" % kirlia_score),
		assert_true(drifloon_score > kirlia_score, "A real attacker body should outrank active Kirlia for manual energy during transition-shell handoff"),
	])


func test_tm_preload_attach_energy_outranks_filler_stadium_before_bench_targets_exist() -> String:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0)
	_add_tm_future_targets(player)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var tm_score: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var stadium_score: float = s.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)},
		gs, 0
	)
	return run_checks([
		assert_true(attach_score > stadium_score, "When shell launch is still assembling and TM is already in hand, pre-charging the active carrier should outrank filler stadium tempo (attach=%f stadium=%f)" % [attach_score, stadium_score]),
		assert_true(tm_score > stadium_score, "When shell launch is still assembling and TM is already in hand, pre-loading TM on the active carrier should outrank filler stadium tempo (tm=%f stadium=%f)" % [tm_score, stadium_score]),
	])


func test_tm_preload_stays_positive_before_evolvable_bench_targets_exist() -> String:
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS, "Basic", "P", 70), 0)
	_add_tm_future_targets(player)
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0))
	var s := _new_strategy()
	var attach_score: float = s.score_action_absolute(
		{"kind": "attach_energy", "card": CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	var tm_score: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0), "target_slot": player.active_pokemon},
		gs, 0
	)
	return run_checks([
		assert_true(attach_score > 0.0, "TM launch should allow positive pre-charge on the active carrier even before bench evolution targets are fully online (got %f)" % attach_score),
		assert_true(tm_score > 0.0, "TM launch should allow positive TM preload on the active carrier even before bench evolution targets are fully online (got %f)" % tm_score),
	])
