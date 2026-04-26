extends Control

const CARD_IMAGE_DOWNLOADER := preload("res://scripts/network/CardImageDownloader.gd")
const DeckViewDialogScript := preload("res://scripts/ui/decks/DeckViewDialog.gd")

const CARD_TILE_WIDTH := 100
const CARD_TILE_HEIGHT := 140
const VIEW_GRID_COLUMNS := 6
const RENAME_DIALOG_SIZE := Vector2i(460, 230)
const HUD_ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const HUD_ACCENT_WARM := Color(1.0, 0.55, 0.24, 1.0)
const HUD_DANGER := Color(1.0, 0.28, 0.22, 1.0)
const HUD_TEXT := Color(0.92, 0.98, 1.0, 1.0)
const HUD_TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)

const ENERGY_TYPE_LABELS: Dictionary = {
	"R": "火", "W": "水", "G": "草", "L": "雷",
	"P": "超", "F": "斗", "D": "恶", "M": "钢", "N": "龙", "C": "无色",
}

var _importer: DeckImporter = null
var _image_syncer = null
var _current_operation: String = ""
var _panel_mode: String = "import"
var _pending_import_deck: DeckData = null
var _pending_import_errors: PackedStringArray = PackedStringArray()
var _rename_dialog: AcceptDialog = null
var _rename_input: LineEdit = null
var _rename_error_label: Label = null
var _rename_confirm_button: Button = null
var _rename_target_deck: DeckData = null
var _rename_ignore_deck_id: int = -1
var _rename_context: String = ""
var _rename_forced: bool = false
var _texture_cache: Dictionary = {}
var _failed_texture_paths: Dictionary = {}
var _deck_view_dialog: RefCounted = DeckViewDialogScript.new()


func _ready() -> void:
	_apply_hud_theme()
	%BtnImport.pressed.connect(_on_import_pressed)
	%BtnSyncImages.pressed.connect(_on_sync_images_pressed)
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnDoImport.pressed.connect(_on_do_import)
	%BtnCloseImport.pressed.connect(_on_close_import)

	CardDatabase.decks_changed.connect(_refresh_deck_list)
	_refresh_deck_list()

	_importer = DeckImporter.new()
	add_child(_importer)
	_importer.import_progress.connect(_on_import_progress)
	_importer.import_completed.connect(_on_import_completed)
	_importer.import_failed.connect(_on_import_failed)

	_image_syncer = CARD_IMAGE_DOWNLOADER.new()
	add_child(_image_syncer)
	_image_syncer.progress.connect(_on_image_sync_progress)
	_image_syncer.completed.connect(_on_image_sync_completed)
	_image_syncer.failed.connect(_on_image_sync_failed)


func _apply_hud_theme() -> void:
	var shade := get_node_or_null("BackgroundShade") as ColorRect
	if shade != null:
		shade.color = Color(0.01, 0.025, 0.045, 0.18)
	_ensure_hud_frame()
	_style_hud_labels_recursive(self)
	for button_name: String in ["BtnImport", "BtnSyncImages", "BtnBack", "BtnDoImport", "BtnCloseImport"]:
		var button := get_node_or_null("%" + button_name) as Button
		if button != null:
			_style_hud_button(button, HUD_ACCENT_WARM if button_name in ["BtnImport", "BtnDoImport"] else HUD_ACCENT)
	var import_box := find_child("ImportBox", true, false) as PanelContainer
	if import_box != null:
		import_box.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.92), Color(0.30, 0.86, 1.0, 0.92), 20))
	var import_bg := find_child("ImportBg", true, false) as ColorRect
	if import_bg != null:
		import_bg.color = Color(0.0, 0.0, 0.0, 0.42)
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	if url_input != null:
		_style_hud_line_edit(url_input)
	var empty_label := get_node_or_null("%EmptyLabel") as Label
	if empty_label != null:
		empty_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)


