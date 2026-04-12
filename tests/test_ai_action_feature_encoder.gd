class_name TestAIActionFeatureEncoder
extends TestBase

const AIActionFeatureEncoderScript = preload("res://scripts/ai/AIActionFeatureEncoder.gd")
const AIFeatureExtractorScript = preload("res://scripts/ai/AIFeatureExtractor.gd")


func _make_player_state(player_index: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = player_index
	return player


func _make_ai_manual_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 4
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	CardInstance.reset_id_counter()
	return gsm


func _make_pokemon_card(
	name: String,
	stage: String = "Basic",
	evolves_from: String = "",
	attacks: Array = [],
	mechanic: String = "",
	energy_type: String = "L"
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.hp = 220
	card.energy_type = energy_type
	card.mechanic = mechanic
	card.attacks.clear()
	for attack: Variant in attacks:
		if attack is Dictionary:
			card.attacks.append(attack.duplicate(true))
	return card


func _make_energy_card(name: String, energy_type: String = "L") -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return CardInstance.create(card, 0)


func _make_trainer_card(name: String, card_type: String = "Item", effect_id: String = "") -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.effect_id = effect_id
	return CardInstance.create(card, 0)


func _make_slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func test_action_feature_encoder_returns_stable_vector_shape_for_supported_actions() -> String:
	var encoder = AIActionFeatureEncoderScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_slot(CardInstance.create(_make_pokemon_card("Miraidon ex", "Basic", "", [{
		"name": "Zap",
		"cost": "L",
		"damage": "160",
	}], "ex", "L"), 0))
	var bench_slot := _make_slot(CardInstance.create(_make_pokemon_card("Raikou V", "Basic", "", [], "V", "L"), 0))
	player.active_pokemon = active_slot
	player.bench = [bench_slot]
	player.hand = [
		_make_trainer_card("Nest Ball", "Item", "1af63a7e2cb7a79215474ad8db8fd8fd"),
		_make_trainer_card("Forest Seal Stone", "Tool", "9fa9943ccda36f417ac3cb675177c216"),
		_make_energy_card("Lightning Energy", "L"),
	]

	var actions: Array[Dictionary] = [
		{"kind": "play_trainer", "card": player.hand[0]},
		{"kind": "attach_tool", "card": player.hand[1], "target_slot": active_slot},
		{"kind": "attach_energy", "card": player.hand[2], "target_slot": active_slot},
		{"kind": "attack", "attack_index": 0},
	]
	var lengths: Array[int] = []
	for action: Dictionary in actions:
		lengths.append(encoder.build_vector(gsm, 0, action).size())

	return run_checks([
		assert_eq(lengths.size(), 4, "Fixture should build four action vectors"),
		assert_eq(lengths[0], lengths[1], "All supported action kinds should share one vector shape"),
		assert_eq(lengths[1], lengths[2], "All supported action kinds should share one vector shape"),
		assert_eq(lengths[2], lengths[3], "All supported action kinds should share one vector shape"),
		assert_gt(lengths[0], 8, "Action vector should be richer than a trivial handful of flags"),
	])


func test_action_feature_encoder_marks_attach_tool_target_role() -> String:
	var encoder = AIActionFeatureEncoderScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_slot(CardInstance.create(_make_pokemon_card("Miraidon ex", "Basic", "", [], "ex", "L"), 0))
	var bench_slot := _make_slot(CardInstance.create(_make_pokemon_card("Raikou V", "Basic", "", [], "V", "L"), 0))
	player.active_pokemon = active_slot
	player.bench = [bench_slot]
	var tool := _make_trainer_card("Rescue Board", "Tool", "0b4cc131a19862f92acf71494f29a0ed")

	var active_features: Dictionary = encoder.build_features(gsm, 0, {
		"kind": "attach_tool",
		"card": tool,
		"target_slot": active_slot,
	})
	var bench_features: Dictionary = encoder.build_features(gsm, 0, {
		"kind": "attach_tool",
		"card": tool,
		"target_slot": bench_slot,
	})

	return run_checks([
		assert_true(bool(active_features.get("is_active_target", false)), "Tool attach should mark active targets"),
		assert_false(bool(active_features.get("is_bench_target", true)), "Active tool attach should not mark bench targets"),
		assert_false(bool(bench_features.get("is_active_target", true)), "Bench tool attach should not mark active targets"),
		assert_true(bool(bench_features.get("is_bench_target", false)), "Tool attach should mark bench targets"),
	])


func test_action_feature_encoder_marks_attack_damage_and_knockout() -> String:
	var encoder = AIActionFeatureEncoderScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card("Miraidon ex", "Basic", "", [{
		"name": "Photon Blaster",
		"cost": "LL",
		"damage": "220",
	}], "ex", "L"), 0))
	player.active_pokemon.attached_energy = [_make_energy_card("L", "L"), _make_energy_card("L", "L")]
	opponent.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card("Charmander", "Basic", "", [], "", "R"), 1))

	var features: Dictionary = encoder.build_features(gsm, 0, {
		"kind": "attack",
		"attack_index": 0,
	})

	return run_checks([
		assert_gt(float(features.get("projected_damage", 0.0)), 0.0, "Attack features should include projected damage"),
		assert_true(bool(features.get("projected_knockout", false)), "Attack features should recognize projected knockouts"),
	])


