class_name AbilityDrawIfKnockoutLastTurn
extends BaseEffect

var draw_count: int = 3
var shared_flag_key: String = "ability_draw_if_knockout_last_turn"


func _init(count: int = 3, shared_key: String = "ability_draw_if_knockout_last_turn") -> void:
	draw_count = count
	shared_flag_key = shared_key


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	if state.current_player_index != pi:
		return false
	if state.last_knockout_turn_against[pi] != state.turn_number - 1:
		return false
	var shared_key := "%s_%d" % [shared_flag_key, pi]
	if int(state.shared_turn_flags.get(shared_key, -1)) == state.turn_number:
		return false
	return not state.players[pi].deck.is_empty()


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	state.players[pi].draw_cards(draw_count)
	state.shared_turn_flags["%s_%d" % [shared_flag_key, pi]] = state.turn_number


func get_description() -> String:
	return "If one of your Pokemon was Knocked Out during your opponent's last turn, draw cards."