func _ensure_hud_frame() -> void:
	if get_node_or_null("HudFrame") != null:
		return
	var margin := get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		return
	var frame := PanelContainer.new()
	frame.name = "HudFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.layout_mode = margin.layout_mode
	frame.anchors_preset = margin.anchors_preset
	frame.anchor_left = margin.anchor_left
	frame.anchor_top = margin.anchor_top
	frame.anchor_right = margin.anchor_right
	frame.anchor_bottom = margin.anchor_bottom
	frame.offset_left = margin.offset_left + 8
	frame.offset_top = margin.offset_top + 8
	frame.offset_right = margin.offset_right - 8
	frame.offset_bottom = margin.offset_bottom - 8
	frame.grow_horizontal = margin.grow_horizontal
	frame.grow_vertical = margin.grow_vertical
	frame.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.72), Color(0.30, 0.86, 1.0, 0.86), 24))
	add_child(frame)
	move_child(frame, margin.get_index())


func _style_hud_labels_recursive(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if label.name in ["Title", "TitleLabel"]:
			label.add_theme_font_size_override("font_size", 32)
			label.add_theme_color_override("font_color", HUD_TEXT)
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.72))
			label.add_theme_constant_override("shadow_offset_y", 2)
		else:
			label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	for child: Node in node.get_children():
		_style_hud_labels_recursive(child)


func _hud_panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border.r, border.g, border.b, 0.22)
	style.shadow_size = 10
	style.set_content_margin_all(10)
	return style


func _hud_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.92) if pressed else Color(0.035, 0.075, 0.105, 0.92)
	if hover and not pressed:
		style.bg_color = Color(0.055, 0.13, 0.17, 0.96)
	style.border_color = accent
	style.set_border_width_all(2 if hover else 1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28 if hover else 0.12)
	style.shadow_size = 8 if hover else 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _style_hud_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.12, 0.16, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	button.add_theme_stylebox_override("normal", _hud_button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _hud_button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _hud_button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _hud_button_style(Color(0.26, 0.31, 0.36, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_hud_line_edit(input: LineEdit) -> void:
	input.add_theme_font_size_override("font_size", 15)
	input.add_theme_color_override("font_color", HUD_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.66, 0.74, 0.78))
	input.add_theme_color_override("caret_color", HUD_ACCENT)
	input.add_theme_stylebox_override("normal", _hud_input_style(false))
	input.add_theme_stylebox_override("focus", _hud_input_style(true))


func _hud_input_style(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.055, 0.88)
	if hover:
		style.bg_color = Color(0.025, 0.075, 0.105, 0.94)
	style.border_color = Color(0.23, 0.78, 1.0, 0.70 if hover else 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _refresh_deck_list() -> void:
	var deck_list_container: VBoxContainer = %DeckList
	for child: Node in deck_list_container.get_children():
		if child != %EmptyLabel:
			child.queue_free()

	var decks := CardDatabase.get_all_decks()
	%EmptyLabel.visible = decks.is_empty()

	for deck: DeckData in decks:
		deck_list_container.add_child(_create_deck_item(deck))


func _create_deck_item(deck: DeckData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.035, 0.075, 0.11, 0.88), Color(0.26, 0.84, 1.0, 0.58), 16))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = deck.deck_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", HUD_TEXT)
	info_vbox.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = "%d 张卡牌 | 导入于 %s" % [deck.total_cards, deck.import_date.substr(0, 10)]
	detail_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	info_vbox.add_child(detail_label)

	var btn_view := Button.new()
	btn_view.text = "查看"
	btn_view.custom_minimum_size = Vector2(70, 35)
	btn_view.pressed.connect(_on_view_deck.bind(deck))
	hbox.add_child(btn_view)

	var btn_edit := Button.new()
	btn_edit.text = "编辑"
	btn_edit.custom_minimum_size = Vector2(70, 35)
	btn_edit.pressed.connect(_on_edit_deck.bind(deck))
	hbox.add_child(btn_edit)

	var btn_rename := Button.new()
	btn_rename.text = "重命名"
	btn_rename.custom_minimum_size = Vector2(90, 35)
	btn_rename.pressed.connect(_on_rename_deck.bind(deck))
	hbox.add_child(btn_rename)

	var btn_delete := Button.new()
	btn_delete.text = "删除"
	btn_delete.custom_minimum_size = Vector2(70, 35)
	btn_delete.pressed.connect(_on_delete_deck.bind(deck))
	hbox.add_child(btn_delete)

	_style_hud_button(btn_view, HUD_ACCENT)
	_style_hud_button(btn_edit, HUD_ACCENT)
	_style_hud_button(btn_rename, HUD_ACCENT)
	_style_hud_button(btn_delete, HUD_DANGER)

	return panel


func _on_import_pressed() -> void:
	if _current_operation != "":
		return
	_panel_mode = "import"
	_configure_operation_panel()
	%UrlInput.text = ""
	%ProgressLabel.text = ""
	%ProgressBar.visible = false
	%BtnDoImport.disabled = false
	%ImportPanel.visible = true


func _on_close_import() -> void:
	if _current_operation != "":
		return
	%ImportPanel.visible = false


func _on_do_import() -> void:
	if _panel_mode != "import":
		return

	var url: String = %UrlInput.text.strip_edges()
	if url.is_empty():
		%ProgressLabel.text = "请输入卡组链接或卡组 ID。"
		return

	_current_operation = "import"
	_set_operation_busy(true)
	%BtnDoImport.disabled = true
	%ProgressBar.visible = true
	%ProgressBar.value = 0
	%ProgressLabel.text = "正在导入卡组..."
	_importer.import_deck(url)


func _on_sync_images_pressed() -> void:
	if _current_operation != "":
		return

	_panel_mode = "sync_images"
	_configure_operation_panel()
	%ImportPanel.visible = true
	_current_operation = "sync_images"
	_set_operation_busy(true)
	%ProgressBar.visible = true
	%ProgressBar.value = 0
	%ProgressLabel.text = "正在同步卡图..."
	_image_syncer.sync_cached_cards()


func _on_import_progress(current: int, total: int, message: String) -> void:
	%ProgressLabel.text = message
	if total > 0:
		%ProgressBar.value = (float(current) / total) * 100.0


func _on_import_completed(deck: DeckData, errors: PackedStringArray) -> void:
	if _has_duplicate_deck_name(deck.deck_name, deck.id):
		_pending_import_deck = deck
		_pending_import_errors = PackedStringArray(errors)
		_show_import_rename_dialog(deck.deck_name)
		return

	_finalize_import_save(deck, errors)


func _finalize_import_save(deck: DeckData, errors: PackedStringArray) -> void:
	CardDatabase.save_deck(deck)
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)
	%BtnDoImport.disabled = false

	if errors.is_empty():
		%ProgressLabel.text = "导入完成：%s（%d 张卡）" % [deck.deck_name, deck.total_cards]
	else:
		%ProgressLabel.text = "导入完成，包含 %d 条警告" % errors.size()
		for err: String in errors:
			push_warning("导入警告：%s" % err)


