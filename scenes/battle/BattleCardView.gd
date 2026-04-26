class_name BattleCardView
extends PanelContainer

signal left_clicked(card_instance: CardInstance, card_data: CardData)
signal right_clicked(card_instance: CardInstance, card_data: CardData)

const MODE_HAND := "hand"
const MODE_SLOT_ACTIVE := "slot_active"
const MODE_SLOT_BENCH := "slot_bench"
const MODE_CHOICE := "choice"
const MODE_PREVIEW := "preview"
const ENERGY_ICON_TEXTURES := {
	"R": preload("res://assets/ui/e-huo.png"),
	"W": preload("res://assets/ui/e-shui.png"),
	"G": preload("res://assets/ui/e-cao.png"),
	"L": preload("res://assets/ui/e-lei.png"),
	"P": preload("res://assets/ui/e-chao.png"),
	"F": preload("res://assets/ui/e-dou.png"),
	"D": preload("res://assets/ui/e-e.png"),
	"M": preload("res://assets/ui/e-gang.png"),
	"N": preload("res://assets/ui/e-long.png"),
	"C": preload("res://assets/ui/e-wu.png"),
}

static var _texture_cache: Dictionary = {}
static var _failed_texture_paths: Dictionary = {}

var card_instance: CardInstance = null
var card_data: CardData = null
var display_mode: String = MODE_HAND
var _selected: bool = false
var _selectable_hint: bool = false
var _selectable_hint_text: String = "可选"
var _selected_badge_text: String = "已选"
var _disabled: bool = false
var _face_down: bool = false
var _clickable: bool = true
var _back_texture: Texture2D = null
var _battle_status_active: bool = false
var _battle_status: Dictionary = {}
var _compact_preview: bool = false
var _tilt_degrees: float = 0.0

var _outer_margin: MarginContainer
var _art_frame: PanelContainer

var _texture_rect: TextureRect
var _missing_art_panel: PanelContainer
var _placeholder: Label
var _top_left_badge: Label
var _top_right_badge: Label
var _info_panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _status_hud: VBoxContainer
var _status_used_panel: PanelContainer
var _status_used_label: Label
var _status_hp_value_label: Label
var _status_hp_bar_panel: PanelContainer
var _status_hp_bar: ProgressBar
var _status_energy_panel: PanelContainer
var _status_energy_row: HBoxContainer
var _status_tool_panel: PanelContainer
var _status_tool_label: Label
var _selection_overlay: PanelContainer
var _selection_badge_panel: PanelContainer
var _selection_badge: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if _clickable else Control.MOUSE_FILTER_IGNORE
	_ensure_ui()
	_refresh()
	_apply_tilt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_tilt()


func setup_from_instance(inst: CardInstance = null, mode: String = MODE_HAND) -> void:
	_ensure_ui()
	card_instance = inst
	card_data = inst.card_data if inst != null else null
	display_mode = mode
	_selected = false
	_selectable_hint = false
	clear_battle_status()
	_refresh()


func setup_from_card_data(data: CardData, mode: String = MODE_CHOICE) -> void:
	_ensure_ui()
	card_instance = null
	card_data = data
	display_mode = mode
	_selected = false
	_selectable_hint = false
	clear_battle_status()
	_refresh()


func set_selected(selected: bool) -> void:
	_ensure_ui()
	_selected = selected
	_update_style()


func set_selectable_hint(selectable_hint: bool) -> void:
	_ensure_ui()
	_selectable_hint = selectable_hint
	_update_style()


func set_selectable_hint_text(text: String) -> void:
	_ensure_ui()
	_selectable_hint_text = text.strip_edges() if text.strip_edges() != "" else "可选"
	_update_style()


func set_selected_badge_text(text: String) -> void:
	_ensure_ui()
	_selected_badge_text = text.strip_edges() if text.strip_edges() != "" else "已选"
	_update_style()


func set_disabled(disabled: bool) -> void:
	_ensure_ui()
	_disabled = disabled
	_update_style()


