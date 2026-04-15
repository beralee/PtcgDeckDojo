class_name TestAIBaseline
extends TestBase

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AISetupPlannerScript = preload("res://scripts/ai/AISetupPlanner.gd")
const AIFeatureExtractorScript = preload("res://scripts/ai/AIFeatureExtractor.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")
const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")
const AbilityBonusDrawIfActiveScript = preload("res://scripts/effects/pokemon_effects/AbilityBonusDrawIfActive.gd")


class InteractiveChoiceEffect extends BaseEffect:
	func can_execute(_card: CardInstance, _game_state: GameState) -> bool:
		return true

	func can_use_ability(_pokemon: PokemonSlot, _state: GameState) -> bool:
		return true

	func get_interaction_steps(_card: CardInstance, _game_state: GameState) -> Array[Dictionary]:
		return [{
			"id": "pick_one",
			"title": "Pick",
			"items": ["A"],
			"labels": ["A"],
			"min_select": 1,
			"max_select": 1,
		}]


class SpyAIOpponent extends RefCounted:
	var player_index: int = 1
	var difficulty: int = 1
	var run_count: int = 0

	func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
		if game_state == null or ui_blocked:
			return false
		return game_state.current_player_index == player_index

	func run_single_step(_battle_scene: Control, _gsm: GameStateMachine) -> bool:
		run_count += 1
		return true


class FollowupSchedulingSpyAIOpponent extends RefCounted:
	var player_index: int = 1
	var difficulty: int = 1
	var run_count: int = 0

	func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
		if game_state == null or ui_blocked:
			return false
		return game_state.current_player_index == player_index

	func run_single_step(battle_scene: Control, _gsm: GameStateMachine) -> bool:
		run_count += 1
		if run_count == 1:
			battle_scene._refresh_ui_after_successful_action()
		return true


class CountingAIOpponent extends RefCounted:
	var player_index: int = 1
	var difficulty: int = 1
	var run_count: int = 0
	var _delegate = AIOpponentScript.new()

	func _init(next_player_index: int = 1) -> void:
		player_index = next_player_index
		_delegate.configure(next_player_index, difficulty)

	func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
		return _delegate.should_control_turn(game_state, ui_blocked)

	func run_single_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
		run_count += 1
		return _delegate.run_single_step(battle_scene, gsm)


class SpyGameStateMachine extends GameStateMachine:
	var retreat_calls: int = 0
	var retreat_result: bool = true
	var mulligan_resolve_calls: int = 0
	var resolved_beneficiary: int = -1
	var resolved_draw_extra: bool = false

	func retreat(_player_index: int, _energy_to_discard: Array[CardInstance], _bench_target: PokemonSlot) -> bool:
		retreat_calls += 1
		return retreat_result

	func resolve_mulligan_choice(beneficiary: int, draw_extra: bool) -> void:
		mulligan_resolve_calls += 1
		resolved_beneficiary = beneficiary
		resolved_draw_extra = draw_extra


class SpyPrizeResolveGameStateMachine extends GameStateMachine:
	var resolve_take_prize_calls: int = 0

	func resolve_take_prize(player_index: int, slot_index: int) -> bool:
		resolve_take_prize_calls += 1
		return super.resolve_take_prize(player_index, slot_index)


class SpySendOutViewGameStateMachine extends GameStateMachine:
	var send_out_calls: int = 0

	func send_out_pokemon(_player_index: int, _bench_slot: PokemonSlot) -> bool:
		send_out_calls += 1
		game_state.current_player_index = 1
		return true


class SpyHeavyBatonResolveGameStateMachine extends GameStateMachine:
	var resolve_heavy_baton_choice_calls: int = 0
	var resolved_heavy_baton_player_index: int = -1
	var resolved_heavy_baton_target: PokemonSlot = null

	func resolve_heavy_baton_choice(player_index: int, bench_slot: PokemonSlot) -> bool:
		resolve_heavy_baton_choice_calls += 1
		resolved_heavy_baton_player_index = player_index
		resolved_heavy_baton_target = bench_slot
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


class FakeSendOutInteractionScorer extends RefCounted:
	func score_delta(_state_features: Array, interaction_vector: Array) -> float:
		if interaction_vector.size() <= 25:
			return 0.0
		var attached_energy_hint: float = float(interaction_vector[25])
		return 260.0 if attached_energy_hint < 0.01 else 0.0


class DelayedPrizeAnimationScene extends Control:
	var _pending_choice: String = "take_prize"
	var _pending_prize_player_index: int = 1
	var _pending_prize_remaining: int = 1
	var _pending_prize_animating: bool = false
	var try_take_prize_calls: int = 0

	func _try_take_prize_from_slot(_player_index: int, _slot_index: int) -> void:
		try_take_prize_calls += 1
		_pending_prize_animating = true


class SpySetupBattleScene extends Control:
	var _pending_choice: String = ""
	var _dialog_data: Dictionary = {}
	var after_setup_active_calls: Array[int] = []
	var after_setup_bench_calls: Array[int] = []
	var show_setup_bench_dialog_calls: Array[int] = []
	var refresh_ui_calls: int = 0

	func _after_setup_active(pi: int) -> void:
		after_setup_active_calls.append(pi)

	func _after_setup_bench(pi: int) -> void:
		after_setup_bench_calls.append(pi)

	func _show_setup_bench_dialog(pi: int) -> void:
		show_setup_bench_dialog_calls.append(pi)

	func _refresh_ui() -> void:
		refresh_ui_calls += 1


class SpyInteractiveActionBattleScene extends Control:
	var trainer_interaction_calls: int = 0
	var ability_interaction_calls: int = 0
	var attack_interaction_calls: int = 0

	func _try_play_trainer_with_interaction(_player_index: int, _card: CardInstance) -> void:
		trainer_interaction_calls += 1

	func _try_use_ability_with_interaction(_player_index: int, _slot: PokemonSlot, _ability_index: int) -> void:
		ability_interaction_calls += 1

	func _try_use_attack_with_interaction(_player_index: int, _slot: PokemonSlot, _attack_index: int) -> void:
		attack_interaction_calls += 1


func _make_player_state(player_index: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = player_index
	return player


func _make_basic(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 60
	return CardInstance.create(card, 1)


func _make_item(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 1)


func _make_ai_manual_gsm() -> GameStateMachine:
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


func _new_legal_action_builder() -> Variant:
	var builder_script: Variant = load("res://scripts/ai/AILegalActionBuilder.gd")
	if builder_script == null:
		return null
	return builder_script.new()


func _make_ai_pokemon_card_data(
	name: String,
	stage: String = "Basic",
	evolves_from: String = "",
	effect_id: String = "",
	abilities: Array = [],
	attacks: Array = [],
	retreat_cost: int = 1
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.effect_id = effect_id
	card.hp = 100
	card.retreat_cost = retreat_cost
	card.abilities.clear()
	for ability: Dictionary in abilities:
		card.abilities.append(ability.duplicate(true))
	card.attacks.clear()
	for attack: Dictionary in attacks:
		card.attacks.append(attack.duplicate(true))
	return card


func _make_ai_trainer_card_data(name: String, card_type: String, effect_id: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.effect_id = effect_id
	return card


func _make_ai_energy_card_data(name: String, energy_type: String = "L", card_type: String = "Basic Energy", effect_id: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.energy_provides = energy_type
	card.effect_id = effect_id
	return card


func _make_ai_slot(card: CardInstance, turn_played: int = 1) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = turn_played
	return slot


func _build_ai_actions(gsm: GameStateMachine, player_index: int = 0) -> Array[Dictionary]:
	var builder: Variant = _new_legal_action_builder()
	if builder == null:
		return []
	return builder.build_actions(gsm, player_index)


func _count_actions_by_kind(actions: Array[Dictionary], kind: String) -> int:
	var count: int = 0
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == kind:
			count += 1
	return count


func _has_action(actions: Array[Dictionary], kind: String, expected: Dictionary = {}) -> bool:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		var matches := true
		for key: Variant in expected.keys():
			if action.get(key) != expected[key]:
				matches = false
				break
		if matches:
			return true
	return false


func _make_battle_scene_refresh_stub() -> Control:
	var battle_scene = BattleSceneScript.new()
	battle_scene.set("_log_list", RichTextLabel.new())
	battle_scene.set("_lbl_phase", Label.new())
	battle_scene.set("_lbl_turn", Label.new())
	battle_scene.set("_opp_prizes", Label.new())
	battle_scene.set("_opp_deck", Label.new())
	battle_scene.set("_opp_discard", Label.new())
	battle_scene.set("_opp_hand_lbl", Label.new())
	battle_scene.set("_opp_hand_bar", PanelContainer.new())
	battle_scene.set("_opp_prize_hud_count", Label.new())
	battle_scene.set("_opp_deck_hud_value", Label.new())
	battle_scene.set("_opp_discard_hud_value", Label.new())
	battle_scene.set("_my_prizes", Label.new())
	battle_scene.set("_my_deck", Label.new())
	battle_scene.set("_my_discard", Label.new())
	battle_scene.set("_my_prize_hud_count", Label.new())
	battle_scene.set("_my_deck_hud_value", Label.new())
	battle_scene.set("_my_discard_hud_value", Label.new())
	battle_scene.set("_btn_end_turn", Button.new())
	battle_scene.set("_hud_end_turn_btn", Button.new())
	battle_scene.set("_stadium_lbl", Label.new())
	battle_scene.set("_btn_stadium_action", Button.new())
	battle_scene.set("_enemy_vstar_value", Label.new())
	battle_scene.set("_my_vstar_value", Label.new())
	battle_scene.set("_enemy_lost_value", Label.new())
	battle_scene.set("_my_lost_value", Label.new())
	battle_scene.set("_hand_container", HBoxContainer.new())
	battle_scene.set("_dialog_overlay", Panel.new())
	battle_scene.set("_dialog_title", Label.new())
	battle_scene.set("_dialog_list", ItemList.new())
	battle_scene.set("_dialog_card_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_card_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_panel", VBoxContainer.new())
	battle_scene.set("_dialog_assignment_summary_lbl", Label.new())
	battle_scene.set("_dialog_assignment_source_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_target_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_source_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_target_row", HBoxContainer.new())
	battle_scene.set("_dialog_status_lbl", Label.new())
	battle_scene.set("_dialog_utility_row", HBoxContainer.new())
	battle_scene.set("_dialog_confirm", Button.new())
	battle_scene.set("_dialog_cancel", Button.new())
	battle_scene.set("_handover_panel", Panel.new())
	battle_scene.set("_handover_lbl", Label.new())
	battle_scene.set("_handover_btn", Button.new())
	battle_scene.set("_coin_overlay", Panel.new())
	battle_scene.set("_detail_overlay", Panel.new())
	battle_scene.set("_discard_overlay", Panel.new())
	battle_scene.set("_field_interaction_overlay", Control.new())
	battle_scene.set("_field_interaction_panel", PanelContainer.new())
	battle_scene.set("_field_interaction_layout", VBoxContainer.new())
	battle_scene.set("_field_interaction_top_spacer", Control.new())
	battle_scene.set("_field_interaction_bottom_spacer", Control.new())
	battle_scene.set("_field_interaction_title_lbl", Label.new())
	battle_scene.set("_field_interaction_status_lbl", Label.new())
	battle_scene.set("_field_interaction_scroll", ScrollContainer.new())
	battle_scene.set("_field_interaction_row", HBoxContainer.new())
	battle_scene.set("_field_interaction_buttons", HBoxContainer.new())
	battle_scene.set("_field_interaction_clear_btn", Button.new())
	battle_scene.set("_field_interaction_cancel_btn", Button.new())
	battle_scene.set("_field_interaction_confirm_btn", Button.new())
	battle_scene.set("_opp_prizes_title", Label.new())
	battle_scene.set("_my_prizes_title", Label.new())
	battle_scene.set("_opp_prize_hud_title", Label.new())
	battle_scene.set("_my_prize_hud_title", Label.new())
	battle_scene.set("_slot_card_views", {})
	battle_scene.set("_opp_prize_slots", [])
	battle_scene.set("_my_prize_slots", [])
	return battle_scene


func _make_setup_ready_battle_scene() -> Control:
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	return scene


func test_ai_opponent_instantiates() -> String:
	var ai := AIOpponentScript.new()
	var blocked_state := GameState.new()
	blocked_state.current_player_index = 0
	var mismatched_state := GameState.new()
	mismatched_state.current_player_index = 1
	var matching_state := GameState.new()
	matching_state.current_player_index = 0

	var initial_checks := run_checks([
		assert_true(ai != null, "AIOpponent should instantiate"),
		assert_true(ai.has_method("configure"), "AIOpponent should expose configure"),
		assert_true(ai.has_method("should_control_turn"), "AIOpponent should expose should_control_turn"),
		assert_true(ai.has_method("run_single_step"), "AIOpponent should expose run_single_step"),
		assert_true(ai.has_method("get_last_decision_trace"), "AIOpponent should expose get_last_decision_trace"),
		assert_eq(ai.player_index, 1, "AIOpponent should default to player_index 1"),
		assert_eq(ai.difficulty, 1, "AIOpponent should default to difficulty 1"),
		assert_null(ai.get_last_decision_trace(), "AIOpponent should start without a decision trace"),
	])
	if initial_checks != "":
		return initial_checks

	ai.configure(0, 3)

	return run_checks([
		assert_eq(ai.player_index, 0, "configure() should update player_index"),
		assert_eq(ai.difficulty, 3, "configure() should update difficulty"),
		assert_false(ai.should_control_turn(null, false), "null game_state should prevent AI turn control"),
		assert_false(ai.should_control_turn(blocked_state, true), "ui_blocked should prevent AI turn control"),
		assert_false(ai.should_control_turn(mismatched_state, false), "AI should not control the wrong player's turn"),
		assert_true(ai.should_control_turn(matching_state, false), "AI should control the configured player's turn"),
		assert_false(ai.run_single_step(null, null), "run_single_step() should remain a safe no-op"),
	])


func test_setup_planner_prefers_basic_active_and_fills_bench() -> String:
	var planner := AISetupPlannerScript.new()
	var player := PlayerState.new()
	player.hand = [_make_basic("A"), _make_basic("B"), _make_item("Ball")]
	var choice: Dictionary = planner.plan_opening_setup(player)
	return run_checks([
		assert_eq(choice.get("active_hand_index", -1), 0, "Should choose a Basic for active"),
		assert_eq(choice.get("bench_hand_indices", []).size(), 1, "Should place extra Basic to bench"),
	])


func test_setup_planner_always_accepts_mulligan_bonus_draw() -> String:
	var planner := AISetupPlannerScript.new()
	return run_checks([
		assert_true(planner.choose_mulligan_bonus_draw(), "Baseline AI should always take the draw"),
	])


func test_ai_legal_action_builder_enumerates_attach_energy_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Active"), 0))
	var bench_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench"), 0))
	var energy := CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 0)
	player.active_pokemon = active_slot
	player.bench = [bench_slot]
	player.hand = [energy, CardInstance.create(_make_ai_trainer_card_data("Ball", "Item"), 0)]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "attach_energy"), 2, "Builder should enumerate one attach action per own Pokemon"),
		assert_true(_has_action(actions, "attach_energy", {"card": energy, "target_slot": active_slot}), "Builder should allow attaching to the active Pokemon"),
		assert_true(_has_action(actions, "attach_energy", {"card": energy, "target_slot": bench_slot}), "Builder should allow attaching to a benched Pokemon"),
	])


