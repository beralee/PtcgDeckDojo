class_name TestBattleSetupMusic
extends TestBase

const BattleSetupScene := preload("res://scenes/battle_setup/BattleSetup.tscn")


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
