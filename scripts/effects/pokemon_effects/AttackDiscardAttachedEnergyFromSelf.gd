class_name AttackDiscardAttachedEnergyFromSelf
extends BaseEffect

const STEP_ID := "discard_attached_energy_from_self"

var discard_count: int = 1
var attack_index_to_match: int = -1


func _init(count: int = 1, match_attack_index: int = -1) -> void:
	discard_count = max(0, count)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = player.active_pokemon
	if attacker == null or attacker.attached_energy.is_empty():
		return []
	var items: Array = attacker.attached_energy.duplicate()
	var labels: Array[String] = []
	for energy: CardInstance in items:
		labels.append(energy.card_data.name if energy != null and energy.card_data != null else "")
	var required: int = mini(discard_count, items.size())
	return [{
		"id": STEP_ID,
		"title": "Choose %d attached Energy to discard" % required,
		"items": items,
		"labels": labels,
		"min_select": required,
		"max_select": required,
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var selected_ids: Dictionary = _get_selected_energy_ids()
	if selected_ids.is_empty():
		return
	var player: PlayerState = state.players[top.owner_index]
	var discarded: Array[CardInstance] = []
	var kept: Array[CardInstance] = []
	for energy: CardInstance in attacker.attached_energy:
		if discarded.size() < discard_count and selected_ids.has(energy.instance_id):
			discarded.append(energy)
		else:
			kept.append(energy)
	if discarded.size() < mini(discard_count, attacker.attached_energy.size()):
		return
	attacker.attached_energy = kept
	for energy: CardInstance in discarded:
		player.discard_pile.append(energy)


func _get_selected_energy_ids() -> Dictionary:
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var result: Dictionary = {}
	for entry: Variant in selected_raw:
		if entry is CardInstance:
			result[(entry as CardInstance).instance_id] = true
			continue
		if entry is Dictionary:
			var entry_dict: Dictionary = entry
			var instance_id: int = int(entry_dict.get("instance_id", entry_dict.get("card_instance_id", -1)))
			if instance_id >= 0:
				result[instance_id] = true
	return result


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "Discard %d attached Energy from this Pokemon." % discard_count
