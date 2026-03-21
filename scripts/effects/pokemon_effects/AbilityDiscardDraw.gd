## Discard 1 Energy card from hand, then draw cards.
class_name AbilityDiscardDraw
extends BaseEffect

var draw_count: int = 2

const USED_KEY: String = "ability_discard_draw_used"


func _init(count: int = 2) -> void:
	draw_count = count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false

	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == USED_KEY and eff.get("turn") == state.turn_number:
			return false

	var player: PlayerState = state.players[top.owner_index]
	return _has_energy_in_hand(player.hand)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if hand_card.card_data != null and hand_card.card_data.is_energy():
			energy_items.append(hand_card)
			energy_labels.append(hand_card.card_data.name)
	if energy_items.is_empty():
		return []
	return [{
		"id": "discard_energy",
		"title": "选择1张要弃置的能量卡",
		"items": energy_items,
		"labels": energy_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]

	var energy_to_discard: CardInstance = null
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("discard_energy", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var selected_card: CardInstance = selected_raw[0] as CardInstance
		if selected_card.card_data != null and selected_card.card_data.is_energy():
			energy_to_discard = selected_card
	elif not targets.is_empty() and targets[0] is CardInstance:
		var candidate: CardInstance = targets[0] as CardInstance
		if candidate.card_data != null and candidate.card_data.is_energy():
			energy_to_discard = candidate

	if energy_to_discard == null:
		for card: CardInstance in player.hand:
			if card.card_data != null and card.card_data.is_energy():
				energy_to_discard = card
				break

	if energy_to_discard == null:
		return

	if not player.remove_from_hand(energy_to_discard):
		return
	player.discard_card(energy_to_discard)
	player.draw_cards(draw_count)

	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func _has_energy_in_hand(hand: Array[CardInstance]) -> bool:
	for card: CardInstance in hand:
		if card.card_data != null and card.card_data.is_energy():
			return true
	return false


func get_description() -> String:
	return "特性：弃置1张手牌能量，然后抽%d张牌。（每回合1次）" % draw_count
