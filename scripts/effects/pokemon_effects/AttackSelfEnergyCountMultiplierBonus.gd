class_name AttackSelfEnergyCountMultiplierBonus
extends BaseEffect

var damage_per_energy: int = 40
var attack_index_to_match: int = -1


func _init(per_energy: int = 40, match_attack_index: int = -1) -> void:
	damage_per_energy = per_energy
	attack_index_to_match = match_attack_index


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
	if attacker == null:
		return 0
	var energy_count: int = attacker.get_total_energy_count()
	return maxi(0, energy_count - 1) * damage_per_energy