func test_ai_legal_action_builder_enumerates_play_basic_to_bench_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var basic := CardInstance.create(_make_ai_pokemon_card_data("Bench Basic"), 0)
	var evolution := CardInstance.create(_make_ai_pokemon_card_data("Stage 1", "Stage 1", "Bench Basic"), 0)
	player.active_pokemon = active_slot
	player.hand = [basic, evolution]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "play_basic_to_bench"), 1, "Builder should only enumerate playable Basic bench actions"),
		assert_true(_has_action(actions, "play_basic_to_bench", {"card": basic}), "Builder should include the playable Basic Pokemon"),
	])


func test_ai_legal_action_builder_blocks_play_basic_to_bench_under_collapsed_stadium_limit() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var basic := CardInstance.create(_make_ai_pokemon_card_data("Bench Basic"), 0)
	player.active_pokemon = active_slot
	player.hand = [basic]
	player.bench.clear()
	for i: int in 4:
		player.bench.append(_make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench %d" % i), 0)))
	var stadium_card := CardInstance.create(_make_ai_trainer_card_data("Collapsed Stadium", "Stadium", "fb3628071280487676f79281696ffbd9"), 0)
	gsm.game_state.stadium_card = stadium_card
	gsm.game_state.stadium_owner_index = 0

	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "play_basic_to_bench"), 0, "Collapsed Stadium在场且备战已满4只时，AI 不应枚举第5只上备战动作"),
	])


func test_ai_legal_action_builder_enumerates_evolve_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	gsm.game_state.turn_number = 3
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Mareep"), 0), 1)
	var evolution := CardInstance.create(_make_ai_pokemon_card_data("Flaaffy", "Stage 1", "Mareep"), 0)
	var wrong_evolution := CardInstance.create(_make_ai_pokemon_card_data("Charmeleon", "Stage 1", "Charmander"), 0)
	player.active_pokemon = active_slot
	player.hand = [evolution, wrong_evolution]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "evolve"), 1, "Builder should enumerate only legal evolve actions"),
		assert_true(_has_action(actions, "evolve", {"card": evolution, "target_slot": active_slot}), "Builder should include the valid evolution target"),
	])


func test_ai_legal_action_builder_enumerates_play_trainer_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var item := CardInstance.create(_make_ai_trainer_card_data("Switch", "Item"), 0)
	var basic := CardInstance.create(_make_ai_pokemon_card_data("Bench Basic"), 0)
	player.active_pokemon = active_slot
	player.hand = [item, basic]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "play_trainer"), 1, "Builder should enumerate trainer cards that can be played immediately"),
		assert_true(_has_action(actions, "play_trainer", {"card": item, "targets": []}), "Builder should include a trainer action with normalized empty targets"),
	])


func test_ai_legal_action_builder_enumerates_interactive_trainer_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var item := CardInstance.create(_make_ai_trainer_card_data("Interactive Item", "Item", "test_ai_interactive_item"), 0)
	gsm.effect_processor.register_effect("test_ai_interactive_item", InteractiveChoiceEffect.new())
	player.hand = [item]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "play_trainer"), 1, "Builder should keep trainer actions that require interaction steps"),
		assert_true(_has_action(actions, "play_trainer", {"card": item}), "Builder should still expose the interactive trainer action"),
	])


func test_ai_legal_action_builder_enumerates_play_stadium_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var stadium := CardInstance.create(_make_ai_trainer_card_data("Training Court", "Stadium"), 0)
	player.hand = [stadium]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "play_stadium"), 1, "Builder should enumerate playable stadium cards"),
		assert_true(_has_action(actions, "play_stadium", {"card": stadium, "targets": []}), "Builder should include a normalized stadium action"),
	])


func test_ai_legal_action_builder_enumerates_use_ability_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var ability_cd := _make_ai_pokemon_card_data(
		"Rotom",
		"Basic",
		"",
		"test_ai_bonus_draw",
		[{"name": "Draw", "text": ""}]
	)
	gsm.effect_processor.register_effect("test_ai_bonus_draw", AbilityBonusDrawIfActiveScript.new())
	var active_slot := _make_ai_slot(CardInstance.create(ability_cd, 0))
	player.active_pokemon = active_slot
	player.deck = [CardInstance.create(_make_ai_pokemon_card_data("Drawn"), 0)]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "use_ability"), 1, "Builder should enumerate immediately usable abilities"),
		assert_true(_has_action(actions, "use_ability", {"source_slot": active_slot, "ability_index": 0, "targets": []}), "Builder should include a normalized ability action"),
	])


func test_ai_legal_action_builder_enumerates_interactive_ability_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var ability_cd := _make_ai_pokemon_card_data(
		"Interactive Ability Mon",
		"Basic",
		"",
		"test_ai_interactive_ability",
		[{"name": "Choose", "text": ""}]
	)
	gsm.effect_processor.register_effect("test_ai_interactive_ability", InteractiveChoiceEffect.new())
	var active_slot := _make_ai_slot(CardInstance.create(ability_cd, 0))
	player.active_pokemon = active_slot
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "use_ability"), 1, "Builder should keep ability actions that require interaction steps"),
		assert_true(_has_action(actions, "use_ability", {"source_slot": active_slot, "ability_index": 0}), "Builder should still expose the interactive ability action"),
	])


func test_ai_legal_action_builder_enumerates_retreat_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Active", "Basic", "", "", [], [], 1), 0))
	var bench_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench"), 0))
	var energy := CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 0)
	active_slot.attached_energy.append(energy)
	player.active_pokemon = active_slot
	player.bench = [bench_slot]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "retreat"), 1, "Builder should enumerate the legal retreat line"),
		assert_true(_has_action(actions, "retreat", {"bench_target": bench_slot, "energy_to_discard": [energy]}), "Builder should include the discard selection needed to retreat legally"),
	])


func test_ai_legal_action_builder_enumerates_attack_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attack_cd := _make_ai_pokemon_card_data(
		"Attacker",
		"Basic",
		"",
		"",
		[],
		[{"name": "Zap", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	)
	var active_slot := _make_ai_slot(CardInstance.create(attack_cd, 0))
	active_slot.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 0))
	player.active_pokemon = active_slot
	opponent.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Defender"), 1))
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "attack"), 1, "Builder should enumerate attacks that are currently usable"),
		assert_true(_has_action(actions, "attack", {"attack_index": 0, "targets": []}), "Builder should include a normalized attack action"),
	])


func test_ai_legal_action_builder_enumerates_end_turn_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "end_turn"), 1, "Builder should always allow ending the turn from the main phase"),
		assert_true(_has_action(actions, "end_turn"), "Builder should include end_turn as a normalized action"),
	])


func test_ai_opponent_resolves_effect_interaction_dialog_choice() -> String:
	var previous_mode: int = GameManager.current_mode
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	scene.set("_field_interaction_overlay", null)
	scene.call("_setup_field_interaction_panel")
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var option_a := CardInstance.create(_make_ai_trainer_card_data("Option A", "Item"), 1)
	var option_b := CardInstance.create(_make_ai_trainer_card_data("Option B", "Item"), 1)
	var hold_step := {
		"id": "hold",
		"title": "Hold",
		"items": [CardInstance.create(_make_ai_trainer_card_data("Hold", "Item"), 1)],
		"labels": ["Hold"],
		"min_select": 1,
		"max_select": 1,
	}
	var steps: Array[Dictionary] = [
		{
			"id": "pick_card",
			"title": "Pick a card",
			"items": [option_a, option_b],
			"labels": ["A", "B"],
			"min_select": 1,
			"max_select": 1,
		},
		hold_step,
	]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_start_effect_interaction", "trainer", 1, steps, CardInstance.create(_make_ai_trainer_card_data("Trainer", "Item"), 1))

	var handled := ai.run_single_step(scene, gsm)
	var context: Dictionary = scene.get("_pending_effect_context")
	var selected_cards: Array = context.get("pick_card", [])
	var first_selected_card: Variant = selected_cards[0] if not selected_cards.is_empty() else null
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(handled, "AI should resolve simple dialog-based effect steps"),
		assert_eq(int(scene.get("_pending_effect_step_index")), 1, "AI should advance to the next effect step after resolving a dialog choice"),
		assert_eq(selected_cards.size(), 1, "AI should store exactly one selected card"),
		assert_eq(first_selected_card, option_a, "AI should pick the first legal dialog option for the baseline policy"),
		assert_eq(str(scene.get("_pending_choice")), "effect_interaction", "Effect interaction flow should continue to the next step"),
	])


func test_ai_opponent_resolves_effect_interaction_field_slot_choice() -> String:
	var previous_mode: int = GameManager.current_mode
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	scene.set("_field_interaction_overlay", null)
	scene.call("_setup_field_interaction_panel")
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	var bench_a := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench A"), 1))
	var bench_b := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench B"), 1))
	player.bench = [bench_a, bench_b]
	var hold_step := {
		"id": "hold",
		"title": "Hold",
		"items": [CardInstance.create(_make_ai_trainer_card_data("Hold", "Item"), 1)],
		"labels": ["Hold"],
		"min_select": 1,
		"max_select": 1,
	}
	var steps: Array[Dictionary] = [
		{
			"id": "pick_slot",
			"title": "Pick a Pokemon",
			"items": [bench_a, bench_b],
			"min_select": 1,
			"max_select": 1,
		},
		hold_step,
	]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_start_effect_interaction", "trainer", 1, steps, CardInstance.create(_make_ai_trainer_card_data("Trainer", "Item"), 1))

	var handled := ai.run_single_step(scene, gsm)
	var context: Dictionary = scene.get("_pending_effect_context")
	var selected_slots: Array = context.get("pick_slot", [])
	var first_selected_slot: Variant = selected_slots[0] if not selected_slots.is_empty() else null
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(handled, "AI should resolve PokemonSlot effect steps through the field UI path"),
		assert_eq(int(scene.get("_pending_effect_step_index")), 1, "AI should advance after selecting a field slot"),
		assert_eq(selected_slots.size(), 1, "AI should store exactly one selected PokemonSlot"),
		assert_eq(first_selected_slot, bench_a, "AI should choose the first legal PokemonSlot by default"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Field interaction UI should close after AI finalizes the slot choice"),
	])


func test_ai_opponent_resolves_effect_interaction_assignment_step() -> String:
	var previous_mode: int = GameManager.current_mode
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	scene.set("_field_interaction_overlay", null)
	scene.call("_setup_field_interaction_panel")
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	var bench_a := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench A"), 1))
	var bench_b := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench B"), 1))
	player.bench = [bench_a, bench_b]
	var energy_a := CardInstance.create(_make_ai_energy_card_data("Energy A"), 1)
	var energy_b := CardInstance.create(_make_ai_energy_card_data("Energy B"), 1)
	var hold_step := {
		"id": "hold",
		"title": "Hold",
		"items": [CardInstance.create(_make_ai_trainer_card_data("Hold", "Item"), 1)],
		"labels": ["Hold"],
		"min_select": 1,
		"max_select": 1,
	}
	var steps: Array[Dictionary] = [
		{
			"id": "assign_energy",
			"title": "Assign energy",
			"ui_mode": "card_assignment",
			"source_items": [energy_a, energy_b],
			"target_items": [bench_a, bench_b],
			"min_select": 2,
			"max_select": 2,
			"source_exclude_targets": {
				1: [0],
			},
		},
		hold_step,
	]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_start_effect_interaction", "trainer", 1, steps, CardInstance.create(_make_ai_trainer_card_data("Trainer", "Item"), 1))

	var handled := ai.run_single_step(scene, gsm)
	var context: Dictionary = scene.get("_pending_effect_context")
	var assignments: Array = context.get("assign_energy", [])
	var first_assignment: Dictionary = assignments[0] if not assignments.is_empty() else {}
	var second_assignment: Dictionary = assignments[1] if assignments.size() > 1 else {}
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(handled, "AI should resolve card-assignment effect steps"),
		assert_eq(int(scene.get("_pending_effect_step_index")), 1, "AI should advance after finalizing the assignment step"),
		assert_eq(assignments.size(), 2, "AI should complete the required number of assignments"),
		assert_eq(first_assignment.get("source"), energy_a, "AI should assign the first source item first"),
		assert_eq(first_assignment.get("target"), bench_a, "AI should pick the first legal target for the first source item"),
		assert_eq(second_assignment.get("source"), energy_b, "AI should continue with the next source item"),
		assert_eq(second_assignment.get("target"), bench_b, "AI should respect source_exclude_targets when assigning later sources"),
	])


