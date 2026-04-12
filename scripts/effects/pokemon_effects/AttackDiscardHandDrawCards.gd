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
	_discard_cards_from_hand_with_log(state, top.owner_index, hand_copy, top, "attack")
	_draw_cards_with_log(state, top.owner_index, draw_count, top, "attack")


func get_description() -> String:
	return "Discard your hand and draw cards."
