class_name TestHeadlessMatchBridge
extends TestBase

const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")


class SetupCompletionSpyGameStateMachine extends GameStateMachine:
	var setup_complete_calls: Array[int] = []

	func setup_complete(player_index: int) -> bool:
		setup_complete_calls.append(player_index)
		return true


func _make_basic_card(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 60
	return CardInstance.create(card, 0)


func _make_filler_card(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func _make_tool_card(name: String, effect_id: String, owner: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Tool"
	card.effect_id = effect_id
	return CardInstance.create(card, owner)


func _make_energy_card(name: String, provides: String, owner: int = 0, card_type: String = "Basic Energy") -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.energy_provides = provides
	return CardInstance.create(card, owner)


func _make_slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _make_gsm() -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	return gsm


func test_bridge_script_exposes_bootstrap_pending_setup() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	return run_checks([
		assert_true(bridge.has_method("bootstrap_pending_setup"), "The extracted bridge script should expose bootstrap_pending_setup"),
	])


func test_bridge_declares_bridge_owned_prompt_handling_contract() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	return run_checks([
		assert_true(bridge.has_method("handles_bridge_owned_prompts"), "The extracted bridge script should expose the bridge-owned prompt contract"),
		assert_true(bridge.handles_bridge_owned_prompts(), "The extracted bridge should opt into bridge-owned prompt handling"),
	])


func test_bridge_declares_effect_interaction_execution_supported() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	return run_checks([
		assert_true(bridge.has_method("supports_effect_interaction_execution"), "The extracted bridge should expose the effect-interaction execution capability contract"),
		assert_true(bridge.supports_effect_interaction_execution(), "HeadlessMatchBridge should support effect interaction execution"),
	])


func test_bootstrap_pending_setup_recovers_mulligan_prompt_from_action_log() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.action_log.append(GameAction.create(GameAction.ActionType.MULLIGAN, 0, {}, 0, "Seeded missed mulligan prompt"))
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()
	return run_checks([
		assert_eq(str(bridge.get("_pending_choice")), "mulligan_extra_draw", "bootstrap_pending_setup should recover the missed mulligan prompt"),
		assert_eq(bridge.get_pending_prompt_owner(), 1, "bootstrap_pending_setup should recover the mulligan beneficiary from the missed action log"),
	])


func test_bootstrap_pending_setup_resumes_from_missing_active_player() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.players[0].active_pokemon = _make_slot(_make_basic_card("P0 Active"))
	gsm.game_state.players[0].hand = [_make_basic_card("P0 Basic")]
	gsm.game_state.players[1].hand = [_make_basic_card("P1 Basic")]
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()
	return run_checks([
		assert_eq(str(bridge.get("_pending_choice")), "setup_active_1", "bootstrap_pending_setup should resume from the player missing an active Pokemon"),
		assert_eq(bridge.get_pending_prompt_owner(), 1, "The resumed setup prompt should belong to the missing-active player"),
	])


func test_get_pending_prompt_owner_uses_dialog_player_for_setup_active() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.set("_pending_choice", "setup_active_1")
	bridge.set("_dialog_data", {"player": 1})
	return run_checks([
		assert_eq(bridge.get_pending_prompt_owner(), 1, "setup_active ownership should come from _dialog_data.player"),
	])


func test_get_pending_prompt_owner_prefers_effect_interaction_dialog_chooser_fields() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.set("_pending_choice", "effect_interaction")
	bridge.set("_dialog_data", {
		"chooser_player_index": 1,
		"player": 0,
		"opponent_chooses": true,
	})
	var chooser_owner := bridge.get_pending_prompt_owner()
	bridge.set("_dialog_data", {
		"player": 0,
		"opponent_chooses": true,
	})
	var opponent_choice_owner := bridge.get_pending_prompt_owner()
	return run_checks([
		assert_eq(chooser_owner, 1, "effect_interaction ownership should prefer chooser_player_index when present"),
		assert_eq(opponent_choice_owner, 1, "effect_interaction ownership should derive the chooser from opponent_chooses when no explicit chooser is present"),
	])


func test_headless_match_bridge_marks_unsupported_prompt_as_no_progress() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge._on_player_choice_required("unsupported_prompt", {"reason": "unsupported"})
	return run_checks([
		assert_eq(str(bridge.get("_pending_choice")), "unsupported_prompt", "Unsupported prompts should be preserved by the bridge"),
		assert_eq(bridge.get("_dialog_data"), {"reason": "unsupported"}, "Unsupported prompts should keep their dialog payload"),
		assert_false(bridge.can_resolve_pending_prompt(), "Unsupported prompts should not be claimed as resolvable"),
	])


func test_bridge_resolves_mulligan_extra_draw_prompt() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.players[0].hand = [_make_basic_card("P0 Basic")]
	gsm.game_state.players[0].deck = [_make_filler_card("P0 Deck")]
	gsm.game_state.players[1].hand = [_make_basic_card("P1 Basic")]
	gsm.game_state.players[1].deck = [_make_filler_card("P1 Deck")]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "mulligan_extra_draw")
	bridge.set("_dialog_data", {"beneficiary": 1, "mulligan_count": 1})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_true(handled, "The bridge should resolve mulligan_extra_draw itself"),
		assert_eq(gsm.game_state.players[1].hand.size(), 2, "The mulligan beneficiary should draw the extra card"),
		assert_eq(str(bridge.get("_pending_choice")), "setup_active_0", "Resolving mulligan should hand off to the setup flow"),
	])


