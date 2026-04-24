class_name TestBattleSetupAIVersions
extends TestBase

const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")


class FakeAIVersionRegistry extends RefCounted:
	var playable_versions: Array[Dictionary] = []

	func list_playable_versions() -> Array[Dictionary]:
		return playable_versions.duplicate(true)

	func list_playable_versions_for_strategy(strategy_id: String) -> Array[Dictionary]:
		var filtered: Array[Dictionary] = []
		for version: Dictionary in playable_versions:
			var compatible_strategy_id := str(version.get("compatible_strategy_id", ""))
			if compatible_strategy_id == "" or compatible_strategy_id == strategy_id:
				filtered.append(version.duplicate(true))
		return filtered

	func get_latest_playable_version() -> Dictionary:
		if playable_versions.is_empty():
			return {}
		return playable_versions[playable_versions.size() - 1].duplicate(true)


class FakeDeckViewDialog extends RefCounted:
	var shown_decks: Array[DeckData] = []

	func show_deck(_scene: Object, deck: DeckData) -> void:
		shown_decks.append(deck)


func _make_scene_ready() -> Control:
	var scene: Control = BattleSetupScene.instantiate()
	scene.call("_ready")
	# AI 控件在 _ready() 中被隐藏，测试需要手动初始化
	scene.call("_setup_ai_source_options")
	scene.call("_refresh_ai_version_options")
	return scene


func _make_deck(deck_id: int, deck_name: String, signature_name: String = "") -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = deck_name
	deck.total_cards = 60
	if signature_name != "":
		deck.cards = [{
			"name": signature_name,
			"name_en": signature_name,
			"card_type": "Pokemon",
			"count": 1,
		}]
	return deck


func _prime_deck_options(scene: Control) -> void:
	scene.set("_deck_list", [
		_make_deck(575716, "deck-a", "喷火龙ex"),
		_make_deck(575720, "deck-b", "密勒顿ex"),
		_make_deck(578647, "deck-c", "沙奈朵ex"),
	])
	scene.set("_ai_deck_list", [
		_make_deck(578647, "deck-c", "Gardevoir ex"),
		_make_deck(575716, "deck-a", "喷火龙ex"),
		_make_deck(575720, "deck-b", "密勒顿ex"),
		_make_deck(575657, "deck-l", "Lugia VSTAR"),
		_make_deck(569061, "deck-d", "阿尔宙斯 VSTAR"),
		_make_deck(579502, "deck-h", "Dragapult ex"),
		_make_deck(575723, "deck-i", "Dragapult ex"),
	])
	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("deck-a", 0)
	deck2_option.add_item("deck-a", 0)
	deck1_option.add_item("deck-b", 1)
	deck2_option.add_item("deck-b", 1)
	deck1_option.add_item("deck-c", 2)
	deck2_option.add_item("deck-d", 2)
	deck1_option.select(0)
	deck2_option.select(1)


func test_battle_setup_includes_ai_source_and_version_controls() -> String:
	var scene := BattleSetupScene.instantiate()
	var ai_source_label := scene.find_child("AISourceLabel", true, false)
	var ai_source_option := scene.find_child("AISourceOption", true, false)
	var ai_version_label := scene.find_child("AIVersionLabel", true, false)
	var ai_version_option := scene.find_child("AIVersionOption", true, false)

	return run_checks([
		assert_true(ai_source_label is Label, "BattleSetup should include AISourceLabel"),
		assert_true(ai_source_option is OptionButton, "BattleSetup should include AISourceOption"),
		assert_true(ai_version_label is Label, "BattleSetup should include AIVersionLabel"),
		assert_true(ai_version_option is OptionButton, "BattleSetup should include AIVersionOption"),
	])


func test_battle_setup_populates_ai_source_options() -> String:
	var scene := _make_scene_ready()
	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton

	return run_checks([
		assert_eq(ai_source_option.get_item_count(), 3, "AI source should have three options"),
		assert_eq(ai_source_option.get_item_text(0), "默认 AI", "Option 0 should be default AI"),
		assert_eq(ai_source_option.get_item_text(1), "最新训练版 AI", "Option 1 should be latest trained AI"),
		assert_eq(ai_source_option.get_item_text(2), "指定训练版本 AI", "Option 2 should be specific trained AI"),
	])


