## Search the deck for cards and put them into the hand.
class_name AbilitySearchAny
extends BaseEffect

var search_count: int = 1
var once_per_turn: bool = true
var is_vstar_power: bool = false

const USED_KEY: String = "ability_search_any_used"


func _init(count: int = 1, once: bool = true, vstar: bool = false) -> void:
	search_count = count
	once_per_turn = once
	is_vstar_power = vstar


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index

	if is_vstar_power and state.vstar_power_used[pi]:
		return false

	if once_per_turn:
		for eff: Dictionary in pokemon.effects:
			if eff.get("type") == USED_KEY and eff.get("turn") == state.turn_number:
				return false

	var player: PlayerState = state.players[pi]
	return not player.deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return []

	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		items.append(deck_card)
		labels.append("%s [%s]" % [deck_card.card_data.name, deck_card.card_data.card_type])

	return [{
		"id": "search_cards",
		"title": "从牌库中选择卡牌加入手牌",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(search_count, items.size()),
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
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]

	if player.deck.is_empty():
		return

	var selected_cards: Array[CardInstance] = []
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("search_cards", [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and entry not in selected_cards:
			selected_cards.append(entry)
			if selected_cards.size() >= search_count:
				break

	if selected_cards.is_empty():
		var count: int = mini(search_count, player.deck.size())
		for idx: int in count:
			selected_cards.append(player.deck[idx])

	for card: CardInstance in selected_cards:
		player.deck.erase(card)
		card.face_up = true
		player.hand.append(card)

	player.shuffle_deck()

	if is_vstar_power:
		state.vstar_power_used[pi] = true
	elif once_per_turn:
		pokemon.effects.append({
			"type": USED_KEY,
			"turn": state.turn_number,
		})


func get_description() -> String:
	var limit_str := ""
	if is_vstar_power:
		limit_str = "（VSTAR力量，每局1次）"
	elif once_per_turn:
		limit_str = "（每回合1次）"
	return "特性：从牌库中选择%d张卡加入手牌%s" % [search_count, limit_str]
