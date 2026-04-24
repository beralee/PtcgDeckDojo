## 对战设置场景
extends Control

const DeckViewDialogScript := preload("res://scripts/ui/decks/DeckViewDialog.gd")

const FIRST_PLAYER_RANDOM := -1
const FIRST_PLAYER_PLAYER_ONE := 0
const FIRST_PLAYER_PLAYER_TWO := 1
const AI_SOURCE_DEFAULT := 0
const AI_SOURCE_LATEST := 1
const AI_SOURCE_SPECIFIC := 2
const AI_PREVIEW_STRENGTH_WEAK := 0
const AI_PREVIEW_STRENGTH_STRONG := 1
const BACKGROUND_DIR := "res://assets/ui"
const DEFAULT_BACKGROUND := "res://assets/ui/background.png"
const SETTINGS_PATH := "user://battle_setup.json"
const DEFAULT_DECK1_ID := 575716  ## 喷火龙 大比鸟
const DEFAULT_DECK2_ID := 578647  ## 沙奈朵
const MIRAIDON_DECK_ID := 575720
const ARCEUS_GIRATINA_DECK_ID := 569061
const LUGIA_ARCHEOPS_DECK_ID := 575657
const DRAGAPULT_CHARIZARD_DECK_ID := 579502
const BACKGROUND_CARD_SIZE := Vector2(188, 112)
const AIVersionRegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")
const AIFixedDeckOrderRegistryScript = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

## 卡组列表，与 OptionButton index 对应
var _deck_list: Array = []
var _ai_deck_list: Array = []
var _battle_backgrounds: Array[String] = []
var _background_cards: Array[PanelContainer] = []
var _selected_background_path: String = DEFAULT_BACKGROUND
var _battle_music_tracks: Array[Dictionary] = []
var _selected_battle_music_id: String = "none"
var _selected_battle_music_volume_percent: int = 20
var _ai_version_registry: RefCounted = AIVersionRegistryScript.new()
var _ai_fixed_deck_order_registry: RefCounted = AIFixedDeckOrderRegistryScript.new()
var _playable_ai_versions: Array[Dictionary] = []
var _deck_view_dialog: RefCounted = DeckViewDialogScript.new()
var _deck_strategy_registry: RefCounted = DeckStrategyRegistryScript.new()
var _pending_ai_strategy_variant_id: String = ""


func _ready() -> void:
	%ModeOption.clear()
	%ModeOption.add_item("自己练牌", 0)
	%ModeOption.add_item("AI 对战", 1)
	%ModeOption.item_selected.connect(_on_mode_changed)

	# 旧的 AI 策略下拉不再使用。
	%AIStrategyLabel.visible = false
	%AIStrategyOption.visible = false
	%AISourceLabel.visible = false
	%AISourceOption.visible = false
	%AIVersionLabel.visible = false
	%AIVersionOption.visible = false
	_setup_ai_preview_strength_options()

	_setup_first_player_options()
	_setup_background_gallery()
	_setup_battle_music_options()

	%BtnStart.pressed.connect(_on_start)
	%BtnBack.pressed.connect(_on_back)
	%Deck2Option.item_selected.connect(_on_deck2_changed)
	%Deck1ViewButton.pressed.connect(_on_deck_view_pressed.bind(0))
	%Deck1EditButton.pressed.connect(_on_deck_edit_pressed.bind(0))
	%Deck2ViewButton.pressed.connect(_on_deck_view_pressed.bind(1))
	%Deck2EditButton.pressed.connect(_on_deck_edit_pressed.bind(1))
	if not %BtnPreviewBgm.pressed.is_connected(_on_bgm_preview_pressed):
		%BtnPreviewBgm.pressed.connect(_on_bgm_preview_pressed)

	_refresh_deck_options()
	_load_settings()
	_restore_returned_setup_context()
	_refresh_ai_ui_visibility()


func _on_mode_changed(_index: int) -> void:
	_refresh_deck_options()
	_refresh_ai_ui_visibility()


func _on_deck2_changed(_index: int) -> void:
	_refresh_ai_strategy_variant_options()
	_refresh_deck_action_buttons()


func _refresh_ai_ui_visibility() -> void:
	var is_ai: bool = %ModeOption.selected == 1
	%Deck2Label.text = "AI 卡组" if is_ai else "玩家2 卡组"
	%AIPreviewStrengthOption.visible = is_ai
	%AIPreviewStrengthOption.disabled = not is_ai
	%Deck2EditButton.visible = not is_ai
	_refresh_ai_strategy_variant_options()
	_refresh_deck_action_buttons()


