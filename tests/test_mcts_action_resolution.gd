class_name TestMCTSActionResolution
extends TestBase

const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")
const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")


func _make_basic_card_data(card_name: String, hp: int = 100) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _make_energy_card_data(card_name: String, energy_type: String = "L") -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return card


func _make_manual_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	return gsm


func test_resolve_action_prefers_card_instance_id_over_raw_reference() -> String:
	var planner := MCTSPlannerScript.new()
	var cloner := GameStateClonerScript.new()
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Lead"), 0))
	player.active_pokemon = active
	var energy := CardInstance.create(_make_energy_card_data("Lightning Energy"), 0)
	player.hand.append(energy)

	var cloned_gsm: GameStateMachine = cloner.clone_gsm(gsm)
	var resolved: Dictionary = planner._resolve_action_for_gsm({
		"kind": "attach_energy",
		"card_instance_id": energy.instance_id,
		"card": null,
		"target_slot_card_id": active.get_top_card().instance_id,
		"target_slot": null,
	}, cloned_gsm, 0)
	var resolved_card: CardInstance = resolved.get("card")
	var resolved_slot: PokemonSlot = resolved.get("target_slot")
	var checks: Array[String] = [
		assert_true(resolved_card != null, "card_instance_id should be enough to resolve a hand card on the cloned GSM"),
		assert_true(resolved_slot != null, "target_slot_card_id should be enough to resolve a slot on the cloned GSM"),
	]
	if resolved_card != null:
		checks.append(assert_true(resolved_card in cloned_gsm.game_state.players[0].hand, "resolved attach card should come from the cloned hand"))
	if resolved_slot != null:
		checks.append(assert_eq(resolved_slot.get_pokemon_name(), "Lead", "resolved slot should point at the cloned target slot"))
	return run_checks(checks)


func test_resolve_action_maps_nested_target_card_refs_via_instance_id() -> String:
	var planner := MCTSPlannerScript.new()
	var cloner := GameStateClonerScript.new()
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Lead"), 0))
	player.active_pokemon = active
	var nest_ball_target := CardInstance.create(_make_basic_card_data("Bench Basic"), 0)
	player.deck.append(nest_ball_target)

	var cloned_gsm: GameStateMachine = cloner.clone_gsm(gsm)
	var resolved: Dictionary = planner._resolve_action_for_gsm({
		"kind": "play_trainer",
		"targets": [{
			"basic_pokemon": [{
				"__type": "card_ref",
				"instance_id": nest_ball_target.instance_id,
				"owner_index": 0,
			}],
		}],
	}, cloned_gsm, 0)
	var resolved_targets: Array = resolved.get("targets", [])
	var resolved_ctx: Dictionary = {} if resolved_targets.is_empty() else resolved_targets[0]
	var resolved_cards: Array = resolved_ctx.get("basic_pokemon", [])
	var resolved_card: Variant = null if resolved_cards.is_empty() else resolved_cards[0]
	var checks: Array[String] = [
		assert_true(resolved_card != null, "nested card_ref targets should resolve on the cloned GSM"),
		assert_true(resolved_card is CardInstance, "nested card_ref targets should resolve to CardInstance objects"),
	]
	if resolved_card is CardInstance:
		checks.append(assert_true(resolved_card in cloned_gsm.game_state.players[0].deck, "nested target should point at the cloned deck card"))
		checks.append(assert_eq(int(resolved_card.instance_id), nest_ball_target.instance_id, "resolved nested target should preserve instance id"))
	return run_checks(checks)