func test_battle_scene_schedules_ai_for_effect_interaction_prompt_owned_by_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	scene.set("_field_interaction_overlay", null)
	scene.call("_setup_field_interaction_panel")
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 0
	scene.set("_gsm", gsm)
	var opponent: PlayerState = gsm.game_state.players[1]
	var bench_a := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench A"), 1))
	var bench_b := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench B"), 1))
	opponent.bench = [bench_a, bench_b]
	var hold_step := {
		"id": "hold",
		"title": "Hold",
		"items": [CardInstance.create(_make_ai_trainer_card_data("Hold", "Item"), 1)],
		"labels": ["Hold"],
		"min_select": 1,
		"max_select": 1,
	}
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var steps: Array[Dictionary] = [
		{
			"id": "opponent_pick",
			"title": "Opponent chooses",
			"items": [bench_a, bench_b],
			"min_select": 1,
			"max_select": 1,
			"chooser_player_index": 1,
		},
		hold_step,
	]
	scene.call("_start_effect_interaction", "ability", 0, steps, CardInstance.create(_make_ai_pokemon_card_data("Human Card", "Basic"), 0))
	scene._maybe_run_ai()
	var scheduled := bool(scene.get("_ai_step_scheduled"))
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	var context: Dictionary = scene.get("_pending_effect_context")
	var selected_slots: Array = context.get("opponent_pick", [])
	var first_selected_slot: Variant = selected_slots[0] if not selected_slots.is_empty() else null
	return run_checks([
		assert_true(scheduled, "BattleScene should schedule AI when the pending effect step chooser is the AI player"),
		assert_eq(int(scene.get("_pending_effect_step_index")), 1, "AI should advance the human-owned interaction once it resolves the chooser step"),
		assert_eq(selected_slots.size(), 1, "AI-owned chooser steps should still record a selection"),
		assert_eq(first_selected_slot, bench_a, "Baseline AI should pick the first legal slot for chooser-owned effect prompts"),
	])


func test_battle_scene_keeps_ai_owned_dialog_effect_step_hidden_from_human_ui() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	scene.set("_field_interaction_overlay", null)
	scene.call("_setup_field_interaction_panel")
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var steps: Array[Dictionary] = [
		{
			"id": "discard_energy",
			"title": "选择要丢弃的能量",
			"items": [
				CardInstance.create(_make_ai_energy_card_data("Lightning A"), 1),
				CardInstance.create(_make_ai_energy_card_data("Lightning B"), 1),
			],
			"labels": ["A", "B"],
			"min_select": 0,
			"max_select": 2,
		}
	]
	scene.call("_start_effect_interaction", "attack", 1, steps, CardInstance.create(_make_ai_pokemon_card_data("AI Attacker"), 1))
	scene._maybe_run_ai()
	var pending_choice: String = str(scene.get("_pending_choice"))
	var dialog_visible: bool = bool(scene.get("_dialog_overlay").visible)
	var scheduled: bool = bool(scene.get("_ai_step_scheduled"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(pending_choice, "effect_interaction", "AI-owned dialog effect steps should still use effect_interaction state"),
		assert_false(dialog_visible, "AI-owned dialog effect steps should stay hidden from the human UI"),
		assert_true(scheduled, "AI-owned dialog effect steps should still schedule the AI follow-up"),
	])


func test_ai_heuristics_prioritize_knockout_attack() -> String:
	var heuristics = AIHeuristicsScript.new()
	var attack_action := {"kind": "attack", "projected_knockout": true}
	var end_turn_action := {"kind": "end_turn"}
	return run_checks([
		assert_true(
			heuristics.score_action(attack_action, {}) > heuristics.score_action(end_turn_action, {}),
			"Knockout attacks should outrank ending the turn"
		),
	])


func test_ai_heuristics_prioritize_play_basic_to_bench_over_end_turn() -> String:
	var heuristics = AIHeuristicsScript.new()
	var bench_action := {"kind": "play_basic_to_bench"}
	var end_turn_action := {"kind": "end_turn"}
	return run_checks([
		assert_true(
			heuristics.score_action(bench_action, {}) > heuristics.score_action(end_turn_action, {}),
			"Benching a Basic should outrank ending the turn"
		),
	])


func test_ai_heuristics_prioritize_active_attach_targets() -> String:
	var heuristics = AIHeuristicsScript.new()
	var active_attach := {"kind": "attach_energy", "is_active_target": true}
	var bench_attach := {"kind": "attach_energy", "is_active_target": false}
	return run_checks([
		assert_true(
			heuristics.score_action(active_attach, {}) > heuristics.score_action(bench_attach, {}),
			"Attaching to the active Pokemon should outrank a generic bench attach in the baseline policy"
		),
	])


func test_ai_heuristics_prioritize_productive_attach_over_dead_trainer() -> String:
	var heuristics = AIHeuristicsScript.new()
	var attach_action := {"kind": "attach_energy", "is_active_target": true}
	var dead_trainer := {"kind": "play_trainer", "productive": false}
	return run_checks([
		assert_true(
			heuristics.score_action(attach_action, {}) > heuristics.score_action(dead_trainer, {}),
			"Productive attaches should outrank low-value trainer plays"
		),
	])


func test_ai_heuristics_accept_richer_scoring_context_and_preserve_attach_priority() -> String:
	var heuristics = AIHeuristicsScript.new()
	var extractor := AIFeatureExtractorScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Active", "Basic", "", "", [], [{"name": "Hit", "cost": "C", "damage": "10"}]), 0))
	var bench_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench"), 0))
	var active_energy := CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 0)
	var bench_energy := CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 0)
	player.active_pokemon = active_slot
	player.bench = [bench_slot]

	var active_action := {"kind": "attach_energy", "card": active_energy, "target_slot": active_slot, "is_active_target": true}
	var bench_action := {"kind": "attach_energy", "card": bench_energy, "target_slot": bench_slot, "is_active_target": false}
	var active_context := {
		"gsm": gsm,
		"game_state": gsm.game_state,
		"player_index": 0,
		"features": extractor.build_context(gsm, 0, active_action),
	}
	var bench_context := {
		"gsm": gsm,
		"game_state": gsm.game_state,
		"player_index": 0,
		"features": extractor.build_context(gsm, 0, bench_action),
	}
	var active_score: float = heuristics.score_action(active_action, active_context)
	var bench_score: float = heuristics.score_action(bench_action, bench_context)

	return run_checks([
		assert_true(
			active_score > bench_score,
			"Rich scoring context should preserve the active attach preference"
		),
	])


func test_ai_heuristics_tag_bench_development_and_dead_trainer_penalty() -> String:
	var heuristics = AIHeuristicsScript.new()
	var bench_action := {"kind": "play_basic_to_bench"}
	var dead_trainer := {"kind": "play_trainer"}
	var bench_context := {
		"features": {
			"improves_bench_development": true,
			"bench_development_delta": 1,
		},
	}
	var dead_trainer_context := {
		"features": {
			"productive": false,
		},
	}
	var bench_score: float = heuristics.score_action(bench_action, bench_context)
	var dead_trainer_score: float = heuristics.score_action(dead_trainer, dead_trainer_context)

	return run_checks([
		assert_true(
			bench_score > dead_trainer_score,
			"Bench development should outrank dead trainer actions once richer heuristic context is applied"
		),
		assert_true(
			Array(bench_action.get("reason_tags", [])).has("bench_development"),
			"Bench development score bumps should record a stable bench_development reason tag"
		),
		assert_true(
			Array(dead_trainer.get("reason_tags", [])).has("dead_trainer_penalty"),
			"Dead trainer penalties should record a stable dead_trainer_penalty reason tag"
		),
	])


func test_ai_opponent_executes_attack_before_ending_turn() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	var opponent: PlayerState = gsm.game_state.players[0]
	var attacker_cd := _make_ai_pokemon_card_data(
		"Attacker",
		"Basic",
		"",
		"",
		[],
		[{"name": "Zap", "cost": "C", "damage": "50", "text": "", "is_vstar_power": false}]
	)
	var attacker_slot := _make_ai_slot(CardInstance.create(attacker_cd, 1))
	attacker_slot.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 1))
	player.active_pokemon = attacker_slot
	opponent.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Defender"), 0))

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should execute an available attack"),
		assert_eq(opponent.active_pokemon.damage_counters, 50, "AI should deal attack damage before considering end_turn"),
		assert_true(gsm.game_state.phase != GameState.GamePhase.MAIN, "Executing the attack should leave the main-phase idle state"),
	])


func test_ai_opponent_plays_basic_to_bench_when_no_attack_is_available() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 1))
	var bench_basic := CardInstance.create(_make_ai_pokemon_card_data("Bench Basic"), 1)
	player.hand = [bench_basic]

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should play a benchable Basic when it cannot attack"),
		assert_eq(player.bench.size(), 1, "AI should place the Basic onto the bench"),
		assert_eq(player.bench[0].get_pokemon_name(), "Bench Basic", "AI should bench the available Basic Pokemon"),
		assert_false(bench_basic in player.hand, "The benched Basic should leave the hand"),
	])


func test_ai_opponent_prioritizes_stage2_progress_over_nonadvancing_attach() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	var charmander_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Charmander"), 1), 1)
	var charmeleon := CardInstance.create(_make_ai_pokemon_card_data("Charmeleon", "Stage 1", "Charmander"), 1)
	var charizard_ex := CardInstance.create(_make_ai_pokemon_card_data("Charizard ex", "Stage 2", "Charmeleon"), 1)
	var fire_energy := CardInstance.create(_make_ai_energy_card_data("Fire Energy", "R"), 1)
	player.active_pokemon = charmander_slot
	player.hand = [charmeleon, charizard_ex, fire_energy]

	var handled := ai.run_single_step(scene, gsm)
	var trace = ai.get_last_decision_trace()
	return run_checks([
		assert_true(handled, "AI should take a productive action when Stage 2 progress is available"),
		assert_eq(player.active_pokemon.get_pokemon_name(), "Charmeleon", "AI should evolve into the Stage 1 that directly advances the Stage 2 line"),
		assert_true(fire_energy in player.hand, "AI should not spend the attachment before taking the key Stage 2 progression step"),
		assert_eq(trace.chosen_action.get("kind", ""), "evolve", "Decision trace should show the evolution line was chosen"),
		assert_true(Array(trace.reason_tags).has("stage2_progress"), "Stage 2 progression bumps should record a stable stage2_progress reason tag"),
	])


func test_ai_opponent_records_attack_readiness_reason_tag_when_attach_beats_cosmetic_action() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	var attacker_cd := _make_ai_pokemon_card_data(
		"Attacker",
		"Basic",
		"",
		"",
		[],
		[{"name": "Zap", "cost": "L", "damage": "50", "text": "", "is_vstar_power": false}]
	)
	player.active_pokemon = _make_ai_slot(CardInstance.create(attacker_cd, 1))
	player.hand = [
		CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 1),
		CardInstance.create(_make_ai_trainer_card_data("Beach Court", "Stadium"), 1),
	]

	var handled := ai.run_single_step(scene, gsm)
	var trace = ai.get_last_decision_trace()
	return run_checks([
		assert_true(handled, "AI should take the setup action that advances an attack"),
		assert_eq(trace.chosen_action.get("kind", ""), "attach_energy", "Attack-readiness setup should beat purely cosmetic stadium play"),
		assert_true(Array(trace.reason_tags).has("attack_readiness"), "Attack-readiness score bumps should record a stable attack_readiness reason tag"),
	])


func test_ai_opponent_uses_nest_ball_after_attaching_when_basic_targets_remain() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpyInteractiveActionBattleScene.new()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 1))
	var fire_energy := CardInstance.create(_make_ai_energy_card_data("Fire Energy", "R"), 1)
	var nest_ball := CardInstance.create(
		_make_ai_trainer_card_data("Nest Ball", "Item", "1af63a7e2cb7a79215474ad8db8fd8fd"),
		1
	)
	var stage_two := CardInstance.create(_make_ai_pokemon_card_data("Charizard ex", "Stage 2", "Charmeleon"), 1)
	player.hand = [fire_energy, nest_ball, stage_two]
	player.deck = [CardInstance.create(_make_ai_pokemon_card_data("Charmander"), 1)]

	var handled_attach := ai.run_single_step(scene, gsm)
	var actions_after_attach := _build_ai_actions(gsm, 1)
	var handled_followup := ai.run_single_step(scene, gsm)
	var followup_trace = ai.get_last_decision_trace()
	var bench_size_after_followup: int = player.bench.size()
	var nest_ball_in_hand_after_followup: bool = nest_ball in player.hand
	return run_checks([
		assert_true(handled_attach, "AI should use the first action to attach energy"),
		assert_false(_has_action(actions_after_attach, "attach_energy"), "Attach actions should disappear after the once-per-turn attach is spent"),
		assert_true(_has_action(actions_after_attach, "play_trainer", {"card": nest_ball}), "Nest Ball should remain a legal follow-up while deck still contains a Basic target"),
		assert_eq(scene.trainer_interaction_calls, 0, "Nest Ball should now resolve through the headless AI path instead of opening BattleScene interaction UI"),
		assert_true(handled_followup, "The Nest Ball follow-up should count as handled work"),
		assert_eq(followup_trace.chosen_action.get("kind", ""), "play_trainer", "Decision trace should show the productive Nest Ball line was chosen"),
		assert_true(Array(followup_trace.reason_tags).has("bench_development"), "Productive Nest Ball follow-ups should record a stable bench_development reason tag"),
		assert_eq(bench_size_after_followup, 1, "Headless Nest Ball resolution should still bench the selected Basic Pokemon"),
		assert_false(nest_ball_in_hand_after_followup, "Nest Ball should leave the hand after the headless follow-up resolves"),
	])


func test_ai_can_legally_pass_after_attach_when_nest_ball_has_no_basic_target() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpyInteractiveActionBattleScene.new()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 1))
	var opponent: PlayerState = gsm.game_state.players[0]
	opponent.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Opponent Lead"), 0))
	var fire_energy := CardInstance.create(_make_ai_energy_card_data("Fire Energy", "R"), 1)
	var nest_ball := CardInstance.create(
		_make_ai_trainer_card_data("Nest Ball", "Item", "1af63a7e2cb7a79215474ad8db8fd8fd"),
		1
	)
	var stage_two := CardInstance.create(_make_ai_pokemon_card_data("Charizard ex", "Stage 2", "Charmeleon"), 1)
	player.hand = [fire_energy, nest_ball, stage_two]
	player.deck = [CardInstance.create(_make_ai_trainer_card_data("Arven", "Supporter"), 1)]

	var handled_attach := ai.run_single_step(scene, gsm)
	var actions_after_attach := _build_ai_actions(gsm, 1)
	var handled_followup := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled_attach, "AI should still attach energy first in the baseline policy"),
		assert_false(_has_action(actions_after_attach, "play_trainer", {"card": nest_ball}), "Nest Ball should stop being legal when the deck has no remaining Basic Pokemon"),
		assert_false(_has_action(actions_after_attach, "play_basic_to_bench"), "A Stage 2 Pokemon in hand should not create a bench action"),
		assert_eq(scene.trainer_interaction_calls, 0, "AI should not try to open Nest Ball when it has no valid target"),
		assert_true(handled_followup, "Ending the turn should still count as handled work when no productive legal actions remain"),
		assert_true(gsm.game_state.current_player_index != 1 or gsm.game_state.phase != GameState.GamePhase.MAIN, "With no productive legal actions left, AI should be allowed to pass the turn"),
	])


