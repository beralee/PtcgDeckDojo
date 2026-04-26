class_name AttackBonusIfSelfStatus
extends BaseEffect

var status_name: String = "poisoned"
var bonus_damage: int = 0
var attack_index_to_match: int = -1


func _init(status: String = "poisoned", bonus: int = 0, match_attack_index: int = -1) -> void:
	status_name = status
	bonus_damage = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
	return bonus_damage if bool(attacker.status_conditions.get(status_name, false)) else 0


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "If this Pokemon is %s, this attack does %d more damage." % [status_name, bonus_damage]
