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


func _make_energy_cd(pname: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
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


func test_boss_orders_low_when_only_benched_ready_attacker_exists_but_active_cannot_pivot() -> String:
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	active.get_card_data().retreat_cost = 2
	player.active_pokemon = active
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_pokemon_cd("Psychic Energy", "Basic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_pokemon_cd("Darkness Energy", "Basic Energy", "D"), 0))
	player.bench.append(scream_tail)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Weak Target", "Basic", "C", 40), 1))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BOSSS_ORDERS, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0, "Boss should stay low when only a benched ready attacker exists but the active Pokemon cannot pivot this turn (got %f)" % score)


func test_counter_catcher_low_when_only_benched_ready_attacker_exists_but_active_cannot_pivot() -> String:
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	active.get_card_data().retreat_cost = 2
	player.active_pokemon = active
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_pokemon_cd("Psychic Energy", "Basic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_pokemon_cd("Darkness Energy", "Basic Energy", "D"), 0))
	player.bench.append(scream_tail)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Weak Target", "Basic", "C", 40), 1))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.COUNTER_CATCHER), 0)},
		gs,
		0
	)
	return assert_true(score <= 0.0, "Counter Catcher should stay low when only a benched ready attacker exists but the active Pokemon cannot pivot this turn (got %f)" % score)


func test_turn_plan_stays_transitional_when_ready_attacker_exists_but_active_cannot_pivot() -> String:
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	active.get_card_data().retreat_cost = 2
	player.active_pokemon = active
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0))
	var scream_tail := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	player.bench.append(scream_tail)
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	return run_checks([
		assert_eq(str(plan.get("intent", "")), "transition_to_conversion", "Turn intent should stay transitional when only a benched ready attacker exists but the active Pokemon cannot pivot"),
		assert_false(bool(plan.get("flags", {}).get("immediate_attack_window", false)), "Immediate attack window should stay false when the active Pokemon cannot pivot into the benched attacker"),
	])


func test_turn_plan_phase_does_not_jump_to_late_while_shell_lock_is_still_active() -> String:
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	return run_checks([
		assert_true(bool(plan.get("flags", {}).get("shell_lock", false)), "Shell lock should still be active before the first Gardevoir ex is online"),
		assert_true(
			str(plan.get("intent", "")) in ["force_first_gardevoir", "post_tm_refill"],
			"Intent should stay on a shell-building line while shell lock is still active even if the generic phase detector has drifted"
		),
	])


func test_shell_lock_thin_shell_keeps_owner_on_bridge_target_instead_of_off_plan_active() -> String:
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.SCREAM_TAIL, "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	var contract: Dictionary = s.build_turn_contract(gs, 0, {})
	return run_checks([
		assert_true(bool(plan.get("flags", {}).get("shell_lock", false)), "Shell lock should be active while the shell is still thin"),
		assert_eq(str(plan.get("targets", {}).get("bridge_target_name", "")), DeckStrategyGardevoirScript.RALTS, "Bridge target should stay on Ralts in a thin-shell opening"),
		assert_eq(str(plan.get("targets", {}).get("primary_attacker_name", "")), DeckStrategyGardevoirScript.RALTS, "Thin-shell turn owner should stay on the bridge target instead of an off-plan active attacker"),
		assert_eq(str(contract.get("owner", {}).get("turn_owner_name", "")), DeckStrategyGardevoirScript.RALTS, "Turn contract owner should stay on the bridge target during thin-shell launch"),
		assert_eq(str(contract.get("owner", {}).get("pivot_target_name", "")), DeckStrategyGardevoirScript.RALTS, "Thin-shell pivot target should stay on the bridge target"),
	])


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


func test_boss_orders_stays_negative_during_first_gardevoir_emergency() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Weak Target", "Basic", "C", 40), 1))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BOSSS_ORDERS, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Boss should stay negative while first Gardevoir ex is still missing (got %f)" % score)


func test_counter_catcher_stays_negative_during_first_gardevoir_emergency() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Weak Target", "Basic", "C", 40), 1))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.COUNTER_CATCHER), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Counter Catcher should stay negative while first Gardevoir ex is still missing (got %f)" % score)


func test_kirlia_refinement_stays_live_when_direct_first_gardevoir_line_exists_but_fuel_is_missing() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var active := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	active.get_card_data().abilities = [{"name": "Refinement"}]
	player.active_pokemon = active
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": active},
		gs,
		0
	)
	return assert_true(score >= 450.0, "Kirlia draw should stay live when a direct first-Gardevoir line exists but psychic fuel is still missing (got %f)" % score)