func test_bridge_resolves_setup_active_prompt() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	var lead := _make_basic_card("Lead Basic")
	var bench := _make_basic_card("Bench Basic")
	gsm.game_state.players[1].hand = [lead, bench]
	gsm.game_state.players[1].deck = [_make_filler_card("P1 Deck 1"), _make_filler_card("P1 Deck 2")]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "setup_active_1")
	bridge.set("_dialog_data", {
		"player": 1,
		"basics": [lead, bench],
	})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_true(handled, "The bridge should resolve setup_active prompts"),
		assert_not_null(gsm.game_state.players[1].active_pokemon, "setup_active should place an active Pokemon"),
		assert_eq(gsm.game_state.players[1].active_pokemon.get_pokemon_name(), "Lead Basic", "setup_active should choose the first available Basic"),
		assert_eq(str(bridge.get("_pending_choice")), "setup_bench_1", "setup_active should continue into the bench setup prompt"),
	])


func test_bridge_resolves_setup_bench_prompt() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := SetupCompletionSpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	gsm.game_state.players[0].active_pokemon = _make_slot(_make_basic_card("P0 Active"))
	gsm.game_state.players[1].active_pokemon = _make_slot(_make_basic_card("P1 Active"))
	var bench_card := _make_basic_card("P1 Bench")
	gsm.game_state.players[1].hand = [bench_card]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "setup_bench_1")
	bridge.set("_dialog_data", {
		"player": 1,
		"cards": [bench_card],
	})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_true(handled, "The bridge should resolve setup_bench prompts"),
		assert_eq(gsm.game_state.players[1].bench.size(), 1, "setup_bench should place the planned Basic onto the bench"),
		assert_eq(gsm.setup_complete_calls.size(), 1, "setup_bench should hand off to setup completion"),
		assert_eq(gsm.setup_complete_calls[0], 0, "setup_bench should finish setup through setup_complete"),
		assert_eq(str(bridge.get("_pending_choice")), "", "setup_bench should clear the pending prompt after completion"),
	])


func test_bridge_resolves_take_prize_prompt() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	var prize_card := _make_filler_card("Prize Card")
	gsm.game_state.players[1].set_prizes([prize_card])
	gsm.set("_pending_prize_player_index", 1)
	gsm.set("_pending_prize_remaining", 1)
	bridge.bind(gsm)
	bridge.set("_pending_choice", "take_prize")
	bridge.set("_dialog_data", {"player": 1})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_true(handled, "The bridge should resolve take_prize prompts"),
		assert_eq(gsm.game_state.players[1].prizes.size(), 0, "take_prize should remove the prize card"),
		assert_true(prize_card in gsm.game_state.players[1].hand, "take_prize should move the prize into hand"),
		assert_eq(str(bridge.get("_pending_choice")), "", "take_prize should clear the pending prompt"),
	])


func test_bridge_resolves_send_out_prompt() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	var replacement := _make_slot(_make_basic_card("Replacement Basic"))
	gsm.game_state.players[1].bench = [replacement]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "send_out")
	bridge.set("_dialog_data", {"player": 1})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_true(handled, "The bridge should resolve send_out prompts"),
		assert_eq(gsm.game_state.players[1].active_pokemon, replacement, "send_out should move the chosen bench Pokemon into the active slot"),
		assert_eq(str(bridge.get("_pending_choice")), "", "send_out should clear the pending prompt"),
	])


func test_bridge_starts_granted_attack_effect_interaction_for_tm_turbo_energize() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	var attacker := _make_slot(_make_basic_card("Iron Thorns ex"))
	attacker.attached_energy.append(_make_energy_card("Lightning Energy", "L"))
	attacker.attached_tool = _make_tool_card("Technical Machine: Turbo Energize", "2614722b9b28d9df8fd769b926ec82f2")
	var bench_target := _make_slot(_make_basic_card("Bench Future"))
	var defender := _make_slot(_make_basic_card("Defender"))
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].bench = [bench_target]
	gsm.game_state.players[0].deck = [
		_make_energy_card("Lightning Energy", "L"),
		_make_energy_card("Fighting Energy", "F"),
	]
	gsm.game_state.players[1].active_pokemon = defender
	bridge.bind(gsm)
	var granted_attacks: Array[Dictionary] = gsm.effect_processor.get_granted_attacks(attacker, gsm.game_state)
	var handled := false
	if not granted_attacks.is_empty():
		handled = bridge._try_use_granted_attack_with_interaction(0, attacker, granted_attacks[0])
	return run_checks([
		assert_eq(granted_attacks.size(), 1, "TM Turbo Energize should grant exactly one attack"),
		assert_true(handled, "Headless bridge should start granted-attack interaction when TM Turbo Energize needs assignments"),
		assert_eq(str(bridge.get("_pending_choice")), "effect_interaction", "Granted attack interaction should enter effect_interaction mode"),
		assert_eq(bridge.get_pending_prompt_owner(), 0, "Granted attack interaction should belong to the acting player"),
	])