func test_ai_opponent_starts_interactive_trainer_actions_through_battle_scene() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpyInteractiveActionBattleScene.new()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 1))
	var item := CardInstance.create(_make_ai_trainer_card_data("Interactive Item", "Item", "test_ai_interactive_item"), 1)
	gsm.effect_processor.register_effect("test_ai_interactive_item", InteractiveChoiceEffect.new())
	player.hand = [item]

	var handled := ai.run_single_step(scene, gsm)
	var item_in_hand_after_action: bool = item in player.hand
	var trace = ai.get_last_decision_trace()
	return run_checks([
		assert_true(handled, "AI should treat interactive trainer actions as executable work"),
		assert_eq(scene.trainer_interaction_calls, 0, "Headless trainer targets should no longer require BattleScene interaction"),
		assert_eq(trace.chosen_action.get("kind", ""), "play_trainer", "Decision trace should still record the trainer action"),
		assert_false(item_in_hand_after_action, "The interactive trainer should still resolve and leave the hand through the headless path"),
	])


func test_ai_opponent_starts_interactive_ability_actions_through_battle_scene() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpyInteractiveActionBattleScene.new()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	var player: PlayerState = gsm.game_state.players[1]
	var ability_cd := _make_ai_pokemon_card_data(
		"Interactive Ability Mon",
		"Basic",
		"",
		"test_ai_interactive_ability",
		[{"name": "Choose", "text": ""}]
	)
	gsm.effect_processor.register_effect("test_ai_interactive_ability", InteractiveChoiceEffect.new())
	player.active_pokemon = _make_ai_slot(CardInstance.create(ability_cd, 1))

	var handled := ai.run_single_step(scene, gsm)
	var trace = ai.get_last_decision_trace()
	return run_checks([
		assert_true(handled, "AI should treat interactive ability actions as executable work"),
		assert_eq(scene.ability_interaction_calls, 0, "Headless ability targets should no longer require BattleScene interaction"),
		assert_eq(trace.chosen_action.get("kind", ""), "use_ability", "Decision trace should still record the ability action"),
	])


func test_ai_opponent_routes_setup_active_prompt_through_setup_planner() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpySetupBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.hand = [_make_basic("A"), _make_basic("B"), _make_item("Ball")]
	scene.set("_gsm", gsm)
	scene.set("_setup_done", [false, false])
	scene.set("_view_player", 1)
	scene.set("_pending_choice", "setup_active_1")
	scene.set("_dialog_data", {
		"basics": [player.hand[0], player.hand[1]],
		"player": 1,
	})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle setup active prompts"),
		assert_not_null(player.active_pokemon, "AI should place an active Pokemon during setup"),
		assert_eq(player.active_pokemon.get_pokemon_name(), "A", "AI should choose the first available Basic as active"),
		assert_eq(scene.after_setup_active_calls.size(), 1, "AI should advance the setup flow after placing the active Pokemon"),
	])


func test_ai_opponent_routes_setup_bench_prompt_through_setup_planner() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpySetupBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(_make_basic("Lead"))
	player.hand = [_make_basic("Bench A"), _make_item("Ball")]
	scene.set("_gsm", gsm)
	scene.set("_setup_done", [false, false])
	scene.set("_view_player", 1)
	scene.set("_pending_choice", "setup_bench_1")
	scene.set("_dialog_data", {
		"cards": [player.hand[0]],
		"player": 1,
	})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle setup bench prompts"),
		assert_eq(player.bench.size(), 1, "AI should bench an extra Basic during setup"),
		assert_eq(player.bench[0].get_pokemon_name(), "Bench A", "AI should choose the available Basic for bench"),
		assert_eq(scene.refresh_ui_calls, 1, "AI should request a refresh after benching a Basic"),
		assert_eq(scene.show_setup_bench_dialog_calls.size(), 1, "AI should continue the bench setup flow after a successful bench placement"),
	])


func test_ai_opponent_clears_final_setup_bench_prompt_before_advancing() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpySetupBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(_make_basic("Lead"))
	scene.set("_gsm", gsm)
	scene.set("_setup_done", [false, false])
	scene.set("_view_player", 1)
	scene.set("_pending_choice", "setup_bench_1")
	scene.set("_dialog_data", {
		"cards": [],
		"player": 1,
	})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle a final setup bench prompt with no remaining Basics"),
		assert_eq(str(scene.get("_pending_choice")), "", "AI should clear setup_bench after finishing the setup bench step"),
		assert_eq(scene.after_setup_bench_calls.size(), 1, "AI should still advance the setup flow once"),
	])


func test_ai_opponent_accepts_mulligan_bonus_draw_prompt() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := BattleSceneScript.new()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "mulligan_extra_draw")
	scene.set("_dialog_data", {"beneficiary": 1})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle mulligan bonus-draw prompts"),
		assert_eq(gsm.mulligan_resolve_calls, 1, "AI should resolve mulligan choice exactly once"),
		assert_eq(gsm.resolved_beneficiary, 1, "AI should resolve the configured mulligan beneficiary"),
		assert_eq(gsm.resolved_draw_extra, true, "Baseline AI should always accept the extra draw"),
	])


func test_ai_opponent_clears_mulligan_prompt_after_resolving_it() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := BattleSceneScript.new()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "mulligan_extra_draw")
	scene.set("_dialog_data", {"beneficiary": 1})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should still resolve the mulligan prompt"),
		assert_eq(str(scene.get("_pending_choice")), "", "AI should clear mulligan_extra_draw after consuming it"),
	])


func test_ai_opponent_resolves_ai_owned_take_prize_prompt() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var prize_card := _make_item("Prize")
	gsm.game_state.players[1].set_prizes([prize_card])
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "take_prize")
	scene.set("_pending_prize_player_index", 1)
	scene.set("_pending_prize_remaining", 1)
	gsm.set("_pending_prize_player_index", 1)
	gsm.set("_pending_prize_remaining", 1)
	scene.set("_opp_prize_slots", [BattleCardViewScript.new()])

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle its own take_prize prompt"),
		assert_eq(gsm.game_state.players[1].prizes.size(), 0, "AI should remove a prize card from its prize area"),
		assert_true(prize_card in gsm.game_state.players[1].hand, "AI should put the taken prize into hand"),
		assert_eq(str(scene.get("_pending_choice")), "", "AI should clear the take_prize prompt after resolving it"),
	])


func test_ai_opponent_waits_for_delayed_prize_animation_before_fallback_resolve() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := DelayedPrizeAnimationScene.new()
	var gsm := SpyPrizeResolveGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	gsm.game_state.players[1].set_prizes([_make_item("Prize")])
	gsm.set("_pending_prize_player_index", 1)
	gsm.set("_pending_prize_remaining", 1)

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should treat a started prize flip animation as handled work"),
		assert_eq(scene.try_take_prize_calls, 1, "AI should still kick off the prize flip interaction"),
		assert_true(bool(scene.get("_pending_prize_animating")), "Prize prompt should remain in the animating state"),
		assert_eq(gsm.resolve_take_prize_calls, 0, "AI should not fallback to GameStateMachine.resolve_take_prize while the flip animation is running"),
		assert_eq(str(scene.get("_pending_choice")), "take_prize", "AI should leave the take_prize prompt pending until the animation callback completes"),
	])


func test_ai_opponent_resolves_ai_owned_send_out_prompt() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.first_player_index = 0
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(_make_ai_pokemon_card_data("AI Replacement"), 1))
	gsm.game_state.players[1].bench = [replacement]
	gsm.game_state.players[1].deck = [CardInstance.create(_make_ai_pokemon_card_data("Draw Card"), 1)]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "send_out")
	scene.set("_dialog_data", {
		"player": 1,
		"bench": [replacement],
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	})
	scene.set("_view_player", 0)

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should resolve its own send_out prompt"),
		assert_eq(gsm.game_state.players[1].active_pokemon, replacement, "AI should move its chosen bench Pokemon into the active slot"),
		assert_eq(str(scene.get("_pending_choice")), "", "AI should clear the send_out prompt after resolving it"),
	])


func test_ai_owned_send_out_keeps_human_view_in_vs_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	var gsm := SpySendOutViewGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(_make_ai_pokemon_card_data("AI Bench"), 1))
	gsm.game_state.players[1].bench = [replacement]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "send_out")
	scene.set("_dialog_data", {
		"player": 1,
		"bench": [replacement],
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	})
	scene.set("_view_player", 0)

	var handled := ai.run_single_step(scene, gsm)
	var current_after_send_out: int = gsm.game_state.current_player_index
	var view_after_send_out: int = int(scene.get("_view_player"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(handled, "AI should resolve its own send_out prompt"),
		assert_eq(gsm.send_out_calls, 1, "AI should drive the send_out transition through GameStateMachine"),
		assert_eq(current_after_send_out, 1, "The send_out transition may still advance the turn to the AI"),
		assert_eq(view_after_send_out, 0, "VS_AI should keep the visible side on the human player after AI send_out"),
	])


func test_ai_send_out_prefers_deck_strategy_handoff_target() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set_deck_strategy(FakeSendOutStrategy.new("Preferred Bench"))
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var energy_bench := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Energy Bench"), 1))
	energy_bench.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 1))
	var preferred_bench := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Preferred Bench"), 1))
	gsm.game_state.players[1].bench = [energy_bench, preferred_bench]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "send_out")
	scene.set("_dialog_data", {
		"player": 1,
		"bench": [energy_bench, preferred_bench],
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should resolve the send_out prompt with deck-local handoff scoring"),
		assert_eq(gsm.game_state.players[1].active_pokemon, preferred_bench, "Deck strategy send_out scoring should outrank the generic energy-based fallback"),
	])


func test_ai_send_out_allows_learned_interaction_overlay() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set("_interaction_scorer", FakeSendOutInteractionScorer.new())
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var energy_bench := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Energy Bench"), 1))
	energy_bench.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 1))
	var plain_bench := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Plain Bench"), 1))
	gsm.game_state.players[1].bench = [energy_bench, plain_bench]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "send_out")
	scene.set("_dialog_data", {
		"player": 1,
		"bench": [energy_bench, plain_bench],
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should resolve the send_out prompt when an interaction scorer is injected"),
		assert_eq(gsm.game_state.players[1].active_pokemon, plain_bench, "Learned interaction scoring should be able to override the generic send_out fallback ordering"),
	])


func test_ai_heavy_baton_prefers_deck_strategy_handoff_target() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set_deck_strategy(FakeHandoffStrategy.new("heavy_baton_target", "Preferred Baton Bench"))
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := SpyHeavyBatonResolveGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var energy_bench := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Energy Baton Bench"), 1))
	energy_bench.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 1))
	var preferred_bench := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Preferred Baton Bench"), 1))
	gsm.game_state.players[1].bench = [energy_bench, preferred_bench]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "heavy_baton_target")
	scene.set("_dialog_data", {
		"player": 1,
		"bench": [energy_bench, preferred_bench],
		"count": 3,
		"source_name": "Heavy Baton",
	})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should resolve the heavy_baton_target prompt with deck-local handoff scoring"),
		assert_eq(gsm.resolve_heavy_baton_choice_calls, 1, "AI should resolve the Heavy Baton target through GameStateMachine"),
		assert_eq(gsm.resolved_heavy_baton_player_index, 1, "Heavy Baton prompt resolution should preserve the owning player"),
		assert_eq(gsm.resolved_heavy_baton_target, preferred_bench, "Deck-local handoff scoring should outrank the generic energy-based Heavy Baton fallback"),
	])


func test_ai_opponent_ignores_human_owned_mulligan_bonus_draw_prompt() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := BattleSceneScript.new()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "mulligan_extra_draw")
	scene.set("_dialog_data", {"beneficiary": 0})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_false(handled, "AI should ignore mulligan prompts owned by the human player"),
		assert_eq(gsm.mulligan_resolve_calls, 0, "AI should not resolve a human-owned mulligan prompt"),
	])


func test_battle_scene_schedules_ai_for_mulligan_setup_prompt() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_setup_ready_battle_scene()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._on_player_choice_required("mulligan_extra_draw", {"beneficiary": 1, "mulligan_count": 1})
	var scheduled_after_prompt: bool = scene.get("_ai_step_scheduled")
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(scene.get("_dialog_overlay").visible, "Mulligan prompt should show the dialog overlay"),
		assert_true(scheduled_after_prompt, "BattleScene should schedule AI for its mulligan setup prompt"),
		assert_eq(gsm.mulligan_resolve_calls, 1, "BattleScene should drive the AI mulligan choice through the real scheduling path"),
		assert_eq(gsm.resolved_beneficiary, 1, "BattleScene should pass the mulligan beneficiary through unchanged"),
		assert_true(gsm.resolved_draw_extra, "Baseline AI should still accept the mulligan bonus draw"),
	])


func test_battle_scene_schedules_ai_for_setup_active_prompt_target_player() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_setup_ready_battle_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.hand = [_make_basic("A"), _make_basic("B"), _make_item("Ball")]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._show_setup_active_dialog(1)
	var scheduled_after_prompt: bool = scene.get("_ai_step_scheduled")
	var dialog_visible_after_prompt: bool = bool(scene.get("_dialog_overlay").visible)
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_false(dialog_visible_after_prompt, "AI-owned setup active prompts should stay hidden from the human UI"),
		assert_true(scheduled_after_prompt, "BattleScene should schedule AI for setup_active prompts owned by the AI"),
		assert_not_null(player.active_pokemon, "AI should place its active Pokemon through BattleScene scheduling"),
		assert_eq(player.active_pokemon.get_pokemon_name(), "A", "AI should still choose the first available Basic as active"),
	])