func test_force_first_gardevoir_direct_line_outranks_tm_preload_on_off_plan_active() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MANAPHY, "Basic", "W", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var ultra_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0)},
		gs,
		0
	)
	var tm_score: float = s.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0), "target_slot": player.active_pokemon},
		gs,
		0
	)
	return run_checks([
		assert_true(ultra_score >= 320.0, "Direct first-Gardevoir line should keep Ultra Ball live (got %f)" % ultra_score),
		assert_true(ultra_score > tm_score, "Direct first-Gardevoir line should outrank TM preload on an off-plan active (got %f vs %f)" % [ultra_score, tm_score]),
	])


func test_night_stretcher_closed_loop_prefers_rebuilding_the_real_attacker() -> String:
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.GARDEVOIR_EX, "Stage 2", "P", 310, DeckStrategyGardevoirScript.KIRLIA, "ex"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	gs.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0))
	gs.players[0].discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy A", "P"), 0))
	gs.players[0].discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy B", "P"), 0))
	var s := _new_strategy()
	var play_score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.NIGHT_STRETCHER), 0)},
		gs,
		0
	)
	var target_score: float = s.score_interaction_target(
		CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0),
		{"id": "night_stretcher_choice"},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_true(play_score >= 500.0, "Night Stretcher should become a top rebuild action when Gardevoir ex can immediately restart the attacker loop (got %f)" % play_score),
		assert_true(target_score >= 900.0, "Night Stretcher should prioritize the real attacker body in the closed rebuild loop (got %f)" % target_score),
	])


func test_super_rod_stays_negative_during_first_gardevoir_emergency_without_live_target() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 80, DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.SUPER_ROD), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Super Rod should stay negative during first-Gardevoir emergency without a real recovery target (got %f)" % score)


func _make_post_stage2_handoff_state() -> GameState:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var gardevoir := _make_slot(
		_make_pokemon_cd(
			DeckStrategyGardevoirScript.GARDEVOIR_EX,
			"Stage 2",
			"P",
			310,
			DeckStrategyGardevoirScript.KIRLIA,
			"ex",
			[{"name": "Psychic Embrace"}]
		),
		0
	)
	player.active_pokemon = gardevoir
	var kirlia := _make_slot(
		_make_pokemon_cd(
			DeckStrategyGardevoirScript.KIRLIA,
			"Stage 1",
			"P",
			90,
			DeckStrategyGardevoirScript.RALTS,
			"",
			[{"name": "Refinement"}]
		),
		0
	)
	player.bench.append(kirlia)
	var drifloon := _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.DRIFLOON, "Basic", "P", 70), 0)
	player.bench.append(drifloon)
	var munkidori := _make_slot(
		_make_pokemon_cd(
			DeckStrategyGardevoirScript.MUNKIDORI,
			"Basic",
			"D",
			110,
			"",
			"",
			[{"name": "Adrena-Brain"}]
		),
		0
	)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("基本恶能量", "D"), 0))
	player.bench.append(munkidori)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("基本超能量", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("基本超能量", "P"), 0))
	var opponent := gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	return gs


func test_poffin_stays_negative_after_stage2_shell_when_attacker_handoff_is_live() -> String:
	var gs := _make_post_stage2_handoff_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.BUDDY_BUDDY_POFFIN), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Poffin should cool off once the stage2 shell is online and attacker handoff is live (got %f)" % score)


func test_artazon_stays_negative_after_stage2_shell_when_attacker_handoff_is_live() -> String:
	var gs := _make_post_stage2_handoff_state()
	var player := gs.players[0]
	player.deck.append(CardInstance.create(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ARTAZON, "Stadium"), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Artazon should cool off once the stage2 shell is online and attacker handoff is live (got %f)" % score)


func test_heavy_ball_stays_negative_after_stage2_shell_when_attacker_handoff_is_live() -> String:
	var gs := _make_post_stage2_handoff_state()
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.HISUIAN_HEAVY_BALL), 0)},
		gs,
		0
	)
	return assert_true(score < 0.0, "Heavy Ball should cool off once the stage2 shell is online and attacker handoff is live (got %f)" % score)


func test_munkidori_ability_stays_non_positive_after_stage2_shell_when_it_cannot_secure_ko() -> String:
	var gs := _make_post_stage2_handoff_state()
	var player := gs.players[0]
	var munkidori: PokemonSlot = player.bench[1]
	munkidori.damage_counters = 1
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "use_ability", "source_slot": munkidori},
		gs,
		0
	)
	return assert_true(score <= 0.0, "Munkidori should cool off once the stage2 shell is online and it cannot secure a KO (got %f)" % score)


