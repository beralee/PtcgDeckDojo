class_name TestAIHeadlessActionBuilder
extends TestBase

const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")
const AbilityMoveOpponentDamageCountersScript = preload("res://scripts/effects/pokemon_effects/AbilityMoveOpponentDamageCounters.gd")
const EffectCapturingAromaScript = preload("res://scripts/effects/trainer_effects/EffectCapturingAroma.gd")
const EffectRareCandyScript = preload("res://scripts/effects/trainer_effects/EffectRareCandy.gd")


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


class ExactBenchSubsetStrategy extends RefCounted:
	var chosen: Array = []

	func pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		if str(step.get("id", "")) != "buddy_poffin_pokemon":
			return []
		var selected: Array = []
		for wanted: Variant in chosen:
			for item: Variant in items:
				if item == wanted:
					selected.append(item)
					break
		return selected


class ExactEnergyAssignmentSubsetStrategy extends RefCounted:
	var chosen: Array = []

	func pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		if str(step.get("id", "")) != "energy_assignments":
			return []
		var selected: Array = []
		for wanted: Variant in chosen:
			for item: Variant in items:
				if item == wanted:
					selected.append(item)
					break
		return selected


class ContextAwareSearchPairStrategy extends RefCounted:
	func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
		if not (item is CardInstance) or (item as CardInstance).card_data == null:
			return 0.0
		var name: String = str((item as CardInstance).card_data.name)
		var step_id: String = str(step.get("id", ""))
		if step_id == "search_item":
			if name == "Earthen Vessel":
				return 100.0
			if name == "Ultra Ball":
				return 10.0
			return 0.0
		if step_id == "search_tool":
			var selected_item: Variant = context.get("search_item", [])
			var selected_name: String = ""
			if selected_item is Array and not (selected_item as Array).is_empty():
				var first_item: Variant = (selected_item as Array)[0]
				if first_item is CardInstance and (first_item as CardInstance).card_data != null:
					selected_name = str((first_item as CardInstance).card_data.name)
			if selected_name == "Earthen Vessel":
				return 100.0 if name == "TM Evolution" else 10.0
			return 100.0 if name == "Bravery Charm" else 10.0
		return 0.0


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


