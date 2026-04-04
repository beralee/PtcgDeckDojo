class_name TestAIToolActions
extends TestBase

const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AbilityVSTARSearch = preload("res://scripts/effects/pokemon_effects/AbilityVSTARSearch.gd")


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
	mechanic: String = "",
	effect_id: String = "",
	abilities: Array = []
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 200
	card.energy_type = energy_type
	card.mechanic = mechanic
	card.effect_id = effect_id
	card.abilities.clear()
	for ability: Dictionary in abilities:
		card.abilities.append(ability.duplicate(true))
	return card


func _make_trainer_card_data(name: String, card_type: String, effect_id: String = "") -> CardData:
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


func test_builder_generates_attach_tool_actions_for_valid_slots() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_card := CardInstance.create(_make_pokemon_card_data("Miraidon ex", "L", "ex"), 0)
	var bench_card := CardInstance.create(_make_pokemon_card_data("Iron Hands ex", "L", "ex"), 0)
	player.active_pokemon = _make_slot(active_card)
	player.bench.append(_make_slot(bench_card))
	var tool := CardInstance.create(_make_trainer_card_data("Rescue Board", "Tool", "0b4cc131a19862f92acf71494f29a0ed"), 0)
	player.hand = [tool]

	var attach_actions: Array[Dictionary] = []
	for action: Dictionary in _build_actions(gsm):
		if str(action.get("kind", "")) == "attach_tool":
			attach_actions.append(action)

	var target_names: Array[String] = []
	for action: Dictionary in attach_actions:
		var target_slot: PokemonSlot = action.get("target_slot")
		target_names.append("" if target_slot == null else target_slot.get_pokemon_name())

	return run_checks([
		assert_eq(attach_actions.size(), 2, "Tool in hand should create attach actions for each valid Pokemon slot"),
		assert_contains(target_names, "Miraidon ex", "Attach-tool actions should include the active Pokemon"),
		assert_contains(target_names, "Iron Hands ex", "Attach-tool actions should include eligible bench Pokemon"),
	])


func test_ai_executes_attach_tool_action_and_removes_tool_from_hand() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_card := CardInstance.create(_make_pokemon_card_data("Miraidon ex", "L", "ex"), 0)
	player.active_pokemon = _make_slot(active_card)
	var tool := CardInstance.create(_make_trainer_card_data("Rescue Board", "Tool", "0b4cc131a19862f92acf71494f29a0ed"), 0)
	player.hand = [tool]

	var action := _find_action(_build_actions(gsm), "attach_tool", func(candidate: Dictionary) -> bool:
		return candidate.get("card") == tool and candidate.get("target_slot") == player.active_pokemon
	)
	var ai = AIOpponentScript.new()
	ai.configure(0, 1)
	var executed: bool = bool(ai.call("_execute_action", null, gsm, action))

	return run_checks([
		assert_false(action.is_empty(), "AI should see a concrete attach_tool action before execution"),
		assert_true(executed, "AI should be able to execute an attach_tool action"),
		assert_eq(player.active_pokemon.attached_tool, tool, "Successful execution should attach the tool to the chosen slot"),
		assert_false(tool in player.hand, "Attached tool should be removed from hand"),
	])


func test_forest_seal_stone_attachment_exposes_granted_ability_to_ai() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_cd := _make_pokemon_card_data("Raikou V", "L", "V")
	gsm.effect_processor.register_pokemon_card(active_cd)
	var active_card := CardInstance.create(active_cd, 0)
	player.active_pokemon = _make_slot(active_card)
	var search_target := CardInstance.create(_make_trainer_card_data("Switch Cart", "Item"), 0)
	player.deck = [search_target]
	var forest := CardInstance.create(_make_trainer_card_data("Forest Seal Stone", "Tool", AbilityVSTARSearch.FOREST_SEAL_EFFECT_ID), 0)
	player.hand = [forest]

	var attach_action := _find_action(_build_actions(gsm), "attach_tool", func(candidate: Dictionary) -> bool:
		return candidate.get("card") == forest and candidate.get("target_slot") == player.active_pokemon
	)
	var ai = AIOpponentScript.new()
	ai.configure(0, 1)
	var executed: bool = bool(ai.call("_execute_action", null, gsm, attach_action))
	var ability_action := _find_action(_build_actions(gsm), "use_ability", func(candidate: Dictionary) -> bool:
		return candidate.get("source_slot") == player.active_pokemon
	)

	return run_checks([
		assert_false(attach_action.is_empty(), "Forest Seal Stone should first appear as an attach_tool action"),
		assert_true(executed, "AI should be able to attach Forest Seal Stone"),
		assert_false(ability_action.is_empty(), "After attachment, the granted Forest Seal Stone ability should appear in legal ability actions"),
		assert_eq(int(ability_action.get("ability_index", -1)), 0, "Granted ability should be exposed through the standard ability action path"),
	])


func test_mcts_resolution_can_match_attach_tool_actions() -> String:
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_card := CardInstance.create(_make_pokemon_card_data("Miraidon ex", "L", "ex"), 0)
	player.active_pokemon = _make_slot(active_card)
	var tool := CardInstance.create(_make_trainer_card_data("Rescue Board", "Tool", "0b4cc131a19862f92acf71494f29a0ed"), 0)
	player.hand = [tool]

	var attach_action := _find_action(_build_actions(gsm), "attach_tool")
	var ai = AIOpponentScript.new()
	ai.configure(0, 1)
	var resolved: Dictionary = ai.call("_resolve_mcts_action", gsm, {
		"kind": "attach_tool",
		"card_instance_id": tool.instance_id,
		"target_slot_card_id": active_card.instance_id,
	})

	return run_checks([
		assert_false(attach_action.is_empty(), "Attach-tool should appear in the legal action set before MCTS resolution"),
		assert_false(resolved.is_empty(), "MCTS resolution should be able to resolve serialized attach_tool actions"),
		assert_eq(resolved.get("card"), tool, "Resolved attach_tool action should point at the live tool instance"),
		assert_eq(resolved.get("target_slot"), player.active_pokemon, "Resolved attach_tool action should point at the live slot"),
	])
