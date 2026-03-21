## 弃能量到放逐区效果 - 放逐冲击（骑拉帝纳VSTAR）
## 从自己场上宝可梦身上选择指定数量的能量，放入放逐区
## 参数:
##   discard_count   弃置的能量数量（默认2）
##   to_lost_zone    是否放入放逐区（默认true；false则普通弃置）
##   from_field      是否从全场宝可梦选择能量（默认true；false则仅从攻击者）
class_name AttackLostZoneEnergy
extends BaseEffect

## 弃置的能量数量
var discard_count: int = 2
## 是否放入放逐区（用标记区分）
var to_lost_zone: bool = true
## 是否从全场宝可梦选择能量（true = 场上任意宝可梦；false = 仅攻击者自身）
var from_field: bool = true


func _init(count: int = 2, lost_zone: bool = true, field: bool = true) -> void:
	discard_count = count
	to_lost_zone = lost_zone
	from_field = field


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	var slots: Array[PokemonSlot] = _get_candidate_slots(player)
	for slot: PokemonSlot in slots:
		for energy: CardInstance in slot.attached_energy:
			items.append(energy)
			labels.append("%s (%s)" % [energy.card_data.name, slot.get_pokemon_name()])
	if items.is_empty():
		return []
	return [{
		"id": "lost_zone_energy",
		"title": "选择 %d 个能量放入放逐区" % discard_count,
		"items": items,
		"labels": labels,
		"min_select": mini(discard_count, items.size()),
		"max_select": mini(discard_count, items.size()),
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	var pi: int = top_card.owner_index
	var player: PlayerState = state.players[pi]

	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("lost_zone_energy", [])

	# 如果有交互选择，使用玩家选择的能量
	if not selected_raw.is_empty():
		_remove_selected_energy(selected_raw, player, state)
		return

	# 向后兼容：无交互时自动从攻击者身上移除
	var removed: int = 0
	var i: int = attacker.attached_energy.size() - 1
	while i >= 0 and removed < discard_count:
		var energy_card: CardInstance = attacker.attached_energy[i]
		attacker.attached_energy.remove_at(i)
		_send_to_zone(energy_card, player, attacker, state)
		removed += 1
		i -= 1


func _remove_selected_energy(selected: Array, player: PlayerState, state: GameState) -> void:
	var removed: int = 0
	var selected_ids: Dictionary = {}
	for entry: Variant in selected:
		if entry is CardInstance:
			selected_ids[(entry as CardInstance).instance_id] = true
	if selected_ids.is_empty():
		return
	var slots: Array[PokemonSlot] = _get_candidate_slots(player)
	for slot: PokemonSlot in slots:
		var kept: Array[CardInstance] = []
		for energy: CardInstance in slot.attached_energy:
			if removed < discard_count and selected_ids.has(energy.instance_id):
				_send_to_zone(energy, player, slot, state)
				removed += 1
			else:
				kept.append(energy)
		slot.attached_energy = kept


func _send_to_zone(energy: CardInstance, player: PlayerState, slot: PokemonSlot, state: GameState) -> void:
	energy.face_up = true
	if to_lost_zone:
		player.lost_zone.append(energy)
		slot.effects.append({
			"type": "lost_zone_energy",
			"card_instance_id": energy.instance_id,
			"turn": state.turn_number,
		})
	else:
		player.discard_pile.append(energy)


func _get_candidate_slots(player: PlayerState) -> Array[PokemonSlot]:
	if from_field:
		return player.get_all_pokemon()
	var result: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		result.append(player.active_pokemon)
	return result


func get_description() -> String:
	var dest_str: String = "放逐区" if to_lost_zone else "弃牌区"
	var source_str: String = "场上宝可梦" if from_field else "这只宝可梦"
	return "选择%s身上的%d个能量放入%s。" % [source_str, discard_count, dest_str]
