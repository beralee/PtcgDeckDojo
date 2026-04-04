## 对战设置场景
extends Control

const FIRST_PLAYER_RANDOM := -1
const FIRST_PLAYER_PLAYER_ONE := 0
const AI_SOURCE_DEFAULT := 0
const AI_SOURCE_LATEST := 1
const AI_SOURCE_SPECIFIC := 2
const BACKGROUND_DIR := "res://assets/ui"
const DEFAULT_BACKGROUND := "res://assets/ui/background.png"
const BACKGROUND_CARD_SIZE := Vector2(188, 112)
const AIVersionRegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")

## 卡组列表，与 OptionButton index 对应
var _deck_list: Array = []
var _battle_backgrounds: Array[String] = []
var _background_cards: Array[PanelContainer] = []
var _selected_background_path: String = DEFAULT_BACKGROUND
var _ai_version_registry: RefCounted = AIVersionRegistryScript.new()
var _playable_ai_versions: Array[Dictionary] = []


func _ready() -> void:
	%ModeOption.clear()
	%ModeOption.add_item("双人操控", 0)
	%ModeOption.add_item("AI 对战", 1)

	_setup_ai_source_options()
	_refresh_ai_version_options()
	_setup_first_player_options()
	_setup_background_gallery()

	%BtnStart.pressed.connect(_on_start)
	%BtnBack.pressed.connect(_on_back)

	_refresh_deck_options()


func _setup_first_player_options() -> void:
	%FirstPlayerOption.clear()
	%FirstPlayerOption.add_item("随机先后攻", FIRST_PLAYER_RANDOM)
	%FirstPlayerOption.add_item("玩家1卡组先攻", FIRST_PLAYER_PLAYER_ONE)
	%FirstPlayerOption.select(_first_player_option_index_from_choice(GameManager.first_player_choice))


func _setup_ai_source_options() -> void:
	%AISourceOption.clear()
	%AISourceOption.add_item("默认 AI", AI_SOURCE_DEFAULT)
	%AISourceOption.add_item("最新训练版 AI", AI_SOURCE_LATEST)
	%AISourceOption.add_item("指定训练版本 AI", AI_SOURCE_SPECIFIC)
	%AISourceOption.select(_ai_source_option_index_from_source(str(GameManager.ai_selection.get("source", "default"))))
	if not %AISourceOption.item_selected.is_connected(_on_ai_source_changed):
		%AISourceOption.item_selected.connect(_on_ai_source_changed)
	_refresh_ai_version_control_state()


func _refresh_ai_version_options() -> void:
	_playable_ai_versions = []
	if _ai_version_registry != null:
		_playable_ai_versions = _ai_version_registry.list_playable_versions()

	%AIVersionOption.clear()
	for version: Dictionary in _playable_ai_versions:
		%AIVersionOption.add_item(_format_ai_version_option_label(version))

	var selected_version_id := str(GameManager.ai_selection.get("version_id", ""))
	if not selected_version_id.is_empty():
		var selected_index := _ai_version_option_index_from_version_id(selected_version_id)
		if selected_index >= 0:
			%AIVersionOption.select(selected_index)
	elif not _playable_ai_versions.is_empty():
		%AIVersionOption.select(0)

	_refresh_ai_version_control_state()


func set_ai_version_registry_for_test(registry: RefCounted) -> void:
	_ai_version_registry = registry
	if get_node_or_null("%AIVersionOption") != null:
		_refresh_ai_version_options()


func _ai_source_option_index_from_source(source: String) -> int:
	match source:
		"latest_trained":
			return AI_SOURCE_LATEST
		"specific_version":
			return AI_SOURCE_SPECIFIC
		_:
			return AI_SOURCE_DEFAULT


func _ai_source_from_option_index(option_index: int) -> String:
	match option_index:
		AI_SOURCE_LATEST:
			return "latest_trained"
		AI_SOURCE_SPECIFIC:
			return "specific_version"
		_:
			return "default"


func _on_ai_source_changed(_index: int) -> void:
	_refresh_ai_version_control_state()


func _ai_version_option_index_from_version_id(version_id: String) -> int:
	for idx: int in _playable_ai_versions.size():
		if str(_playable_ai_versions[idx].get("version_id", "")) == version_id:
			return idx
	return -1


func _format_ai_version_option_label(version: Dictionary) -> String:
	var version_id := str(version.get("version_id", ""))
	var display_name := str(version.get("display_name", ""))
	var label := version_id
	if not display_name.is_empty():
		label = "%s | %s" % [version_id, display_name]

	var benchmark_summary := str(version.get("benchmark_summary", ""))
	if benchmark_summary != "" and benchmark_summary != "{}":
		label += " | %s" % benchmark_summary
	return label


func _refresh_ai_version_control_state() -> void:
	var show_version_picker := _ai_source_from_option_index(%AISourceOption.selected) == "specific_version"
	%AIVersionLabel.visible = show_version_picker
	%AIVersionOption.visible = show_version_picker
	%AIVersionOption.disabled = not show_version_picker or _playable_ai_versions.is_empty()


func _selected_ai_version_record() -> Dictionary:
	var selected_index: int = %AIVersionOption.selected
	if selected_index < 0 or selected_index >= _playable_ai_versions.size():
		return {}
	return _playable_ai_versions[selected_index].duplicate(true)


