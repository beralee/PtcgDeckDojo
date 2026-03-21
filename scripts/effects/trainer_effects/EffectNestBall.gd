## 巢穴球 - 从牌库检索1张基础宝可梦放到备战区
class_name EffectNestBall
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for c: CardInstance in player.deck:
		if c.card_data.is_basic_pokemon():
			items.append(c)
			labels.append("%s (HP %d)" % [c.card_data.name, c.card_data.hp])
	return [{
		"id": "basic_pokemon",
		"title": "选择1张基础宝可梦放入备战区",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	# 备战区必须未满
	if player.is_bench_full():
		return false
	# 牌库中必须有基础宝可梦
	for c: CardInstance in player.deck:
		if c.card_data.is_basic_pokemon():
			return true
	return false


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var pokemon: CardInstance = null
	var selected_raw: Array = ctx.get("basic_pokemon", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var selected: CardInstance = selected_raw[0]
		if selected in player.deck and selected.card_data.is_basic_pokemon():
			pokemon = selected
	if pokemon == null:
		for deck_card: CardInstance in player.deck:
			if deck_card.card_data.is_basic_pokemon():
				pokemon = deck_card
				break

	if pokemon == null:
		player.shuffle_deck()
		return

	player.deck.erase(pokemon)

	# 放到备战区
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(pokemon)
	slot.turn_played = state.turn_number
	player.bench.append(slot)

	player.shuffle_deck()


func get_description() -> String:
	return "从牌库检索1张基础宝可梦放到备战区"
