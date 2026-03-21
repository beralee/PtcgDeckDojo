## 手牌区域 - 显示并管理玩家手牌（点击选牌）
extends Control

signal card_selected(card: CardInstance)
signal card_deselected()

var _selected_card: CardInstance = null
var _hidden: bool = false

@onready var _container: HBoxContainer = $ScrollContainer/HBoxContainer
@onready var _lbl_hidden: Label = $LblHidden
@onready var _scroll: ScrollContainer = $ScrollContainer


## 刷新手牌显示
func refresh(hand: Array[CardInstance], selectable: bool = true) -> void:
	_selected_card = null
	for child: Node in _container.get_children():
		child.queue_free()

	if _hidden:
		_lbl_hidden.visible = true
		_scroll.visible = false
		_lbl_hidden.text = "手牌: %d张（已隐藏）" % hand.size()
		return

	_lbl_hidden.visible = false
	_scroll.visible = true

	for inst: CardInstance in hand:
		_container.add_child(_build_card_panel(inst, selectable))


func _build_card_panel(inst: CardInstance, selectable: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(90, 120)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var lbl_name := Label.new()
	lbl_name.text = inst.card_data.name
	lbl_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_size_override("font_size", 11)
	vbox.add_child(lbl_name)

	var lbl_type := Label.new()
	lbl_type.text = _short_type(inst.card_data)
	lbl_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_type.add_theme_font_size_override("font_size", 10)
	lbl_type.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(lbl_type)

	if inst.card_data.is_pokemon():
		var lbl_hp := Label.new()
		lbl_hp.text = "HP %d" % inst.card_data.hp
		lbl_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_hp.add_theme_font_size_override("font_size", 10)
		vbox.add_child(lbl_hp)

	if selectable:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mbe := event as InputEventMouseButton
				if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
					_on_card_clicked(inst, panel)
		)

	return panel


func _short_type(cd: CardData) -> String:
	var emap := {"R":"火","W":"水","G":"草","L":"雷","P":"超","F":"斗","D":"恶","M":"钢","N":"龙","C":"无"}
	match cd.card_type:
		"Pokemon":      return "%s·%s" % [cd.stage, emap.get(cd.energy_type, cd.energy_type)]
		"Item":         return "物品"
		"Supporter":    return "支援者"
		"Tool":         return "道具"
		"Stadium":      return "竞技场"
		"Basic Energy": return "基本能量·%s" % emap.get(cd.energy_provides, "")
		"Special Energy": return "特殊能量"
		_: return cd.card_type


func _on_card_clicked(inst: CardInstance, panel: PanelContainer) -> void:
	if _selected_card == inst:
		_selected_card = null
		_clear_highlights()
		card_deselected.emit()
	else:
		_selected_card = inst
		_clear_highlights()
		_highlight_panel(panel, true)
		card_selected.emit(inst)


func _clear_highlights() -> void:
	for child: Node in _container.get_children():
		if child is PanelContainer:
			(child as PanelContainer).remove_theme_stylebox_override("panel")


func _highlight_panel(panel: PanelContainer, on: bool) -> void:
	if on:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.5, 1.0, 0.35)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.4, 0.7, 1.0)
		panel.add_theme_stylebox_override("panel", sb)
	else:
		panel.remove_theme_stylebox_override("panel")


func get_selected_card() -> CardInstance:
	return _selected_card


func deselect_all() -> void:
	_selected_card = null
	_clear_highlights()


func set_hidden(hidden: bool) -> void:
	_hidden = hidden
