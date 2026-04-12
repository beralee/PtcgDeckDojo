## 精炼特性 - 奇鲁莉安
## 弃1张任意手牌（不限类型），抽2张。每回合1次。
class_name AbilityDiscardDrawAny
extends BaseEffect

var draw_count: int = 2

const USED_KEY: String = "ability_discard_draw_any_used"


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
	return not player.hand.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
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

	var card_to_discard: CardInstance = null
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("discard_card", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var selected: CardInstance = selected_raw[0] as CardInstance
		if selected in player.hand:
			card_to_discard = selected

	if card_to_discard == null:
		if player.hand.is_empty():
			return
		card_to_discard = player.hand[0]

	var discarded_cards: Array[CardInstance] = _discard_cards_from_hand_with_log(state, top.owner_index, [card_to_discard], top, "ability")
	if discarded_cards.is_empty():
		return
	_draw_cards_with_log(state, top.owner_index, draw_count, top, "ability")

	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "特性【精炼】：弃置1张手牌，抽%d张牌。（每回合1次）" % draw_count
