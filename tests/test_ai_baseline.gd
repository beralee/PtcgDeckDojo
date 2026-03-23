class_name TestAIBaseline
extends TestBase

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
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

	func retreat(_player_index: int, _energy_to_discard: Array[CardInstance], _bench_target: PokemonSlot) -> bool:
		retreat_calls += 1
		return retreat_result


func _make_player_state(player_index: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = player_index
	return player


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