func _setup_ai_preview_strength_options() -> void:
	%AIPreviewStrengthOption.clear()
	%AIPreviewStrengthOption.add_item("弱", AI_PREVIEW_STRENGTH_WEAK)
	%AIPreviewStrengthOption.add_item("强", AI_PREVIEW_STRENGTH_STRONG)
	%AIPreviewStrengthOption.select(AI_PREVIEW_STRENGTH_WEAK)


func _refresh_ai_strategy_variant_options() -> void:
	var variants := _detect_ai_strategy_variants()
	var show_variant := _is_ai_mode() and variants.size() > 1
	%AIStrategyLabel.visible = show_variant
	%AIStrategyOption.visible = show_variant
	if not show_variant:
		return
	var prev_selected_id := ""
	if %AIStrategyOption.selected >= 0 and %AIStrategyOption.selected < %AIStrategyOption.item_count:
		prev_selected_id = str(%AIStrategyOption.get_item_metadata(%AIStrategyOption.selected))
	%AIStrategyOption.clear()
	for variant: Dictionary in variants:
		var idx: int = %AIStrategyOption.item_count
		%AIStrategyOption.add_item(str(variant.get("label", "")))
		%AIStrategyOption.set_item_metadata(idx, str(variant.get("id", "")))
	var restore_id := prev_selected_id if prev_selected_id != "" else _pending_ai_strategy_variant_id
	_pending_ai_strategy_variant_id = ""
	for i: int in %AIStrategyOption.item_count:
		if str(%AIStrategyOption.get_item_metadata(i)) == restore_id:
			%AIStrategyOption.select(i)
			return
	%AIStrategyOption.select(0)


func _detect_ai_strategy_variants() -> Array[Dictionary]:
	var deck := _selected_deck_for_slot(1)
	if deck == null or _deck_strategy_registry == null:
		return []
	var base_id := ""
	if _deck_strategy_registry.has_method("resolve_strategy_id_for_deck"):
		base_id = str(_deck_strategy_registry.call("resolve_strategy_id_for_deck", deck))
	if base_id != "raging_bolt_ogerpon":
		return []
	var api_config: Dictionary = GameManager.get_battle_review_api_config()
	var has_api := str(api_config.get("endpoint", "")).strip_edges() != "" and str(api_config.get("api_key", "")).strip_edges() != ""
	if not has_api:
		return []
	return [
		{"id": "raging_bolt_ogerpon", "label": "猛雷鼓 规则版"},
		{"id": "raging_bolt_ogerpon_llm", "label": "猛雷鼓 LLM版"},
	]


func _selected_ai_strategy_variant_id() -> String:
	if not %AIStrategyOption.visible or %AIStrategyOption.selected < 0:
		return ""
	return str(%AIStrategyOption.get_item_metadata(%AIStrategyOption.selected))


func _setup_first_player_options() -> void:
	%FirstPlayerOption.clear()
	%FirstPlayerOption.add_item("随机先后攻")
	%FirstPlayerOption.add_item("玩家1先攻")
	%FirstPlayerOption.add_item("玩家2先攻")
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
	var strategy_id := _selected_ai_strategy_id()
	if _ai_version_registry != null and strategy_id != "" and _ai_version_registry.has_method("list_playable_versions_for_strategy"):
		_playable_ai_versions = _ai_version_registry.list_playable_versions_for_strategy(strategy_id)
	elif _ai_version_registry != null:
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


func _selected_ai_strategy_id() -> String:
	var deck := _selected_deck_for_slot(1)
	if deck == null:
		return ""
	match deck.id:
		MIRAIDON_DECK_ID:
			return "miraidon"
		DEFAULT_DECK2_ID:
			return "gardevoir"
		ARCEUS_GIRATINA_DECK_ID:
			return "arceus_giratina"
		LUGIA_ARCHEOPS_DECK_ID:
			return "lugia_archeops"
		DRAGAPULT_CHARIZARD_DECK_ID:
			return "dragapult_charizard"
		DEFAULT_DECK1_ID:
			return "charizard_ex"
		_:
			return ""