func test_battle_scene_schedules_ai_for_setup_bench_prompt_target_player() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_setup_ready_battle_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(_make_basic("Lead"))
	player.hand = [_make_basic("Bench A"), _make_item("Ball")]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._show_setup_bench_dialog(1)
	var scheduled_after_prompt: bool = scene.get("_ai_step_scheduled")
	var dialog_visible_after_prompt: bool = bool(scene.get("_dialog_overlay").visible)
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_false(dialog_visible_after_prompt, "AI-owned setup bench prompts should stay hidden from the human UI"),
		assert_true(scheduled_after_prompt, "BattleScene should schedule AI for setup_bench prompts owned by the AI"),
		assert_eq(player.bench.size(), 1, "AI should place a bench Pokemon through BattleScene scheduling"),
		assert_eq(player.bench[0].get_pokemon_name(), "Bench A", "AI should choose the available Basic for bench"),
	])


func test_battle_scene_schedules_ai_for_send_out_prompt_target_player() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(_make_ai_pokemon_card_data("AI Bench"), 1))
	gsm.game_state.players[1].bench = [replacement]
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene.set("_view_player", 0)
	scene._on_player_choice_required("send_out_pokemon", {"player": 1})
	var scheduled_after_prompt: bool = bool(scene.get("_ai_step_scheduled"))
	var field_overlay_visible: bool = bool(scene.get("_field_interaction_overlay").visible)
	var dialog_visible_after_prompt: bool = bool(scene.get("_dialog_overlay").visible)
	var view_after_prompt: int = int(scene.get("_view_player"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "send_out", "AI-owned replacement should leave send_out pending"),
		assert_true(scheduled_after_prompt, "BattleScene should schedule AI for AI-owned send_out prompts"),
		assert_false(field_overlay_visible, "AI-owned send_out prompts should stay hidden from the human field UI"),
		assert_false(dialog_visible_after_prompt, "AI-owned send_out prompts should not show the dialog overlay"),
		assert_eq(view_after_prompt, 0, "AI-owned send_out prompts should not flip the visible side back to the AI"),
		assert_eq(spy_ai.run_count, 0, "Scheduling should not immediately execute the AI step"),
	])


func test_battle_scene_handoff_from_human_setup_to_ai_active_prompt_schedules_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_setup_ready_battle_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var human: PlayerState = gsm.game_state.players[0]
	var ai_player: PlayerState = gsm.game_state.players[1]
	human.hand = [_make_basic("Human Lead"), _make_item("Ball")]
	ai_player.hand = [_make_basic("AI Lead"), _make_basic("AI Bench")]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_setup_done", [false, false])
	scene._show_setup_active_dialog(0)
	scene._handle_dialog_choice(PackedInt32Array([0]))
	var pending_after_human_choice: String = str(scene.get("_pending_choice"))
	var scheduled_after_handoff: bool = bool(scene.get("_ai_step_scheduled"))
	var dialog_visible_after_handoff: bool = bool(scene.get("_dialog_overlay").visible)
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(pending_after_human_choice, "setup_active_1", "Human setup completion should hand off to the AI active-choice prompt"),
		assert_true(scheduled_after_handoff, "Handing setup to the AI should schedule an AI step"),
		assert_false(dialog_visible_after_handoff, "The AI active-choice prompt should not be shown back to the human"),
		assert_not_null(ai_player.active_pokemon, "AI should place its active Pokemon after the handoff"),
		assert_eq(ai_player.active_pokemon.get_pokemon_name(), "AI Lead", "AI should choose its own opening active Pokemon"),
	])


func test_battle_scene_ai_first_player_setup_hands_off_into_first_turn() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_setup_ready_battle_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var human: PlayerState = gsm.game_state.players[0]
	var ai_player: PlayerState = gsm.game_state.players[1]
	human.hand = [_make_basic("Human Lead")]
	ai_player.hand = [_make_basic("AI Lead"), _make_basic("AI Bench")]
	for pi: int in 2:
		for deck_idx: int in 7:
			gsm.game_state.players[pi].deck.append(_make_basic("Deck %d-%d" % [pi, deck_idx]))
	gsm.state_changed.connect(scene._on_state_changed)
	gsm.action_logged.connect(scene._on_action_logged)
	gsm.player_choice_required.connect(scene._on_player_choice_required)
	gsm.game_over.connect(scene._on_game_over)
	gsm.coin_flipper.coin_flipped.connect(scene._on_coin_flipped)
	var ai := CountingAIOpponent.new(1)
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_ai_opponent", ai)
	scene._begin_setup_flow()
	scene._handle_dialog_choice(PackedInt32Array([0]))
	scene._handle_dialog_choice(PackedInt32Array([0]))
	var scheduled_after_human_setup: bool = bool(scene.get("_ai_step_scheduled"))
	scene._run_ai_step()
	var scheduled_after_ai_active: bool = bool(scene.get("_ai_step_scheduled"))
	scene._run_ai_step()
	var phase_after_setup: int = int(gsm.game_state.phase)
	var current_player_after_setup: int = int(gsm.game_state.current_player_index)
	var pending_choice_after_setup: String = str(scene.get("_pending_choice"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(scheduled_after_human_setup, "Human setup completion should still schedule the AI setup step when the AI is first player"),
		assert_true(scheduled_after_ai_active, "AI active placement should queue the follow-up setup bench step"),
		assert_eq(phase_after_setup, GameState.GamePhase.MAIN, "Setup completion should advance into the opening main phase"),
		assert_eq(current_player_after_setup, 1, "AI-first setup should keep the AI as the opening turn owner"),
		assert_eq(pending_choice_after_setup, "", "No setup prompt should remain pending after setup completes"),
		assert_true(ai.run_count >= 2, "AI should have resolved both setup prompts before entering its first turn"),
	])


func test_ai_send_out_prompt_preserves_followup_take_prize_prompt() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_setup_ready_battle_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.state_changed.connect(scene._on_state_changed)
	gsm.action_logged.connect(scene._on_action_logged)
	gsm.player_choice_required.connect(scene._on_player_choice_required)
	gsm.game_over.connect(scene._on_game_over)
	gsm.coin_flipper.coin_flipped.connect(scene._on_coin_flipped)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		my_prize_slots.append(BattleCardViewScript.new())
		opp_prize_slots.append(BattleCardViewScript.new())
	scene.set("_my_prize_slots", my_prize_slots)
	scene.set("_opp_prize_slots", opp_prize_slots)
	for pi: int in 2:
		var player := _make_player_state(pi)
		for deck_idx: int in 3:
			player.deck.append(CardInstance.create(_make_ai_pokemon_card_data("Deck %d-%d" % [pi, deck_idx]), pi))
		gsm.game_state.players.append(player)
	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	for energy_type: String in ["R", "P"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Energy %s" % energy_type, energy_type), 0))
	gsm.effect_processor.register_pokemon_card(dragapult_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var active_target_cd := _make_ai_pokemon_card_data("Active Prize Target")
	active_target_cd.hp = 200
	active_target_cd.energy_type = "W"
	var active_target := PokemonSlot.new()
	active_target.pokemon_stack.append(CardInstance.create(active_target_cd, 1))
	gsm.game_state.players[1].active_pokemon = active_target
	var bench_target_cd := _make_ai_pokemon_card_data("Bench Prize Target")
	bench_target_cd.hp = 60
	bench_target_cd.energy_type = "W"
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(bench_target_cd, 1))
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(_make_ai_pokemon_card_data("AI Replacement"), 1))
	gsm.game_state.players[1].bench = [bench_target, replacement]
	for prize_idx: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_ai_pokemon_card_data("My Prize %d" % prize_idx), 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_ai_pokemon_card_data("Opp Prize %d" % prize_idx), 1))
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_ai_opponent", ai)
	var attacked: bool = gsm.use_attack(0, 1, [{
		"bench_damage_counters": [
			{"target": bench_target, "amount": 60},
		],
	}])
	var first_prompt: String = str(scene.get("_pending_choice"))
	scene._try_take_prize_from_slot(0, 0)
	var prompt_after_first_prize: String = str(scene.get("_pending_choice"))
	var ai_scheduled_after_first_prize: bool = bool(scene.get("_ai_step_scheduled"))
	scene._run_ai_step()
	var prompt_after_ai_send_out: String = str(scene.get("_pending_choice"))
	var scene_pending_second_prize: int = int(scene.get("_pending_prize_remaining"))
	var gsm_pending_second_prize: int = int(gsm.get("_pending_prize_remaining"))
	scene._try_take_prize_from_slot(0, 1)
	var player_hand_after_second_prize: int = gsm.game_state.players[0].hand.size()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_not_null(dragapult_cd, "CSV8C_159 should exist in the card database"),
		assert_true(attacked, "Dragapult ex Phantom Dive should set up the double-KO fixture"),
		assert_eq(first_prompt, "take_prize", "The first Dragapult ex knockout should prompt prize selection"),
		assert_eq(prompt_after_first_prize, "send_out", "After the first prize, the AI should still need to send out a replacement before the next prize"),
		assert_true(ai_scheduled_after_first_prize, "The AI-owned send_out prompt should schedule the AI follow-up"),
		assert_eq(prompt_after_ai_send_out, "take_prize", "After the AI sends out a replacement, the second prize prompt should still be pending for the human player"),
		assert_eq(scene_pending_second_prize, 1, "BattleScene should keep exactly one prize pending after the AI send-out"),
		assert_eq(gsm_pending_second_prize, 1, "GameStateMachine should keep exactly one prize pending after the AI send-out"),
		assert_eq(player_hand_after_second_prize, 2, "The player should still be able to take the second Dragapult ex prize"),
	])


func test_ai_opponent_reuses_planned_setup_bench_choices_across_repeated_prompts() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpySetupBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.hand = [_make_basic("Active A"), _make_basic("Bench A"), _make_basic("Bench B"), _make_item("Ball")]
	scene.set("_gsm", gsm)
	scene.set("_setup_done", [false, false])
	scene.set("_view_player", 1)
	scene.set("_pending_choice", "setup_active_1")
	scene.set("_dialog_data", {
		"basics": [player.hand[0], player.hand[1], player.hand[2]],
		"player": 1,
	})

	var handled_active := ai.run_single_step(scene, gsm)
	scene.set("_pending_choice", "setup_bench_1")
	scene.set("_dialog_data", {
		"cards": [player.hand[0], player.hand[1]],
		"player": 1,
	})
	var handled_first_bench := ai.run_single_step(scene, gsm)
	scene.set("_pending_choice", "setup_bench_1")
	scene.set("_dialog_data", {
		"cards": [player.hand[0]],
		"player": 1,
	})
	var handled_second_bench := ai.run_single_step(scene, gsm)

	return run_checks([
		assert_true(handled_active, "AI should plan setup from the active prompt"),
		assert_true(handled_first_bench, "AI should consume the first repeated bench prompt"),
		assert_true(handled_second_bench, "AI should consume the second repeated bench prompt"),
		assert_eq(player.bench.size(), 2, "AI should bench both planned Basics across repeated prompts"),
		assert_eq(player.bench[0].get_pokemon_name(), "Bench A", "AI should bench the first planned Basic first"),
		assert_eq(player.bench[1].get_pokemon_name(), "Bench B", "AI should carry the remaining planned Basic to the next prompt"),
	])


func test_battle_scene_schedules_ai_in_vs_ai_when_unblocked() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._maybe_run_ai()
	var scheduled_after_maybe_run: bool = scene.get("_ai_step_scheduled")
	scene._run_ai_step()
	var checks := run_checks([
		assert_true(scheduled_after_maybe_run, "BattleScene should request a deferred AI step in VS_AI mode on the AI turn"),
		assert_eq(spy_ai.run_count, 1, "BattleScene should execute exactly one AI step when the deferred step runs"),
		assert_false(scene.get("_ai_step_scheduled"), "BattleScene should clear the scheduled AI step flag after running"),
	])
	GameManager.current_mode = previous_mode
	return checks


func test_battle_scene_handover_confirmation_callback_schedules_ai_in_vs_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene.set("_pending_handover_action", func() -> void:
		pass
	)
	scene._on_handover_confirmed()
	var scheduled_after_callback: bool = scene.get("_ai_step_scheduled")
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(scheduled_after_callback, "Handover confirmation should schedule AI on the AI turn in VS_AI mode"),
		assert_eq(spy_ai.run_count, 1, "Handover confirmation should lead to one AI step"),
	])


func test_battle_scene_ai_draw_reveal_auto_continue_reschedules_ai_turn() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var drawn_card := CardInstance.create(_make_ai_pokemon_card_data("AI Drawn Card"), 1)
	gsm.game_state.players[1].hand = [drawn_card]
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 1, "card_names": [drawn_card.card_data.name], "card_instance_ids": [drawn_card.instance_id]},
		2,
		"AI draw"
	)
	scene._on_action_logged(action)
	var auto_pending_before: bool = bool(scene.get("_draw_reveal_auto_continue_pending"))
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	controller.call("run_auto_continue", scene)
	var scheduled_after_auto_continue: bool = bool(scene.get("_ai_step_scheduled"))
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(auto_pending_before, "AI draw reveals should arm auto-continue before resuming the turn"),
		assert_true(scheduled_after_auto_continue, "When the AI draw reveal auto-continues, BattleScene should schedule the next AI step"),
		assert_eq(spy_ai.run_count, 1, "After the AI draw reveal finishes, the AI turn should continue with one scheduled step"),
	])


func test_battle_scene_does_not_schedule_generic_ai_turn_during_setup_without_ai_prompt() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._maybe_run_ai()
	var scheduled_during_setup: bool = bool(scene.get("_ai_step_scheduled"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_false(scheduled_during_setup, "BattleScene should not schedule a generic AI turn during setup before an AI-owned prompt exists"),
		assert_eq(spy_ai.run_count, 0, "Setup without an AI-owned prompt should not run the AI"),
	])


