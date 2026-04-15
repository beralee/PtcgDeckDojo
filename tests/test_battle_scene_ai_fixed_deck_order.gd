class_name TestBattleSceneAIFixedDeckOrder
extends TestBase

const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


class SpyFixedOrderGameStateMachine extends GameStateMachine:
	var override_player_index: int = -1
	var override_cards: Array[Dictionary] = []

	func set_deck_order_override(player_index: int, top_to_bottom: Array[Dictionary]) -> void:
		override_player_index = player_index
		override_cards = top_to_bottom.duplicate(true)
		super.set_deck_order_override(player_index, top_to_bottom)


class FixedOrderBattleSceneStub extends BattleSceneScript:
	var spy_gsm: SpyFixedOrderGameStateMachine = SpyFixedOrderGameStateMachine.new()
	var runtime_events: Array[String] = []

	func _build_game_state_machine() -> GameStateMachine:
		return spy_gsm

	func _ensure_battle_recording_started() -> void:
		pass

	func _capture_battle_recording_context_if_ready() -> void:
		pass

	func _runtime_log(event: String, detail: String = "") -> void:
		runtime_events.append("%s:%s" % [event, detail])


func test_battle_scene_applies_fixed_order_override_for_strong_ai_mode() -> String:
	var previous_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids = [575716, 575720]
	GameManager.first_player_choice = 0
	GameManager.ai_selection = {
		"source": "default",
		"version_id": "",
		"agent_config_path": "",
		"value_net_path": "",
		"action_scorer_path": "",
		"interaction_scorer_path": "",
		"display_name": "",
		"opening_mode": "fixed_order",
		"fixed_deck_order_path": "res://data/bundled_user/ai_fixed_deck_orders/575720.json",
	}

	var scene := FixedOrderBattleSceneStub.new()
	scene.call("_start_battle")

	var override_player_index := scene.spy_gsm.override_player_index
	var override_cards := scene.spy_gsm.override_cards.duplicate(true)

	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_eq(override_player_index, 1, "Strong AI mode should inject the fixed order into the AI player deck"),
		assert_eq(override_cards.size(), 13, "Strong Miraidon mode should load the bundled fixed order sample"),
		assert_eq(str(override_cards[0].get("set_code", "")), "151C", "The first fixed-order card should match the configured top card"),
		assert_eq(str(override_cards[0].get("card_index", "")), "151", "The first fixed-order card index should match the configured top card"),
	])