func test_ai_feature_extractor_exposes_action_vector_for_existing_context_calls() -> String:
	var extractor = AIFeatureExtractorScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_slot(CardInstance.create(_make_pokemon_card("Active", "Basic", "", [{
		"name": "Hit",
		"cost": "C",
		"damage": "10",
	}], "", "L"), 0))
	player.active_pokemon = active_slot

	var features: Dictionary = extractor.build_context(gsm, 0, {
		"kind": "attach_energy",
		"card": _make_energy_card("Lightning Energy"),
		"target_slot": active_slot,
	})
	var action_vector: Array = features.get("action_vector", [])

	return run_checks([
		assert_false(action_vector.is_empty(), "Feature extractor should expose a reusable action vector for downstream learning"),
		assert_true(bool(features.get("improves_attack_readiness", false)), "Existing heuristic-facing fields should remain intact"),
	])


func test_action_feature_encoder_marks_bench_attack_readiness_when_attach_unlocks_bench_attacker() -> String:
	var encoder = AIActionFeatureEncoderScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_slot(CardInstance.create(_make_pokemon_card("Miraidon ex", "Basic", "", [], "ex", "L"), 0))
	var bench_slot := _make_slot(CardInstance.create(_make_pokemon_card("Raikou V", "Basic", "", [{
		"name": "Lightning Rondo",
		"cost": "LL",
		"damage": "20+",
	}], "V", "L"), 0))
	bench_slot.attached_energy = [_make_energy_card("Lightning Energy", "L")]
	player.active_pokemon = active_slot
	player.bench = [bench_slot]

	var features: Dictionary = encoder.build_features(gsm, 0, {
		"kind": "attach_energy",
		"card": _make_energy_card("Lightning Energy", "L"),
		"target_slot": bench_slot,
	})

	return run_checks([
		assert_true(bool(features.get("is_bench_target", false)), "Bench attach should still mark bench targets"),
		assert_true(bool(features.get("improves_bench_attack_readiness", false)), "Bench attach should expose when it unlocks a bench attacker"),
	])


func test_action_feature_encoder_marks_search_productivity_and_churn_pressure() -> String:
	var encoder = AIActionFeatureEncoderScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_slot(CardInstance.create(_make_pokemon_card("Miraidon ex", "Basic", "", [{
		"name": "Photon Blaster",
		"cost": "LL",
		"damage": "220",
	}], "ex", "L"), 0))
	player.active_pokemon.attached_energy = [_make_energy_card("L", "L"), _make_energy_card("L", "L")]
	player.deck = [
		_make_energy_card("Lightning Energy", "L"),
		_make_energy_card("Lightning Energy", "L"),
		_make_trainer_card("Switch"),
		_make_trainer_card("Switch"),
	]
	var nest_ball := _make_trainer_card("Nest Ball", "Item", "1af63a7e2cb7a79215474ad8db8fd8fd")
	player.hand = [nest_ball, _make_trainer_card("Professor's Research", "Supporter")]
	player.deck.append(CardInstance.create(_make_pokemon_card("Iron Hands ex", "Basic", "", [], "ex", "L"), 0))

	var nest_ball_features: Dictionary = encoder.build_features(gsm, 0, {
		"kind": "play_trainer",
		"card": nest_ball,
	})
	var churn_features: Dictionary = encoder.build_features(gsm, 0, {
		"kind": "play_trainer",
		"card": player.hand[1],
	})

	return run_checks([
		assert_true(bool(nest_ball_features.get("search_productive", false)), "Search trainers should expose when legal targets still exist"),
		assert_true(bool(churn_features.get("deck_out_pressure", false)), "Small-deck ready boards should expose deck-out pressure"),
		assert_true(bool(churn_features.get("creates_churn_risk", false)), "Draw churn trainers should expose late-turn churn risk under deck pressure"),
	])