func _build_ai_selection(source: String, version_record: Dictionary = {}) -> Dictionary:
	return {
		"source": source,
		"version_id": str(version_record.get("version_id", "")),
		"agent_config_path": str(version_record.get("agent_config_path", "")),
		"value_net_path": str(version_record.get("value_net_path", "")),
		"action_scorer_path": str(version_record.get("action_scorer_path", "")),
		"display_name": str(version_record.get("display_name", "")),
		"opening_mode": "default",
		"fixed_deck_order_path": "",
	}


func _resolve_ai_opening_selection(deck: DeckData) -> Dictionary:
	if not _is_ai_mode() or %AIPreviewStrengthOption.selected != AI_PREVIEW_STRENGTH_STRONG:
		return {"opening_mode": "default", "fixed_deck_order_path": ""}
	if deck == null or _ai_fixed_deck_order_registry == null:
		return {"opening_mode": "default", "fixed_deck_order_path": ""}
	var fixed_order_path := str(_ai_fixed_deck_order_registry.call("get_fixed_order_path", int(deck.id)))
	if fixed_order_path == "":
		return {"opening_mode": "default", "fixed_deck_order_path": ""}
	return {"opening_mode": "fixed_order", "fixed_deck_order_path": fixed_order_path}


func _setup_background_gallery() -> void:
	%BackgroundGallery.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	%BackgroundGallery.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_refresh_background_gallery()


func _setup_battle_music_options() -> void:
	BattleMusicManager.ensure_custom_music_dir()
	_battle_music_tracks = BattleMusicManager.get_available_battle_tracks()
	%BgmOption.clear()
	for track: Dictionary in _battle_music_tracks:
		%BgmOption.add_item(str(track.get("label", "")))
	_selected_battle_music_id = BattleMusicManager.sanitize_track_id(GameManager.selected_battle_music_id)
	_selected_battle_music_volume_percent = clampi(int(GameManager.battle_bgm_volume_percent), 0, 100)
	var selected_index := _battle_music_index_from_id(_selected_battle_music_id)
	if selected_index >= 0 and selected_index < %BgmOption.item_count:
		%BgmOption.select(selected_index)
	elif %BgmOption.item_count > 0:
		%BgmOption.select(0)
	_sync_selected_battle_music_from_option()
	%BgmVolumeSlider.value = _selected_battle_music_volume_percent
	_update_bgm_volume_value_label()
	%BgmHint.text = "自定义音乐目录: %s" % BattleMusicManager.get_custom_music_absolute_dir_path()
	if not %BgmOption.item_selected.is_connected(_on_bgm_option_changed):
		%BgmOption.item_selected.connect(_on_bgm_option_changed)
	if not %BgmVolumeSlider.value_changed.is_connected(_on_bgm_volume_changed):
		%BgmVolumeSlider.value_changed.connect(_on_bgm_volume_changed)
	_update_bgm_preview_button()


func _on_bgm_option_changed(_index: int) -> void:
	_sync_selected_battle_music_from_option()
	_update_bgm_preview_button()


func _on_bgm_volume_changed(value: float) -> void:
	_selected_battle_music_volume_percent = clampi(int(round(value)), 0, 100)
	_update_bgm_volume_value_label()
	BattleMusicManager.set_battle_music_volume_percent(_selected_battle_music_volume_percent)


func _update_bgm_volume_value_label() -> void:
	%BgmVolumeValue.text = "%d%%" % _selected_battle_music_volume_percent


func _sync_selected_battle_music_from_option() -> void:
	var selected_index: int = %BgmOption.selected
	if selected_index >= 0 and selected_index < _battle_music_tracks.size():
		_selected_battle_music_id = str(_battle_music_tracks[selected_index].get("id", "none"))
	else:
		_selected_battle_music_id = "none"
	_selected_battle_music_id = BattleMusicManager.sanitize_track_id(_selected_battle_music_id)


func _on_bgm_preview_pressed() -> void:
	_sync_selected_battle_music_from_option()
	if BattleMusicManager.is_battle_music_playing() and BattleMusicManager.get_current_track_id() == _selected_battle_music_id:
		BattleMusicManager.stop_battle_music()
		_update_bgm_preview_button()
		return
	BattleMusicManager.set_battle_music_volume_percent(_selected_battle_music_volume_percent)
	BattleMusicManager.play_battle_music(_selected_battle_music_id)
	_update_bgm_preview_button()


func _update_bgm_preview_button() -> void:
	var is_current_preview := BattleMusicManager.is_battle_music_playing() and BattleMusicManager.get_current_track_id() == _selected_battle_music_id and _selected_battle_music_id != "none"
	%BtnPreviewBgm.text = "停止试听" if is_current_preview else "试听"