func test_dead_gardevoir_ex_does_not_count_as_online_shell_or_live_ability_source() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 90, DeckStrategyGardevoirScript.RALTS, "", [{"name": "Refinement"}]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 90, DeckStrategyGardevoirScript.RALTS, "", [{"name": "Refinement"}]), 0))
	var dead_gardevoir := _make_slot(
		_make_pokemon_cd(
			DeckStrategyGardevoirScript.GARDEVOIR_EX,
			"Stage 2",
			"P",
			310,
			DeckStrategyGardevoirScript.KIRLIA,
			"ex",
			[{"name": "Psychic Embrace"}]
		),
		0
	)
	dead_gardevoir.damage_counters = 310
	player.bench.append(dead_gardevoir)
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	var ability_score: float = s.score_action_absolute({"kind": "use_ability", "source_slot": dead_gardevoir}, gs, 0)
	return run_checks([
		assert_false(bool(plan.get("flags", {}).get("has_gardevoir_ex", false)), "A dead Gardevoir ex should not count as an online shell body"),
		assert_true(str(plan.get("intent", "")) in ["force_first_gardevoir", "post_tm_refill"], "With only dead stage2 bodies, the turn should still stay on first-Gardevoir recovery"),
		assert_true(ability_score < 0.0, "A dead Gardevoir ex should not keep Psychic Embrace live (got %f)" % ability_score),
	])


func test_prof_turo_stays_low_when_only_dead_ex_targets_exist() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 90, DeckStrategyGardevoirScript.RALTS, "", [{"name": "Refinement"}]), 0)
	var dead_gardevoir := _make_slot(
		_make_pokemon_cd(
			DeckStrategyGardevoirScript.GARDEVOIR_EX,
			"Stage 2",
			"P",
			310,
			DeckStrategyGardevoirScript.KIRLIA,
			"ex",
			[{"name": "Psychic Embrace"}]
		),
		0
	)
	dead_gardevoir.damage_counters = 310
	player.bench.append(dead_gardevoir)
	var s := _new_strategy()
	var score: float = s.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.PROF_TURO, "Supporter"), 0)},
		gs,
		0
	)
	return assert_true(score <= 20.0, "Prof Turo should stay low when the only ex rescue target is already dead (got %f)" % score)



func test_first_gardevoir_emergency_contract_keeps_owner_on_gardevoir_ex_not_active_kirlia() -> String:
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 90, DeckStrategyGardevoirScript.RALTS, "", [{"name": "Refinement"}]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 90, DeckStrategyGardevoirScript.RALTS, "", [{"name": "Refinement"}]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Basic Psychic Energy", "P"), 0))
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	var contract: Dictionary = s.build_turn_contract(gs, 0, {})
	return run_checks([
		assert_true(bool(plan.get("flags", {}).get("must_force_first_gardevoir", false)), "Scenario should enter first-Gardevoir emergency"),
		assert_eq(str(contract.get("owner", {}).get("turn_owner_name", "")), DeckStrategyGardevoirScript.GARDEVOIR_EX, "First-Gardevoir emergency should keep turn owner on Gardevoir ex rather than active Kirlia"),
		assert_eq(str(contract.get("owner", {}).get("pivot_target_name", "")), DeckStrategyGardevoirScript.GARDEVOIR_EX, "Pivot target should stay on the missing first Gardevoir ex"),
	])


func test_first_gardevoir_emergency_intent_outranks_tm_combo_turn() -> String:
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.MUNKIDORI, "Basic", "D", 110), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Basic Darkness Energy", "D"), 0))
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.TM_EVOLUTION, "Tool"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.KIRLIA, "Stage 1", "P", 90, DeckStrategyGardevoirScript.RALTS, "", [{"name": "Refinement"}]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(DeckStrategyGardevoirScript.RALTS), 0))
	player.hand.append(CardInstance.create(_make_trainer_cd(DeckStrategyGardevoirScript.ULTRA_BALL), 0))
	var s := _new_strategy()
	var plan: Dictionary = s.build_turn_plan(gs, 0, {})
	var contract: Dictionary = s.build_turn_contract(gs, 0, {})
	return run_checks([
		assert_true(bool(plan.get("flags", {}).get("must_force_first_gardevoir", false)), "Scenario should still be a first-Gardevoir emergency"),
		assert_eq(str(plan.get("intent", "")), "force_first_gardevoir", "First-Gardevoir emergency should outrank TM combo intent once Kirlia is online and a direct line exists"),
		assert_eq(str(contract.get("owner", {}).get("turn_owner_name", "")), DeckStrategyGardevoirScript.GARDEVOIR_EX, "Turn owner should stay on the missing first Gardevoir ex rather than the TM carrier"),
	])
