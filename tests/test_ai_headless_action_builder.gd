class_name TestAIHeadlessActionBuilder
extends TestBase

const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")


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