func _battle_music_index_from_id(track_id: String) -> int:
	for i: int in _battle_music_tracks.size():
		if str(_battle_music_tracks[i].get("id", "")) == track_id:
			return i
	return 0


## 导出后 DirAccess 无法遍历 pck 内的 res:// 目录，
## 因此背景列表采用硬编码 + 运行时校验 ResourceLoader.exists()。
func _list_available_background_paths() -> Array[String]:
	var candidates: Array[String] = [
		"res://assets/ui/background.png",
		"res://assets/ui/background1.png",
		"res://assets/ui/background2.png",
		"res://assets/ui/background3.png",
		"res://assets/ui/background4.png",
	]
	var results: Array[String] = []
	for path: String in candidates:
		if ResourceLoader.exists(path):
			results.append(path)
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
	var selected_deck1 := _selected_deck_for_slot(0)
	var selected_deck2 := _selected_deck_for_slot(1)
	_deck_list = CardDatabase.get_all_decks()
	_ai_deck_list = CardDatabase.get_all_ai_decks()
	%Deck1Option.clear()
	%Deck2Option.clear()

	if _deck_list.size() < 1 or (_is_ai_mode() and _ai_deck_list.is_empty()) or (not _is_ai_mode() and _deck_list.size() < 2):
		%NoDeckWarning.visible = true
		%BtnStart.disabled = true
		_refresh_deck_action_buttons()
		return

	%NoDeckWarning.visible = false
	%BtnStart.disabled = false

	for deck: DeckData in _deck_list:
		var label := "%s (%d张)" % [deck.deck_name, deck.total_cards]
		%Deck1Option.add_item(label)
	if _is_ai_mode():
		for ai_deck: DeckData in _ai_deck_list:
			%Deck2Option.add_item("%s (%d张)" % [ai_deck.deck_name, ai_deck.total_cards])
	else:
		for deck: DeckData in _deck_list:
			%Deck2Option.add_item("%s (%d张)" % [deck.deck_name, deck.total_cards])

	_select_option_for_deck_id(%Deck1Option, selected_deck1.id if selected_deck1 != null else DEFAULT_DECK1_ID)
	var default_deck2_id := MIRAIDON_DECK_ID if _is_ai_mode() else DEFAULT_DECK2_ID
	_select_option_for_deck_id(%Deck2Option, selected_deck2.id if selected_deck2 != null else default_deck2_id)
	_refresh_deck_action_buttons()


func _selected_deck_for_slot(slot_index: int) -> DeckData:
	var option: OptionButton = %Deck1Option if slot_index == 0 else %Deck2Option
	var selected_index := option.selected
	if selected_index < 0 or selected_index >= option.item_count:
		return null
	var selected_text := option.get_item_text(selected_index)
	var source_list: Array = _deck_list if slot_index == 0 or not _is_ai_mode() else _ai_deck_list
	for deck: DeckData in source_list:
		if selected_text == deck.deck_name or selected_text.begins_with(deck.deck_name):
			return deck
	return null


func _is_ai_mode() -> bool:
	return %ModeOption.selected == 1


func _select_option_for_deck_id(option: OptionButton, deck_id: int) -> void:
	if option == null or option.item_count <= 0:
		return
	var source_list: Array = _deck_list
	if option == %Deck2Option and _is_ai_mode():
		source_list = _ai_deck_list
	for i: int in option.item_count:
		var label := option.get_item_text(i)
		for deck: DeckData in source_list:
			if deck.id == deck_id and (label == deck.deck_name or label.begins_with(deck.deck_name)):
				option.select(i)
				return
	if option.selected < 0:
		option.select(0)


func _first_player_choice_from_option_index(option_index: int) -> int:
	match option_index:
		1: return FIRST_PLAYER_PLAYER_ONE
		2: return FIRST_PLAYER_PLAYER_TWO
		_: return FIRST_PLAYER_RANDOM


func _first_player_option_index_from_choice(choice: int) -> int:
	match choice:
		FIRST_PLAYER_PLAYER_ONE: return 1
		FIRST_PLAYER_PLAYER_TWO: return 2
		_: return 0


