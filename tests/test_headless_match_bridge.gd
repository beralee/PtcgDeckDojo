class_name TestHeadlessMatchBridge
extends TestBase

const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


class SetupCompletionSpyGameStateMachine extends GameStateMachine:
	var setup_complete_calls: Array[int] = []

	func setup_complete(player_index: int) -> bool:
		setup_complete_calls.append(player_index)
		return true


class FakeSendOutStrategy extends RefCounted:
	var preferred_name: String = ""

	func _init(next_preferred_name: String = "") -> void:
		preferred_name = next_preferred_name

	func score_interaction_target(item: Variant, step: Dictionary, _context: Dictionary = {}) -> float:
		if str(step.get("id", "")) != "send_out" or not item is PokemonSlot:
			return 0.0
		return 500.0 if (item as PokemonSlot).get_pokemon_name() == preferred_name else 0.0


class FakeHandoffStrategy extends RefCounted:
	var step_id: String = ""
	var preferred_name: String = ""

	func _init(next_step_id: String = "", next_preferred_name: String = "") -> void:
		step_id = next_step_id
		preferred_name = next_preferred_name

	func score_handoff_target(item: Variant, step: Dictionary, _context: Dictionary = {}) -> float:
		if str(step.get("id", "")) != step_id or not item is PokemonSlot:
			return 0.0
		return 500.0 if (item as PokemonSlot).get_pokemon_name() == preferred_name else 0.0


class HeavyBatonResolveSpyGameStateMachine extends GameStateMachine:
	var resolve_heavy_baton_choice_calls: int = 0
	var resolved_heavy_baton_player_index: int = -1
	var resolved_heavy_baton_target: PokemonSlot = null

	func resolve_heavy_baton_choice(player_index: int, bench_slot: PokemonSlot) -> bool:
		resolve_heavy_baton_choice_calls += 1
		resolved_heavy_baton_player_index = player_index
		resolved_heavy_baton_target = bench_slot
		return true


class FakeSendOutInteractionScorer extends RefCounted:
	func score_delta(_state_features: Array, interaction_vector: Array) -> float:
		if interaction_vector.size() <= 25:
			return 0.0
		var attached_energy_hint: float = float(interaction_vector[25])
		return 260.0 if attached_energy_hint < 0.01 else 0.0


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


func test_bridge_accepts_modern_battle_scene_success_hook_signature() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge._refresh_ui_after_successful_action(false, 1)
	return assert_true(true,
		"HeadlessMatchBridge should accept the BattleScene success hook signature with action_player_index")


func test_bridge_accepts_modern_battle_scene_end_turn_signature() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	bridge.bind(gsm)
	bridge._on_end_turn(1)
	return assert_true(true,
		"HeadlessMatchBridge should accept the BattleScene end-turn signature with action_player_index")


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


func test_bridge_exposes_send_out_prompt_to_ai_owner() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	var replacement := _make_slot(_make_basic_card("Replacement Basic"))
	gsm.game_state.players[1].bench = [replacement]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "send_out")
	bridge.set("_dialog_data", {"player": 1})
	return run_checks([
		assert_false(bridge.can_resolve_pending_prompt(), "send_out should be delegated to the owning AI instead of auto-resolved by the bridge"),
		assert_eq(bridge.get_pending_prompt_owner(), 1, "send_out ownership should still be exposed to the benchmark loop"),
		assert_eq(str(bridge.get("_pending_choice")), "send_out", "The bridge should preserve the send_out prompt until the AI handles it"),
	])


func test_bridge_does_not_auto_resolve_send_out_even_if_called_directly() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	var replacement := _make_slot(_make_basic_card("Replacement Basic"))
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.players[1].bench = [replacement]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "send_out")
	bridge.set("_dialog_data", {"player": 1})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_false(handled, "send_out should never be auto-resolved by the bridge"),
		assert_eq(gsm.game_state.players[1].active_pokemon, null, "Direct bridge resolution should not move a replacement to the active slot"),
		assert_eq(str(bridge.get("_pending_choice")), "send_out", "Failed direct resolution should restore the pending send_out prompt"),
	])


