class_name AttackFieldEnergyThresholdBonus
extends BaseEffect

var required_energy_count: int = 3
var bonus_damage: int = 70
var attack_index_to_match: int = -1


func _init(required_count: int = 3, bonus: int = 70, match_attack_index: int = -1) -> void:
	required_energy_count = required_count
	bonus_damage = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null:
		return 0
	var player: PlayerState = state.players[attacker.get_top_card().owner_index]
	var total: int = 0
	for slot: PokemonSlot in player.get_all_pokemon():
		total += slot.get_total_energy_count()
	return bonus_damage if total >= required_energy_count else 0