func _apply_setup_selection() -> bool:
	var mode_idx: int = %ModeOption.selected
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER if mode_idx == 0 else GameManager.GameMode.VS_AI

	var deck1 := _selected_deck_for_slot(0)
	var deck2 := _selected_deck_for_slot(1)
	if deck1 == null or deck2 == null:
		return false

	GameManager.selected_deck_ids = [deck1.id, deck2.id]
	GameManager.first_player_choice = _first_player_choice_from_option_index(%FirstPlayerOption.selected)
	GameManager.selected_battle_background = _selected_background_path if _selected_background_path != "" else DEFAULT_BACKGROUND
	_sync_battle_music_preferences_from_ui()

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
	GameManager.ai_deck_strategy = _selected_ai_strategy_variant_id()
	var ai_opening_selection := _resolve_ai_opening_selection(_selected_deck_for_slot(1))
	for key_variant: Variant in ai_opening_selection.keys():
		var key := str(key_variant)
		GameManager.ai_selection[key] = ai_opening_selection[key]
	return true


func _on_start() -> void:
	if not _apply_setup_selection():
		return
	_save_settings()
	GameManager.goto_battle()


func _on_back() -> void:
	_sync_battle_music_preferences_from_ui()
	_save_settings()
	BattleMusicManager.stop_battle_music()
	GameManager.goto_main_menu()


func _exit_tree() -> void:
	BattleMusicManager.stop_battle_music()


