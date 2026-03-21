class_name AttackReduceDamageNextTurn
extends BaseEffect

var reduction_amount: int = 80


func _init(amount: int = 80) -> void:
	reduction_amount = amount


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	attacker.effects.append({
		"type": "reduce_damage_next_turn",
		"amount": reduction_amount,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "During your opponent's next turn, this Pokemon takes less damage."
