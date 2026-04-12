class_name EffectIrida
extends BaseEffect

const WATER_ENERGY_TYPE: String = "W"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for deck_card: CardInstance in player.deck:
		var cd: CardData = deck_card.card_data
		if cd.is_pokemon() and cd.energy_type == WATER_ENERGY_TYPE:
			return true
		if cd.card_type == "Item":
			return true
	return false


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var found_water_pokemon: CardInstance = null
	var found_item: CardInstance = null
	var water_raw: Array = ctx.get("water_pokemon", [])
	if not water_raw.is_empty() and water_raw[0] is CardInstance:
		var water_selected: CardInstance = water_raw[0]
		if water_selected in player.deck and water_selected.card_data.is_pokemon() and water_selected.card_data.energy_type == WATER_ENERGY_TYPE:
			found_water_pokemon = water_selected
	var item_raw: Array = ctx.get("item_card", [])
	if not item_raw.is_empty() and item_raw[0] is CardInstance:
		var item_selected: CardInstance = item_raw[0]
		if item_selected in player.deck and item_selected.card_data.card_type == "Item":
			found_item = item_selected

	for deck_card: CardInstance in player.deck:
		var cd: CardData = deck_card.card_data
		if found_water_pokemon == null and cd.is_pokemon() and cd.energy_type == WATER_ENERGY_TYPE:
			found_water_pokemon = deck_card
		if found_item == null and cd.card_type == "Item":
			found_item = deck_card
		if found_water_pokemon != null and found_item != null:
			break

	var revealed_cards: Array[CardInstance] = []
	var public_labels: Array[String] = []
	if found_water_pokemon != null:
		revealed_cards.append(found_water_pokemon)
		public_labels.append("水属性宝可梦")
	if found_item != null:
		revealed_cards.append(found_item)
		public_labels.append("物品")
	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		revealed_cards,
		card,
		"trainer",
		"search_to_hand",
		public_labels
	)

	player.shuffle_deck()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var pokemon_items: Array = []
	var pokemon_labels: Array[String] = []
	var item_items: Array = []
	var item_labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		var cd: CardData = deck_card.card_data
		if cd.is_pokemon() and cd.energy_type == WATER_ENERGY_TYPE:
			pokemon_items.append(deck_card)
			pokemon_labels.append(cd.name)
		elif cd.card_type == "Item":
			item_items.append(deck_card)
			item_labels.append(cd.name)
	var steps: Array[Dictionary] = []
	if not pokemon_items.is_empty():
		steps.append({
			"id": "water_pokemon",
			"title": "Choose a Water Pokemon",
			"items": pokemon_items,
			"labels": pokemon_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		})
	if not item_items.is_empty():
		steps.append({
			"id": "item_card",
			"title": "Choose an Item card",
			"items": item_items,
			"labels": item_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		})
	if steps.is_empty():
		return [build_empty_search_resolution_step("牌库里没有水属性宝可梦或物品卡。你仍可以使用这张卡。")]
	return steps


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func get_description() -> String:
	return "Search your deck for a Water Pokemon and an Item card."
