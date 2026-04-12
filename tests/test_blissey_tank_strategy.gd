class_name TestBlisseyTankStrategy
extends TestBase

const DeckStrategyBlisseyTankScript = preload("res://scripts/ai/DeckStrategyBlisseyTank.gd")
const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")


class TraceCollector extends RefCounted:
	var traces: Array = []

	func record_trace(trace) -> void:
		if trace == null:
			return
		traces.append(trace.clone())


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	return DeckStrategyBlisseyTankScript.new()


func _make_bundled_ai(player_index: int, deck_id: int) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var deck: DeckData = CardDatabase.get_deck(deck_id)
	if deck == null:
		return ai
	var registry := DeckStrategyRegistryScript.new()
	registry.apply_strategy_for_deck(ai, deck)
	return ai


func _trace_tail_summary(traces: Array, limit: int = 16) -> String:
	var start_index := maxi(0, traces.size() - limit)
	var parts: Array[String] = []
	for idx: int in range(start_index, traces.size()):
		var trace = traces[idx]
		if trace == null:
			continue
		var chosen_action: Dictionary = trace.chosen_action if trace.chosen_action is Dictionary else {}
		var reason_tags: Array = trace.reason_tags if trace.reason_tags is Array else []
		var source_name := ""
		var source_slot: Variant = chosen_action.get("source_slot", null)
		if source_slot is PokemonSlot:
			source_name = (source_slot as PokemonSlot).get_pokemon_name()
		parts.append("t%d:p%d:%s:%s:%s:%d:%s" % [
			int(trace.turn_number),
			int(trace.player_index),
			str(chosen_action.get("kind", "")),
			source_name,
			str(chosen_action.get("card_name", chosen_action.get("name", ""))),
			int(chosen_action.get("ability_index", -1)),
			",".join(reason_tags),
		])
	return " | ".join(parts)


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "C",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = [],
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	cd.abilities.clear()
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy_cd(pname: String, energy_provides: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _make_tool_cd(pname: String) -> CardData:
	return _make_trainer_cd(pname, "Tool")


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
		var player := _make_player(pi)
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active %d" % pi), pi)
		gs.players.append(player)
	return gs


func _ctx(gs: GameState, pi: int = 0) -> Dictionary:
	return {"game_state": gs, "player_index": pi}


func _blissey_cd() -> CardData:
	return _make_pokemon_cd(
		"Blissey ex",
		"Stage 1",
		"C",
		300,
		"Chansey",
		"ex",
		[{"name": "Happy Switch", "text": ""}],
		[{"name": "Happy Chance", "cost": "CCC", "damage": "180"}],
		4
	)


func _chansey_cd() -> CardData:
	return _make_pokemon_cd(
		"Chansey",
		"Basic",
		"C",
		110,
		"",
		"",
		[],
		[{"name": "Rollout", "cost": "CCC", "damage": "70"}],
		2
	)


func _munkidori_cd() -> CardData:
	return _make_pokemon_cd(
		"Munkidori",
		"Basic",
		"P",
		110,
		"",
		"",
		[{"name": "Adrena-Brain", "text": ""}],
		[{"name": "Mind Bend", "cost": "PC", "damage": "60"}],
		1
	)


func _ogerpon_cd() -> CardData:
	return _make_pokemon_cd(
		"Cornerstone Mask Ogerpon ex",
		"Basic",
		"F",
		210,
		"",
		"ex",
		[],
		[{"name": "Cornerstone Stance", "cost": "FCC", "damage": "140"}],
		2
	)


func _farigiraf_cd() -> CardData:
	return _make_pokemon_cd(
		"Farigiraf ex",
		"Stage 1",
		"P",
		260,
		"Girafarig",
		"ex",
		[],
		[{"name": "Bending Control", "cost": "PCC", "damage": "160"}],
		2
	)


func test_setup_prefers_chansey_active_and_benches_core_support() -> String:
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_chansey_cd(), 0))
	player.hand.append(CardInstance.create(_munkidori_cd(), 0))
	player.hand.append(CardInstance.create(_ogerpon_cd(), 0))
	var strategy := _new_strategy()
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_idx: int = int(choice.get("active_hand_index", -1))
	var active_name: String = str(player.hand[active_idx].card_data.name) if active_idx >= 0 else ""
	var bench_names: Array[String] = []
	for idx: int in choice.get("bench_hand_indices", []):
		bench_names.append(str(player.hand[idx].card_data.name))
	return run_checks([
		assert_eq(active_name, "Chansey", "Chansey should be the preferred opener for the Blissey tank shell"),
		assert_contains(bench_names, "Munkidori", "Opening setup should bench Munkidori when available"),
		assert_contains(bench_names, "Cornerstone Mask Ogerpon ex", "Opening setup should preserve a secondary tank on the bench"),
	])


