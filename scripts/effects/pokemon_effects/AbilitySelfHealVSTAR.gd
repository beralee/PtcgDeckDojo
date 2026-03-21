class_name AbilitySelfHealVSTAR
extends BaseEffect


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	return pokemon.damage_counters > 0 and not state.vstar_power_used[top.owner_index]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	pokemon.damage_counters = 0
	state.vstar_power_used[top.owner_index] = true


func get_description() -> String:
	return "VSTAR Power: Heal all damage from this Pokemon."