func _save_settings() -> void:
	_sync_battle_music_preferences_from_ui()
	var deck1 := _selected_deck_for_slot(0)
	var deck2 := _selected_deck_for_slot(1)
	var data := {
		"deck1_id": deck1.id if deck1 != null else -1,
		"deck2_id": deck2.id if deck2 != null else -1,
		"first_player_choice": _first_player_choice_from_option_index(%FirstPlayerOption.selected),
		"background_path": _selected_background_path,
		"battle_music_id": _selected_battle_music_id,
		"battle_bgm_volume_percent": _selected_battle_music_volume_percent,
		"mode": %ModeOption.selected,
		"ai_preview_strength_index": %AIPreviewStrengthOption.selected,
		"ai_strategy_variant_id": _selected_ai_strategy_variant_id(),
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _sync_battle_music_preferences_from_ui() -> void:
	_sync_selected_battle_music_from_option()
	_selected_battle_music_volume_percent = clampi(int(round(%BgmVolumeSlider.value)), 0, 100)
	GameManager.selected_battle_music_id = _selected_battle_music_id
	GameManager.battle_bgm_volume_percent = _selected_battle_music_volume_percent


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		_apply_default_deck_selection()
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if not data is Dictionary:
		return

	var deck1_id: int = int(data.get("deck1_id", -1))
	var deck2_id: int = int(data.get("deck2_id", -1))
	var mode_idx: int = int(data.get("mode", 0))
	if mode_idx >= 0 and mode_idx < %ModeOption.item_count:
		%ModeOption.select(mode_idx)
	_refresh_deck_options()
	_select_option_for_deck_id(%Deck1Option, deck1_id)
	_select_option_for_deck_id(%Deck2Option, deck2_id)
	var ai_preview_strength_index: int = int(data.get("ai_preview_strength_index", AI_PREVIEW_STRENGTH_WEAK))
	if ai_preview_strength_index >= 0 and ai_preview_strength_index < %AIPreviewStrengthOption.item_count:
		%AIPreviewStrengthOption.select(ai_preview_strength_index)
	_pending_ai_strategy_variant_id = str(data.get("ai_strategy_variant_id", ""))

	var fp_choice: int = int(data.get("first_player_choice", FIRST_PLAYER_RANDOM))
	%FirstPlayerOption.select(_first_player_option_index_from_choice(fp_choice))

	var bg_path: String = str(data.get("background_path", DEFAULT_BACKGROUND))
	if bg_path in _battle_backgrounds:
		_selected_background_path = bg_path
		_refresh_background_selection()

	_selected_battle_music_id = BattleMusicManager.sanitize_track_id(str(data.get("battle_music_id", _selected_battle_music_id)))
	_selected_battle_music_volume_percent = clampi(int(data.get("battle_bgm_volume_percent", _selected_battle_music_volume_percent)), 0, 100)
	var battle_music_index := _battle_music_index_from_id(_selected_battle_music_id)
	if battle_music_index >= 0 and battle_music_index < %BgmOption.item_count:
		%BgmOption.select(battle_music_index)
	%BgmVolumeSlider.value = _selected_battle_music_volume_percent
	_update_bgm_volume_value_label()
	_update_bgm_preview_button()


func _capture_setup_selection_context() -> Dictionary:
	var deck1 := _selected_deck_for_slot(0)
	var deck2 := _selected_deck_for_slot(1)
	return {
		"deck1_id": deck1.id if deck1 != null else -1,
		"deck2_id": deck2.id if deck2 != null else -1,
		"first_player_choice": _first_player_choice_from_option_index(%FirstPlayerOption.selected),
		"background_path": _selected_background_path,
		"mode": %ModeOption.selected,
		"ai_source_index": %AISourceOption.selected,
		"ai_version_index": %AIVersionOption.selected,
		"ai_preview_strength_index": %AIPreviewStrengthOption.selected,
		"ai_strategy_variant_id": _selected_ai_strategy_variant_id(),
	}


func _apply_setup_context(context: Dictionary) -> void:
	var deck1_id := int(context.get("deck1_id", -1))
	var deck2_id := int(context.get("deck2_id", -1))
	var mode_idx := int(context.get("mode", %ModeOption.selected))
	if mode_idx >= 0 and mode_idx < %ModeOption.item_count:
		%ModeOption.select(mode_idx)
	_refresh_deck_options()
	_select_option_for_deck_id(%Deck1Option, deck1_id)
	_select_option_for_deck_id(%Deck2Option, deck2_id)

	var first_player_choice := int(context.get("first_player_choice", FIRST_PLAYER_RANDOM))
	%FirstPlayerOption.select(_first_player_option_index_from_choice(first_player_choice))

	var background_path := str(context.get("background_path", DEFAULT_BACKGROUND))
	if background_path in _battle_backgrounds:
		_selected_background_path = background_path
		_refresh_background_selection()

	var ai_source_index := int(context.get("ai_source_index", %AISourceOption.selected))
	if ai_source_index >= 0 and ai_source_index < %AISourceOption.item_count:
		%AISourceOption.select(ai_source_index)
	var ai_version_index := int(context.get("ai_version_index", %AIVersionOption.selected))
	if ai_version_index >= 0 and ai_version_index < %AIVersionOption.item_count:
		%AIVersionOption.select(ai_version_index)
	var ai_preview_strength_index := int(context.get("ai_preview_strength_index", %AIPreviewStrengthOption.selected))
	if ai_preview_strength_index >= 0 and ai_preview_strength_index < %AIPreviewStrengthOption.item_count:
		%AIPreviewStrengthOption.select(ai_preview_strength_index)
	_pending_ai_strategy_variant_id = str(context.get("ai_strategy_variant_id", ""))

	_refresh_ai_ui_visibility()


func _restore_returned_setup_context() -> void:
	var context: Dictionary = GameManager.consume_deck_editor_return_context()
	if str(context.get("return_scene", "")) != "battle_setup":
		return
	_apply_setup_context(context)


func _refresh_deck_action_buttons() -> void:
	%Deck1ViewButton.disabled = _selected_deck_for_slot(0) == null
	%Deck1EditButton.disabled = _selected_deck_for_slot(0) == null
	%Deck2ViewButton.disabled = _selected_deck_for_slot(1) == null
	%Deck2EditButton.disabled = _is_ai_mode() or _selected_deck_for_slot(1) == null


func _on_deck_view_pressed(slot_index: int) -> void:
	var deck := _selected_deck_for_slot(slot_index)
	if deck == null:
		return
	if _is_ai_mode() and slot_index == 1 and %AIPreviewStrengthOption.selected == AI_PREVIEW_STRENGTH_STRONG:
		_show_strong_ai_preview_placeholder()
		return
	_deck_view_dialog.call("show_deck", self, deck)


func _show_strong_ai_preview_placeholder() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "强 AI 占位"
	dialog.dialog_text = "hello world"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	dialog.close_requested.connect(func() -> void:
		dialog.queue_free()
	)
	if is_inside_tree():
		dialog.popup_centered()


func _on_deck_edit_pressed(slot_index: int) -> void:
	if _is_ai_mode() and slot_index == 1:
		return
	var deck := _selected_deck_for_slot(slot_index)
	if deck == null:
		return
	var context := _capture_setup_selection_context()
	context["return_scene"] = "battle_setup"
	GameManager.goto_deck_editor(deck.id, context)


func _apply_default_deck_selection() -> void:
	_select_option_for_deck_id(%Deck1Option, DEFAULT_DECK1_ID)
	_select_option_for_deck_id(%Deck2Option, DEFAULT_DECK2_ID)