func _has_duplicate_deck_name(deck_name: String, ignored_deck_id: int = -1) -> bool:
	var normalized_name: String = deck_name.strip_edges()
	if normalized_name == "":
		return false

	for deck: DeckData in CardDatabase.get_all_decks():
		if deck.id == ignored_deck_id:
			continue
		if deck.deck_name.strip_edges() == normalized_name:
			return true

	return false


func _validate_deck_name(deck_name: String, ignored_deck_id: int = -1) -> String:
	var normalized_name: String = deck_name.strip_edges()
	if normalized_name == "":
		return "请输入卡组名称。"
	if _has_duplicate_deck_name(normalized_name, ignored_deck_id):
		return "已有已保存卡组使用该名称。"
	return ""


func _validate_import_deck_name(deck_name: String) -> String:
	return _validate_deck_name(deck_name)


func _on_rename_deck(deck: DeckData) -> void:
	_show_rename_dialog(
		deck.deck_name,
		"重命名卡组",
		"请输入新的卡组名称。",
		deck.id
	)
	_rename_target_deck = deck
	_rename_context = "existing"
	_rename_forced = false


func _show_import_rename_dialog(initial_name: String) -> void:
	_show_rename_dialog(
		initial_name,
		"卡组名称重复",
		"导入的卡组名称已存在，请输入一个不同的名称后再保存。",
		-1
	)
	_rename_target_deck = _pending_import_deck
	_rename_context = "import"
	_rename_forced = true


