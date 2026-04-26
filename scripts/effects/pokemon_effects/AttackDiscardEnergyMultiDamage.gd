## 弃指定能量×倍伤害效果 - 强劲电光（雷丘V）
## 弃置攻击者身上所有指定类型的能量，每弃1张追加额外伤害
## 参数:
##   energy_type       要弃置的能量类型（默认"L"=雷能量）
##   damage_per_energy 每弃1张追加的伤害值（默认60）
class_name AttackDiscardEnergyMultiDamage
extends BaseEffect

const STEP_ID := "discard_energy"

## 要弃置的能量类型
var energy_type: String = "L"
## 每弃1张追加的伤害值
var damage_per_energy: int = 60
var attack_index_to_match: int = -1

const LUMINOUS_ENERGY_EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"
const LEGACY_ENERGY_EFFECT_ID := "6f31b7241a181631016466e561f148f3"
const TEMPLE_OF_SINNOH_EFFECT_ID := "53864b068a4a1e8dce3c53c884b67efa"


func _init(e_type: String = "L", per_energy: int = 60, match_attack_index: int = -1) -> void:
	energy_type = e_type
	damage_per_energy = per_energy
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or not applies_to_attack_index(_resolve_attack_index(card, _attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		for energy_card: CardInstance in slot.attached_energy:
			if not _matches_energy_type(energy_card, state):
				continue
			items.append(energy_card)
			labels.append("%s on %s" % [energy_card.card_data.name, slot.get_pokemon_name()])
	return [{
		"id": STEP_ID,
		"title": "选择要弃置的能量",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": items.size(),
		"allow_cancel": true,
	}]


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var selected_count: int = _count_selected_energy(attacker, state)
	return (selected_count - 1) * damage_per_energy


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	var pi: int = top_card.owner_index
	var player: PlayerState = state.players[pi]

	var selected_ids: Dictionary = _get_selected_energy_ids()
	if selected_ids.is_empty():
		return

	for slot: PokemonSlot in player.get_all_pokemon():
		var kept: Array[CardInstance] = []
		for attached: CardInstance in slot.attached_energy:
			if selected_ids.has(attached.instance_id) and _matches_energy_type(attached, state):
				player.discard_pile.append(attached)
			else:
				kept.append(attached)
		slot.attached_energy = kept


## 判断能量卡是否符合指定类型
func _matches_energy_type(card: CardInstance, state: GameState = null) -> bool:
	var cd: CardData = card.card_data
	if cd == null:
		return false
	if not cd.is_energy():
		return false
	if energy_type == "":
		return true
	if cd.energy_provides == energy_type or cd.energy_type == energy_type:
		return true
	if cd.card_type != "Special Energy" or _is_special_energy_suppressed(state):
		return false
	if cd.effect_id == LEGACY_ENERGY_EFFECT_ID:
		return true
	if cd.effect_id == LUMINOUS_ENERGY_EFFECT_ID:
		return not _luminous_is_downgraded_to_colorless(card, state)
	return false


func _count_selected_energy(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null:
		return 0
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return 0
	var selected_ids: Dictionary = _get_selected_energy_ids()
	if selected_ids.is_empty():
		return 0
	var player: PlayerState = state.players[top_card.owner_index]
	var count: int = 0
	for slot: PokemonSlot in player.get_all_pokemon():
		for attached: CardInstance in slot.attached_energy:
			if selected_ids.has(attached.instance_id) and _matches_energy_type(attached, state):
				count += 1
	return count


func _get_selected_energy_ids() -> Dictionary:
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var result: Dictionary = {}
	for entry: Variant in selected_raw:
		if entry is CardInstance:
			var selected_card: CardInstance = entry
			if selected_card.card_data != null and selected_card.card_data.is_energy():
				result[selected_card.instance_id] = true
			continue
		if entry is Dictionary:
			var entry_dict: Dictionary = entry
			var instance_id: int = int(entry_dict.get("instance_id", entry_dict.get("card_instance_id", -1)))
			if instance_id >= 0:
				result[instance_id] = true
	return result


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func _is_special_energy_suppressed(state: GameState) -> bool:
	return state != null and state.stadium_card != null and state.stadium_card.card_data != null and state.stadium_card.card_data.effect_id == TEMPLE_OF_SINNOH_EFFECT_ID


func _luminous_is_downgraded_to_colorless(card: CardInstance, state: GameState) -> bool:
	if state == null:
		return false
	for player: PlayerState in state.players:
		for slot: PokemonSlot in player.get_all_pokemon():
			if not (card in slot.attached_energy):
				continue
			for other: CardInstance in slot.attached_energy:
				if other != card and other.card_data != null and other.card_data.card_type == "Special Energy":
					return true
			return false
	return false


func get_description() -> String:
	return "强劲电光：弃置己方场上任意数量的%s能量，每弃1张追加%d伤害。" % [energy_type, damage_per_energy]