func test_battle_scene_handover_confirmation_does_not_schedule_ai_outside_vs_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene.set("_pending_handover_action", func() -> void:
		pass
	)
	scene._on_handover_confirmed()
	var scheduled_after_callback: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_false(scheduled_after_callback, "Handover confirmation should not schedule AI outside VS_AI mode"),
		assert_eq(spy_ai.run_count, 0, "Blocked handover callback should not run the AI"),
	])


func test_battle_scene_retreat_action_path_schedules_ai_after_success() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(CardData.new(), 1))
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene.set("_ai_action_pause_seconds", 2.0)
	scene.set("_pending_choice", "retreat_bench")
	scene.set("_dialog_data", {
		"player": 1,
		"bench": [bench_target],
		"energy_discard": [],
	})
	scene._handle_dialog_choice(PackedInt32Array([0]))
	var pause_active_after_retreat: bool = bool(scene.call("_is_ai_action_pause_active"))
	var scheduled_after_retreat: bool = bool(scene.get("_ai_step_scheduled"))
	scene.call("_on_ai_action_pause_finished")
	var scheduled_after_pause: bool = bool(scene.get("_ai_step_scheduled"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(gsm.retreat_calls, 1, "Retreat action path should call GameStateMachine.retreat"),
		assert_true(pause_active_after_retreat, "Successful AI retreat should trigger the action pause"),
		assert_false(scheduled_after_retreat, "BattleScene should wait for the AI action pause before scheduling the next step"),
		assert_true(scheduled_after_pause, "BattleScene should resume AI scheduling after the retreat pause finishes"),
	])


func test_battle_scene_running_ai_can_queue_followup_step_from_success_hook() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var spy_ai := FollowupSchedulingSpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._maybe_run_ai()
	scene._run_ai_step()
	var scheduled_followup: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(spy_ai.run_count, 1, "The first AI step should run"),
		assert_true(scheduled_followup, "A success hook during AI execution should queue one follow-up step"),
	])


func test_battle_scene_successful_ai_action_pauses_before_next_vs_ai_step() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", SpyAIOpponent.new())
	scene.set("_ai_action_pause_seconds", 2.0)
	GameManager.current_mode = GameManager.GameMode.VS_AI

	scene._refresh_ui_after_successful_action(false, 1)
	scene._maybe_run_ai()
	var pause_active: bool = bool(scene.call("_is_ai_action_pause_active"))
	var can_accept_during_pause: bool = bool(scene.call("_can_accept_live_action"))
	var scheduled_during_pause: bool = bool(scene.get("_ai_step_scheduled"))

	scene.call("_on_ai_action_pause_finished")
	var scheduled_after_pause: bool = bool(scene.get("_ai_step_scheduled"))
	if scheduled_after_pause:
		scene._run_ai_step()
	var resumed_run_count: int = int(scene.get("_ai_opponent").run_count)
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(pause_active, "Successful AI actions in VS_AI should start the action pause"),
		assert_false(can_accept_during_pause, "The live scene should reject player input while the AI action pause is active"),
		assert_false(scheduled_during_pause, "BattleScene should not schedule the next AI step until the pause finishes"),
		assert_true(scheduled_after_pause, "When the AI action pause finishes, BattleScene should resume AI scheduling"),
		assert_eq(resumed_run_count, 1, "The resumed AI step should execute exactly once after the pause"),
	])


func test_battle_scene_ai_end_turn_pauses_before_human_input_returns() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", SpyAIOpponent.new())
	scene.set("_ai_action_pause_seconds", 2.0)
	GameManager.current_mode = GameManager.GameMode.VS_AI

	scene._on_end_turn(1)
	var pause_active: bool = bool(scene.call("_is_ai_action_pause_active"))
	var can_accept_during_pause: bool = bool(scene.call("_can_accept_live_action"))

	scene.call("_on_ai_action_pause_finished")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(pause_active, "AI end turn should also trigger the action pause in VS_AI mode"),
		assert_false(can_accept_during_pause, "The human player should stay blocked until the AI end-turn pause finishes"),
	])


func test_battle_scene_ai_started_interactive_ability_queues_followup_step() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	var player: PlayerState = gsm.game_state.players[1]
	var ability_cd := _make_ai_pokemon_card_data(
		"Interactive Ability Mon",
		"Basic",
		"",
		"test_ai_interactive_ability",
		[{"name": "Choose", "text": ""}]
	)
	gsm.effect_processor.register_effect("test_ai_interactive_ability", InteractiveChoiceEffect.new())
	player.active_pokemon = _make_ai_slot(CardInstance.create(ability_cd, 1))
	scene.set("_gsm", gsm)
	scene.set("_ai_opponent", SpyAIOpponent.new())
	scene.set("_ai_running", true)
	GameManager.current_mode = GameManager.GameMode.VS_AI

	scene._try_use_ability_with_interaction(1, player.active_pokemon, 0)
	var queued_followup: bool = bool(scene.get("_ai_followup_requested"))
	var pending_choice: String = str(scene.get("_pending_choice"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(pending_choice, "effect_interaction", "Interactive abilities should enter effect_interaction state"),
		assert_true(queued_followup, "AI-started interactive abilities should immediately queue an AI follow-up step"),
	])


func test_ai_effect_interaction_queues_followup_for_next_ai_owned_step() -> String:
	var previous_mode: int = GameManager.current_mode
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	scene.set("_ai_opponent", SpyAIOpponent.new())
	var source_card := CardInstance.create(_make_ai_trainer_card_data("Multi Step Item", "Item"), 1)
	var steps: Array[Dictionary] = [
		{
			"id": "pick_one",
			"title": "Pick One",
			"items": [CardInstance.create(_make_ai_trainer_card_data("A", "Item"), 1)],
			"labels": ["A"],
			"min_select": 1,
			"max_select": 1,
		},
		{
			"id": "pick_two",
			"title": "Pick Two",
			"items": [CardInstance.create(_make_ai_trainer_card_data("B", "Item"), 1)],
			"labels": ["B"],
			"min_select": 1,
			"max_select": 1,
		},
	]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_start_effect_interaction", "trainer", 1, steps, source_card)
	scene.set("_ai_followup_requested", false)
	scene.set("_ai_running", true)

	var handled := ai.run_single_step(scene, gsm)
	var queued_followup: bool = bool(scene.get("_ai_followup_requested"))
	var next_step_index: int = int(scene.get("_pending_effect_step_index"))
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(handled, "AI should resolve the current effect-interaction step"),
		assert_eq(next_step_index, 1, "AI should advance to the next interaction step"),
		assert_true(queued_followup, "AI should queue another follow-up when the next step is still AI-owned"),
	])


func test_battle_scene_failed_retreat_does_not_schedule_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := SpyGameStateMachine.new()
	gsm.retreat_result = false
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(CardData.new(), 1))
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene.set("_pending_choice", "retreat_bench")
	scene.set("_dialog_data", {
		"player": 1,
		"bench": [bench_target],
		"energy_discard": [],
	})
	scene._handle_dialog_choice(PackedInt32Array([0]))
	var scheduled_after_retreat: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(gsm.retreat_calls, 1, "Failed retreat path should still call GameStateMachine.retreat"),
		assert_false(scheduled_after_retreat, "Failed retreat should not schedule the AI"),
		assert_eq(spy_ai.run_count, 0, "Failed retreat should not run the AI"),
	])


func test_battle_scene_take_prize_prompt_schedules_ai_when_ai_owns_it() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._on_player_choice_required("take_prize", {"player": 1, "count": 1})
	var scheduled_during_prize_choice: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "take_prize", "Prize prompt should leave take_prize pending"),
		assert_true(scheduled_during_prize_choice, "AI-owned prize prompts should schedule the AI"),
		assert_eq(spy_ai.run_count, 0, "Prize prompt should not run the AI"),
	])


func test_battle_scene_take_prize_prompt_blocks_ai_when_human_owns_it() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._on_player_choice_required("take_prize", {"player": 0, "count": 1})
	var scheduled_during_prize_choice: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "take_prize", "Prize prompt should leave take_prize pending"),
		assert_false(scheduled_during_prize_choice, "Human-owned prize prompts should still block the AI"),
		assert_eq(spy_ai.run_count, 0, "Human-owned prize prompts should not run the AI"),
	])


func test_battle_scene_does_not_schedule_ai_when_mode_turn_or_ui_block_it() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	var dialog_overlay := Panel.new()
	var handover_panel := Panel.new()
	var field_overlay := Control.new()
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", dialog_overlay)
	scene.set("_handover_panel", handover_panel)
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_field_interaction_overlay", field_overlay)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)

	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene._maybe_run_ai()
	var scheduled_outside_vs_ai: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = GameManager.GameMode.VS_AI
	gsm.game_state.current_player_index = 0
	scene._maybe_run_ai()
	var scheduled_on_wrong_turn: bool = scene.get("_ai_step_scheduled")
	gsm.game_state.current_player_index = 1
	dialog_overlay.visible = true
	scene._maybe_run_ai()
	var scheduled_with_dialog: bool = scene.get("_ai_step_scheduled")
	dialog_overlay.visible = false
	handover_panel.visible = true
	scene._maybe_run_ai()
	var scheduled_with_handover: bool = scene.get("_ai_step_scheduled")
	handover_panel.visible = false
	field_overlay.visible = true
	scene._maybe_run_ai()
	var scheduled_with_field_overlay: bool = scene.get("_ai_step_scheduled")
	field_overlay.visible = false
	scene.set("_pending_prize_animating", true)
	scene._maybe_run_ai()
	var scheduled_with_prize_animation: bool = scene.get("_ai_step_scheduled")
	scene.set("_pending_prize_animating", false)

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_false(scheduled_outside_vs_ai, "AI should not schedule outside VS_AI mode"),
		assert_false(scheduled_on_wrong_turn, "AI should not schedule on the human turn"),
		assert_false(scheduled_with_dialog, "Dialog overlay should block AI scheduling"),
		assert_false(scheduled_with_handover, "Handover prompt should block AI scheduling"),
		assert_false(scheduled_with_field_overlay, "Field interaction overlay should block AI scheduling"),
		assert_false(scheduled_with_prize_animation, "Prize animation should block AI scheduling"),
		assert_eq(spy_ai.run_count, 0, "BattleScene should not run the AI when scheduling is blocked"),
	])


# -- 卡组偏好测试 --


func _make_deck_bias_context(gsm: GameStateMachine, player_index: int, action: Dictionary) -> Dictionary:
	## 构建包含特征的评分上下文（用于卡组偏好测试）
	var extractor := AIFeatureExtractorScript.new()
	return {
		"gsm": gsm,
		"game_state": gsm.game_state,
		"player_index": player_index,
		"action": action,
		"features": extractor.build_context(gsm, player_index, action),
	}


func test_deck_bias_miraidon_prefers_electric_generator_over_generic_item() -> String:
	## Miraidon 卡组应优先使用 Electric Generator
	var heuristics := AIHeuristicsScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	# 在场上放一只 Miraidon ex 作为卡组信号
	var miraidon_cd := _make_ai_pokemon_card_data("Miraidon ex", "Basic", "", "", [], [], 2)
	miraidon_cd.energy_type = "L"
	miraidon_cd.mechanic = "ex"
	player.active_pokemon = _make_ai_slot(CardInstance.create(miraidon_cd, 0))
	# Electric Generator（标记为可生产的训练师）
	var electric_gen := CardInstance.create(
		_make_ai_trainer_card_data("Electric Generator", "Item", ""),
		0
	)
	# 普通道具
	var generic_item := CardInstance.create(
		_make_ai_trainer_card_data("Switch", "Item", ""),
		0
	)
	player.hand = [electric_gen, generic_item]
	var eg_action := {"kind": "play_trainer", "card": electric_gen, "productive": true}
	var gi_action := {"kind": "play_trainer", "card": generic_item, "productive": true}
	var eg_ctx := _make_deck_bias_context(gsm, 0, eg_action)
	var gi_ctx := _make_deck_bias_context(gsm, 0, gi_action)
	var eg_score: float = heuristics.score_action(eg_action, eg_ctx)
	var gi_score: float = heuristics.score_action(gi_action, gi_ctx)
	return run_checks([
		assert_true(
			eg_score > gi_score,
			"Miraidon deck should score Electric Generator higher than a generic item (got eg=%s, gi=%s)" % [eg_score, gi_score]
		),
	])


func test_deck_bias_miraidon_prefers_benching_electric_basic() -> String:
	## Miraidon 卡组上板时应优先放电属性基础宝可梦
	var heuristics := AIHeuristicsScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var miraidon_cd := _make_ai_pokemon_card_data("Miraidon ex", "Basic", "", "", [], [], 2)
	miraidon_cd.energy_type = "L"
	miraidon_cd.mechanic = "ex"
	player.active_pokemon = _make_ai_slot(CardInstance.create(miraidon_cd, 0))
	var electric_basic_cd := _make_ai_pokemon_card_data("Shinx", "Basic")
	electric_basic_cd.energy_type = "L"
	var colorless_basic_cd := _make_ai_pokemon_card_data("Pidgey", "Basic")
	colorless_basic_cd.energy_type = "C"
	var electric_card := CardInstance.create(electric_basic_cd, 0)
	var colorless_card := CardInstance.create(colorless_basic_cd, 0)
	player.hand = [electric_card, colorless_card]
	var elec_action := {"kind": "play_basic_to_bench", "card": electric_card}
	var color_action := {"kind": "play_basic_to_bench", "card": colorless_card}
	var elec_ctx := _make_deck_bias_context(gsm, 0, elec_action)
	var color_ctx := _make_deck_bias_context(gsm, 0, color_action)
	var elec_score: float = heuristics.score_action(elec_action, elec_ctx)
	var color_score: float = heuristics.score_action(color_action, color_ctx)
	return run_checks([
		assert_true(
			elec_score > color_score,
			"Miraidon deck should prefer benching an Electric basic over a Colorless one (got elec=%s, color=%s)" % [elec_score, color_score]
		),
	])


