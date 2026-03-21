## Search the deck for up to N cards matching a filter and put them into the hand.
class_name AttackSearchDeckToHand
extends BaseEffect

var search_count: int = 1
var card_type_filter: String = ""


func _init(count: int = 1, filter: String = "") -> void:
	search_count = count
	card_type_filter = filter


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var found: Array[CardInstance] = []
	for deck_card: CardInstance in player.deck:
		if _matches_filter(deck_card):
			found.append(deck_card)
			if found.size() >= search_count:
				break
	for card: CardInstance in found:
		player.deck.erase(card)
		card.face_up = true
		player.hand.append(card)
	player.shuffle_deck()


func _matches_filter(card: CardInstance) -> bool:
	if card_type_filter == "":
		return true
	var cd: CardData = card.card_data
	if cd == null:
		return false
	return cd.card_type == card_type_filter


func get_description() -> String:
	return "Search your deck for up to %d %s card(s)." % [search_count, card_type_filter]
