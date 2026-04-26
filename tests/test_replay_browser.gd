class_name TestReplayBrowser
extends TestBase


class FakeRecordIndex extends RefCounted:
	func list_rows() -> Array[Dictionary]:
		return [{
			"match_id": "match_new",
			"match_dir": "user://match_records/match_new",
			"recorded_at": "2026-04-04 13:00",
			"player_labels": ["Player A", "Player B"],
			"winner_index": 1,
			"first_player_index": 0,
			"turn_count": 9,
			"final_prize_counts": [2, 0],
		}]


class FakeReplayLocator extends RefCounted:
	var _result: Dictionary = {}

	func _init(result: Dictionary) -> void:
		_result = result.duplicate(true)

	func locate(_match_dir: String) -> Dictionary:
		return _result.duplicate(true)


func test_replay_browser_and_ai_settings_use_hud_panels() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var replay_scene: Control = load("res://scenes/replay_browser/ReplayBrowser.tscn").instantiate()
	var settings_scene: Control = load("res://scenes/settings/Settings.tscn").instantiate()
	tree.root.add_child(replay_scene)
	tree.root.add_child(settings_scene)
	replay_scene.call("_apply_hud_theme")
	settings_scene.call("_apply_hud_theme")

	var replay_frame := replay_scene.get_node_or_null("HudFrame") as PanelContainer
	var settings_frame := settings_scene.get_node_or_null("HudFrame") as PanelContainer
	var replay_style := replay_frame.get_theme_stylebox("panel") as StyleBoxFlat if replay_frame != null else null
	var settings_style := settings_frame.get_theme_stylebox("panel") as StyleBoxFlat if settings_frame != null else null
	var settings_endpoint := settings_scene.get_node_or_null("%EndpointInput") as LineEdit
	var settings_save := settings_scene.get_node_or_null("%BtnSave") as Button
	var settings_form := settings_scene.get_node_or_null("VBoxContainer") as Control
	var endpoint_style := settings_endpoint.get_theme_stylebox("normal") as StyleBoxFlat if settings_endpoint != null else null
	var save_style := settings_save.get_theme_stylebox("normal") as StyleBoxFlat if settings_save != null else null

	var result := run_checks([
		assert_true(replay_style != null and replay_style.bg_color.a < 0.9, "Replay browser should use a translucent HUD frame"),
		assert_true(settings_style != null and settings_style.bg_color.a < 0.9, "AI settings should use a translucent HUD frame"),
		assert_true(settings_frame != null and settings_form != null and settings_frame.offset_bottom > settings_form.offset_bottom + 50.0, "AI settings HUD frame should extend below the button row"),
		assert_true(endpoint_style != null and endpoint_style.bg_color.a < 1.0, "AI settings inputs should use translucent HUD styling"),
		assert_true(save_style != null and save_style.border_color.a > 0.8, "AI settings buttons should use explicit HUD borders"),
	])

	replay_scene.queue_free()
	settings_scene.queue_free()
	return result


func test_main_menu_includes_battle_replay_button() -> String:
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	var replay_button := scene.get_node_or_null("VBoxContainer/BtnBattleReplay")

	return run_checks([
		assert_true(replay_button is Button, "MainMenu should expose BtnBattleReplay"),
	])


func test_main_menu_uses_hud_buttons_shifted_down() -> String:
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	scene.call("_apply_main_menu_hud")
	var menu := scene.get_node_or_null("VBoxContainer") as VBoxContainer
	var start_button := scene.get_node_or_null("%BtnStartBattle") as Button
	var button_style := start_button.get_theme_stylebox("normal") as StyleBoxFlat if start_button != null else null

	var result := run_checks([
		assert_true(menu != null and absf(menu.offset_top - -135.0) < 0.1, "Main menu button group should sit 50px higher than the previous HUD position"),
		assert_true(menu != null and absf(menu.offset_bottom - 215.0) < 0.1, "Main menu button group bottom should move with the top"),
		assert_true(button_style != null and button_style.bg_color.a < 0.9 and button_style.border_color.a > 0.5, "Main menu buttons should use softer translucent HUD button styling"),
		assert_eq(start_button.custom_minimum_size, Vector2(280, 48), "Main menu HUD buttons should be wider and taller than the old default buttons"),
	])

	scene.queue_free()
	return result


func test_replay_browser_renders_rows_from_record_index() -> String:
	var scene: Control = load("res://scenes/replay_browser/ReplayBrowser.tscn").instantiate()
	scene.set("_record_index", FakeRecordIndex.new())
	scene.set("_replay_locator", FakeReplayLocator.new({"entry_turn_number": 6, "entry_source": "loser_key_turn", "turn_numbers": [4, 6]}))
	scene.call("_render_rows")
	var list_container := scene.find_child("ListContainer", true, false) as VBoxContainer
	var first_row := list_container.get_child(0) if list_container != null and list_container.get_child_count() > 0 else null
	var replay_button := first_row.find_child("ReplayButton", true, false) if first_row != null else null
	var delete_button := first_row.find_child("DeleteButton", true, false) if first_row != null else null

	# 收集行内所有 Label 的文本
	var all_text := ""
	if first_row != null:
		for label: Node in _find_labels_recursive(first_row):
			all_text += (label as Label).text + " "

	return run_checks([
		assert_true(list_container != null, "ReplayBrowser should expose ListContainer"),
		assert_eq(list_container.get_child_count(), 1, "ReplayBrowser should render one row for the fake index"),
		assert_true(replay_button is Button, "ReplayBrowser rows should include a Replay button"),
		assert_false((replay_button as Button).disabled, "Replay button should be enabled once locator support is wired"),
		assert_true(delete_button is Button, "ReplayBrowser rows should include a Delete button"),
		assert_true(all_text.contains("Player A"), "Replay rows should include player names"),
		assert_true(all_text.contains("Player B"), "Replay rows should include player names"),
		assert_true(all_text.contains("2026-04-04"), "Replay rows should include the recorded time"),
		assert_true(all_text.contains("2-0"), "Replay rows should include the final prize count"),
	])


func test_replay_browser_launches_battle_scene_with_locator_output() -> String:
	GameManager.consume_battle_replay_launch()
	var scene: Control = load("res://scenes/replay_browser/ReplayBrowser.tscn").instantiate()
	scene.set("_auto_navigate_to_battle", false)
	scene.set("_record_index", FakeRecordIndex.new())
	scene.set("_replay_locator", FakeReplayLocator.new({
		"entry_turn_number": 6,
		"entry_source": "loser_key_turn",
		"turn_numbers": [4, 6],
	}))
	scene.call("_on_replay_pressed", {"match_dir": "user://match_records/match_a"})
	var launch: Dictionary = GameManager.consume_battle_replay_launch()

	return run_checks([
		assert_eq(str(launch.get("match_dir", "")), "user://match_records/match_a", "Replay launch should preserve match_dir"),
		assert_eq(int(launch.get("entry_turn_number", 0)), 6, "Replay button should forward locator output into GameManager launch state"),
		assert_eq(str(launch.get("entry_source", "")), "loser_key_turn", "Replay button should preserve the locator source"),
	])


func _find_labels_recursive(node: Node) -> Array[Node]:
	var labels: Array[Node] = []
	if node is Label:
		labels.append(node)
	for child: Node in node.get_children():
		labels.append_array(_find_labels_recursive(child))
	return labels
