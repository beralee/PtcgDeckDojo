extends RefCounted

const ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const ACCENT_WARM := Color(1.0, 0.55, 0.24, 1.0)
const TEXT := Color(0.92, 0.98, 1.0, 1.0)
const TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)


static func apply(root: Node) -> void:
	if root == null:
		return
	var shade := root.get_node_or_null("BackgroundShade") as ColorRect
	if shade != null:
		shade.color = Color(0.01, 0.025, 0.045, 0.18)
	_apply_recursive(root)


static func _apply_recursive(node: Node) -> void:
	if node is PanelContainer:
		_style_panel(node as PanelContainer)
	elif node is Button:
		var accent := ACCENT_WARM if node.name in ["BtnStart", "BtnNext", "BtnStartRound", "BtnPrimary"] else ACCENT
		_style_button(node as Button, accent)
	elif node is OptionButton:
		_style_option(node as OptionButton)
	elif node is LineEdit:
		_style_line_edit(node as LineEdit)
	elif node is TextEdit:
		_style_text_edit(node as TextEdit)
	elif node is RichTextLabel:
		_style_rich_text(node as RichTextLabel)
	elif node is Label:
		_style_label(node as Label)

	for child: Node in node.get_children():
		_apply_recursive(child)


static func _style_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(
		Color(0.025, 0.055, 0.085, 0.76),
		Color(0.30, 0.86, 1.0, 0.86),
		24
	))


static func _style_label(label: Label) -> void:
	if label.name in ["TitleLabel", "Title"]:
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", TEXT)
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.72))
		label.add_theme_constant_override("shadow_offset_y", 2)
		return
	if label.name.ends_with("Title") or label.name.ends_with("Label") and label.name in ["MetaTitle", "DistributionTitle", "RosterTitle", "StandingsLabel"]:
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50, 1.0))
		return
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_MUTED)


static func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.12, 0.16, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	button.add_theme_stylebox_override("normal", button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.26, 0.31, 0.36, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _style_option(option: OptionButton) -> void:
	option.add_theme_font_size_override("font_size", 15)
	option.add_theme_color_override("font_color", TEXT)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_stylebox_override("normal", input_style(false))
	option.add_theme_stylebox_override("hover", input_style(true))
	option.add_theme_stylebox_override("pressed", input_style(true))
	option.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _style_line_edit(input: LineEdit) -> void:
	input.add_theme_font_size_override("font_size", 15)
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.66, 0.74, 0.78))
	input.add_theme_color_override("caret_color", ACCENT)
	input.add_theme_stylebox_override("normal", input_style(false))
	input.add_theme_stylebox_override("focus", input_style(true))


static func _style_text_edit(input: TextEdit) -> void:
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("caret_color", ACCENT)
	input.add_theme_stylebox_override("normal", input_style(false))
	input.add_theme_stylebox_override("focus", input_style(true))


static func _style_rich_text(label: RichTextLabel) -> void:
	label.add_theme_color_override("default_color", TEXT_MUTED)
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_stylebox_override("normal", input_style(false))


static func panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border.r, border.g, border.b, 0.22)
	style.shadow_size = 10
	style.set_content_margin_all(10)
	return style


static func button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
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


static func input_style(hover: bool) -> StyleBoxFlat:
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
