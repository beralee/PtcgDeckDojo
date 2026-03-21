class_name AttackMillSelfDeck
extends BaseEffect

var mill_count: int = 2
var attack_index_to_match: int = -1


func _init(count: int = 2, match_attack_index: int = -1) -> void:
	mill_count = count
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
	for _i: int in mini(mill_count, player.deck.size()):
		var milled: CardInstance = player.deck.pop_front()
		milled.face_up = true
		player.discard_pile.append(milled)


func get_description() -> String:
	return "Discard cards from the top of your deck."