func test_battle_setup_refreshes_ai_version_options_from_registry() -> String:
	var scene := _make_scene_ready()
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [
		{
			"version_id": "AI-20260328-01",
			"display_name": "v015 + value1",
			"benchmark_summary": {"win_rate_vs_current_best": 0.57},
		},
		{
			"version_id": "AI-20260328-02",
			"display_name": "v016 + value2",
		},
	]
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_refresh_ai_version_options")
	var ai_version_option := scene.find_child("AIVersionOption", true, false) as OptionButton

	return run_checks([
		assert_eq(ai_version_option.get_item_count(), 2, "AI version dropdown should reflect playable versions"),
		assert_str_contains(ai_version_option.get_item_text(0), "AI-20260328-01", "First option should include version_id"),
		assert_str_contains(ai_version_option.get_item_text(0), "v015 + value1", "First option should include display_name"),
		assert_str_contains(ai_version_option.get_item_text(1), "AI-20260328-02", "Second option should include version_id"),
	])


func test_battle_setup_filters_ai_versions_to_selected_ai_strategy() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [
		{
			"version_id": "AI-MIRAIDON-01",
			"display_name": "miraidon build",
			"compatible_strategy_id": "miraidon",
		},
		{
			"version_id": "AI-GARDEVOIR-01",
			"display_name": "gardevoir build",
			"compatible_strategy_id": "gardevoir",
		},
		{
			"version_id": "AI-DRAGAPULT-01",
			"display_name": "dragapult build",
			"compatible_strategy_id": "dragapult_charizard",
		},
	]
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_refresh_ai_version_options")
	var ai_version_option := scene.find_child("AIVersionOption", true, false) as OptionButton
	return run_checks([
		assert_eq(ai_version_option.get_item_count(), 1, "AI version dropdown should only show versions compatible with the selected AI deck strategy"),
		assert_str_contains(ai_version_option.get_item_text(0), "AI-MIRAIDON-01", "Miraidon deck selection should keep the Miraidon-compatible version"),
	])


func test_battle_setup_ai_mode_limits_ai_decks_to_supported_shortlist() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	var supported_ids: Array[int] = CardDatabase.get_supported_ai_deck_ids()
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)

	var resolved_ids: Array[int] = []
	for i: int in deck2_option.item_count:
		deck2_option.select(i)
		var deck := scene.call("_selected_deck_for_slot", 1) as DeckData
		if deck != null:
			resolved_ids.append(deck.id)

	return run_checks([
		assert_eq(deck2_option.item_count, supported_ids.size(), "AI mode should only expose the supported AI decks"),
		assert_true(575716 in resolved_ids, "AI deck list should include Charizard ex / Pidgeot ex"),
		assert_true(575720 in resolved_ids, "AI deck list should include Miraidon"),
		assert_true(569061 in resolved_ids, "AI deck list should include Arceus / Giratina"),
		assert_true(575657 in resolved_ids, "AI deck list should include Lugia / Archeops"),
		assert_true(578647 in resolved_ids, "AI deck list should include Gardevoir"),
		assert_true(575718 in resolved_ids, "AI deck list should include Raging Bolt / Ogerpon"),
		assert_true(579502 in resolved_ids, "AI deck list should include Dragapult / Charizard"),
		assert_true(575723 in resolved_ids, "AI deck list should include Dragapult / Dusknoir"),
	])


func test_battle_setup_filters_dragapult_charizard_ai_versions() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck2Option", true, false), 579502)
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [
		{
			"version_id": "AI-DRAGAPULT-01",
			"display_name": "dragapult build",
			"compatible_strategy_id": "dragapult_charizard",
		},
		{
			"version_id": "AI-MIRAIDON-01",
			"display_name": "miraidon build",
			"compatible_strategy_id": "miraidon",
		},
	]
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_refresh_ai_version_options")
	var ai_version_option := scene.find_child("AIVersionOption", true, false) as OptionButton
	return run_checks([
		assert_eq(ai_version_option.get_item_count(), 1, "Dragapult / Charizard AI selection should only show compatible versions"),
		assert_str_contains(ai_version_option.get_item_text(0), "AI-DRAGAPULT-01", "Dragapult / Charizard selection should keep the deck-local version"),
	])