func _show_rename_dialog(initial_name: String, title: String, message_text: String, ignored_deck_id: int) -> void:
	_close_rename_dialog(false)

	_rename_ignore_deck_id = ignored_deck_id
	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = title
	_rename_dialog.ok_button_text = "\u786e\u8ba4"
	_rename_dialog.dialog_hide_on_ok = false
	_rename_dialog.min_size = RENAME_DIALOG_SIZE
	_rename_dialog.size = RENAME_DIALOG_SIZE
	_rename_dialog.close_requested.connect(_on_rename_close_requested)
	_rename_dialog.confirmed.connect(_on_confirm_rename)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(RENAME_DIALOG_SIZE.x - 40, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rename_dialog.add_child(scroll)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(RENAME_DIALOG_SIZE.x - 60, 0)
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	var message := Label.new()
	message.text = message_text
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(message)

	_rename_input = LineEdit.new()
	_rename_input.text = initial_name
	_rename_input.text_changed.connect(_on_rename_text_changed)
	content.add_child(_rename_input)

	_rename_error_label = Label.new()
	_rename_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_rename_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	content.add_child(_rename_error_label)

	add_child(_rename_dialog)
	_rename_confirm_button = _rename_dialog.get_ok_button()
	_on_rename_text_changed(initial_name)

	if is_inside_tree():
		_rename_dialog.popup_centered(RENAME_DIALOG_SIZE)

func _on_rename_text_changed(new_text: String) -> void:
	var validation_error: String = _validate_deck_name(new_text, _rename_ignore_deck_id)
	if _rename_error_label != null:
		_rename_error_label.text = validation_error
	if _rename_confirm_button != null:
		_rename_confirm_button.disabled = validation_error != ""


func _on_confirm_rename() -> void:
	if _rename_target_deck == null or _rename_input == null:
		return

	var new_name: String = _rename_input.text.strip_edges()
	var validation_error: String = _validate_deck_name(new_name, _rename_ignore_deck_id)
	if validation_error != "":
		_on_rename_text_changed(new_name)
		return

	var deck := _rename_target_deck
	var is_import_rename := _rename_context == "import"
	var errors := PackedStringArray(_pending_import_errors)
	deck.deck_name = new_name

	if is_import_rename:
		_pending_import_deck = null
		_pending_import_errors = PackedStringArray()
	else:
		CardDatabase.save_deck(deck)

	_close_rename_dialog()

	if is_import_rename:
		_finalize_import_save(deck, errors)


func _on_rename_close_requested() -> void:
	if _rename_forced:
		if _rename_dialog != null and is_instance_valid(_rename_dialog) and is_inside_tree():
			_rename_dialog.popup_centered(RENAME_DIALOG_SIZE)
		return

	_close_rename_dialog()


func _close_rename_dialog(clear_target: bool = true) -> void:
	if _rename_dialog != null and is_instance_valid(_rename_dialog):
		_rename_dialog.queue_free()

	_rename_dialog = null
	_rename_input = null
	_rename_error_label = null
	_rename_confirm_button = null
	_rename_ignore_deck_id = -1
	_rename_context = ""
	_rename_forced = false

	if clear_target:
		_rename_target_deck = null


func _on_import_rename_text_changed(new_text: String) -> void:
	_on_rename_text_changed(new_text)


func _on_confirm_import_rename() -> void:
	_on_confirm_rename()


func _on_import_rename_close_requested() -> void:
	_on_rename_close_requested()


func _close_import_rename_dialog() -> void:
	_close_rename_dialog()


func _on_import_failed(error_message: String) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)
	%BtnDoImport.disabled = false
	%ProgressLabel.text = "导入失败：%s" % error_message


func _on_image_sync_progress(current: int, total: int, message: String) -> void:
	%ProgressLabel.text = message
	if total > 0:
		%ProgressBar.value = (float(current) / total) * 100.0


func _on_image_sync_completed(stats: Dictionary, errors: PackedStringArray) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)

	var total := int(stats.get("total", 0))
	var downloaded := int(stats.get("downloaded", 0))
	var updated := int(stats.get("updated", 0))
	var skipped := int(stats.get("skipped", 0))

	if errors.is_empty():
		%ProgressLabel.text = "同步完成：共 %d 张，下载 %d 张，跳过 %d 张，更新 %d 张" % [
			total, downloaded, skipped, updated
		]
	else:
		%ProgressLabel.text = "同步完成：共 %d 张，下载 %d 张，警告 %d 条" % [
			total, downloaded, errors.size()
		]
		for err: String in errors:
			push_warning("卡图同步警告：%s" % err)


func _on_image_sync_failed(error_message: String) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)
	%ProgressLabel.text = "同步失败：%s" % error_message


