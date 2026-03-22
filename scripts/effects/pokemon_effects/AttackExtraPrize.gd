## Knockout bonus prize effect for a specific attack.
class_name AttackExtraPrize
extends BaseEffect

var extra_prizes: int = 1
var attack_index_to_match: int = -1


func _init(extra: int = 1, match_attack_index: int = -1) -> void:
	extra_prizes = extra
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	_state: GameState
) -> void:
	if defender == null or not applies_to_attack_index(attack_index):
		return
	defender.effects.append({
		"type": "extra_prize",
		"count": extra_prizes,
		"source": "attack",
	})


func get_description() -> String:
	return "If this attack Knocks Out the opponent's Pokemon, take %d extra Prize card(s)." % extra_prizes
