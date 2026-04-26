class_name TestBattleDisplayController
extends TestBase

const BattleDisplayControllerScript = preload("res://scripts/ui/battle/BattleDisplayController.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


class RefreshHandSceneStub extends Control:
	var _gsm: GameStateMachine = null
	var _draw_reveal_active: bool = false
	var _draw_reveal_allow_hand_refresh_during_fly: bool = false
	var _draw_reveal_pending_hand_refresh: bool = false
	var _draw_reveal_current_action: GameAction = null
	var _draw_reveal_visible_instance_ids: Array[int] = []
	var _draw_reveal_queue: Array = []
	var _hand_container: HBoxContainer = HBoxContainer.new()
	var _view_player: int = 0
	var _latest_opponent_action_text: String = ""
	var _latest_opponent_action_turn_number: int = -1
	var _selected_hand_card: CardInstance = null
	var _play_card_size: Vector2 = Vector2(130, 182)

	func _init() -> void:
		add_child(_hand_container)

	func _bt(key: String, params: Dictionary = {}) -> String:
		return BattleI18n.t(key, params)


func _make_refresh_hand_scene_stub(current_player: int, turn_number: int) -> RefreshHandSceneStub:
	var scene := RefreshHandSceneStub.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = current_player
	gsm.game_state.turn_number = turn_number
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	scene._gsm = gsm
	return scene


func _u(codepoints: Array[int]) -> String:
	var text := ""
	for codepoint: int in codepoints:
		text += char(codepoint)
	return text


func test_get_selected_deck_name_falls_back_to_unknown_label() -> String:
	var controller := BattleDisplayControllerScript.new()
	var original_ids: Array = GameManager.selected_deck_ids.duplicate()
	GameManager.selected_deck_ids.clear()
	var result := str(controller.call("get_selected_deck_name", 0))
	GameManager.selected_deck_ids = original_ids.duplicate()

	return run_checks([
		assert_eq(result, _u([0x672A, 0x77E5, 0x724C, 0x7EC4]), "Missing deck selections should fall back to the unknown deck label"),
	])


func test_get_selected_deck_name_uses_dedicated_ai_deck_in_vs_ai_mode() -> String:
	var controller := BattleDisplayControllerScript.new()
	var original_ids: Array = GameManager.selected_deck_ids.duplicate()
	var original_mode: int = GameManager.current_mode
	var test_deck_id := 990002

	var normal_deck := DeckData.new()
	normal_deck.id = test_deck_id
	normal_deck.deck_name = "Normal Slot 2"
	normal_deck.total_cards = 60
	var ai_deck := DeckData.new()
	ai_deck.id = test_deck_id
	ai_deck.deck_name = "AI Slot 2"
	ai_deck.total_cards = 60

	CardDatabase.save_deck(normal_deck)
	CardDatabase.save_ai_deck(ai_deck)
	GameManager.selected_deck_ids = [123, test_deck_id]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var result := str(controller.call("get_selected_deck_name", 1))
	GameManager.selected_deck_ids = original_ids.duplicate()
	GameManager.current_mode = original_mode
	CardDatabase.delete_deck(test_deck_id)
	CardDatabase.delete_ai_deck(test_deck_id)

	return run_checks([
		assert_eq(result, "AI Slot 2", "Battle display should show the dedicated AI deck name for player 2 in VS_AI mode"),
	])


func test_get_display_player_name_prefers_tournament_names() -> String:
	var controller := BattleDisplayControllerScript.new()
	var previous_names := GameManager.battle_player_display_names.duplicate()
	var previous_mode := GameManager.current_mode
	var previous_selection := GameManager.ai_selection.duplicate(true)

	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.ai_selection["display_name"] = "系统AI"
	GameManager.set_battle_player_display_names(["小林", "青木"])
	var player_name := str(controller.call("get_display_player_name", 0))
	var opponent_name := str(controller.call("get_display_player_name", 1))

	GameManager.battle_player_display_names = previous_names
	GameManager.current_mode = previous_mode
	GameManager.ai_selection = previous_selection

	return run_checks([
		assert_eq(player_name, "小林", "Battle display should use the explicit player tournament name for player 1"),
		assert_eq(opponent_name, "青木", "Battle display should use the explicit player tournament name for player 2"),
	])
	

func test_battle_scene_formats_action_log_with_display_names() -> String:
	var scene := BattleSceneScript.new()
	var previous_names := GameManager.battle_player_display_names.duplicate()
	GameManager.set_battle_player_display_names(["小林", "青木"])
	var rendered := str(scene.call("_format_action_description_for_display", "第3回合开始，玩家1行动；玩家2抽1张牌"))
	GameManager.battle_player_display_names = previous_names

	return run_checks([
		assert_true(rendered.find("小林") >= 0, "BattleScene should replace 玩家1 with the player display name in battle logs"),
		assert_true(rendered.find("青木") >= 0, "BattleScene should replace 玩家2 with the opponent display name in battle logs"),
		assert_true(rendered.find("玩家1") < 0 and rendered.find("玩家2") < 0, "BattleScene display log text should not keep numeric default player labels when tournament names are available"),
	])


func test_hand_card_subtext_formats_basic_energy() -> String:
	var controller := BattleDisplayControllerScript.new()
	var card_data := CardData.new()
	card_data.card_type = "Basic Energy"
	card_data.energy_provides = "W"
	var result := str(controller.call("hand_card_subtext", card_data))

	return run_checks([
		assert_eq(result, _u([0x57FA, 0x672C, 0x80FD, 0x91CF, 0x20, 0x2F, 0x20, 0x6C34]), "Basic Energy subtext should show the localized energy type"),
	])


func test_clear_container_children_removes_existing_nodes() -> String:
	var controller := BattleDisplayControllerScript.new()
	var container := HBoxContainer.new()
	container.add_child(Label.new())
	container.add_child(Button.new())

	controller.call("clear_container_children", container)

	return run_checks([
		assert_eq(container.get_child_count(), 0, "clear_container_children should empty the target container"),
	])


func test_refresh_hand_shows_latest_opponent_action_text_during_opponent_turn() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(1, 7)
	scene._latest_opponent_action_text = "玩家2使用了老大的指令"
	scene._latest_opponent_action_turn_number = 7

	controller.call("refresh_hand", scene)

	var hand_container: HBoxContainer = scene._hand_container
	var label := hand_container.get_child(0) as Label
	return run_checks([
		assert_eq(hand_container.get_child_count(), 1, "Opponent turns should still render a single status label in the hand area"),
		assert_eq(label.text, "玩家2使用了老大的指令", "The hand-area waiting label should mirror the latest opponent action text for the current turn"),
	])


func test_refresh_hand_falls_back_to_waiting_text_when_opponent_has_no_current_turn_action() -> String:
	var controller := BattleDisplayControllerScript.new()
	var scene := _make_refresh_hand_scene_stub(1, 8)
	scene._latest_opponent_action_text = "玩家2使用了老大的指令"
	scene._latest_opponent_action_turn_number = 7

	controller.call("refresh_hand", scene)

	var hand_container: HBoxContainer = scene._hand_container
	var label := hand_container.get_child(0) as Label
	return run_checks([
		assert_eq(label.text, BattleI18n.t("battle.hand.waiting"), "The hand area should fall back to the waiting copy before the opponent logs a new action this turn"),
	])