func _build_ai_selection(source: String, version_record: Dictionary = {}) -> Dictionary:
	return {
		"source": source,
		"version_id": str(version_record.get("version_id", "")),
		"agent_config_path": str(version_record.get("agent_config_path", "")),
		"value_net_path": str(version_record.get("value_net_path", "")),
		"action_scorer_path": str(version_record.get("action_scorer_path", "")),
		"display_name": str(version_record.get("display_name", "")),
	}


func _setup_background_gallery() -> void:
	%BackgroundGallery.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	%BackgroundGallery.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_refresh_background_gallery()


func _list_available_background_paths() -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(BACKGROUND_DIR)
	if dir != null:
		dir.list_dir_begin()
		while true:
			var file_name := dir.get_next()
			if file_name == "":
				break
			if dir.current_is_dir():
				continue
			var lower_name := file_name.to_lower()
			if not lower_name.begins_with("background"):
				continue
			if not (lower_name.ends_with(".png") or lower_name.ends_with(".jpg") or lower_name.ends_with(".jpeg") or lower_name.ends_with(".webp")):
				continue
			results.append("%s/%s" % [BACKGROUND_DIR, file_name])
		dir.list_dir_end()
	results.sort()
	if results.is_empty():
		results.append(DEFAULT_BACKGROUND)
	return results


func _refresh_background_gallery() -> void:
	_battle_backgrounds = _list_available_background_paths()
	_selected_background_path = GameManager.selected_battle_background if GameManager.selected_battle_background != "" else DEFAULT_BACKGROUND
	_clear_background_gallery()
	for bg_path: String in _battle_backgrounds:
		var texture := _load_background_preview_texture(bg_path)
		var card := _build_background_card(bg_path, texture)
		%BackgroundGalleryRow.add_child(card)
		_background_cards.append(card)
	_refresh_background_selection()


func _background_selection_index(path: String) -> int:
	var normalized_path := path if path != "" else DEFAULT_BACKGROUND
	var idx := _battle_backgrounds.find(normalized_path)
	return idx if idx >= 0 else 0


func _clear_background_gallery() -> void:
	for child: Node in %BackgroundGalleryRow.get_children():
		%BackgroundGalleryRow.remove_child(child)
		child.queue_free()
	_background_cards.clear()


func _build_background_card(path: String, texture: Texture2D) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = BACKGROUND_CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.clip_contents = true
	card.set_meta("background_path", path)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_background_path = path
			_refresh_background_selection()
	)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var preview := TextureRect.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.texture = texture
	margin.add_child(preview)

	return card


func _refresh_background_selection() -> void:
	if _selected_background_path == "":
		_selected_background_path = DEFAULT_BACKGROUND
	for card: PanelContainer in _background_cards:
		if card == null:
			continue
		var is_selected := str(card.get_meta("background_path", "")) == _selected_background_path
		_apply_background_card_style(card, is_selected)


func _apply_background_card_style(card: PanelContainer, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.1, 0.72)
	style.border_color = Color(0.19, 0.36, 0.46, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	if selected:
		style.bg_color = Color(0.04, 0.12, 0.18, 0.86)
		style.border_color = Color(0.48, 0.92, 1.0, 1.0)
	card.add_theme_stylebox_override("panel", style)


func _load_background_preview_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			return resource as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null


func _refresh_deck_options() -> void:
	_deck_list = CardDatabase.get_all_decks()
	%Deck1Option.clear()
	%Deck2Option.clear()

	if _deck_list.size() < 2:
		%NoDeckWarning.visible = true
		%BtnStart.disabled = true
		return

	%NoDeckWarning.visible = false
	%BtnStart.disabled = false

	for deck: Variant in _deck_list:
		var label := "%s (%d张)" % [deck.deck_name, deck.total_cards]
		%Deck1Option.add_item(label)
		%Deck2Option.add_item(label)

	if _deck_list.size() >= 2:
		%Deck2Option.select(1)


func _first_player_choice_from_option_index(option_index: int) -> int:
	return FIRST_PLAYER_PLAYER_ONE if option_index == 1 else FIRST_PLAYER_RANDOM


func _first_player_option_index_from_choice(choice: int) -> int:
	return 1 if choice == FIRST_PLAYER_PLAYER_ONE else 0


func _apply_setup_selection() -> bool:
	var mode_idx: int = %ModeOption.selected
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER if mode_idx == 0 else GameManager.GameMode.VS_AI

	var deck1_idx: int = %Deck1Option.selected
	var deck2_idx: int = %Deck2Option.selected
	if deck1_idx < 0 or deck2_idx < 0:
		return false

	GameManager.selected_deck_ids = [_deck_list[deck1_idx].id, _deck_list[deck2_idx].id]
	GameManager.first_player_choice = _first_player_choice_from_option_index(%FirstPlayerOption.selected)
	GameManager.selected_battle_background = _selected_background_path if _selected_background_path != "" else DEFAULT_BACKGROUND

	var ai_source := _ai_source_from_option_index(%AISourceOption.selected)
	var ai_version: Dictionary = {}
	if ai_source == "latest_trained":
		if _ai_version_registry != null:
			ai_version = _ai_version_registry.get_latest_playable_version()
	elif ai_source == "specific_version":
		ai_version = _selected_ai_version_record()
	if ai_source != "default" and ai_version.is_empty():
		ai_source = "default"
	GameManager.ai_selection = _build_ai_selection(ai_source, ai_version)
	return true


func _on_start() -> void:
	if not _apply_setup_selection():
		return
	GameManager.goto_battle()


func _on_back() -> void:
	GameManager.goto_main_menu()
