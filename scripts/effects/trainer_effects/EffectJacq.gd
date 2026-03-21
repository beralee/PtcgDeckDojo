## Jacq - search up to two Evolution Pokemon
class_name EffectJacq
extends BaseEffect

const MAX_SEARCH_COUNT: int = 2


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for c: CardInstance in player.deck:
		if c.card_data.is_evolution_pokemon():
			return true
	return false


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	var found: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("evolution_pokemon", [])
	for c: Variant in selected_raw:
		if c is CardInstance and c in player.deck and c.card_data.is_evolution_pokemon():
			found.append(c)
			if found.size() >= MAX_SEARCH_COUNT:
				break

	if found.is_empty():
		for c: CardInstance in player.deck:
			if found.size() >= MAX_SEARCH_COUNT:
				break
			if c.card_data.is_evolution_pokemon():
				found.append(c)

	for c: CardInstance in found:
		player.deck.erase(c)
		c.face_up = true
		player.hand.append(c)

	player.shuffle_deck()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for c: CardInstance in player.deck:
		if c.card_data.is_evolution_pokemon():
			items.append(c)
			labels.append(c.card_data.name)
	return [{
		"id": "evolution_pokemon",
		"title": "Choose up to two Evolution Pokemon",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(MAX_SEARCH_COUNT, items.size()),
		"allow_cancel": true,
	}]


func get_description() -> String:
	return "Search your deck for up to two Evolution Pokemon."
