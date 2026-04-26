class_name AbilityBenchShuffleIntoDeck
extends BaseEffect


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null:
		return false
	var owner_index: int = pokemon.get_top_card().owner_index
	if state.current_player_index != owner_index:
		return false
	var player: PlayerState = state.players[owner_index]
	return pokemon in player.bench


func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
	if not can_use_ability(pokemon, state):
		return
	var owner_index: int = pokemon.get_top_card().owner_index
	var player: PlayerState = state.players[owner_index]
	for card: CardInstance in pokemon.pokemon_stack:
		card.face_up = false
		player.deck.append(card)
	for card: CardInstance in pokemon.attached_energy:
		card.face_up = false
		player.deck.append(card)
	if pokemon.attached_tool != null:
		pokemon.attached_tool.face_up = false
		player.deck.append(pokemon.attached_tool)
	player.bench.erase(pokemon)
	pokemon.pokemon_stack.clear()
	pokemon.attached_energy.clear()
	pokemon.attached_tool = null
	pokemon.effects.clear()
	pokemon.clear_all_status()
	pokemon.damage_counters = 0
	player.shuffle_deck()


func get_description() -> String:
	return "如果这只宝可梦在备战区的话，则在自己的回合可以使用1次。将这只宝可梦，以及放于其身上的所有卡牌，放回自己的牌库并重洗牌库。"