func test_selected_deck_for_ai_slot_reads_dedicated_ai_deck_list() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)

	var player_deck := _make_deck(700001, "player-deck", "Player Signature")
	var ai_deck := _make_deck(700002, "ai-deck", "AI Signature")
	scene.set("_deck_list", [player_deck])
	scene.set("_ai_deck_list", [ai_deck])

	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("player-deck", 0)
	deck2_option.add_item("ai-deck", 0)
	deck1_option.select(0)
	deck2_option.select(0)

	var selected_ai_deck := scene.call("_selected_deck_for_slot", 1) as DeckData
	return run_checks([
		assert_not_null(selected_ai_deck, "AI slot should still resolve a selected deck in VS_AI mode"),
		assert_eq(selected_ai_deck.id if selected_ai_deck != null else -1, 700002, "AI slot should resolve from the dedicated AI deck list instead of the player deck list"),
	])


func test_apply_setup_selection_writes_default_ai_selection() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)

	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton
	ai_source_option.select(0)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection

	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed"),
		assert_eq(str(selection.get("source", "")), "default", "Default source should write default"),
		assert_eq(str(selection.get("version_id", "")), "", "Default source should not bind version_id"),
		assert_eq(str(selection.get("agent_config_path", "")), "", "Default source should not bind agent_config_path"),
		assert_eq(str(selection.get("value_net_path", "")), "", "Default source should not bind value_net_path"),
		assert_eq(str(selection.get("display_name", "")), "", "Default source should not bind display_name"),
	])


func test_apply_setup_selection_enables_fixed_order_for_strong_miraidon_ai() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	preview_option.select(1)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection.duplicate(true)

	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed for strong Miraidon AI"),
		assert_eq(str(selection.get("opening_mode", "")), "fixed_order", "Strong Miraidon AI should enable fixed opening mode"),
		assert_eq(
			str(selection.get("fixed_deck_order_path", "")),
			"res://data/bundled_user/ai_fixed_deck_orders/575720.json",
			"Strong Miraidon AI should bind the bundled fixed deck order path"
		),
	])


func test_apply_setup_selection_resolves_filtered_ai_deck_ids_in_ai_mode() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck1Option", true, false), 575716)
	scene.call("_select_option_for_deck_id", scene.find_child("Deck2Option", true, false), 569061)

	var ok: bool = scene.call("_apply_setup_selection")
	var selected_ids: Array = GameManager.selected_deck_ids.duplicate()

	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed in AI mode with a filtered deck list"),
		assert_eq(int(selected_ids[0]), 575716, "Player deck should still resolve correctly"),
		assert_eq(int(selected_ids[1]), 569061, "Filtered AI deck selection should resolve to Arceus / Giratina by deck id"),
	])


func test_capture_setup_selection_context_no_longer_persists_legacy_ai_strategy() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var context: Dictionary = scene.call("_capture_setup_selection_context")
	return run_checks([
		assert_false(context.has("ai_strategy"), "Deck-driven setup should not persist the removed ai_strategy field"),
	])


func test_apply_setup_selection_writes_latest_trained_ai_selection() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [{
		"version_id": "AI-20260328-03",
		"display_name": "v017 + value3",
		"agent_config_path": "user://ai_agents/agent_v017.json",
		"value_net_path": "user://ai_models/value_net_v3.json",
	}]
	scene.call("set_ai_version_registry_for_test", registry)

	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton
	ai_source_option.select(1)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection
	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed"),
		assert_eq(str(selection.get("source", "")), "latest_trained", "Latest source should write latest_trained"),
		assert_eq(str(selection.get("version_id", "")), "AI-20260328-03", "Latest source should bind version_id"),
		assert_eq(str(selection.get("agent_config_path", "")), "user://ai_agents/agent_v017.json", "Latest source should bind agent_config_path"),
		assert_eq(str(selection.get("value_net_path", "")), "user://ai_models/value_net_v3.json", "Latest source should bind value_net_path"),
		assert_eq(str(selection.get("display_name", "")), "v017 + value3", "Latest source should bind display_name"),
	])