func test_score_evolve_blissey_ex_above_generic_stage1() -> String:
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_chansey_cd(), 0)
	var strategy := _new_strategy()
	var blissey_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_blissey_cd(), 0)},
		gs,
		0
	)
	var generic_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_make_pokemon_cd("Pidgeotto", "Stage 1", "C", 80, "Pidgey"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(blissey_score >= 450.0, "Blissey ex evolution should score as a premium setup action (got %f)" % blissey_score),
		assert_true(blissey_score > generic_score, "Blissey ex evolution should outrank a generic Stage 1 evolve"),
	])


func test_score_attach_basic_energy_prefers_blissey_tank_over_support() -> String:
	var gs := _make_game_state(3)
	var blissey := _make_slot(_blissey_cd(), 0)
	blissey.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "C", "Special Energy"), 0))
	gs.players[0].active_pokemon = blissey
	var farigiraf := _make_slot(_farigiraf_cd(), 0)
	gs.players[0].bench.append(farigiraf)
	var strategy := _new_strategy()
	var energy := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var score_blissey: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": energy, "target_slot": blissey},
		gs,
		0
	)
	var score_farigiraf: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": energy, "target_slot": farigiraf},
		gs,
		0
	)
	return run_checks([
		assert_true(score_blissey >= 300.0, "A near-ready Blissey tank should be a strong basic-energy target (got %f)" % score_blissey),
		assert_true(score_blissey > score_farigiraf, "The tank should outrank utility support for generic basic-energy routing"),
	])


func test_score_attach_dark_energy_prefers_munkidori_support() -> String:
	var gs := _make_game_state(3)
	var blissey := _make_slot(_blissey_cd(), 0)
	gs.players[0].active_pokemon = blissey
	var munkidori := _make_slot(_munkidori_cd(), 0)
	gs.players[0].bench.append(munkidori)
	var strategy := _new_strategy()
	var dark := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var score_munkidori: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": dark, "target_slot": munkidori},
		gs,
		0
	)
	var score_blissey: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": dark, "target_slot": blissey},
		gs,
		0
	)
	return run_checks([
		assert_true(score_munkidori >= 250.0, "Darkness Energy should strongly prefer enabling Munkidori (got %f)" % score_munkidori),
		assert_true(score_munkidori > score_blissey, "Munkidori should outrank the tank for Darkness Energy routing"),
	])


func test_score_cherens_care_high_for_damaged_blissey_tempo_reset() -> String:
	var gs := _make_game_state(5)
	var blissey := _make_slot(_blissey_cd(), 0)
	blissey.damage_counters = 220
	blissey.attached_tool = CardInstance.create(_make_tool_cd("Hero's Cape"), 0)
	blissey.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "C", "Special Energy"), 0))
	blissey.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	blissey.attached_energy.append(CardInstance.create(_make_energy_cd("Fighting Energy", "F"), 0))
	gs.players[0].active_pokemon = blissey
	var strategy := _new_strategy()
	var cheren_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Cheren's Care", "Supporter"), 0)},
		gs,
		0
	)
	var research_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(cheren_score >= 650.0, "Cheren's Care should become a premium tempo reset when a tank is heavily damaged (got %f)" % cheren_score),
		assert_true(cheren_score > research_score, "The reset line should outrank a generic draw supporter in that board state"),
	])


func test_cherens_care_is_not_treated_as_cornerstone_reset() -> String:
	var gs := _make_game_state(5)
	var cornerstone := _make_slot(_ogerpon_cd(), 0)
	cornerstone.damage_counters = 180
	gs.players[0].active_pokemon = cornerstone
	var strategy := _new_strategy()
	var cheren_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Cheren's Care", "Supporter"), 0)},
		gs,
		0
	)
	var research_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(cheren_score < 300.0, "Cheren's Care should not be scored like a premium reset on Cornerstone because it is not a legal target"),
		assert_true(cheren_score <= research_score, "An illegal Cornerstone reset should not outrank generic draw"),
	])


