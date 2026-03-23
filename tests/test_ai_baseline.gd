class_name TestAIBaseline
extends TestBase

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AISetupPlannerScript = preload("res://scripts/ai/AISetupPlanner.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


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


func _make_battle_scene_refresh_stub() -> Control:
	var battle_scene = BattleSceneScript.new()
	battle_scene.set("_log_list", ItemList.new())
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
	battle_scene.set("_coin_overlay", Panel.new())
	battle_scene.set("_detail_overlay", Panel.new())
	battle_scene.set("_discard_overlay", Panel.new())
	battle_scene.set("_field_interaction_overlay", Control.new())
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
		assert_eq(ai.player_index, 1, "AIOpponent should default to player_index 1"),
		assert_eq(ai.difficulty, 1, "AIOpponent should default to difficulty 1"),
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
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(scene.get("_dialog_overlay").visible, "Setup active prompt should show the dialog overlay"),
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
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(scene.get("_dialog_overlay").visible, "Setup bench prompt should show the dialog overlay"),
		assert_true(scheduled_after_prompt, "BattleScene should schedule AI for setup_bench prompts owned by the AI"),
		assert_eq(player.bench.size(), 1, "AI should place a bench Pokemon through BattleScene scheduling"),
		assert_eq(player.bench[0].get_pokemon_name(), "Bench A", "AI should choose the available Basic for bench"),
	])


func test_battle_scene_schedules_ai_in_vs_ai_when_unblocked() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
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
		assert_eq(gsm.retreat_calls, 1, "Retreat action path should call GameStateMachine.retreat"),
		assert_true(scheduled_after_retreat, "Successful retreat action path should schedule the AI"),
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


func test_battle_scene_take_prize_prompt_blocks_ai_scheduling() -> String:
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
		assert_false(scheduled_during_prize_choice, "AI should not schedule while prize selection is pending"),
		assert_eq(spy_ai.run_count, 0, "Prize prompt should not run the AI"),
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
