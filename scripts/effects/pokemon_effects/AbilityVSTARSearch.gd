## VSTAR search ability granted by Forest Seal Stone.
class_name AbilityVSTARSearch
extends BaseEffect

const FOREST_SEAL_EFFECT_ID: String = "9fa9943ccda36f417ac3cb675177c216"
const ABILITY_NAME: String = "星星炼金术"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if not has_vstar_search(pokemon, state):
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	return not state.players[top.owner_index].deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null:
		return []
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
		"title": "从牌库中选择1张牌加入手牌",
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
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]
	if player.deck.is_empty():
		return

	var found_idx: int = -1
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("search_cards", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		found_idx = player.deck.find(selected_raw[0] as CardInstance)
	elif targets.size() > 0 and targets[0] is CardInstance:
		found_idx = player.deck.find(targets[0] as CardInstance)

	if found_idx == -1:
		found_idx = 0
	if found_idx < 0 or found_idx >= player.deck.size():
		return

	var selected: CardInstance = player.deck[found_idx]
	player.deck.remove_at(found_idx)
	selected.face_up = true
	player.hand.append(selected)
	player.shuffle_deck()
	state.vstar_power_used[pi] = true


static func has_vstar_search(slot: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	if state.vstar_power_used[pi]:
		return false

	var cd: CardData = top.card_data
	if cd == null or cd.mechanic != "V":
		return false

	var tool: CardInstance = slot.attached_tool
	if tool == null or tool.card_data == null:
		return false
	return tool.card_data.effect_id == FOREST_SEAL_EFFECT_ID


func get_ability_name() -> String:
	return ABILITY_NAME


func get_description() -> String:
	return "VSTAR力量【%s】：从牌库中选择1张牌加入手牌。（每局1次）" % ABILITY_NAME