func set_face_down(face_down: bool) -> void:
	_ensure_ui()
	_face_down = face_down
	_refresh()


func set_back_texture(texture: Texture2D) -> void:
	_ensure_ui()
	_back_texture = texture
	_refresh()


func set_clickable(clickable: bool) -> void:
	_clickable = clickable
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE


func set_compact_preview(compact: bool) -> void:
	_compact_preview = compact
	_ensure_ui()
	_update_layout()
	_update_style()


func set_tilt_degrees(degrees: float) -> void:
	_tilt_degrees = degrees
	_apply_tilt()


func set_badges(left_text: String = "", right_text: String = "") -> void:
	_ensure_ui()
	_top_left_badge.text = left_text
	_top_left_badge.visible = left_text != ""
	_top_right_badge.text = right_text
	_top_right_badge.visible = right_text != ""


func set_info(title_text: String, subtitle_text: String = "") -> void:
	_ensure_ui()
	_battle_status_active = false
	_title_label.text = title_text
	_title_label.visible = title_text != ""
	_subtitle_label.text = subtitle_text
	_subtitle_label.visible = subtitle_text != ""
	_update_overlay_visibility()


func clear_battle_status() -> void:
	_ensure_ui()
	_battle_status_active = false
	_battle_status.clear()
	_update_overlay_visibility()


func set_battle_status(data: Dictionary) -> void:
	_ensure_ui()
	_battle_status_active = true
	_battle_status = data.duplicate(true)
	_update_battle_status_ui()
	_update_overlay_visibility()