func test_deck_bias_gardevoir_prefers_evolving_psychic_line() -> String:
	## Gardevoir 卡组应优先进化超能属性进化线
	var heuristics := AIHeuristicsScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	# 沙奈朵ex在手（Stage 2 信号卡）
	var gardevoir_cd := _make_ai_pokemon_card_data("沙奈朵ex", "Stage 2", "奇鲁莉安")
	gardevoir_cd.energy_type = "P"
	gardevoir_cd.mechanic = "ex"
	gardevoir_cd.abilities = [{"name": "精神拥抱", "text": ""}]
	var gardevoir_card := CardInstance.create(gardevoir_cd, 0)
	# 奇鲁莉安在场（可进化目标）
	var kirlia_cd := _make_ai_pokemon_card_data("奇鲁莉安", "Stage 1", "拉鲁拉丝")
	kirlia_cd.energy_type = "P"
	var kirlia_slot := _make_ai_slot(CardInstance.create(kirlia_cd, 0), 1)
	# 普通 Stage 1（无 Stage 2 配套）
	var pidgeotto_cd := _make_ai_pokemon_card_data("Pidgeotto", "Stage 1", "Pidgey")
	pidgeotto_cd.energy_type = "C"
	var pidgey_cd := _make_ai_pokemon_card_data("Pidgey", "Basic")
	pidgey_cd.energy_type = "C"
	var pidgey_slot := _make_ai_slot(CardInstance.create(pidgey_cd, 0), 1)
	var pidgeotto_card := CardInstance.create(pidgeotto_cd, 0)
	player.active_pokemon = kirlia_slot
	player.bench = [pidgey_slot]
	player.hand = [gardevoir_card, pidgeotto_card]
	# 进化 Kirlia -> Gardevoir ex 线
	var kirlia_evolve := {"kind": "evolve", "card": gardevoir_card, "target_slot": kirlia_slot}
	# 进化 Pidgey -> Pidgeotto 线
	var pidgey_evolve := {"kind": "evolve", "card": pidgeotto_card, "target_slot": pidgey_slot}
	var kirlia_ctx := _make_deck_bias_context(gsm, 0, kirlia_evolve)
	var pidgey_ctx := _make_deck_bias_context(gsm, 0, pidgey_evolve)
	var kirlia_score: float = heuristics.score_action(kirlia_evolve, kirlia_ctx)
	var pidgey_score: float = heuristics.score_action(pidgey_evolve, pidgey_ctx)
	return run_checks([
		assert_true(
			kirlia_score > pidgey_score,
			"Gardevoir deck should prefer evolving the Gardevoir ex line over an unrelated line (got kirlia=%s, pidgey=%s)" % [kirlia_score, pidgey_score]
		),
	])


func test_deck_bias_gardevoir_prefers_psychic_embrace_ability() -> String:
	## Gardevoir 卡组应高度优先使用 Psychic Embrace 特性
	var heuristics := AIHeuristicsScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var gardevoir_cd := _make_ai_pokemon_card_data(
		"沙奈朵ex", "Stage 2", "奇鲁莉安", "",
		[{"name": "精神拥抱", "text": ""}]
	)
	gardevoir_cd.energy_type = "P"
	gardevoir_cd.mechanic = "ex"
	var gardevoir_slot := _make_ai_slot(CardInstance.create(gardevoir_cd, 0))
	# 弃牌堆添加超能量燃料（Embrace 需要燃料才有价值）
	for _i: int in 3:
		var psychic_energy_cd := CardData.new()
		psychic_energy_cd.name = "Psychic Energy"
		psychic_energy_cd.card_type = "Basic Energy"
		psychic_energy_cd.energy_provides = "P"
		player.discard_pile.append(CardInstance.create(psychic_energy_cd, 0))
	# 攻击手目标（Embrace 贴能需要有效目标）
	var attacker_cd := _make_ai_pokemon_card_data("飘飘球", "Basic", "", "")
	attacker_cd.energy_type = "P"
	attacker_cd.hp = 70
	attacker_cd.attacks = [{"name": "Balloon Bomb", "cost": "PP", "damage": "0"}]
	var attacker_slot := _make_ai_slot(CardInstance.create(attacker_cd, 0))
	# 另一个有普通特性的宝可梦
	var generic_ability_cd := _make_ai_pokemon_card_data(
		"Bidoof", "Basic", "", "",
		[{"name": "Headbutt Stand", "text": ""}]
	)
	var bidoof_slot := _make_ai_slot(CardInstance.create(generic_ability_cd, 0))
	player.active_pokemon = gardevoir_slot
	player.bench = [bidoof_slot, attacker_slot]
	var psychic_action := {"kind": "use_ability", "source_slot": gardevoir_slot, "ability_index": 0}
	var generic_action := {"kind": "use_ability", "source_slot": bidoof_slot, "ability_index": 0}
	var psychic_ctx := _make_deck_bias_context(gsm, 0, psychic_action)
	var generic_ctx := _make_deck_bias_context(gsm, 0, generic_action)
	var psychic_score: float = heuristics.score_action(psychic_action, psychic_ctx)
	var generic_score: float = heuristics.score_action(generic_action, generic_ctx)
	return run_checks([
		assert_true(
			psychic_score > generic_score,
			"Gardevoir deck should score Psychic Embrace higher than a generic ability (got psychic=%s, generic=%s)" % [psychic_score, generic_score]
		),
	])


func test_deck_bias_charizard_prefers_rare_candy() -> String:
	## Charizard 卡组应优先使用 Rare Candy
	var heuristics := AIHeuristicsScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	# Charizard ex 在手（Stage 2 信号卡）
	var charizard_cd := _make_ai_pokemon_card_data("Charizard ex", "Stage 2", "Charmeleon")
	charizard_cd.energy_type = "R"
	charizard_cd.mechanic = "ex"
	var charizard_card := CardInstance.create(charizard_cd, 0)
	# Charmander 在场
	var charmander_cd := _make_ai_pokemon_card_data("Charmander", "Basic")
	charmander_cd.energy_type = "R"
	player.active_pokemon = _make_ai_slot(CardInstance.create(charmander_cd, 0))
	var rare_candy := CardInstance.create(
		_make_ai_trainer_card_data("Rare Candy", "Item", ""),
		0
	)
	var generic_item := CardInstance.create(
		_make_ai_trainer_card_data("Switch", "Item", ""),
		0
	)
	player.hand = [charizard_card, rare_candy, generic_item]
	var rc_action := {"kind": "play_trainer", "card": rare_candy, "productive": true}
	var gi_action := {"kind": "play_trainer", "card": generic_item, "productive": true}
	var rc_ctx := _make_deck_bias_context(gsm, 0, rc_action)
	var gi_ctx := _make_deck_bias_context(gsm, 0, gi_action)
	var rc_score: float = heuristics.score_action(rc_action, rc_ctx)
	var gi_score: float = heuristics.score_action(gi_action, gi_ctx)
	return run_checks([
		assert_true(
			rc_score > gi_score,
			"Charizard deck should score Rare Candy higher than a generic item (got rc=%s, gi=%s)" % [rc_score, gi_score]
		),
	])


func test_deck_bias_charizard_prefers_stage2_evolution_progress() -> String:
	## Charizard 卡组中 Charmander->Charmeleon 进化应获得额外加分
	var heuristics := AIHeuristicsScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var charizard_cd := _make_ai_pokemon_card_data("Charizard ex", "Stage 2", "Charmeleon")
	charizard_cd.energy_type = "R"
	charizard_cd.mechanic = "ex"
	var charizard_card := CardInstance.create(charizard_cd, 0)
	var charmander_cd := _make_ai_pokemon_card_data("Charmander", "Basic")
	charmander_cd.energy_type = "R"
	var charmander_slot := _make_ai_slot(CardInstance.create(charmander_cd, 0), 1)
	var charmeleon_cd := _make_ai_pokemon_card_data("Charmeleon", "Stage 1", "Charmander")
	charmeleon_cd.energy_type = "R"
	var charmeleon_card := CardInstance.create(charmeleon_cd, 0)
	# 对照：无关的进化线
	var pidgey_cd := _make_ai_pokemon_card_data("Pidgey", "Basic")
	pidgey_cd.energy_type = "C"
	var pidgey_slot := _make_ai_slot(CardInstance.create(pidgey_cd, 0), 1)
	var pidgeotto_cd := _make_ai_pokemon_card_data("Pidgeotto", "Stage 1", "Pidgey")
	pidgeotto_cd.energy_type = "C"
	var pidgeotto_card := CardInstance.create(pidgeotto_cd, 0)
	player.active_pokemon = charmander_slot
	player.bench = [pidgey_slot]
	player.hand = [charizard_card, charmeleon_card, pidgeotto_card]
	# 进化 Charmander -> Charmeleon（Charizard 线）
	var char_evolve := {"kind": "evolve", "card": charmeleon_card, "target_slot": charmander_slot}
	# 进化 Pidgey -> Pidgeotto（无关线）
	var pidg_evolve := {"kind": "evolve", "card": pidgeotto_card, "target_slot": pidgey_slot}
	var char_ctx := _make_deck_bias_context(gsm, 0, char_evolve)
	var pidg_ctx := _make_deck_bias_context(gsm, 0, pidg_evolve)
	var char_score: float = heuristics.score_action(char_evolve, char_ctx)
	var pidg_score: float = heuristics.score_action(pidg_evolve, pidg_ctx)
	return run_checks([
		assert_true(
			char_score > pidg_score,
			"Charizard deck should prefer evolving the Charizard line over an unrelated line (got char=%s, pidg=%s)" % [char_score, pidg_score]
		),
	])


func test_deck_bias_tags_are_recorded_in_reason_tags() -> String:
	## 卡组偏好加分应在 reason_tags 中留下记录
	var heuristics := AIHeuristicsScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var miraidon_cd := _make_ai_pokemon_card_data("Miraidon ex", "Basic", "", "", [], [], 2)
	miraidon_cd.energy_type = "L"
	miraidon_cd.mechanic = "ex"
	player.active_pokemon = _make_ai_slot(CardInstance.create(miraidon_cd, 0))
	var electric_basic_cd := _make_ai_pokemon_card_data("Shinx", "Basic")
	electric_basic_cd.energy_type = "L"
	var electric_card := CardInstance.create(electric_basic_cd, 0)
	player.hand = [electric_card]
	var elec_action := {"kind": "play_basic_to_bench", "card": electric_card}
	var elec_ctx := _make_deck_bias_context(gsm, 0, elec_action)
	heuristics.score_action(elec_action, elec_ctx)
	var tags: Array = elec_action.get("reason_tags", [])
	return run_checks([
		assert_true(
			tags.has("deck_bias"),
			"Deck bias adjustments should record a 'deck_bias' reason tag (got tags=%s)" % [str(tags)]
		),
	])


# -- MCTS 集成测试 --


func test_ai_opponent_mcts_mode_disabled_by_default() -> String:
	var ai := AIOpponentScript.new()
	return run_checks([
		assert_false(ai.use_mcts, "MCTS mode should be disabled by default"),
	])


func test_ai_opponent_mcts_mode_executes_multi_step_sequence() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.use_mcts = true
	ai.mcts_config = {
		"branch_factor": 2,
		"rollouts_per_sequence": 3,
		"rollout_max_steps": 20,
	}
	var scene := SpyInteractiveActionBattleScene.new()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	var player: PlayerState = gsm.game_state.players[1]
	var opponent: PlayerState = gsm.game_state.players[0]

	var attacker_cd := _make_ai_pokemon_card_data(
		"Attacker", "Basic", "", "", [],
		[{"name": "Zap", "cost": "C", "damage": "40", "text": "", "is_vstar_power": false}]
	)
	player.active_pokemon = _make_ai_slot(CardInstance.create(attacker_cd, 1))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Energy"), 1))
	var bench_basic := CardInstance.create(_make_ai_pokemon_card_data("Bench Mon"), 1)
	player.hand = [bench_basic]
	opponent.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Defender"), 0))

	for _i in 6:
		player.prizes.append(CardInstance.create(_make_ai_pokemon_card_data("Prize"), 1))
		opponent.prizes.append(CardInstance.create(_make_ai_pokemon_card_data("Prize"), 0))
	for _i in 10:
		player.deck.append(CardInstance.create(_make_ai_pokemon_card_data("Deck"), 1))
		opponent.deck.append(CardInstance.create(_make_ai_pokemon_card_data("Deck"), 0))

	var step_count: int = 0
	while step_count < 10:
		var handled := ai.run_single_step(scene, gsm)
		if not handled:
			break
		step_count += 1
		if gsm.game_state.phase != GameState.GamePhase.MAIN or gsm.game_state.current_player_index != 1:
			break

	return run_checks([
		assert_true(step_count >= 2, "MCTS mode should execute a multi-step sequence, got %d steps" % step_count),
	])
func _battle_scene_ai_version_test_base_dir() -> String:
	return "user://battle_scene_ai_versions_test"


func _battle_scene_remove_dir_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var child_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_battle_scene_remove_dir_recursive(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _cleanup_battle_scene_ai_version_test_dir() -> void:
	var dir_path := ProjectSettings.globalize_path(_battle_scene_ai_version_test_base_dir())
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	_battle_scene_remove_dir_recursive(dir_path)
	DirAccess.remove_absolute(dir_path)


func _write_battle_scene_test_json(path: String, data: Dictionary) -> void:
	var dir_path := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()


func test_battle_scene_uses_default_ai_selection_when_no_version_is_set() -> String:
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	GameManager.reset_ai_selection()
	GameManager.selected_deck_ids = [575716, 575720]
	var scene := _make_setup_ready_battle_scene()
	scene.call("_ensure_ai_opponent")
	var ai = scene.get("_ai_opponent")
	var selection: Dictionary = GameManager.ai_selection.duplicate(true)
	GameManager.ai_selection = previous_ai_selection
	GameManager.selected_deck_ids = previous_selected_deck_ids
	return run_checks([
		assert_true(ai != null, "BattleScene should create a default AI opponent"),
		assert_eq(str(selection.get("source", "")), "default", "GameManager default source should remain default"),
		assert_eq(str(ai.get_meta("ai_source", "")), "default", "Default AI should mark its source as default"),
	])


func test_battle_scene_default_ai_resolves_selected_ai_deck_strategy() -> String:
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_ai_strategy := GameManager.ai_deck_strategy
	GameManager.reset_ai_selection()
	GameManager.ai_deck_strategy = "generic"
	GameManager.selected_deck_ids = [575716, 575720]
	var scene := _make_setup_ready_battle_scene()
	scene.call("_ensure_ai_opponent")
	var ai = scene.get("_ai_opponent")
	var strategy_id := ""
	if ai != null and ai.get("_deck_strategy") != null and ai.get("_deck_strategy").has_method("get_strategy_id"):
		strategy_id = str(ai.get("_deck_strategy").call("get_strategy_id"))
	GameManager.ai_selection = previous_ai_selection
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.ai_deck_strategy = previous_ai_strategy
	return run_checks([
		assert_true(ai != null, "BattleScene should create an AI opponent for the selected AI deck"),
		assert_eq(strategy_id, "miraidon", "Default AI should resolve the selected AI deck through the unified deck strategy registry"),
	])


func _battle_scene_runtime_log_path() -> String:
	return "user://logs/battle_runtime.log"


func _cleanup_battle_scene_runtime_log() -> void:
	var log_path := ProjectSettings.globalize_path(_battle_scene_runtime_log_path())
	if FileAccess.file_exists(_battle_scene_runtime_log_path()) or FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)