func _on_edit_deck(deck: DeckData) -> void:
	GameManager.goto_deck_editor(deck.id)


func _on_view_deck(deck: DeckData) -> void:
	_deck_view_dialog.call("show_deck", self, deck)


const VIEW_CATEGORY_ORDER: Dictionary = {
	"Pokemon": 0,
	"Item": 1,
	"Tool": 2,
	"Supporter": 3,
	"Stadium": 4,
	"Basic Energy": 5,
	"Special Energy": 6,
}


func _sort_entries_by_category(cards: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = cards.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: int = VIEW_CATEGORY_ORDER.get(a.get("card_type", ""), 99)
		var ob: int = VIEW_CATEGORY_ORDER.get(b.get("card_type", ""), 99)
		if oa != ob:
			return oa < ob
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result


func _create_view_tile(card_name: String, set_code: String, card_index: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_TILE_WIDTH, CARD_TILE_HEIGHT + 20)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.22, 0.3, 1.0)
	sb.border_color = Color(0.3, 0.32, 0.4, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(CARD_TILE_WIDTH - 8, CARD_TILE_HEIGHT - 8)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var texture := _load_card_texture(set_code, card_index)
	if texture != null:
		tex_rect.texture = texture
	else:
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(CARD_TILE_WIDTH - 8, CARD_TILE_HEIGHT - 8)
		tex_rect.texture = placeholder
	vbox.add_child(tex_rect)

	var label := Label.new()
	label.text = card_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(CARD_TILE_WIDTH - 8, 0)
	vbox.add_child(label)

	return panel


func _on_view_tile_input(event: InputEvent, set_code: String, card_index: String) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		var card := CardDatabase.get_card(set_code, card_index)
		if card != null:
			_show_card_detail(card)


func _show_card_detail(card: CardData) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = card.name
	dialog.ok_button_text = "关闭"
	dialog.size = Vector2i(500, 480)

	var scroll := ScrollContainer.new()
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	scroll.offset_left = 8
	scroll.offset_top = 8
	scroll.offset_right = -8
	scroll.offset_bottom = -8
	dialog.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	var header := Label.new()
	header.text = card.name
	header.add_theme_font_size_override("font_size", 20)
	content.add_child(header)

	var meta_parts: PackedStringArray = []
	meta_parts.append(card.card_type)
	if card.mechanic != "":
		meta_parts.append(card.mechanic)
	if card.set_code != "":
		meta_parts.append("%s %s" % [card.set_code, card.card_index])
	if card.rarity != "":
		meta_parts.append(card.rarity)
	var meta_label := Label.new()
	meta_label.text = " | ".join(meta_parts)
	meta_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content.add_child(meta_label)

	if card.is_pokemon():
		_add_detail_separator(content)
		var stat_parts: PackedStringArray = []
		stat_parts.append("HP %d" % card.hp)
		stat_parts.append("属性: %s" % _energy_display(card.energy_type))
		stat_parts.append("阶段: %s" % card.stage)
		stat_parts.append("撤退: %d" % card.retreat_cost)
		var stat_label := Label.new()
		stat_label.text = " | ".join(stat_parts)
		content.add_child(stat_label)

		if card.evolves_from != "":
			var evo_label := Label.new()
			evo_label.text = "从 %s 进化" % card.evolves_from
			content.add_child(evo_label)

		var weakness_text := ""
		if card.weakness_energy != "":
			weakness_text = "弱点: %s %s" % [_energy_display(card.weakness_energy), card.weakness_value]
		var resist_text := ""
		if card.resistance_energy != "":
			resist_text = "抗性: %s %s" % [_energy_display(card.resistance_energy), card.resistance_value]
		if weakness_text != "" or resist_text != "":
			var wr_label := Label.new()
			wr_label.text = "  ".join([weakness_text, resist_text]).strip_edges()
			content.add_child(wr_label)

		for ab: Dictionary in card.abilities:
			_add_detail_separator(content)
			var ab_title := Label.new()
			ab_title.text = "[特性] %s" % ab.get("name", "")
			ab_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			content.add_child(ab_title)
			if ab.get("text", "") != "":
				var ab_text := Label.new()
				ab_text.text = str(ab.get("text", ""))
				ab_text.autowrap_mode = TextServer.AUTOWRAP_WORD
				content.add_child(ab_text)

		for atk: Dictionary in card.attacks:
			_add_detail_separator(content)
			var cost_str: String = str(atk.get("cost", ""))
			var dmg_str: String = str(atk.get("damage", ""))
			var atk_header := Label.new()
			var parts: PackedStringArray = []
			if cost_str != "":
				parts.append("[%s]" % cost_str)
			parts.append(str(atk.get("name", "")))
			if dmg_str != "":
				parts.append(dmg_str)
			atk_header.text = " ".join(parts)
			atk_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
			content.add_child(atk_header)
			if atk.get("text", "") != "":
				var atk_text := Label.new()
				atk_text.text = str(atk.get("text", ""))
				atk_text.autowrap_mode = TextServer.AUTOWRAP_WORD
				content.add_child(atk_text)

	if card.description != "":
		_add_detail_separator(content)
		var desc := Label.new()
		desc.text = card.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(desc)

	if card.effect_id != "":
		_add_detail_separator(content)
		var eid := Label.new()
		eid.text = "效果ID: %s" % card.effect_id
		eid.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content.add_child(eid)

	if card.name_en != "":
		var en_label := Label.new()
		en_label.text = "英文名: %s" % card.name_en
		en_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content.add_child(en_label)

	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _add_detail_separator(container: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	container.add_child(sep)


func _energy_display(energy_code: String) -> String:
	return ENERGY_TYPE_LABELS.get(energy_code, energy_code)


func _load_card_texture(set_code: String, card_index: String) -> Texture2D:
	var file_path := CardData.resolve_existing_image_path(
		CardData.get_image_candidate_paths(set_code, card_index)
	)
	if file_path == "":
		return null
	if _texture_cache.has(file_path):
		return _texture_cache[file_path]
	if _failed_texture_paths.has(file_path):
		return null
	var image_bytes := FileAccess.get_file_as_bytes(file_path)
	if image_bytes.is_empty():
		_failed_texture_paths[file_path] = true
		return null
	var image := Image.new()
	var err := _load_image_from_buffer(image, image_bytes)
	if err != OK:
		_failed_texture_paths[file_path] = true
		return null
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[file_path] = texture
	return texture


func _load_image_from_buffer(image: Image, image_bytes: PackedByteArray) -> int:
	if image_bytes.size() >= 12:
		if image_bytes[0] == 0x89 and image_bytes[1] == 0x50 and image_bytes[2] == 0x4E and image_bytes[3] == 0x47:
			return image.load_png_from_buffer(image_bytes)
		if image_bytes[0] == 0xFF and image_bytes[1] == 0xD8:
			return image.load_jpg_from_buffer(image_bytes)
		if image_bytes[0] == 0x52 and image_bytes[1] == 0x49 and image_bytes[2] == 0x46 and image_bytes[3] == 0x46:
			if image_bytes[8] == 0x57 and image_bytes[9] == 0x45 and image_bytes[10] == 0x42 and image_bytes[11] == 0x50:
				return image.load_webp_from_buffer(image_bytes)
	return ERR_FILE_UNRECOGNIZED


func _on_delete_deck(deck: DeckData) -> void:
	var confirm := ConfirmationDialog.new()
	confirm.title = "确认删除"
	confirm.dialog_text = "确定要删除卡组“%s”吗？" % deck.deck_name
	confirm.ok_button_text = "删除"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func() -> void:
		CardDatabase.delete_deck(deck.id)
		confirm.queue_free()
	)
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()


func _on_back_pressed() -> void:
	GameManager.goto_main_menu()


func _configure_operation_panel() -> void:
	var title_label: Label = $ImportPanel/ImportBox/VBox/TitleLabel
	var hint_label: Label = $ImportPanel/ImportBox/VBox/HintLabel

	if _panel_mode == "sync_images":
		title_label.text = "同步卡图"
		hint_label.visible = false
		%UrlInput.visible = false
		%BtnDoImport.visible = false
	else:
		title_label.text = "导入卡组"
		hint_label.visible = true
		%UrlInput.visible = true
		%BtnDoImport.visible = true

	%BtnCloseImport.text = "关闭"


func _set_operation_busy(busy: bool) -> void:
	%BtnImport.disabled = busy
	%BtnSyncImages.disabled = busy
	%BtnBack.disabled = busy