func _build_ui() -> void:
	if _texture_rect != null:
		return

	_outer_margin = MarginContainer.new()
	_make_passthrough(_outer_margin)
	_outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_outer_margin)

	var aspect := AspectRatioContainer.new()
	_make_passthrough(aspect)
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aspect.ratio = 0.716
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_outer_margin.add_child(aspect)

	_art_frame = PanelContainer.new()
	_make_passthrough(_art_frame)
	_art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aspect.add_child(_art_frame)

	_texture_rect = TextureRect.new()
	_make_passthrough(_texture_rect)
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_frame.add_child(_texture_rect)

	_missing_art_panel = PanelContainer.new()
	_make_passthrough(_missing_art_panel)
	_missing_art_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_frame.add_child(_missing_art_panel)

	var missing_margin := MarginContainer.new()
	_make_passthrough(missing_margin)
	missing_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	missing_margin.add_theme_constant_override("margin_left", 12)
	missing_margin.add_theme_constant_override("margin_top", 14)
	missing_margin.add_theme_constant_override("margin_right", 12)
	missing_margin.add_theme_constant_override("margin_bottom", 14)
	_missing_art_panel.add_child(missing_margin)

	_placeholder = Label.new()
	_make_passthrough(_placeholder)
	_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placeholder.add_theme_font_size_override("font_size", 12)
	missing_margin.add_child(_placeholder)

	var overlay := MarginContainer.new()
	_make_passthrough(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 8)
	overlay.add_theme_constant_override("margin_top", 6)
	overlay.add_theme_constant_override("margin_right", 8)
	overlay.add_theme_constant_override("margin_bottom", 6)
	_art_frame.add_child(overlay)

	var overlay_vbox := VBoxContainer.new()
	_make_passthrough(overlay_vbox)
	overlay_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay.add_child(overlay_vbox)

	var badge_row := HBoxContainer.new()
	_make_passthrough(badge_row)
	badge_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	badge_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_row.add_theme_constant_override("separation", 6)
	overlay_vbox.add_child(badge_row)

	_top_left_badge = _make_badge_label()
	badge_row.add_child(_top_left_badge)

	var spacer := Control.new()
	_make_passthrough(spacer)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_row.add_child(spacer)

	_top_right_badge = _make_badge_label()
	_top_right_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_row.add_child(_top_right_badge)

	var grow := Control.new()
	_make_passthrough(grow)
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_vbox.add_child(grow)

	_status_hud = VBoxContainer.new()
	_make_passthrough(_status_hud)
	_status_hud.add_theme_constant_override("separation", 3)
	overlay_vbox.add_child(_status_hud)

	_status_used_panel = _make_status_panel()
	_status_hud.add_child(_status_used_panel)
	var used_margin := _make_status_margin(6, 2, 6, 2)
	_status_used_panel.add_child(used_margin)
	_status_used_label = Label.new()
	_make_passthrough(_status_used_label)
	_status_used_label.text = "USED"
	_status_used_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_used_label.add_theme_font_size_override("font_size", 10)
	var used_font := FontVariation.new()
	used_font.base_font = ThemeDB.fallback_font
	used_font.variation_embolden = 1.1
	_status_used_label.add_theme_font_override("font", used_font)
	used_margin.add_child(_status_used_label)

	_status_hp_bar_panel = _make_status_panel()
	_status_hud.add_child(_status_hp_bar_panel)
	var hp_bar_margin := _make_status_margin(6, 3, 6, 3)
	_status_hp_bar_panel.add_child(hp_bar_margin)
	var hp_bar_overlay := Control.new()
	_make_passthrough(hp_bar_overlay)
	hp_bar_overlay.custom_minimum_size = Vector2(0, 16)
	hp_bar_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar_margin.add_child(hp_bar_overlay)

	_status_hp_bar = ProgressBar.new()
	_make_passthrough(_status_hp_bar)
	_status_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_hp_bar.offset_top = 3
	_status_hp_bar.offset_bottom = -3
	_status_hp_bar.min_value = 0.0
	_status_hp_bar.max_value = 100.0
	_status_hp_bar.show_percentage = false
	hp_bar_overlay.add_child(_status_hp_bar)

	_status_hp_value_label = Label.new()
	_make_passthrough(_status_hp_value_label)
	_status_hp_value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_hp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hp_font := FontVariation.new()
	hp_font.base_font = ThemeDB.fallback_font
	hp_font.variation_embolden = 1.2
	_status_hp_value_label.add_theme_font_override("font", hp_font)
	_status_hp_value_label.add_theme_font_size_override("font_size", 12)
	hp_bar_overlay.add_child(_status_hp_value_label)

	_status_energy_panel = _make_status_panel()
	_status_hud.add_child(_status_energy_panel)
	var energy_margin := _make_status_margin(6, 3, 6, 3)
	_status_energy_panel.add_child(energy_margin)
	_status_energy_row = HBoxContainer.new()
	_make_passthrough(_status_energy_row)
	_status_energy_row.add_theme_constant_override("separation", 2)
	energy_margin.add_child(_status_energy_row)

	_status_tool_panel = _make_status_panel(true)
	_status_hud.add_child(_status_tool_panel)
	var tool_margin := _make_status_margin(8, 2, 8, 2)
	_status_tool_panel.add_child(tool_margin)
	_status_tool_label = Label.new()
	_make_passthrough(_status_tool_label)
	_status_tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_tool_label.add_theme_font_size_override("font_size", 9)
	tool_margin.add_child(_status_tool_label)

	_info_panel = PanelContainer.new()
	_make_passthrough(_info_panel)
	overlay_vbox.add_child(_info_panel)

	var info_margin := MarginContainer.new()
	_make_passthrough(info_margin)
	info_margin.add_theme_constant_override("margin_left", 8)
	info_margin.add_theme_constant_override("margin_top", 4)
	info_margin.add_theme_constant_override("margin_right", 8)
	info_margin.add_theme_constant_override("margin_bottom", 4)
	_info_panel.add_child(info_margin)

	var info_vbox := VBoxContainer.new()
	_make_passthrough(info_vbox)
	info_vbox.add_theme_constant_override("separation", 2)
	info_margin.add_child(info_vbox)

	_title_label = Label.new()
	_make_passthrough(_title_label)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_make_passthrough(_subtitle_label)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 9)
	_subtitle_label.modulate = Color(0.92, 0.92, 0.92)
	info_vbox.add_child(_subtitle_label)

	_status_hud.visible = false
	_info_panel.visible = false

	_selection_overlay = PanelContainer.new()
	_make_passthrough(_selection_overlay)
	_selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_overlay.visible = false
	_art_frame.add_child(_selection_overlay)

	var selection_margin := MarginContainer.new()
	_make_passthrough(selection_margin)
	selection_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_margin.add_theme_constant_override("margin_left", 8)
	selection_margin.add_theme_constant_override("margin_top", 7)
	selection_margin.add_theme_constant_override("margin_right", 8)
	selection_margin.add_theme_constant_override("margin_bottom", 7)
	_selection_overlay.add_child(selection_margin)

	var selection_box := VBoxContainer.new()
	_make_passthrough(selection_box)
	selection_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_margin.add_child(selection_box)

	var selection_row := HBoxContainer.new()
	_make_passthrough(selection_row)
	selection_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_box.add_child(selection_row)

	var selection_spacer := Control.new()
	_make_passthrough(selection_spacer)
	selection_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_row.add_child(selection_spacer)

	_selection_badge_panel = PanelContainer.new()
	_make_passthrough(_selection_badge_panel)
	_selection_badge_panel.add_theme_stylebox_override("panel", _make_selection_badge_style(true))
	selection_row.add_child(_selection_badge_panel)

	var badge_margin := MarginContainer.new()
	_make_passthrough(badge_margin)
	badge_margin.add_theme_constant_override("margin_left", 10)
	badge_margin.add_theme_constant_override("margin_top", 3)
	badge_margin.add_theme_constant_override("margin_right", 10)
	badge_margin.add_theme_constant_override("margin_bottom", 3)
	_selection_badge_panel.add_child(badge_margin)

	_selection_badge = Label.new()
	_make_passthrough(_selection_badge)
	_selection_badge.text = "已选"
	_selection_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selection_badge.add_theme_font_size_override("font_size", 12)
	_selection_badge.add_theme_color_override("font_color", Color(0.10, 0.06, 0.00, 1.0))
	var selection_font := FontVariation.new()
	selection_font.base_font = ThemeDB.fallback_font
	selection_font.variation_embolden = 1.4
	_selection_badge.add_theme_font_override("font", selection_font)
	badge_margin.add_child(_selection_badge)

	var selection_grow := Control.new()
	_make_passthrough(selection_grow)
	selection_grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_box.add_child(selection_grow)

	set_badges()
	_update_layout()
	_update_style()


