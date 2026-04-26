class_name AbilityActiveRetreatLock
extends BaseEffect


func prevents_opponent_retreat(pokemon: PokemonSlot, player_index: int, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null:
		return false
	var owner_index: int = pokemon.get_top_card().owner_index
	if owner_index == player_index:
		return false
	var owner: PlayerState = state.players[owner_index]
	return owner.active_pokemon == pokemon


func get_description() -> String:
	return "只要这只宝可梦在战斗场上，对手的战斗宝可梦，无法撤退。"
