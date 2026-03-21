## 宝可梦槽位UI - 显示场上一只宝可梦的状态
class_name PokemonSlotUI
extends PanelContainer

signal slot_clicked(slot: PokemonSlot)

var slot: PokemonSlot = null
var _highlight: bool = false

@onready var _lbl_name: Label = $VBox/LblName
@onready var _lbl_hp: Label = $VBox/LblHP
@onready var _progress_hp: ProgressBar = $VBox/ProgressHP
@onready var _lbl_energy: Label = $VBox/LblEnergy
@onready var _lbl_status: Label = $VBox/LblStatus
@onready var _lbl_empty: Label = $VBox/LblEmpty


func setup(pokemon_slot: PokemonSlot) -> void:
	slot = pokemon_slot
	refresh()


func clear() -> void:
	slot = null
	refresh()


func refresh() -> void:
	if slot == null or slot.pokemon_stack.is_empty():
		_lbl_empty.visible = true
		_lbl_name.visible = false
		_lbl_hp.visible = false
		_progress_hp.visible = false
		_lbl_energy.visible = false
		_lbl_status.visible = false
		return

	_lbl_empty.visible = false
	_lbl_name.visible = true
	_lbl_hp.visible = true
	_progress_hp.visible = true
	_lbl_energy.visible = true
	_lbl_status.visible = true

	var cd: CardData = slot.get_card_data()
	var max_hp: int = slot.get_max_hp()
	var rem_hp: int = slot.get_remaining_hp()

	# 名称（进化层数）
	var stage_prefix := ""
	if slot.pokemon_stack.size() > 1:
		stage_prefix = "[进化x%d] " % (slot.pokemon_stack.size() - 1)
	_lbl_name.text = stage_prefix + cd.name

	# HP
	_lbl_hp.text = "HP %d / %d" % [rem_hp, max_hp]
	_progress_hp.max_value = max_hp
	_progress_hp.value = rem_hp
	if rem_hp <= max_hp / 4:
		_progress_hp.modulate = Color.RED
	elif rem_hp <= max_hp / 2:
		_progress_hp.modulate = Color.YELLOW
	else:
		_progress_hp.modulate = Color.GREEN

	# 能量
	var energy_map := {"R":"火","W":"水","G":"草","L":"雷","P":"超","F":"斗","D":"恶","M":"钢","N":"龙","C":"无"}
	var energy_counts: Dictionary = {}
	for e: CardInstance in slot.attached_energy:
		var t: String = e.card_data.energy_provides if e.card_data.energy_provides != "" else "C"
		energy_counts[t] = energy_counts.get(t, 0) + 1
	var energy_parts: Array[String] = []
	for k: String in energy_counts:
		energy_parts.append("%s×%d" % [energy_map.get(k, k), energy_counts[k]])
	_lbl_energy.text = "能量: " + (", ".join(energy_parts) if not energy_parts.is_empty() else "无")

	# 道具
	if slot.attached_tool != null:
		_lbl_energy.text += "  道具: " + slot.attached_tool.card_data.name

	# 状态
	var statuses: Array[String] = []
	var status_names := {"poisoned":"中毒","burned":"灼伤","asleep":"睡眠","paralyzed":"麻痹","confused":"混乱"}
	for k: String in status_names:
		if slot.status_conditions.get(k, false):
			statuses.append(status_names[k])
	_lbl_status.text = "状态: " + (", ".join(statuses) if not statuses.is_empty() else "正常")

	_update_style()


func set_highlight(on: bool) -> void:
	_highlight = on
	_update_style()


func _update_style() -> void:
	if _highlight:
		add_theme_color_override("panel_color", Color(0.2, 0.8, 0.3, 0.4))
	else:
		remove_theme_color_override("panel_color")


func _gui_input(event: InputEvent) -> void:
	if slot == null:
		return
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(slot)