func _update_layout() -> void:
	if _outer_margin == null:
		return
	var outer_pad: int = 0 if _compact_preview else 4
	_outer_margin.add_theme_constant_override("margin_left", outer_pad)
	_outer_margin.add_theme_constant_override("margin_top", outer_pad)
	_outer_margin.add_theme_constant_override("margin_right", outer_pad)
	_outer_margin.add_theme_constant_override("margin_bottom", outer_pad)


func _ensure_ui() -> void:
	if _texture_rect == null:
		_build_ui()


func _make_badge_label() -> Label:
	var label := Label.new()
	_make_passthrough(label)
	label.visible = false
	label.add_theme_font_size_override("font_size", 10)
	return label


func _make_status_panel(light: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	_make_passthrough(panel)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.modulate = Color(1, 1, 1, 1) if not light else Color(0.98, 0.98, 0.94, 1.0)
	return panel


func _make_status_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	_make_passthrough(margin)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _make_selection_badge_style(selected: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(1.0, 0.78, 0.08, 0.96)
		style.border_color = Color(1.0, 0.96, 0.48, 1.0)
		style.shadow_color = Color(1.0, 0.66, 0.08, 0.55)
	else:
		style.bg_color = Color(0.36, 0.95, 1.0, 0.72)
		style.border_color = Color(0.78, 1.0, 1.0, 0.78)
		style.shadow_color = Color(0.12, 0.72, 1.0, 0.24)
	style.set_border_width_all(2)
	style.set_corner_radius_all(999)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_passthrough(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh() -> void:
	_ensure_ui()

	var texture: Texture2D = _back_texture if _face_down else _load_texture(card_data)
	_texture_rect.texture = texture
	var show_missing_art := texture == null and not _face_down and card_data != null
	if _missing_art_panel != null:
		_missing_art_panel.visible = show_missing_art
	_placeholder.visible = texture == null and not _face_down
	_placeholder.text = _missing_art_text() if show_missing_art else _placeholder_text()

	if display_mode == MODE_PREVIEW:
		set_info("", "")
	elif card_data != null:
		set_info(card_data.name, _default_subtitle())
	else:
		set_info("", "")

	if _battle_status_active:
		_update_battle_status_ui()
		_update_overlay_visibility()

	_update_style()
	_apply_tilt()


func _placeholder_text() -> String:
	if _face_down:
		return ""
	if card_data == null:
		if display_mode == MODE_SLOT_ACTIVE or display_mode == MODE_SLOT_BENCH:
			return ""
		return "空位"
	return card_data.name


func _missing_art_text() -> String:
	if card_data == null:
		return ""

	var lines: Array[String] = [card_data.name]
	if card_data.card_type != "":
		lines.append(card_data.card_type)
	if card_data.is_pokemon() and card_data.hp > 0:
		lines.append("HP %d" % card_data.hp)
	elif card_data.energy_provides != "":
		lines.append("能量 %s" % card_data.energy_provides)
	lines.append("图片缺失")
	return "\n".join(lines)


func _default_subtitle() -> String:
	if card_data == null:
		return ""

	match display_mode:
		MODE_SLOT_ACTIVE, MODE_SLOT_BENCH:
			return card_data.card_type
		MODE_CHOICE:
			return "%s | %s" % [card_data.name, card_data.card_type]
		MODE_PREVIEW:
			return ""
		_:
			if card_data.is_pokemon():
				return "HP %d" % card_data.hp
			return card_data.card_type


func _load_texture(data: CardData) -> Texture2D:
	if data == null:
		return null

	var file_path := CardData.resolve_existing_image_path(
		CardData.get_image_candidate_paths(data.set_code, data.card_index, data.image_local_path)
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
		if image_bytes[0] == 0x52 and image_bytes[1] == 0x49 and image_bytes[2] == 0x46 and image_bytes[3] == 0x46 and image_bytes[8] == 0x57 and image_bytes[9] == 0x45 and image_bytes[10] == 0x42 and image_bytes[11] == 0x50:
			return image.load_webp_from_buffer(image_bytes)
	if image_bytes.size() >= 2 and image_bytes[0] == 0xFF and image_bytes[1] == 0xD8:
		return image.load_jpg_from_buffer(image_bytes)
	return ERR_FILE_UNRECOGNIZED


func _update_overlay_visibility() -> void:
	if _status_hud == null or _info_panel == null:
		return
	if _battle_status_active:
		_status_hud.visible = true
		_info_panel.visible = false
		return
	_status_hud.visible = false
	_info_panel.visible = _title_label.visible or _subtitle_label.visible


func _update_battle_status_ui() -> void:
	if _status_hud == null:
		return

	var hp_current := int(_battle_status.get("hp_current", 0))
	var hp_max := maxi(int(_battle_status.get("hp_max", 0)), 1)
	var hp_ratio := clampf(float(_battle_status.get("hp_ratio", float(hp_current) / float(hp_max))), 0.0, 1.0)
	_status_used_panel.visible = bool(_battle_status.get("ability_used_this_turn", false))
	_status_hp_value_label.text = "%d/%d" % [hp_current, hp_max]
	_status_hp_bar.value = hp_ratio * 100.0

	var energy_icons_raw: Variant = _battle_status.get("energy_icons", [])
	_clear_children(_status_energy_row)
	var energy_count := 0
	for energy_code_variant: Variant in energy_icons_raw:
		var energy_code := str(energy_code_variant)
		_status_energy_row.add_child(_make_energy_icon(energy_code))
		energy_count += 1
	_status_energy_panel.visible = energy_count > 0

	var tool_name := str(_battle_status.get("tool_name", ""))
	_status_tool_label.text = tool_name
	_status_tool_panel.visible = tool_name != ""


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _make_energy_icon(energy_code: String) -> Control:
	var texture: Texture2D = ENERGY_ICON_TEXTURES.get(energy_code, null)
	if texture != null:
		var rect := TextureRect.new()
		_make_passthrough(rect)
		rect.texture = texture
		rect.custom_minimum_size = Vector2(14, 14)
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return rect

	var chip := Label.new()
	_make_passthrough(chip)
	chip.text = energy_code
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.custom_minimum_size = Vector2(16, 14)
	chip.add_theme_font_size_override("font_size", 9)
	return chip


func _update_style() -> void:
	if _info_panel == null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 1.0)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.set_border_width_all(2)
	style.border_color = Color(0.24, 0.3, 0.4)
	style.set_content_margin_all(2)
	if _selected:
		style.bg_color = Color(0.13, 0.11, 0.05, 1.0)
		style.border_color = Color(1.0, 0.78, 0.10, 0.82)
		style.set_border_width_all(4)
		style.set_content_margin_all(4)
		style.shadow_color = Color(1.0, 0.70, 0.08, 0.32)
		style.shadow_size = 8
		style.shadow_offset = Vector2.ZERO
	elif _selectable_hint:
		style.bg_color = Color(0.04, 0.12, 0.16, 1.0)
		style.border_color = Color(0.28, 0.88, 1.0, 0.32)
		style.set_border_width_all(2)
		style.set_content_margin_all(2)
		style.shadow_color = Color(0.18, 0.78, 1.0, 0.10)
		style.shadow_size = 4
		style.shadow_offset = Vector2.ZERO
	if _disabled:
		style.border_color = Color(0.35, 0.35, 0.35)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if _art_frame != null:
		_art_frame.add_theme_stylebox_override("panel", style)
	if _missing_art_panel != null:
		var missing_style := StyleBoxFlat.new()
		missing_style.bg_color = Color(0.95, 0.95, 0.9, 0.98)
		missing_style.border_color = Color(0.24, 0.28, 0.34, 0.88)
		missing_style.set_border_width_all(2)
		missing_style.set_corner_radius_all(12)
		_missing_art_panel.add_theme_stylebox_override("panel", missing_style)
	if _placeholder != null:
		_placeholder.modulate = Color(0.14, 0.15, 0.18) if _missing_art_panel != null and _missing_art_panel.visible else Color(0.92, 0.94, 0.98)
		_placeholder.add_theme_font_size_override("font_size", 14 if _missing_art_panel != null and _missing_art_panel.visible else 12)
	if _selection_overlay != null:
		_selection_overlay.visible = (_selected or _selectable_hint) and not _disabled
		var selection_style := StyleBoxFlat.new()
		if _selected:
			selection_style.bg_color = Color(1.0, 0.74, 0.08, 0.06)
			selection_style.border_color = Color(1.0, 0.88, 0.22, 0.72)
			selection_style.shadow_color = Color(1.0, 0.62, 0.02, 0.30)
			selection_style.set_border_width_all(3)
		else:
			selection_style.bg_color = Color(0.08, 0.86, 1.0, 0.025)
			selection_style.border_color = Color(0.25, 0.92, 1.0, 0.58)
			selection_style.shadow_color = Color(0.10, 0.74, 1.0, 0.16)
			selection_style.set_border_width_all(3)
		selection_style.set_corner_radius_all(14)
		selection_style.shadow_size = 10
		selection_style.shadow_offset = Vector2.ZERO
		_selection_overlay.add_theme_stylebox_override("panel", selection_style)
	if _selection_badge_panel != null:
		_selection_badge_panel.modulate = Color(1, 1, 1, 0.92 if _selected else 0.78)
		_selection_badge_panel.add_theme_stylebox_override("panel", _make_selection_badge_style(_selected))
	if _selection_badge != null:
		_selection_badge.text = _selected_badge_text if _selected else _selectable_hint_text
		_selection_badge.add_theme_color_override("font_color", Color(0.10, 0.06, 0.00, 1.0) if _selected else Color(0.01, 0.10, 0.14, 1.0))

	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.05, 0.07, 0.11, 0.78)
	overlay_style.corner_radius_top_left = 10
	overlay_style.corner_radius_top_right = 10
	overlay_style.corner_radius_bottom_right = 10
	overlay_style.corner_radius_bottom_left = 10
	_info_panel.add_theme_stylebox_override("panel", overlay_style)
	_apply_status_styles()

	modulate = Color(0.55, 0.55, 0.55) if _disabled else Color(1, 1, 1)
	if _texture_rect != null:
		_texture_rect.modulate = Color(0.8, 0.8, 0.8) if _disabled else Color(1, 1, 1)


func _apply_status_styles() -> void:
	if _status_hp_bar_panel == null:
		return

	var used_style := StyleBoxFlat.new()
	used_style.bg_color = Color(0.05, 0.11, 0.18, 0.9)
	used_style.set_corner_radius_all(8)
	used_style.set_border_width_all(2)
	used_style.border_color = Color(0.2, 0.78, 0.96, 0.85)
	_status_used_panel.add_theme_stylebox_override("panel", used_style)
	_status_used_label.modulate = Color(0.82, 0.97, 1.0, 1.0)
	_status_used_label.add_theme_color_override("font_color", Color(0.82, 0.97, 1.0, 1.0))
	_status_used_label.add_theme_constant_override("outline_size", 1)
	_status_used_label.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.14, 0.95))

	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(0.04, 0.06, 0.1, 0.8)
	strip_style.set_corner_radius_all(8)
	_status_energy_panel.add_theme_stylebox_override("panel", strip_style)

	var tool_style := StyleBoxFlat.new()
	tool_style.bg_color = Color(0.94, 0.95, 0.9, 0.74)
	tool_style.set_corner_radius_all(8)
	_status_tool_panel.add_theme_stylebox_override("panel", tool_style)
	_status_tool_label.modulate = Color(0.1, 0.12, 0.14)
	_status_hp_value_label.modulate = Color(1, 1, 1)
	_status_hp_value_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	_status_hp_value_label.add_theme_constant_override("outline_size", 0)

	var bar_panel_style := StyleBoxFlat.new()
	bar_panel_style.bg_color = Color(0.04, 0.06, 0.1, 0.86)
	bar_panel_style.set_corner_radius_all(8)
	_status_hp_bar_panel.add_theme_stylebox_override("panel", bar_panel_style)

	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.15, 0.18, 0.22, 0.95)
	bar_background.set_corner_radius_all(4)
	_status_hp_bar.add_theme_stylebox_override("background", bar_background)

	var hp_ratio := clampf(float(_battle_status.get("hp_ratio", 1.0)), 0.0, 1.0)
	var fill_color := Color(0.24, 0.83, 0.42, 0.98)
	if hp_ratio <= 0.5:
		fill_color = Color(0.95, 0.76, 0.22, 0.98)
	if hp_ratio <= 0.2:
		fill_color = Color(0.92, 0.24, 0.2, 0.98)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = fill_color
	bar_fill.set_corner_radius_all(4)
	_status_hp_bar.add_theme_stylebox_override("fill", bar_fill)


func _apply_tilt() -> void:
	rotation_degrees = 0.0
	z_index = 20 if _selected else (10 if _selectable_hint else 0)
	if _art_frame == null:
		return
	_art_frame.rotation_degrees = 0.0


func _gui_input(event: InputEvent) -> void:
	if not _clickable:
		return
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if not mbe.pressed:
			return
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			left_clicked.emit(card_instance, card_data)
		elif mbe.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit(card_instance, card_data)
