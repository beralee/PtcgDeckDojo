class_name AttackDiscardHandDrawCards
extends BaseEffect

var draw_count: int = 6
var attack_index_to_match: int = -1


func _init(count: int = 6, match_attack_index: int = -1) -> void:
	draw_count = count
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	for hand_card: CardInstance in hand_copy:
		player.hand.erase(hand_card)
		player.discard_pile.append(hand_card)
	player.draw_cards(draw_count)


func get_description() -> String:
	return "Discard your hand and draw cards."
