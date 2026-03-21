## 友好宝芬 - 从牌库检索最多2张HP≤70的基础宝可梦放到备战区
class_name EffectBuddyPoffin
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for c: CardInstance in player.deck:
		if c.card_data.is_basic_pokemon() and c.card_data.hp <= 70:
			items.append(c)
			labels.append("%s (HP %d)" % [c.card_data.name, c.card_data.hp])
	var bench_space: int = 5 - player.bench.size()
	return [{
		"id": "buddy_poffin_pokemon",
		"title": "选择最多2张HP不高于70的基础宝可梦放入备战区",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(2, bench_space),
		"allow_cancel": true,
	}]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	if player.is_bench_full():
		return false
	for c: CardInstance in player.deck:
		if c.card_data.is_basic_pokemon() and c.card_data.hp <= 70:
			return true
	return false


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var bench_space: int = 5 - player.bench.size()
	var to_place: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("buddy_poffin_pokemon", [])
	for c: Variant in selected_raw:
		if c is CardInstance and c in player.deck and c.card_data.is_basic_pokemon() and c.card_data.hp <= 70:
			to_place.append(c)
			if to_place.size() >= bench_space or to_place.size() >= 2:
				break

	if to_place.is_empty():
		for deck_card: CardInstance in player.deck:
			var cd: CardData = deck_card.card_data
			if cd.is_basic_pokemon() and cd.hp <= 70:
				to_place.append(deck_card)
				if to_place.size() >= bench_space or to_place.size() >= 2:
					break

	for pokemon: CardInstance in to_place:
		player.deck.erase(pokemon)

	# 放到备战区
	for pokemon: CardInstance in to_place:
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(pokemon)
		slot.turn_played = state.turn_number
		player.bench.append(slot)

	player.shuffle_deck()


func get_description() -> String:
	return "从牌库检索最多2张HP≤70的基础宝可梦放到备战区"
