class_name AttackOwnFieldEnergyCountBonus
extends BaseEffect

var energy_type: String = ""
var damage_per_energy: int = 30
var attack_index_to_match: int = -1


func _init(required_type: String = "", per_energy: int = 30, match_attack_index: int = -1) -> void:
	energy_type = required_type
	damage_per_energy = per_energy
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var pi := attacker.get_top_card().owner_index
	var total := 0
	var player: PlayerState = state.players[pi]
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	slots.append_array(player.bench)
	for slot: PokemonSlot in slots:
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			var provided: String = energy.card_data.energy_provides
			if energy_type == "" or provided == energy_type:
				total += 1
	return total * damage_per_energy


func get_description() -> String:
	return "己方场上每个%s能量追加%d伤害。" % [energy_type if energy_type != "" else "任意", damage_per_energy]