func _read_battle_scene_runtime_log() -> String:
	var log_path := _battle_scene_runtime_log_path()
	if not FileAccess.file_exists(log_path) and not FileAccess.file_exists(ProjectSettings.globalize_path(log_path)):
		return ""
	var file := FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func test_battle_scene_loads_latest_training_ai_version_through_setup_prompt_and_logs_selection() -> String:
	_cleanup_battle_scene_ai_version_test_dir()
	_cleanup_battle_scene_runtime_log()
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_mode: int = GameManager.current_mode
	var registry_script: Variant = load("res://scripts/ai/AIVersionRegistry.gd")
	var registry = registry_script.new()
	registry.base_dir = _battle_scene_ai_version_test_base_dir().path_join("versions")
	var older_agent_config_path := _battle_scene_ai_version_test_base_dir().path_join("older_agent_config.json")
	var latest_agent_config_path := _battle_scene_ai_version_test_base_dir().path_join("latest_agent_config.json")
	var latest_value_net_path := _battle_scene_ai_version_test_base_dir().path_join("latest_value_net.json")
	var latest_action_scorer_path := _battle_scene_ai_version_test_base_dir().path_join("latest_action_scorer.json")
	_write_battle_scene_test_json(older_agent_config_path, {
		"heuristic_weights": {"aggression": 0.5},
		"mcts_config": {
			"branch_factor": 3,
			"rollouts_per_sequence": 4,
			"rollout_max_steps": 25,
			"time_budget_ms": 700,
		},
	})
	_write_battle_scene_test_json(latest_agent_config_path, {
		"heuristic_weights": {"aggression": 1.75},
		"mcts_config": {
			"branch_factor": 5,
			"rollouts_per_sequence": 9,
			"rollout_max_steps": 45,
			"time_budget_ms": 1100,
		},
	})
	_write_battle_scene_test_json(latest_value_net_path, {"weights": []})
	_write_battle_scene_test_json(latest_action_scorer_path, {"layers": []})
	registry.save_version({
		"version_id": "AI-20260328-03",
		"display_name": "older playable",
		"status": "playable",
		"agent_config_path": older_agent_config_path,
		"value_net_path": "",
	})
	registry.save_version({
		"version_id": "AI-20260328-04",
		"display_name": "latest playable",
		"status": "playable",
		"agent_config_path": latest_agent_config_path,
		"value_net_path": latest_value_net_path,
		"action_scorer_path": latest_action_scorer_path,
	})
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.ai_selection = {
		"source": "latest_trained",
		"version_id": "",
		"agent_config_path": "",
		"value_net_path": "",
		"display_name": "",
	}
	var scene := _make_setup_ready_battle_scene()
	scene.call("set_ai_version_registry_for_test", registry)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.hand = [_make_basic("Latest Lead"), _make_basic("Latest Bench"), _make_item("Ball")]
	scene.set("_gsm", gsm)
	scene.call("_init_battle_runtime_log")
	scene._show_setup_active_dialog(1)
	var ai = scene.get("_ai_opponent")
	var scheduled_after_prompt: bool = bool(scene.get("_ai_step_scheduled"))
	var dialog_visible_after_prompt: bool = bool(scene.get("_dialog_overlay").visible)
	var runtime_log := _read_battle_scene_runtime_log()
	GameManager.ai_selection = previous_ai_selection
	GameManager.current_mode = previous_mode
	_cleanup_battle_scene_ai_version_test_dir()
	_cleanup_battle_scene_runtime_log()
	return run_checks([
		assert_true(ai != null, "BattleScene should create an AI opponent for latest_trained selection"),
		assert_false(dialog_visible_after_prompt, "AI-owned setup prompt should stay hidden when latest_trained is selected"),
		assert_true(scheduled_after_prompt, "BattleScene should schedule the AI through the real setup prompt path"),
		assert_eq(str(ai.get_meta("ai_source", "")), "latest_trained", "Loaded AI should record latest_trained source"),
		assert_eq(str(ai.get_meta("ai_version_id", "")), "AI-20260328-04", "Latest playable version should be selected through the registry"),
		assert_eq(str(ai.get_meta("ai_display_name", "")), "latest playable", "Loaded AI should record the latest version display name"),
		assert_eq(str(ai.value_net_path), latest_value_net_path, "Loaded AI should use the latest playable value net"),
		assert_eq(str(ai.action_scorer_path), latest_action_scorer_path, "Loaded AI should use the latest playable action scorer"),
		assert_eq(float(ai.heuristic_weights.get("aggression", 0.0)), 1.75, "Loaded AI should apply heuristic weights from the latest playable config"),
		assert_eq(int(ai.mcts_config.get("branch_factor", 0)), 5, "Loaded AI should apply MCTS config from the latest playable config"),
		assert_str_contains(runtime_log, "ai_loaded", "Battle runtime log should record ai_loaded when the AI is created"),
		assert_str_contains(runtime_log, "source=latest_trained", "Battle runtime log should include the selected AI source"),
		assert_str_contains(runtime_log, "version=AI-20260328-04", "Battle runtime log should include the selected AI version id"),
		assert_str_contains(runtime_log, "display=latest playable", "Battle runtime log should include the AI display name"),
	])


func test_battle_scene_loads_specific_training_ai_version() -> String:
	_cleanup_battle_scene_ai_version_test_dir()
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var registry_script: Variant = load("res://scripts/ai/AIVersionRegistry.gd")
	var registry = registry_script.new()
	registry.base_dir = _battle_scene_ai_version_test_base_dir().path_join("versions")
	var agent_config_path := _battle_scene_ai_version_test_base_dir().path_join("agent_config.json")
	var value_net_path := _battle_scene_ai_version_test_base_dir().path_join("value_net.json")
	var action_scorer_path := _battle_scene_ai_version_test_base_dir().path_join("action_scorer.json")
	_write_battle_scene_test_json(agent_config_path, {
		"heuristic_weights": {"aggression": 1.25},
		"mcts_config": {
			"branch_factor": 4,
			"rollouts_per_sequence": 8,
			"rollout_max_steps": 40,
			"time_budget_ms": 900,
		},
	})
	_write_battle_scene_test_json(value_net_path, {"weights": []})
	_write_battle_scene_test_json(action_scorer_path, {"layers": []})
	registry.save_version({
		"version_id": "AI-20260328-01",
		"display_name": "v015 + value1",
		"status": "playable",
		"agent_config_path": agent_config_path,
		"value_net_path": value_net_path,
		"action_scorer_path": action_scorer_path,
	})
	GameManager.ai_selection = {
		"source": "specific_version",
		"version_id": "AI-20260328-01",
		"agent_config_path": agent_config_path,
		"value_net_path": value_net_path,
		"display_name": "v015 + value1",
	}
	GameManager.selected_deck_ids = [575716, 575720]
	var scene := _make_setup_ready_battle_scene()
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_ensure_ai_opponent")
	var ai = scene.get("_ai_opponent")
	GameManager.ai_selection = previous_ai_selection
	GameManager.selected_deck_ids = previous_selected_deck_ids
	_cleanup_battle_scene_ai_version_test_dir()
	return run_checks([
		assert_true(ai != null, "BattleScene should create an AI opponent for a specific version"),
		assert_eq(str(ai.get_meta("ai_source", "")), "specific_version", "Loaded AI should record specific_version source"),
		assert_eq(str(ai.get_meta("ai_version_id", "")), "AI-20260328-01", "Loaded AI should record the selected version id"),
		assert_eq(str(ai.value_net_path), value_net_path, "Loaded AI should use the version's value net"),
		assert_eq(str(ai.action_scorer_path), action_scorer_path, "Loaded AI should use the version's action scorer"),
		assert_eq(float(ai.heuristic_weights.get("aggression", 0.0)), 1.25, "Loaded AI should apply heuristic weights from agent config"),
		assert_eq(int(ai.mcts_config.get("branch_factor", 0)), 4, "Loaded AI should apply MCTS config from agent config"),
	])


func test_battle_scene_rejects_incompatible_training_version_for_selected_ai_deck() -> String:
	_cleanup_battle_scene_ai_version_test_dir()
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var registry_script: Variant = load("res://scripts/ai/AIVersionRegistry.gd")
	var registry = registry_script.new()
	registry.base_dir = _battle_scene_ai_version_test_base_dir().path_join("versions")
	var agent_config_path := _battle_scene_ai_version_test_base_dir().path_join("agent_config.json")
	_write_battle_scene_test_json(agent_config_path, {
		"heuristic_weights": {"aggression": 1.25},
	})
	registry.save_version({
		"version_id": "AI-20260328-09",
		"display_name": "gardevoir-only build",
		"status": "playable",
		"agent_config_path": agent_config_path,
		"value_net_path": "",
		"compatible_strategy_id": "gardevoir",
	})
	GameManager.ai_selection = {
		"source": "specific_version",
		"version_id": "AI-20260328-09",
		"agent_config_path": agent_config_path,
		"value_net_path": "",
		"display_name": "gardevoir-only build",
	}
	GameManager.selected_deck_ids = [575716, 575720]
	var scene := _make_setup_ready_battle_scene()
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_ensure_ai_opponent")
	var ai = scene.get("_ai_opponent")
	var strategy_id := ""
	if ai != null and ai.get("_deck_strategy") != null and ai.get("_deck_strategy").has_method("get_strategy_id"):
		strategy_id = str(ai.get("_deck_strategy").call("get_strategy_id"))
	GameManager.ai_selection = previous_ai_selection
	GameManager.selected_deck_ids = previous_selected_deck_ids
	_cleanup_battle_scene_ai_version_test_dir()
	return run_checks([
		assert_true(ai != null, "BattleScene should still produce an AI when an incompatible training version is selected"),
		assert_eq(str(ai.get_meta("ai_source", "")), "default", "Incompatible training versions should fall back to the selected deck's default AI"),
		assert_eq(strategy_id, "miraidon", "Fallback should still use the selected AI deck's unified strategy"),
	])


func test_battle_scene_falls_back_to_default_when_training_version_file_is_missing() -> String:
	_cleanup_battle_scene_ai_version_test_dir()
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var registry_script: Variant = load("res://scripts/ai/AIVersionRegistry.gd")
	var registry = registry_script.new()
	registry.base_dir = _battle_scene_ai_version_test_base_dir().path_join("versions")
	registry.save_version({
		"version_id": "AI-20260328-02",
		"display_name": "broken version",
		"status": "playable",
		"agent_config_path": _battle_scene_ai_version_test_base_dir().path_join("missing_agent.json"),
		"value_net_path": "",
	})
	GameManager.ai_selection = {
		"source": "specific_version",
		"version_id": "AI-20260328-02",
		"agent_config_path": _battle_scene_ai_version_test_base_dir().path_join("missing_agent.json"),
		"value_net_path": "",
		"display_name": "broken version",
	}
	var scene := _make_setup_ready_battle_scene()
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_ensure_ai_opponent")
	var ai = scene.get("_ai_opponent")
	GameManager.ai_selection = previous_ai_selection
	_cleanup_battle_scene_ai_version_test_dir()
	return run_checks([
		assert_true(ai != null, "BattleScene should still produce an AI opponent when the training version is broken"),
		assert_eq(str(ai.get_meta("ai_source", "")), "default", "Broken training version should fall back to default AI"),
		assert_eq(str(ai.value_net_path), "", "Fallback AI should not keep a missing value net path"),
		assert_eq(int(ai.mcts_config.get("branch_factor", 0)), 2, "Fallback AI should restore default MCTS config"),
	])


# ============================================================
#  MCTS + 策略评估混合模式测试
# ============================================================

func test_ai_opponent_mcts_strategy_hybrid_priority() -> String:
	## MCTS + 策略评估模式下，_choose_best_action 应走 MCTS 路径
	var ai := AIOpponentScript.new()
	ai.configure(0, 1)
	var strategy := preload("res://scripts/ai/DeckStrategyGardevoir.gd").new()
	ai._deck_strategy = strategy
	ai._deck_strategy_detected = true
	ai.use_mcts = true
	ai._mcts_planner.deck_strategy = strategy
	ai.mcts_config = strategy.get_mcts_config()
	# 构造最小游戏状态
	var gs := GameState.new()
	gs.turn_number = 3
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var p := PlayerState.new()
		p.player_index = pi
		var slot := PokemonSlot.new()
		var cd := CardData.new()
		cd.name = "Active%d" % pi
		cd.card_type = "Pokemon"
		cd.stage = "Basic"
		cd.hp = 100
		slot.pokemon_stack.append(CardInstance.create(cd, pi))
		slot.turn_played = 0
		p.active_pokemon = slot
		gs.players.append(p)
	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	# MCTS planner 应使用策略评估（deck_strategy 已设置）
	return run_checks([
		assert_true(ai._mcts_planner.deck_strategy != null, "MCTS planner 应有 deck_strategy"),
		assert_eq(int(ai.mcts_config.get("rollouts_per_sequence", -1)), 0, "MCTS 配置应 rollouts=0"),
		assert_true(ai.use_mcts, "AI 应启用 MCTS"),
		assert_true(ai._deck_strategy != null, "AI 应有 deck_strategy"),
	])
