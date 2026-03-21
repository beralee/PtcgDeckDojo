## 卡牌UI - 显示一张卡牌（名称/类型/简要信息）
class_name CardUI
extends PanelContainer

signal card_clicked(card: CardInstance)
signal card_right_clicked(card: CardInstance)

var card_instance: CardInstance = null
var _selectable: bool = true
var _selected: bool = false

@onready var _label_name: Label = $VBox/LabelName
@onready var _label_type: Label = $VBox/LabelType
@onready var _label_info: Label = $VBox/LabelInfo


func setup(inst: CardInstance, selectable: bool = true) -> void:
	card_instance = inst
	_selectable = selectable
	_refresh()


func _refresh() -> void:
	if card_instance == null:
		return
	var cd: CardData = card_instance.card_data
	_label_name.text = cd.name
	_label_type.text = _type_label(cd)
	_label_info.text = _info_text(cd)
	_update_style()


func _type_label(cd: CardData) -> String:
	match cd.card_type:
		"Pokemon":
			var stage_map := {"Basic": "基础", "Stage 1": "1阶", "Stage 2": "2阶"}
			var stage: String = stage_map.get(cd.stage, cd.stage)
			var mech: String = " [%s]" % cd.mechanic if cd.mechanic != "" else ""
			return "%s宝可梦%s · %s" % [stage, mech, _energy_cn(cd.energy_type)]
		"Item":        return "物品卡"
		"Supporter":   return "支援者卡"
		"Tool":        return "宝可梦道具"
		"Stadium":     return "竞技场卡"
		"Basic Energy":   return "基本能量 · %s" % _energy_cn(cd.energy_type if cd.energy_type != "" else cd.energy_provides)
		"Special Energy": return "特殊能量"
		_: return cd.card_type


func _info_text(cd: CardData) -> String:
	if cd.is_pokemon():
		return "HP %d  撤退:%d" % [cd.hp, cd.retreat_cost]
	return ""


func _energy_cn(code: String) -> String:
	var map := {"R":"火","W":"水","G":"草","L":"雷","P":"超","F":"斗","D":"恶","M":"钢","N":"龙","C":"无"}
	return map.get(code, code)


func set_selected(sel: bool) -> void:
	_selected = sel
	_update_style()


func _update_style() -> void:
	if _selected:
		add_theme_color_override("panel_color", Color(0.3, 0.6, 1.0, 0.5))
	else:
		remove_theme_color_override("panel_color")


func _gui_input(event: InputEvent) -> void:
	if not _selectable or card_instance == null:
		return
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(card_instance)
		elif mbe.pressed and mbe.button_index == MOUSE_BUTTON_RIGHT:
			card_right_clicked.emit(card_instance)
