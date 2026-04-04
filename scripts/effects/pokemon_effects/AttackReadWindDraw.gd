## Read the Wind attack effect. Discard 1 card from your hand, then draw 3 cards.
## Used by Lugia V "读风".
class_name AttackReadWindDraw
extends BaseEffect


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.hand.is_empty():
		return []

	var items: Array = []
	var labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		items.append(hand_card)
		labels.append(hand_card.card_data.name if hand_card.card_data != null else "未知卡牌")
	return [{
		"id": "discard_card",
		"title": "选择1张手牌放入弃牌区",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


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
	var to_discard: CardInstance = null
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("discard_card", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var selected: CardInstance = selected_raw[0]
		if selected in player.hand:
			to_discard = selected

	if to_discard == null and not player.hand.is_empty():
		to_discard = player.hand[0]

	if to_discard != null and player.remove_from_hand(to_discard):
		player.discard_card(to_discard)

	player.draw_cards(3)


func get_description() -> String:
	return "弃置1张手牌，然后抽3张牌"