func test_score_hero_cape_prefers_blissey_over_support() -> String:
	var gs := _make_game_state(3)
	var blissey := _make_slot(_blissey_cd(), 0)
	gs.players[0].active_pokemon = blissey
	var farigiraf := _make_slot(_farigiraf_cd(), 0)
	gs.players[0].bench.append(farigiraf)
	var strategy := _new_strategy()
	var cape := CardInstance.create(_make_tool_cd("Hero's Cape"), 0)
	var score_blissey: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": cape, "target_slot": blissey},
		gs,
		0
	)
	var score_farigiraf: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": cape, "target_slot": farigiraf},
		gs,
		0
	)
	return run_checks([
		assert_true(score_blissey >= 300.0, "Hero's Cape should strongly prefer the main tank (got %f)" % score_blissey),
		assert_true(score_blissey > score_farigiraf, "Hero's Cape should not prefer a utility support over Blissey"),
	])


func test_psychic_energy_and_farigiraf_line_gain_priority_into_basic_ex_matchup() -> String:
	var gs := _make_game_state(4)
	var blissey := _make_slot(_blissey_cd(), 0)
	gs.players[0].active_pokemon = blissey
	var farigiraf := _make_slot(_farigiraf_cd(), 0)
	gs.players[0].bench.append(farigiraf)
	gs.players[1].active_pokemon = _make_slot(
		_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex", [], [{"name": "Amp", "cost": "LLC", "damage": "160"}]),
		1
	)
	var strategy := _new_strategy()
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var score_farigiraf: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": psychic, "target_slot": farigiraf},
		gs,
		0
	)
	var score_blissey: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": psychic, "target_slot": blissey},
		gs,
		0
	)
	var evolve_score: float = strategy.score_action_absolute(
		{"kind": "evolve", "card": CardInstance.create(_farigiraf_cd(), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(score_farigiraf > score_blissey, "Into Basic ex pressure, Psychic energy should help build the Farigiraf wall before piling onto Blissey"),
		assert_true(evolve_score >= 320.0, "Farigiraf ex should become a real setup line against Basic ex attackers"),
	])


func test_score_munkidori_ability_rises_when_tank_damage_converts_to_ko() -> String:
	var gs := _make_game_state(5)
	var blissey := _make_slot(_blissey_cd(), 0)
	blissey.damage_counters = 120
	gs.players[0].active_pokemon = blissey
	var munkidori := _make_slot(_munkidori_cd(), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	gs.players[0].bench.append(munkidori)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Opponent Tank", "Basic", "C", 220), 1)
	var strategy := _new_strategy()
	var action := {"kind": "use_ability", "source_slot": munkidori, "ability_index": 0}
	var score_no_ko: float = strategy.score_action_absolute(action, gs, 0)
	gs.players[1].active_pokemon.damage_counters = 190
	var score_ko: float = strategy.score_action_absolute(action, gs, 0)
	return assert_true(score_ko > score_no_ko,
		"Munkidori should score higher when shifted tank damage converts into a knockout (%f vs %f)" % [score_ko, score_no_ko])


func test_interaction_target_prefers_damaged_blissey_as_munkidori_source() -> String:
	var gs := _make_game_state(5)
	var blissey := _make_slot(_blissey_cd(), 0)
	blissey.damage_counters = 120
	var chansey := _make_slot(_chansey_cd(), 0)
	chansey.damage_counters = 20
	gs.players[0].active_pokemon = blissey
	gs.players[0].bench.append(chansey)
	var strategy := _new_strategy()
	var step := {"id": "source_pokemon"}
	var context := {"game_state": gs, "player_index": 0, "all_items": [blissey, chansey]}
	var score_blissey: float = strategy.score_interaction_target(blissey, step, context)
	var score_chansey: float = strategy.score_interaction_target(chansey, step, context)
	return assert_true(score_blissey > score_chansey,
		"Munkidori source selection should prefer moving damage off the main tank")


func test_interaction_target_prefers_weakened_opponent_for_damage_move() -> String:
	var gs := _make_game_state(5)
	var strategy := _new_strategy()
	var opponent_active := _make_slot(_make_pokemon_cd("Low HP Target", "Basic", "C", 100), 1)
	opponent_active.damage_counters = 80
	var opponent_bench := _make_slot(_make_pokemon_cd("Healthy Target", "Basic", "C", 180), 1)
	gs.players[1].active_pokemon = opponent_active
	gs.players[1].bench.append(opponent_bench)
	var step := {"id": "target_pokemon"}
	var context := {"game_state": gs, "player_index": 0, "all_items": [opponent_active, opponent_bench]}
	var active_score: float = strategy.score_interaction_target(opponent_active, step, context)
	var bench_score: float = strategy.score_interaction_target(opponent_bench, step, context)
	return assert_true(active_score > bench_score,
		"Damage-moving support should prioritize the soft knockout target")


func test_interaction_target_prefers_munkidori_for_blissey_energy_shift() -> String:
	var gs := _make_game_state(4)
	var blissey := _make_slot(_blissey_cd(), 0)
	gs.players[0].active_pokemon = blissey
	var munkidori := _make_slot(_munkidori_cd(), 0)
	var farigiraf := _make_slot(_farigiraf_cd(), 0)
	gs.players[0].bench.append(munkidori)
	gs.players[0].bench.append(farigiraf)
	var dark := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var strategy := _new_strategy()
	var step := {"id": "assignment_target"}
	var context := {
		"game_state": gs,
		"player_index": 0,
		"all_items": [blissey, munkidori, farigiraf],
		"source_card": dark,
	}
	var score_munkidori: float = strategy.score_interaction_target(munkidori, step, context)
	var score_farigiraf: float = strategy.score_interaction_target(farigiraf, step, context)
	return assert_true(score_munkidori > score_farigiraf,
		"Blissey's energy-move targeting should enable Munkidori before generic support")


func test_turbo_energize_tool_and_assignment_focus_on_next_attacker() -> String:
	var gs := _make_game_state(3)
	var chansey := _make_slot(_chansey_cd(), 0)
	gs.players[0].active_pokemon = chansey
	var blissey := _make_slot(_blissey_cd(), 0)
	var munkidori := _make_slot(_munkidori_cd(), 0)
	gs.players[0].bench.append(blissey)
	gs.players[0].bench.append(munkidori)
	var strategy := _new_strategy()
	var tm := CardInstance.create(_make_tool_cd("Technical Machine: Turbo Energize"), 0)
	var tm_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": tm, "target_slot": chansey},
		gs,
		0
	)
	var cape_score: float = strategy.score_action_absolute(
		{"kind": "attach_tool", "card": CardInstance.create(_make_tool_cd("Hero's Cape"), 0), "target_slot": chansey},
		gs,
		0
	)
	var step := {"id": "assignment_target"}
	var psychic_context := {
		"game_state": gs,
		"player_index": 0,
		"all_items": [blissey, munkidori],
		"source_card": CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
	}
	var psychic_to_blissey: float = strategy.score_interaction_target(blissey, step, psychic_context)
	var psychic_to_munkidori: float = strategy.score_interaction_target(munkidori, step, psychic_context)
	return run_checks([
		assert_true(tm_score > cape_score, "Early Chansey should prefer Turbo Energize over Hero's Cape when it can accelerate the next tank"),
		assert_true(psychic_to_blissey > psychic_to_munkidori, "Turbo Energize routing should push generic energy toward the next attacker before support"),
	])


func test_known_blissey_seed_vs_miraidon_does_not_hit_action_cap() -> String:
	var benchmark_runner := AIBenchmarkRunnerScript.new()
	var gsm := GameStateMachine.new()
	var seed_value := 9000
	benchmark_runner.call("_clear_forced_shuffle_seed")
	benchmark_runner.call("_apply_match_seed", gsm, seed_value)
	benchmark_runner.call("_set_forced_shuffle_seed", seed_value)
	gsm.start_game(CardDatabase.get_deck(581614), CardDatabase.get_deck(575720), 0)
	var trace_collector := TraceCollector.new()
	var result: Dictionary = benchmark_runner.run_headless_duel(
		_make_bundled_ai(0, 581614),
		_make_bundled_ai(1, 575720),
		gsm,
		200,
		Callable(),
		trace_collector
	)
	benchmark_runner.call("_clear_forced_shuffle_seed")
	return run_checks([
		assert_false(bool(result.get("terminated_by_cap", false)),
			"Known seed 9000 should complete without action_cap; tail=%s" % _trace_tail_summary(trace_collector.traces)),
		assert_true(str(result.get("failure_reason", "")) != "action_cap_reached",
			"Known seed 9000 should not end in action_cap_reached"),
	])