func test_serialize_action_replaces_live_refs_with_stable_ids() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Lead"), 0))
	player.active_pokemon = active
	var energy := CardInstance.create(_make_energy_card_data("Lightning Energy"), 0)
	player.hand.append(energy)
	var target_basic := CardInstance.create(_make_basic_card_data("Bench Basic"), 0)
	player.deck.append(target_basic)

	var serialized: Dictionary = planner._serialize_action({
		"kind": "attach_energy",
		"card": energy,
		"target_slot": active,
		"targets": [{
			"basic_pokemon": [target_basic],
			"target_slot": active,
		}],
	})
	var serialized_targets: Array = serialized.get("targets", [])
	var target_ctx: Dictionary = {} if serialized_targets.is_empty() else serialized_targets[0]
	var basic_targets: Array = target_ctx.get("basic_pokemon", [])
	var slot_ref: Variant = target_ctx.get("target_slot")
	var first_basic: Variant = null if basic_targets.is_empty() else basic_targets[0]
	var checks: Array[String] = [
		assert_eq(int(serialized.get("card_instance_id", -1)), energy.instance_id, "serialized actions should keep hand card ids"),
		assert_true(not serialized.has("card"), "serialized actions should not retain live card references"),
		assert_eq(int(serialized.get("target_slot_card_id", -1)), active.get_top_card().instance_id, "serialized actions should keep slot ids"),
		assert_true(not serialized.has("target_slot"), "serialized actions should not retain live slot references"),
		assert_true(first_basic is Dictionary, "nested card targets should serialize to stable dictionaries"),
		assert_true(slot_ref is Dictionary, "nested slot targets should serialize to slot_ref dictionaries"),
	]
	if first_basic is Dictionary:
		checks.append(assert_eq(str((first_basic as Dictionary).get("__type", "")), "card_ref", "nested card targets should become card_ref dictionaries"))
		checks.append(assert_eq(int((first_basic as Dictionary).get("instance_id", -1)), target_basic.instance_id, "nested card targets should keep instance ids"))
	if slot_ref is Dictionary:
		checks.append(assert_eq(str((slot_ref as Dictionary).get("__type", "")), "slot_ref", "nested slot targets should become slot_ref dictionaries"))
		checks.append(assert_eq(int((slot_ref as Dictionary).get("top_card_id", -1)), active.get_top_card().instance_id, "nested slot targets should keep top card ids"))
	return run_checks(checks)


func test_resolve_retreat_targets_from_serialized_ids() -> String:
	var planner := MCTSPlannerScript.new()
	var cloner := GameStateClonerScript.new()
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Lead"), 0))
	var attached_energy := CardInstance.create(_make_energy_card_data("Lightning Energy"), 0)
	active.attached_energy.append(attached_energy)
	player.active_pokemon = active
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Bench Target"), 0))
	player.bench.append(bench)

	var cloned_gsm: GameStateMachine = cloner.clone_gsm(gsm)
	var resolved: Dictionary = planner._resolve_action_for_gsm({
		"kind": "retreat",
		"bench_target_card_id": bench.get_top_card().instance_id,
		"energy_to_discard_ids": PackedInt32Array([attached_energy.instance_id]),
	}, cloned_gsm, 0)
	var resolved_bench: PokemonSlot = resolved.get("bench_target")
	var resolved_discard: Array = resolved.get("energy_to_discard", [])
	var resolved_energy: Variant = null if resolved_discard.is_empty() else resolved_discard[0]
	var checks: Array[String] = [
		assert_true(resolved_bench != null, "bench_target_card_id should resolve retreat target slots on the cloned GSM"),
		assert_eq(-1 if resolved_bench == null or resolved_bench.get_top_card() == null else resolved_bench.get_top_card().instance_id, bench.get_top_card().instance_id, "resolved retreat target should preserve the bench top-card id"),
		assert_eq(resolved_discard.size(), 1, "energy_to_discard_ids should resolve attached energy selections"),
	]
	if resolved_energy != null:
		checks.append(assert_eq(int(resolved_energy.instance_id), attached_energy.instance_id, "resolved discard energy should preserve instance id"))
	return run_checks(checks)


func test_try_execute_action_supports_attach_tool_on_cloned_state() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Lead"), 0))
	player.active_pokemon = active
	var tool_data := CardData.new()
	tool_data.name = "Rescue Board"
	tool_data.card_type = "Tool"
	var tool := CardInstance.create(tool_data, 0)
	player.hand.append(tool)

	var executed: bool = planner._try_execute_action(gsm, 0, {
		"kind": "attach_tool",
		"card": tool,
		"target_slot": active,
	})

	return run_checks([
		assert_true(executed, "MCTS planner simulation should execute attach_tool actions"),
		assert_eq(active.attached_tool, tool, "Successful simulated attach_tool should attach the tool to the target slot"),
		assert_false(tool in player.hand, "Successful simulated attach_tool should remove the tool from hand"),
	])
