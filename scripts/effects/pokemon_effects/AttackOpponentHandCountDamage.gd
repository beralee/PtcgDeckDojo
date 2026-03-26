class_name AttackOpponentHandCountDamage
extends BaseEffect

var damage_per_card: int = 20
var trainer_only: bool = false
var printed_base_damage: int = 0


func _init(per_card: int = 20, only_trainers: bool = false, printed_damage: int = 0) -> void:
	damage_per_card = per_card
	trainer_only = only_trainers
	printed_base_damage = printed_damage


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return 0
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var matching_count := 0
	for card: CardInstance in opponent.hand:
		if card == null or card.card_data == null:
			continue
		if trainer_only and not card.card_data.is_trainer():
			continue
		matching_count += 1
	return (matching_count * damage_per_card) - printed_base_damage


func get_description() -> String:
	if trainer_only:
		return "This attack does damage based on the number of Trainer cards in your opponent's hand."
	return "This attack does damage based on the number of cards in your opponent's hand."
