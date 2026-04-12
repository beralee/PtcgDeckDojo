class_name AttackDrawToHandSize
extends BaseEffect

var target_hand_size: int = 6
var attack_index_to_match: int = -1


func _init(hand_size: int = 6, match_attack_index: int = -1) -> void:
	target_hand_size = hand_size
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	if player.hand.size() >= target_hand_size:
		return
	_draw_cards_with_log(state, top.owner_index, target_hand_size - player.hand.size(), top, "attack")


func get_description() -> String:
	return "Draw cards until you have %d cards in your hand." % target_hand_size