func test_builder_uses_pick_interaction_items_for_multi_select_bench_prompts() -> String:
	var builder := AILegalActionBuilderScript.new()
	var strategy := ExactBenchSubsetStrategy.new()
	var charmander := CardInstance.create(_make_pokemon_card_data("Charmander", "R"), 0)
	var pidgey := CardInstance.create(_make_pokemon_card_data("Pidgey", "C"), 0)
	var duskull := CardInstance.create(_make_pokemon_card_data("Duskull", "P"), 0)
	var items: Array = [charmander, pidgey, duskull]
	strategy.chosen = [pidgey, charmander]
	builder.set_deck_strategy(strategy)
	var picked: Array = builder.call("_pick_items_with_strategy", items, "buddy_poffin_pokemon", 2, {})
	var first_picked: Variant = picked[0] if picked.size() > 0 else null
	var second_picked: Variant = picked[1] if picked.size() > 1 else null
	return run_checks([
		assert_eq(picked.size(), 2, "AILegalActionBuilder should honor custom multi-select plans from pick_interaction_items"),
		assert_eq(first_picked, pidgey, "Custom multi-select plans should preserve the strategy's requested order"),
		assert_eq(second_picked, charmander, "Custom multi-select plans should keep the full requested subset"),
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


func test_builder_uses_charizard_strategy_for_supporter_card_steps() -> String:
	var gsm := _make_manual_gsm()
	var builder := AILegalActionBuilderScript.new()
	var strategy_script: Variant = load("res://scripts/ai/DeckStrategyCharizardEx.gd")
	if strategy_script == null:
		return "DeckStrategyCharizardEx.gd should load before Lumineon supporter selection can be verified"
	builder.set_deck_strategy(strategy_script.new())
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Charmander", "R"), 0))
	player.deck = [
		CardInstance.create(_make_trainer_card_data("Rare Candy", "Item", ""), 0),
		CardInstance.create(_make_trainer_card_data("Buddy-Buddy Poffin", "Item", ""), 0),
		CardInstance.create(_make_trainer_card_data("Nest Ball", "Item", ""), 0),
	]
	var selected: Variant = builder._resolve_headless_step(gsm, 0, 0, {
		"id": "supporter_card",
		"items": [
			CardInstance.create(_make_trainer_card_data("Boss's Orders", "Supporter", ""), 0),
			CardInstance.create(_make_trainer_card_data("Arven", "Supporter", ""), 0),
		],
		"min_select": 1,
		"max_select": 1,
	})
	var picked: Array = selected.get("supporter_card", []) if selected is Dictionary else []
	var picked_name := "" if picked.is_empty() else str((picked[0] as CardInstance).card_data.name)
	return assert_eq(picked_name, "Arven",
		"Charizard headless interaction should treat Lumineon V supporter search as a scored strategy step and pick Arven in the opening bridge window")


func test_builder_uses_charizard_strategy_for_rare_candy_pairing() -> String:
	var gsm := _make_manual_gsm()
	gsm.game_state.turn_number = 3
	var builder := AILegalActionBuilderScript.new()
	var strategy_script: Variant = load("res://scripts/ai/DeckStrategyCharizardEx.gd")
	if strategy_script == null:
		return "DeckStrategyCharizardEx.gd should load before Rare Candy pairing can be verified"
	builder.set_deck_strategy(strategy_script.new())

	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Pidgey", "C"), 0))
	player.bench = [_make_slot(CardInstance.create(_make_pokemon_card_data("Charmander", "R"), 0))]

	var miraidon_cd := _make_pokemon_card_data("Miraidon ex", "L")
	miraidon_cd.mechanic = "ex"
	opponent.active_pokemon = _make_slot(CardInstance.create(miraidon_cd, 1))

	var rare_candy := CardInstance.create(_make_trainer_card_data("Rare Candy", "Item", ""), 0)
	var charizard_cd := _make_pokemon_card_data("Charizard ex", "R")
	charizard_cd.stage = "Stage 2"
	charizard_cd.evolves_from = "Charmeleon"
	charizard_cd.mechanic = "ex"
	var pidgeot_cd := _make_pokemon_card_data("Pidgeot ex", "C")
	pidgeot_cd.stage = "Stage 2"
	pidgeot_cd.evolves_from = "Pidgeotto"
	pidgeot_cd.mechanic = "ex"
	player.hand = [
		rare_candy,
		CardInstance.create(charizard_cd, 0),
		CardInstance.create(pidgeot_cd, 0),
	]
	var charmeleon_cd := _make_pokemon_card_data("Charmeleon", "R")
	charmeleon_cd.stage = "Stage 1"
	charmeleon_cd.evolves_from = "Charmander"
	var pidgeotto_cd := _make_pokemon_card_data("Pidgeotto", "C")
	pidgeotto_cd.stage = "Stage 1"
	pidgeotto_cd.evolves_from = "Pidgey"
	player.deck = [
		CardInstance.create(charmeleon_cd, 0),
		CardInstance.create(pidgeotto_cd, 0),
	]

	var steps: Array[Dictionary] = EffectRareCandyScript.new().get_interaction_steps(rare_candy, gsm.game_state)
	var targets: Variant = builder._build_headless_targets_from_steps(gsm, 0, 0, steps)
	var ctx: Dictionary = {} if not (targets is Array) or (targets as Array).is_empty() else (targets as Array)[0]
	var selected_stage2: Array = ctx.get("stage2_card", [])
	var selected_target: Array = ctx.get("target_pokemon", [])
	var stage2_name := "" if selected_stage2.is_empty() else str((selected_stage2[0] as CardInstance).card_data.name)
	var target_name := "" if selected_target.is_empty() else str((selected_target[0] as PokemonSlot).get_pokemon_name())
	return run_checks([
		assert_eq(stage2_name, "Charizard ex",
			"Against lightning pressure, Charizard should be the preferred Rare Candy Stage 2 line"),
		assert_eq(target_name, "Charmander",
			"Rare Candy headless pairing must choose the matching basic for the selected Stage 2 instead of consuming the card on an invalid pair"),
	])


func test_builder_passes_previous_search_selection_into_followup_tool_choice() -> String:
	var gsm := _make_manual_gsm()
	var builder := AILegalActionBuilderScript.new()
	builder.set_deck_strategy(ContextAwareSearchPairStrategy.new())
	var steps: Array[Dictionary] = [
		{
			"id": "search_item",
			"items": [
				CardInstance.create(_make_trainer_card_data("Ultra Ball", "Item", ""), 0),
				CardInstance.create(_make_trainer_card_data("Earthen Vessel", "Item", ""), 0),
			],
			"min_select": 1,
			"max_select": 1,
		},
		{
			"id": "search_tool",
			"items": [
				CardInstance.create(_make_trainer_card_data("TM Evolution", "Tool", ""), 0),
				CardInstance.create(_make_trainer_card_data("Bravery Charm", "Tool", ""), 0),
			],
			"min_select": 1,
			"max_select": 1,
		},
	]
	var targets: Variant = builder._build_headless_targets_from_steps(gsm, 0, 0, steps)
	var ctx: Dictionary = {} if not (targets is Array) or (targets as Array).is_empty() else (targets as Array)[0]
	var selected_items: Array = ctx.get("search_item", [])
	var selected_tools: Array = ctx.get("search_tool", [])
	var selected_item_name: String = "" if selected_items.is_empty() else str((selected_items[0] as CardInstance).card_data.name)
	var selected_tool_name: String = "" if selected_tools.is_empty() else str((selected_tools[0] as CardInstance).card_data.name)
	return run_checks([
		assert_eq(selected_item_name, "Earthen Vessel", "Headless builder should preserve the best search_item choice"),
		assert_eq(selected_tool_name, "TM Evolution", "Follow-up tool selection should see the prior search_item choice"),
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


func test_builder_splits_infernal_reign_between_charizard_and_retreat_pivot() -> String:
	var gsm := _make_manual_gsm()
	gsm.game_state.turn_number = 3
	var builder := AILegalActionBuilderScript.new()
	var strategy_script: Variant = load("res://scripts/ai/DeckStrategyCharizardEx.gd")
	if strategy_script == null:
		return "DeckStrategyCharizardEx.gd should load before headless Infernal Reign routing can be verified"
	builder.set_deck_strategy(strategy_script.new())

	var player: PlayerState = gsm.game_state.players[0]
	var rotom_cd := _make_pokemon_card_data("Rotom V", "L")
	rotom_cd.mechanic = "V"
	rotom_cd.retreat_cost = 1
	var active_rotom := _make_slot(CardInstance.create(rotom_cd, 0))
	player.active_pokemon = active_rotom

	var charizard_cd := CardData.new()
	charizard_cd.name = "Charizard ex"
	charizard_cd.card_type = "Pokemon"
	charizard_cd.stage = "Stage 2"
	charizard_cd.evolves_from = "Charmeleon"
	charizard_cd.energy_type = "R"
	charizard_cd.mechanic = "ex"
	charizard_cd.hp = 330
	charizard_cd.retreat_cost = 2
	charizard_cd.attacks = [{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	var benched_charizard := _make_slot(CardInstance.create(charizard_cd, 0))
	player.bench = [benched_charizard]

	var fire_a := CardInstance.create(_make_energy_card_data("Fire A", "R"), 0)
	var fire_b := CardInstance.create(_make_energy_card_data("Fire B", "R"), 0)
	var fire_c := CardInstance.create(_make_energy_card_data("Fire C", "R"), 0)
	var resolved: Variant = builder.call("_resolve_headless_assignment_step", gsm, 0, 0, {
		"id": "energy_assignments",
		"source_items": [fire_a, fire_b, fire_c],
		"target_items": [active_rotom, benched_charizard],
		"min_select": 0,
		"max_select": 3,
	})
	var assignments: Array = resolved.get("energy_assignments", []) if resolved is Dictionary else []
	var charizard_count := 0
	var rotom_count := 0
	for assignment_variant: Variant in assignments:
		if not (assignment_variant is Dictionary):
			continue
		var target: Variant = (assignment_variant as Dictionary).get("target")
		if target == benched_charizard:
			charizard_count += 1
		elif target == active_rotom:
			rotom_count += 1
	return run_checks([
		assert_eq(assignments.size(), 3, "Infernal Reign should still plan all three selected Fire Energy assignments"),
		assert_true(charizard_count >= 2,
			"When Charizard ex is still two Energy short, headless planning should route at least two Fire Energy to Charizard instead of feeding the retreat pivot (got %d)" % charizard_count),
		assert_true(rotom_count <= 1,
			"The retreat pivot should receive at most one Fire Energy in this opening conversion window (got %d)" % rotom_count),
	])


func test_builder_allows_strategy_to_choose_exact_energy_assignment_sources() -> String:
	var gsm := _make_manual_gsm()
	var builder = AILegalActionBuilderScript.new()
	var strategy := ExactEnergyAssignmentSubsetStrategy.new()
	var grass_a := CardInstance.create(_make_energy_card_data("Grass A", "G"), 0)
	var grass_b := CardInstance.create(_make_energy_card_data("Grass B", "G"), 0)
	var psychic := CardInstance.create(_make_energy_card_data("Psychic A", "P"), 0)
	strategy.chosen = [grass_a, psychic]
	builder._deck_strategy = strategy
	builder._deck_strategy_detected = true
	var active := _make_slot(CardInstance.create(_make_pokemon_card_data("Active"), 0))
	var bench := _make_slot(CardInstance.create(_make_pokemon_card_data("Bench"), 0))
	var resolved: Variant = builder.call("_resolve_headless_assignment_step", gsm, 0, 0, {
		"id": "energy_assignments",
		"source_items": [grass_a, grass_b, psychic],
		"target_items": [active, bench],
		"min_select": 0,
		"max_select": 2,
	})
	var assignments: Array = resolved.get("energy_assignments", []) if resolved is Dictionary else []
	var chosen_sources: Array = []
	for assignment_variant: Variant in assignments:
		if assignment_variant is Dictionary:
			chosen_sources.append((assignment_variant as Dictionary).get("source"))
	return run_checks([
		assert_eq(assignments.size(), 2, "Energy assignment planning should still produce the requested number of assignments"),
		assert_true(grass_a in chosen_sources, "Headless energy assignment should honor the strategy-picked first Energy source"),
		assert_true(psychic in chosen_sources, "Headless energy assignment should honor the strategy-picked mixed Energy source set"),
		assert_true(not (grass_b in chosen_sources), "Headless energy assignment should not fall back to raw source order when the strategy picked an exact subset"),
	])


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


func test_builder_excludes_knocked_out_slots_from_attach_and_attack_actions() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active_cd := _make_pokemon_card_data("Active", "P")
	active_cd.attacks = [{"name": "Tap", "cost": "", "damage": "30"}]
	var active := _make_slot(CardInstance.create(active_cd, 0))
	active.damage_counters = 120
	var dead_bench := _make_slot(CardInstance.create(_make_pokemon_card_data("Dead Bench", "P"), 0))
	dead_bench.damage_counters = 100
	var live_bench := _make_slot(CardInstance.create(_make_pokemon_card_data("Live Bench", "P"), 0))
	player.active_pokemon = active
	player.bench = [dead_bench, live_bench]
	opponent.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Target", "L"), 1))
	var tm_cd: CardData = CardDatabase.get_card("CSV5C", "119")
	if tm_cd == null:
		return "TM Evolution should exist for granted-attack regression"
	active.attached_tool = CardInstance.create(tm_cd, 0)
	player.hand = [
		CardInstance.create(_make_trainer_card_data("Bravery Charm", "Tool", ""), 0),
		CardInstance.create(_make_energy_card_data("Psychic Energy", "P"), 0),
	]
	var actions := _build_actions(gsm)
	var dead_attach_targets: Array = actions.filter(func(action: Dictionary) -> bool:
		if str(action.get("kind", "")) not in ["attach_energy", "attach_tool"]:
			return false
		var target: PokemonSlot = action.get("target_slot")
		return target == active or target == dead_bench
	)
	var attack_actions: Array = actions.filter(func(action: Dictionary) -> bool:
		return str(action.get("kind", "")) == "attack" or str(action.get("kind", "")) == "granted_attack"
	)
	return run_checks([
		assert_eq(dead_attach_targets.size(), 0, "AI builder should not target knocked out slots with attach actions"),
		assert_eq(attack_actions.size(), 0, "AI builder should not expose attack or granted-attack lines from a knocked out Active Pokemon"),
	])


func test_builder_retreats_only_to_live_bench_targets() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active_cd := _make_pokemon_card_data("Pivot", "P")
	active_cd.retreat_cost = 1
	var active := _make_slot(CardInstance.create(active_cd, 0))
	active.attached_energy.append(CardInstance.create(_make_energy_card_data("Psychic Energy", "P"), 0))
	var dead_bench := _make_slot(CardInstance.create(_make_pokemon_card_data("Dead Bench", "P"), 0))
	dead_bench.damage_counters = 100
	var live_bench := _make_slot(CardInstance.create(_make_pokemon_card_data("Live Bench", "P"), 0))
	player.active_pokemon = active
	player.bench = [dead_bench, live_bench]
	opponent.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card_data("Target", "L"), 1))
	var retreats: Array = _build_actions(gsm).filter(func(action: Dictionary) -> bool:
		return str(action.get("kind", "")) == "retreat"
	)
	var dead_targeted: Array = retreats.filter(func(action: Dictionary) -> bool:
		return action.get("bench_target") == dead_bench
	)
	var live_targeted: Array = retreats.filter(func(action: Dictionary) -> bool:
		return action.get("bench_target") == live_bench
	)
	return run_checks([
		assert_eq(dead_targeted.size(), 0, "Retreat actions should never target knocked out benched Pokemon"),
		assert_eq(live_targeted.size(), 1, "Retreat builder should preserve the live bench target"),
	])
