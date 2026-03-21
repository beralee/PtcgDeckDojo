## Irida - search a Water Pokemon and an Item card
class_name EffectIrida
extends BaseEffect

const WATER_ENERGY_TYPE: String = "W"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for c: CardInstance in player.deck:
		var cd: CardData = c.card_data
		if cd.is_pokemon() and cd.energy_type == WATER_ENERGY_TYPE:
			return true
		if cd.card_type == "Item":
			return true
	return false


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
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

	for c: CardInstance in player.deck:
		var cd: CardData = c.card_data
		if found_water_pokemon == null and cd.is_pokemon() and cd.energy_type == WATER_ENERGY_TYPE:
			found_water_pokemon = c
		if found_item == null and cd.card_type == "Item":
			found_item = c
		if found_water_pokemon != null and found_item != null:
			break

	if found_water_pokemon != null:
		player.deck.erase(found_water_pokemon)
		found_water_pokemon.face_up = true
		player.hand.append(found_water_pokemon)

	if found_item != null:
		player.deck.erase(found_item)
		found_item.face_up = true
		player.hand.append(found_item)

	player.shuffle_deck()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var pokemon_items: Array = []
	var pokemon_labels: Array[String] = []
	var item_items: Array = []
	var item_labels: Array[String] = []
	for c: CardInstance in player.deck:
		var cd: CardData = c.card_data
		if cd.is_pokemon() and cd.energy_type == WATER_ENERGY_TYPE:
			pokemon_items.append(c)
			pokemon_labels.append(cd.name)
		elif cd.card_type == "Item":
			item_items.append(c)
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
	return steps


func get_description() -> String:
	return "Search your deck for a Water Pokemon and an Item card."
