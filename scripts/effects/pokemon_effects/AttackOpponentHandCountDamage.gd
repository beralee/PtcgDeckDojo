class_name AttackOpponentHandCountDamage
extends BaseEffect

var damage_per_card: int = 20


func _init(per_card: int = 20) -> void:
	damage_per_card = per_card


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return 0
	var opponent: PlayerState = state.players[1 - top.owner_index]
	return opponent.hand.size() * damage_per_card


func get_description() -> String:
	return "This attack does damage based on the number of cards in your opponent's hand."