func test_ai_resolves_send_out_through_headless_bridge_with_deck_strategy() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	var energy_bench := _make_slot(_make_basic_card("Energy Bench"))
	energy_bench.attached_energy.append(_make_energy_card("Lightning Energy", "L"))
	var preferred_bench := _make_slot(_make_basic_card("Preferred Bench"))
	gsm.game_state.players[1].bench = [energy_bench, preferred_bench]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "send_out")
	bridge.set("_dialog_data", {"player": 1})
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set_deck_strategy(FakeSendOutStrategy.new("Preferred Bench"))

	var handled := ai.run_single_step(bridge, gsm)
	return run_checks([
		assert_true(handled, "The owning AI should resolve send_out through the headless bridge"),
		assert_eq(gsm.game_state.players[1].active_pokemon, preferred_bench, "Headless send_out should now respect deck-local handoff scoring"),
		assert_eq(str(bridge.get("_pending_choice")), "", "The prompt should clear after AI-owned headless send_out resolution"),
	])


func test_ai_resolves_send_out_through_headless_bridge_with_learned_overlay() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	var energy_bench := _make_slot(_make_basic_card("Energy Bench"))
	energy_bench.attached_energy.append(_make_energy_card("Lightning Energy", "L"))
	var plain_bench := _make_slot(_make_basic_card("Plain Bench"))
	gsm.game_state.players[1].bench = [energy_bench, plain_bench]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "send_out")
	bridge.set("_dialog_data", {"player": 1})
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set("_interaction_scorer", FakeSendOutInteractionScorer.new())

	var handled := ai.run_single_step(bridge, gsm)
	return run_checks([
		assert_true(handled, "The owning AI should resolve send_out through the headless bridge when an interaction scorer is injected"),
		assert_eq(gsm.game_state.players[1].active_pokemon, plain_bench, "Headless send_out should also allow the learned interaction overlay to override the generic fallback"),
		assert_eq(str(bridge.get("_pending_choice")), "", "The prompt should clear after learned headless send_out resolution"),
	])


func test_ai_resolves_heavy_baton_through_headless_bridge_with_deck_strategy() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := HeavyBatonResolveSpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	var energy_bench := _make_slot(_make_basic_card("Energy Baton Bench"))
	energy_bench.attached_energy.append(_make_energy_card("Lightning Energy", "L"))
	var preferred_bench := _make_slot(_make_basic_card("Preferred Baton Bench"))
	gsm.game_state.players[1].bench = [energy_bench, preferred_bench]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "heavy_baton_target")
	bridge.set("_dialog_data", {"player": 1, "bench": [energy_bench, preferred_bench], "count": 3, "source_name": "Heavy Baton"})
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set_deck_strategy(FakeHandoffStrategy.new("heavy_baton_target", "Preferred Baton Bench"))

	var handled := ai.run_single_step(bridge, gsm)
	return run_checks([
		assert_true(handled, "The owning AI should resolve heavy_baton_target through the headless bridge"),
		assert_eq(gsm.resolve_heavy_baton_choice_calls, 1, "Headless bridge should route Heavy Baton resolution through GameStateMachine"),
		assert_eq(gsm.resolved_heavy_baton_player_index, 1, "Heavy Baton resolution should preserve the prompt owner"),
		assert_eq(gsm.resolved_heavy_baton_target, preferred_bench, "Headless Heavy Baton should respect deck-local handoff scoring"),
		assert_eq(str(bridge.get("_pending_choice")), "", "The prompt should clear after AI-owned headless Heavy Baton resolution"),
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


func test_bridge_starts_bench_entry_effect_interaction_for_iron_leaves_ex() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	var active := _make_slot(_make_basic_card("Active Arceus"))
	active.attached_energy.append(_make_energy_card("Grass Energy", "G"))
	gsm.game_state.players[0].active_pokemon = active

	var iron_cd := CardData.new()
	iron_cd.name = "Iron Leaves ex"
	iron_cd.card_type = "Pokemon"
	iron_cd.stage = "Basic"
	iron_cd.hp = 220
	iron_cd.mechanic = "ex"
	iron_cd.effect_id = "2e307380eb013c4e20db0a19816ba3b9"
	iron_cd.abilities = [{"name": "快速游标", "text": ""}]
	var iron_card := CardInstance.create(iron_cd, 0)
	gsm.game_state.players[0].hand = [iron_card]

	bridge.bind(gsm)
	var handled := bridge._try_play_to_bench(0, iron_card, "")
	return run_checks([
		assert_true(handled, "Headless bridge should accept playing Iron Leaves ex to the Bench"),
		assert_eq(str(bridge.get("_pending_choice")), "effect_interaction", "Bench-entry on-play abilities should enter effect_interaction in headless mode"),
		assert_eq(bridge.get_pending_prompt_owner(), 0, "The bench-entry interaction should belong to the acting player"),
	])
