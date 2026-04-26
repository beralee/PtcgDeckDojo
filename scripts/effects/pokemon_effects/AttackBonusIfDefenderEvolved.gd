class_name AttackBonusIfDefenderEvolved
extends BaseEffect

var bonus_damage: int = 30
var attack_index_to_match: int = -1


func _init(bonus: int = 30, match_attack_index: int = -1) -> void:
	bonus_damage = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null:
		return 0
	var defender: PokemonSlot = state.players[1 - attacker.get_top_card().owner_index].active_pokemon
	if defender == null or defender.get_card_data() == null:
		return 0
	return bonus_damage if defender.get_card_data().is_evolution_pokemon() else 0
