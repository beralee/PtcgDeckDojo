class_name TestBattleSetupMusic
extends TestBase

const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")
const SETTINGS_PATH := "user://battle_setup.json"


func _read_settings_text() -> String:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _restore_settings_text(original_text: String) -> void:
	if original_text == "":
		var absolute_path := ProjectSettings.globalize_path(SETTINGS_PATH)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(original_text)
	file.close()


func test_battle_setup_populates_bgm_option() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_setup_battle_music_options")

	var bgm_option := scene.get_node("%BgmOption") as OptionButton
	var bgm_hint := scene.get_node("%BgmHint") as Label
	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	var bgm_volume_value := scene.get_node("%BgmVolumeValue") as Label
	var preview_button := scene.get_node("%BtnPreviewBgm") as Button
	var expected_prefix := ProjectSettings.globalize_path("user://custom_bgm")

	var result := run_checks([
		assert_true(bgm_option != null, "对战设置页应存在 BGM 下拉框"),
		assert_true(bgm_option.item_count >= 1, "BGM 下拉框至少应包含无音乐选项"),
		assert_true(str(bgm_hint.text).contains(expected_prefix), "应显示自定义音乐的绝对路径"),
		assert_true(bgm_volume_slider != null, "应提供 BGM 音量滑块"),
		assert_true(bgm_volume_value != null, "应提供 BGM 音量文本"),
		assert_true(preview_button != null, "应提供 BGM 试听按钮"),
	])

	scene.queue_free()
	return result


func test_battle_setup_applies_selected_bgm_volume_to_game_manager() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_setup_battle_music_options")
	var deck1 := DeckData.new()
	deck1.id = 101
	deck1.deck_name = "Deck A"
	deck1.total_cards = 60
	var deck2 := DeckData.new()
	deck2.id = 202
	deck2.deck_name = "Deck B"
	deck2.total_cards = 60
	scene.set("_deck_list", [deck1, deck2])
	var deck1_option := scene.get_node("%Deck1Option") as OptionButton
	var deck2_option := scene.get_node("%Deck2Option") as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("Deck A")
	deck2_option.add_item("Deck B")
	deck1_option.select(0)
	deck2_option.select(0)

	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	bgm_volume_slider.value = 37
	scene.call("_apply_setup_selection")
	var applied := int(GameManager.get("battle_bgm_volume_percent"))

	scene.queue_free()
	return run_checks([
		assert_eq(applied, 37, "应把对战 BGM 音量写入 GameManager"),
	])


func test_battle_setup_defaults_bgm_volume_to_20_without_saved_settings() -> String:
	var original_settings_text := _read_settings_text()
	_restore_settings_text("")
	var previous_track := GameManager.selected_battle_music_id
	var previous_volume := int(GameManager.battle_bgm_volume_percent)
	GameManager.load_battle_setup_preferences()

	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	var bgm_volume_value := scene.get_node("%BgmVolumeValue") as Label

	var result := run_checks([
		assert_eq(int(round(bgm_volume_slider.value)), 20, "首次启动且没有保存设置时，BGM 音量应默认为 20"),
		assert_eq(bgm_volume_value.text, "20%", "首次启动时应显示 20% 的默认 BGM 音量"),
	])

	scene.queue_free()
	GameManager.selected_battle_music_id = previous_track
	GameManager.battle_bgm_volume_percent = previous_volume
	_restore_settings_text(original_settings_text)
	return result


func test_battle_setup_back_persists_bgm_volume_setting() -> String:
	var original_settings_text := _read_settings_text()
	_restore_settings_text("")
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)

	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	bgm_volume_slider.value = 24
	scene.call("_on_back")

	var saved_text := _read_settings_text()
	var json := JSON.new()
	var parse_ok := json.parse(saved_text) == OK
	var saved_data: Dictionary = json.data if parse_ok and json.data is Dictionary else {}

	scene.queue_free()
	_restore_settings_text(original_settings_text)
	return run_checks([
		assert_true(parse_ok, "返回对战设置后应写入 battle_setup.json"),
		assert_eq(int(saved_data.get("battle_bgm_volume_percent", -1)), 24, "返回主菜单时应持久化当前 BGM 音量"),
	])


func test_battle_setup_preview_button_reflects_playing_state() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_setup_battle_music_options")

	var bgm_option := scene.get_node("%BgmOption") as OptionButton
	var preview_button := scene.get_node("%BtnPreviewBgm") as Button
	bgm_option.select(1)
	scene.call("_on_bgm_preview_pressed")
	var after_start := preview_button.text
	scene.call("_on_bgm_preview_pressed")
	var after_stop := preview_button.text

	scene.queue_free()
	return run_checks([
		assert_eq(after_start, "停止试听", "开始试听后按钮文案应切换"),
		assert_eq(after_stop, "试听", "停止试听后按钮文案应恢复"),
	])


func test_battle_setup_preview_respects_volume_slider_changes_in_real_time() -> String:
	var scene := BattleSetupScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	scene.call("_setup_battle_music_options")

	var bgm_option := scene.get_node("%BgmOption") as OptionButton
	var bgm_volume_slider := scene.get_node("%BgmVolumeSlider") as HSlider
	bgm_option.select(1)
	scene.call("_on_bgm_preview_pressed")
	bgm_volume_slider.value = 25
	scene.call("_on_bgm_volume_changed", 25.0)
	var audio_player := BattleMusicManager.get_node("BattleMusicPlayer") as AudioStreamPlayer
	var quiet_volume := float(audio_player.volume_db)
	bgm_volume_slider.value = 90
	scene.call("_on_bgm_volume_changed", 90.0)
	var loud_volume := float(audio_player.volume_db)

	scene.queue_free()
	return run_checks([
		assert_true(loud_volume > quiet_volume, "试听中调高音量应立即提高播放器音量"),
	])
