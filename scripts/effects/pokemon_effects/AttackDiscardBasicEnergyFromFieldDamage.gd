class_name AttackDiscardBasicEnergyFromFieldDamage
extends BaseEffect

var damage_per_energy: int = 70
var attack_index_to_match: int = -1


func _init(per_energy: int = 70, match_attack_index: int = -1) -> void:
	damage_per_energy = per_energy
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[state.current_player_index]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		for energy: CardInstance in slot.attached_energy:
			if energy.card_data.card_type == "Basic Energy":
				items.append(energy)
				labels.append("%s on %s" % [energy.card_data.name, slot.get_pokemon_name()])
	return [{
		"id": "discard_basic_energy",
		"title": "Choose any number of Basic Energy to discard",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": items.size(),
		"allow_cancel": true,
	}]


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("discard_basic_energy", [])
	return (selected_raw.size() - 1) * damage_per_energy


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("discard_basic_energy", [])
	var selected_ids: Dictionary = {}
	for entry: Variant in selected_raw:
		if entry is CardInstance:
			var selected: CardInstance = entry
			selected_ids[selected.instance_id] = true
	if selected_ids.is_empty():
		return
	var candidate_slots: Array[PokemonSlot] = player.get_all_pokemon().duplicate()
	if attacker != null and not candidate_slots.has(attacker):
		candidate_slots.append(attacker)
	for slot: PokemonSlot in candidate_slots:
		var kept_energy: Array[CardInstance] = []
		for attached: CardInstance in slot.attached_energy:
			if attached.card_data.card_type == "Basic Energy" and selected_ids.has(attached.instance_id):
				player.discard_pile.append(attached)
			else:
				kept_energy.append(attached)
		slot.attached_energy = kept_energy


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1

func get_description() -> String:
	return "Discard any number of Basic Energy from your Pokemon. This attack does more damage for each discarded."
