class_name AttackOwnFieldEnergyCountDamage
extends BaseEffect

var energy_type: String = ""
var damage_per_energy: int = 30
var attack_index_to_match: int = -1


func _init(e_type: String = "", per_energy: int = 30, match_attack_index: int = -1) -> void:
	energy_type = e_type
	damage_per_energy = per_energy
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return 0
	var pi: int = top.owner_index
	var total := 0
	for slot: PokemonSlot in state.players[pi].get_all_pokemon():
		if slot == null:
			continue
		if energy_type == "":
			total += slot.get_total_energy_count()
		else:
			total += slot.count_energy_of_type(energy_type)
	return total * damage_per_energy


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "This attack does %d more damage for each %s Energy attached to all of your Pokemon." % [damage_per_energy, energy_type]
