class_name AttackKODefenderIfHasSpecialEnergy
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	for energy: CardInstance in defender.attached_energy:
		if energy.card_data.card_type == "Special Energy":
			defender.damage_counters = defender.get_max_hp()
			return


func get_description() -> String:
	return "If the Defending Pokemon has Special Energy attached, it is Knocked Out."
