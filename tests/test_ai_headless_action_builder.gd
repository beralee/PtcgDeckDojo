class_name TestAIHeadlessActionBuilder
extends TestBase

const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")
const AbilityMoveOpponentDamageCountersScript = preload("res://scripts/effects/pokemon_effects/AbilityMoveOpponentDamageCounters.gd")
const EffectCapturingAromaScript = preload("res://scripts/effects/trainer_effects/EffectCapturingAroma.gd")


class PartialSearchPriorityStrategy extends RefCounted:
	var scores: Dictionary = {}

	func get_search_priority(card: CardInstance) -> int:
		if card == null or card.card_data == null:
			return 0
		return int(scores.get(str(card.card_data.name), 0))


class ExactDiscardSubsetStrategy extends RefCounted:
	var chosen: Array = []

	func pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		if str(step.get("id", "")) != "discard_energy":
			return []
		var selected: Array = []
		for item: Variant in items:
			if item in chosen:
				selected.append(item)
		return selected


class CountingCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []
	var flip_count: int = 0

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		flip_count += 1
		var result: bool = _results.pop_front() if not _results.is_empty() else false
		coin_flipped.emit(result)
		return result


func _make_manual_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	return gsm


func _make_pokemon_card_data(
	name: String,
	energy_type: String = "L",
	effect_id: String = "",
	abilities: Array = []
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	card.energy_type = energy_type
	card.effect_id = effect_id
	card.abilities.clear()
	for ability: Dictionary in abilities:
		card.abilities.append(ability.duplicate(true))
	return card


func _make_trainer_card_data(name: String, card_type: String, effect_id: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.effect_id = effect_id
	return card


func _make_energy_card_data(name: String, energy_type: String = "R") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return card


func _make_slot(card: CardInstance, turn_played: int = 1) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = turn_played
	return slot


func _build_actions(gsm: GameStateMachine) -> Array[Dictionary]:
	var builder = AILegalActionBuilderScript.new()
	return builder.build_actions(gsm, 0)


func _find_action(actions: Array[Dictionary], kind: String, predicate: Callable = Callable()) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		if predicate.is_null() or bool(predicate.call(action)):
			return action
	return {}


func test_builder_generates_headless_nest_ball_targets() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Lead"), 0))
	var nest_ball := CardInstance.create(_make_trainer_card_data("Nest Ball", "Item", "1af63a7e2cb7a79215474ad8db8fd8fd"), 0)
	player.hand = [nest_ball]
	player.deck = [
		CardInstance.create(_make_pokemon_card_data("Miraidon ex", "L"), 0),
		CardInstance.create(_make_pokemon_card_data("Charizard ex", "R"), 0),
	]
	var action := _find_action(_build_actions(gsm), "play_trainer", func(candidate: Dictionary) -> bool:
		return candidate.get("card") == nest_ball
	)
	var targets: Array = action.get("targets", [])
	var ctx: Dictionary = {} if targets.is_empty() else targets[0]
	var selected: Array = ctx.get("basic_pokemon", [])
	return run_checks([
		assert_false(action.is_empty(), "Nest Ball should remain a legal headless action"),
		assert_false(bool(action.get("requires_interaction", true)), "Nest Ball should no longer require headless interaction"),
		assert_eq(selected.size(), 1, "Nest Ball should synthesize a single selected basic Pokemon"),
		assert_eq((selected[0] as CardInstance).card_data.name, "Miraidon ex", "Nest Ball should prefer the lightning basic target"),
	])


func test_builder_generates_headless_arven_targets() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Lead"), 0))
	var arven := CardInstance.create(_make_trainer_card_data("Arven", "Supporter", "5bdbc985f9aa2e6f248b53f6f35d1d37"), 0)
	player.hand = [arven]
	player.deck = [
		CardInstance.create(_make_trainer_card_data("Switch Cart", "Item", ""), 0),
		CardInstance.create(_make_trainer_card_data("Electric Generator", "Item", "b8dfdd5a5b57fef0c7e31bbf6c596f57"), 0),
	]
	var action := _find_action(_build_actions(gsm), "play_trainer", func(candidate: Dictionary) -> bool:
		return candidate.get("card") == arven
	)
	var targets: Array = action.get("targets", [])
	var ctx: Dictionary = {} if targets.is_empty() else targets[0]
	var selected_items: Array = ctx.get("search_item", [])
	return run_checks([
		assert_false(action.is_empty(), "Arven should remain a legal headless action"),
		assert_false(bool(action.get("requires_interaction", true)), "Arven should no longer require headless interaction"),
		assert_eq(selected_items.size(), 1, "Arven should synthesize an item search target"),
		assert_eq((selected_items[0] as CardInstance).card_data.name, "Electric Generator", "Arven should prioritize Electric Generator in Miraidon-focused headless play"),
	])


func test_builder_does_not_flip_coin_while_previewing_live_capturing_aroma() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Lead"), 0))
	var aroma := CardInstance.create(_make_trainer_card_data("Capturing Aroma", "Item", "7c0b20e121c9d0e0d2d8a43524f7494e"), 0)
	player.hand = [aroma]
	var stage_one := _make_pokemon_card_data("Evolution", "R")
	stage_one.stage = "Stage 1"
	player.deck = [CardInstance.create(stage_one, 0)]
	var flipper := CountingCoinFlipper.new([true])
	gsm.effect_processor.register_effect("7c0b20e121c9d0e0d2d8a43524f7494e", EffectCapturingAromaScript.new(flipper))
	var builder := AILegalActionBuilderScript.new()
	var actions: Array[Dictionary] = builder.build_actions(gsm, 0)
	var action := _find_action(actions, "play_trainer", func(candidate: Dictionary) -> bool:
		return candidate.get("card") == aroma
	)
	return run_checks([
		assert_false(action.is_empty(), "Capturing Aroma should still be a legal AI action in live preview mode"),
		assert_true(bool(action.get("requires_interaction", false)), "Capturing Aroma should stay interactive in live preview mode so the real play path owns the coin flip"),
		assert_eq((action.get("targets", []) as Array).size(), 0, "Live preview should not synthesize headless targets for Capturing Aroma before the card is played"),
		assert_eq(flipper.flip_count, 0, "AI action preview should not flip the shared coin before Capturing Aroma is actually played"),
	])


func test_mcts_planner_does_not_emit_live_coin_flips_while_planning_coin_cards() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Lead"), 0))
	opponent.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Target", "G"), 1))
	var aroma := CardInstance.create(_make_trainer_card_data("Capturing Aroma", "Item", "7c0b20e121c9d0e0d2d8a43524f7494e"), 0)
	player.hand = [aroma]
	var stage_one := _make_pokemon_card_data("Evolution", "R")
	stage_one.stage = "Stage 1"
	player.deck = [CardInstance.create(stage_one, 0)]
	var flipper := CountingCoinFlipper.new([true, false, true, false])
	gsm.coin_flipper = flipper
	gsm.effect_processor = EffectProcessor.new(flipper)
	gsm.effect_processor.register_effect("7c0b20e121c9d0e0d2d8a43524f7494e", EffectCapturingAromaScript.new(flipper))
	var planner := MCTSPlannerScript.new()
	var sequence: Array = planner.plan_turn(gsm, 0, {"branch_factor": 2, "max_actions_per_turn": 3, "rollouts_per_sequence": 0, "time_budget_ms": 50})
	return run_checks([
		assert_eq(flipper.flip_count, 0, "MCTS planning should not emit live coin flips while evaluating coin-based cards"),
		assert_false(sequence.is_empty(), "MCTS should still return a legal fallback sequence when coin-based actions are present"),
	])


func test_builder_only_enables_radiant_charizard_attack_after_prize_cost_reduction() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var radiant_charizard_cd: CardData = CardDatabase.get_card("CS5.5C", "007")
	if radiant_charizard_cd == null:
		return "未找到缓存卡 CS5.5C/007"
	gsm.effect_processor.register_pokemon_card(radiant_charizard_cd)

	var active := _make_slot(CardInstance.create(radiant_charizard_cd, 0))
	active.attached_energy.append(CardInstance.create(_make_energy_card_data("Fire Energy", "R"), 0))
	player.active_pokemon = active
	opponent.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Target", "G"), 1))

	opponent.prizes.clear()
	for i: int in 2:
		opponent.prizes.append(CardInstance.create(_make_pokemon_card_data("Prize %d" % i), 1))
	var enabled_action := _find_action(_build_actions(gsm), "attack", func(candidate: Dictionary) -> bool:
		return int(candidate.get("attack_index", -1)) == 0
	)

	opponent.prizes.append(CardInstance.create(_make_pokemon_card_data("Extra Prize"), 1))
	var disabled_action := _find_action(_build_actions(gsm), "attack", func(candidate: Dictionary) -> bool:
		return int(candidate.get("attack_index", -1)) == 0
	)

	return run_checks([
		assert_false(enabled_action.is_empty(), "Radiant Charizard should be an AI legal attack once Excited Heart reduces the cost to 1 Fire Energy"),
		assert_true(disabled_action.is_empty(), "Radiant Charizard should not be an AI legal attack before the opponent has taken enough prizes"),
	])


func test_builder_generates_headless_tandem_unit_targets() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var miraidon := CardInstance.create(_make_pokemon_card_data(
		"Miraidon ex",
		"L",
		"27fbc2c429b05bd8206cd0c7f5d39b11",
		[{"name": "串联装置", "text": ""}]
	), 0)
	gsm.effect_processor.register_pokemon_card(miraidon.card_data)
	player.active_pokemon = _make_slot(miraidon)
	player.deck = [
		CardInstance.create(_make_pokemon_card_data("Lightning Basic A", "L"), 0),
		CardInstance.create(_make_pokemon_card_data("Lightning Basic B", "L"), 0),
		CardInstance.create(_make_pokemon_card_data("Fire Basic", "R"), 0),
	]
	var action := _find_action(_build_actions(gsm), "use_ability", func(candidate: Dictionary) -> bool:
		return candidate.get("source_slot") == player.active_pokemon
	)
	var targets: Array = action.get("targets", [])
	var ctx: Dictionary = {} if targets.is_empty() else targets[0]
	var selected: Array = ctx.get("bench_pokemon", [])
	var first_energy_type: String = "" if selected.size() < 1 else str((selected[0] as CardInstance).card_data.energy_type)
	var second_energy_type: String = "" if selected.size() < 2 else str((selected[1] as CardInstance).card_data.energy_type)
	return run_checks([
		assert_false(action.is_empty(), "Tandem Unit should remain a legal headless action"),
		assert_false(bool(action.get("requires_interaction", true)), "Tandem Unit should no longer require headless interaction"),
		assert_eq(selected.size(), 2, "Tandem Unit should synthesize two selected lightning basics when available"),
		assert_eq(first_energy_type, "L", "Selected bench Pokemon should match the lightning filter"),
		assert_eq(second_energy_type, "L", "Selected bench Pokemon should match the lightning filter"),
	])


func test_builder_uses_search_priority_fallback_when_interaction_scoring_is_missing() -> String:
	var gsm := _make_manual_gsm()
	var builder = AILegalActionBuilderScript.new()
	var strategy := PartialSearchPriorityStrategy.new()
	strategy.scores = {"Rare Candy": 200, "Buddy-Buddy Poffin": 80}
	builder._deck_strategy = strategy
	builder._deck_strategy_detected = true
	var selected: Variant = builder._resolve_headless_step(gsm, 0, 0, {
		"id": "search_item",
		"items": [
			CardInstance.create(_make_trainer_card_data("Buddy-Buddy Poffin", "Item", ""), 0),
			CardInstance.create(_make_trainer_card_data("Rare Candy", "Item", ""), 0),
		],
		"min_select": 1,
		"max_select": 1,
	})
	var picked: Array = selected.get("search_item", [])
	var picked_name := "" if picked.is_empty() else str((picked[0] as CardInstance).card_data.name)
	return assert_eq(picked_name, "Rare Candy",
		"Headless search fallback should respect get_search_priority even when score_interaction_target is not implemented")


func test_builder_splits_counter_distribution_across_multiple_knockouts_when_possible() -> String:
	var gsm := _make_manual_gsm()
	var builder = AILegalActionBuilderScript.new()
	var target_a := _make_slot(CardInstance.create(_make_pokemon_card_data("Target A", "P"), 1))
	target_a.damage_counters = 80
	target_a.pokemon_stack[0].card_data.hp = 100
	var target_b := _make_slot(CardInstance.create(_make_pokemon_card_data("Target B", "P"), 1))
	target_b.damage_counters = 70
	target_b.pokemon_stack[0].card_data.hp = 100
	var result: Variant = builder._resolve_headless_step(gsm, 0, 0, {
		"id": "spread_damage",
		"ui_mode": "counter_distribution",
		"total_counters": 5,
		"target_items": [target_a, target_b],
	})
	var assignments: Array = result.get("spread_damage", [])
	var total_amount: int = 0
	if assignments.size() >= 2:
		total_amount = int(assignments[0].get("amount", 0)) + int(assignments[1].get("amount", 0))
	return run_checks([
		assert_eq(assignments.size(), 2, "Generic counter distribution should split across multiple targets when that produces extra knockouts"),
		assert_eq(total_amount, 50, "Counter distribution should account for the full available damage"),
	])


func test_builder_allows_strategy_to_choose_exact_discard_subset_for_variable_discard_steps() -> String:
	var gsm := _make_manual_gsm()
	var builder = AILegalActionBuilderScript.new()
	var strategy := ExactDiscardSubsetStrategy.new()
	var energy_a := CardInstance.create(_make_trainer_card_data("Energy A", "Basic Energy", ""), 0)
	energy_a.card_data.energy_provides = "L"
	var energy_b := CardInstance.create(_make_trainer_card_data("Energy B", "Basic Energy", ""), 0)
	energy_b.card_data.energy_provides = "G"
	var energy_c := CardInstance.create(_make_trainer_card_data("Energy C", "Basic Energy", ""), 0)
	energy_c.card_data.energy_provides = "F"
	strategy.chosen = [energy_b]
	builder._deck_strategy = strategy
	builder._deck_strategy_detected = true
	var selected: Variant = builder._resolve_headless_step(gsm, 0, 0, {
		"id": "discard_energy",
		"items": [energy_a, energy_b, energy_c],
		"min_select": 0,
		"max_select": 3,
	})
	var picked: Array = selected.get("discard_energy", [])
	return run_checks([
		assert_eq(picked.size(), 1, "Headless variable discard steps should allow strategy to choose fewer than max_select items"),
		assert_true(picked[0] == energy_b, "Headless variable discard should preserve the strategy-chosen subset"),
	])


func test_builder_excludes_previously_selected_source_from_followup_target_steps() -> String:
	var gsm := _make_manual_gsm()
	var builder = AILegalActionBuilderScript.new()
	var player_0: PlayerState = gsm.game_state.players[0]
	var player_1: PlayerState = gsm.game_state.players[1]
	var alakazam := CardInstance.create(_make_pokemon_card_data("Radiant Alakazam", "P"), 0)
	player_0.active_pokemon = _make_slot(alakazam)
	var source_slot := _make_slot(CardInstance.create(_make_pokemon_card_data("Opp Active", "C"), 1))
	source_slot.damage_counters = 20
	var target_slot := _make_slot(CardInstance.create(_make_pokemon_card_data("Opp Bench", "C"), 1))
	player_1.active_pokemon = source_slot
	player_1.bench = [target_slot]
	var effect := AbilityMoveOpponentDamageCountersScript.new()
	var targets: Variant = builder._build_headless_targets_from_steps(gsm, 0, 0, effect.get_interaction_steps(alakazam, gsm.game_state))
	var ctx: Dictionary = {} if not (targets is Array) or (targets as Array).is_empty() else (targets as Array)[0]
	var selected_sources: Array = ctx.get("source_pokemon", [])
	var selected_targets: Array = ctx.get("target_pokemon", [])
	return run_checks([
		assert_eq(selected_sources.size(), 1, "Radiant Alakazam should still choose exactly one damaged source"),
		assert_eq(selected_targets.size(), 1, "Radiant Alakazam should still choose exactly one destination target"),
		assert_true(selected_sources[0] != selected_targets[0], "Follow-up target selection should not be allowed to pick the same Pokemon as the chosen source"),
		assert_true(selected_targets[0] == target_slot, "When only one legal destination remains, headless selection should pick that remaining target"),
	])
