class_name AbilityRunAwayDraw
extends BaseEffect

const REPLACEMENT_STEP_ID := "replacement_bench"

var draw_count: int = 3


func _init(count: int = 3) -> void:
	draw_count = count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	var player: PlayerState = state.players[top.owner_index]
	if pokemon != player.active_pokemon and pokemon not in player.bench:
		return false
	if player.active_pokemon == pokemon and player.bench.is_empty():
		return false
	return true


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var slot: PokemonSlot = _find_owner_slot(card, player)
	if slot == null or player.active_pokemon != slot or player.bench.is_empty():
		return []
	var labels: Array[String] = []
	for bench_slot: PokemonSlot in player.bench:
		labels.append("%s (HP %d/%d)" % [
			bench_slot.get_pokemon_name(),
			bench_slot.get_remaining_hp(),
			bench_slot.get_max_hp(),
		])
	return [{
		"id": REPLACEMENT_STEP_ID,
		"title": "Choose a new Active Pokemon",
		"items": player.bench.duplicate(),
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
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	player.draw_cards(draw_count)

	var ctx: Dictionary = get_interaction_context(targets)
	var replacement: PokemonSlot = null
	if player.active_pokemon == pokemon:
		var selected_raw: Array = ctx.get(REPLACEMENT_STEP_ID, [])
		if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
			var candidate: PokemonSlot = selected_raw[0]
			if candidate in player.bench:
				replacement = candidate
		if replacement == null and not player.bench.is_empty():
			replacement = player.bench[0]

	for card: CardInstance in pokemon.pokemon_stack:
		card.face_up = false
		player.deck.append(card)
	for card: CardInstance in pokemon.attached_energy:
		card.face_up = false
		player.deck.append(card)
	if pokemon.attached_tool != null:
		pokemon.attached_tool.face_up = false
		player.deck.append(pokemon.attached_tool)

	pokemon.pokemon_stack.clear()
	pokemon.attached_energy.clear()
	pokemon.attached_tool = null
	pokemon.effects.clear()
	pokemon.clear_all_status()
	pokemon.damage_counters = 0

	if player.active_pokemon == pokemon:
		player.active_pokemon = replacement
		if replacement != null:
			player.bench.erase(replacement)
	else:
		player.bench.erase(pokemon)

	player.shuffle_deck()


func _find_owner_slot(card: CardInstance, player: PlayerState) -> PokemonSlot:
	if card == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_top_card() == card:
			return slot
	return null


func get_description() -> String:
	return "Draw cards, then shuffle this Pokemon and all attached cards into your deck."