func test_apply_setup_selection_falls_back_to_default_when_specific_version_missing() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	scene.call("set_ai_version_registry_for_test", FakeAIVersionRegistry.new())

	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton
	ai_source_option.select(2)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection
	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed"),
		assert_eq(str(selection.get("source", "")), "default", "Missing specific version should fall back to default"),
		assert_eq(str(selection.get("version_id", "")), "", "Fallback should not bind version_id"),
		assert_eq(str(selection.get("agent_config_path", "")), "", "Fallback should not bind agent_config_path"),
		assert_eq(str(selection.get("value_net_path", "")), "", "Fallback should not bind value_net_path"),
		assert_eq(str(selection.get("display_name", "")), "", "Fallback should not bind display_name"),
	])


func test_apply_setup_context_ignores_legacy_ai_strategy_and_keeps_explicit_ai_deck() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	scene.call("_apply_setup_context", {
		"deck1_id": 575716,
		"deck2_id": 575720,
		"mode": 1,
		"ai_strategy": 2,
	})
	var selected_deck := scene.call("_selected_deck_for_slot", 1) as DeckData
	return run_checks([
		assert_true(deck2_option.selected >= 0, "Legacy ai_strategy state should still leave an explicit AI deck selected"),
		assert_not_null(selected_deck, "Selected AI deck should still resolve after applying legacy context"),
		assert_eq(selected_deck.id, 575720, "Applying old ai_strategy state should preserve the requested AI deck"),
	])


func test_battle_setup_hides_legacy_ai_strategy_controls_even_in_ai_mode() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var ai_strategy_label := scene.find_child("AIStrategyLabel", true, false) as Label
	var ai_strategy_option := scene.find_child("AIStrategyOption", true, false) as OptionButton
	var dummy_deck := _make_deck(999, "TestDeck", "Pikachu")
	scene.set("_ai_deck_list", [dummy_deck])
	mode_option.select(1)
	scene.call("_refresh_deck_options")
	scene.call("_refresh_ai_ui_visibility")
	return run_checks([
		assert_false(ai_strategy_label.visible, "Deck-driven AI setup should not expose the legacy AI strategy label"),
		assert_false(ai_strategy_option.visible, "Deck-driven AI setup should not expose the legacy AI strategy dropdown"),
	])


func test_battle_setup_ai_preview_strength_option_only_shows_in_ai_mode() -> String:
	var scene := _make_scene_ready()
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton
	mode_option.select(0)
	scene.call("_refresh_ai_ui_visibility")
	var hidden_in_two_player := preview_option.visible
	mode_option.select(1)
	scene.call("_refresh_ai_ui_visibility")

	return run_checks([
		assert_true(preview_option is OptionButton, "BattleSetup should include AIPreviewStrengthOption"),
		assert_false(hidden_in_two_player, "AIPreviewStrengthOption should stay hidden outside VS_AI mode"),
		assert_true(preview_option.visible, "AIPreviewStrengthOption should show in VS_AI mode"),
		assert_eq(preview_option.get_item_count(), 2, "AIPreviewStrengthOption should expose weak/strong choices"),
		assert_eq(preview_option.get_item_text(0), "弱", "Preview strength option 0 should be weak"),
		assert_eq(preview_option.get_item_text(1), "强", "Preview strength option 1 should be strong"),
	])


func test_battle_setup_ai_view_button_keeps_normal_preview_for_weak_mode() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var fake_dialog := FakeDeckViewDialog.new()
	scene.set("_deck_view_dialog", fake_dialog)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	preview_option.select(0)

	scene.call("_on_deck_view_pressed", 1)

	var result := run_checks([
		assert_eq(fake_dialog.shown_decks.size(), 1, "Weak AI preview mode should keep calling the existing deck preview dialog"),
		assert_eq(fake_dialog.shown_decks[0].id if not fake_dialog.shown_decks.is_empty() else -1, 575720, "Weak AI preview mode should preview the selected AI deck"),
	])
	scene.queue_free()
	return result


func test_battle_setup_ai_view_button_uses_placeholder_for_strong_mode() -> String:
	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var preview_option := scene.find_child("AIPreviewStrengthOption", true, false) as OptionButton
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)
	preview_option.select(1)

	scene.call("_on_deck_view_pressed", 1)

	var placeholder_opened := false
	for child: Node in scene.get_children():
		if child is AcceptDialog and (child as AcceptDialog).title == "强 AI 占位":
			placeholder_opened = (child as AcceptDialog).dialog_text == "hello world"
			break

	var result := run_checks([
		assert_true(placeholder_opened, "Strong AI preview mode should open the hello world placeholder dialog"),
	])
	scene.queue_free()
	return result
