## Once during your turn, if this Pokemon is Active, draw 1 card.
class_name AbilityDrawIfActive
extends BaseEffect

const USED_KEY := "ability_draw_if_active_used"

var draw_count: int = 1


func _init(count: int = 1) -> void:
	draw_count = count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	var player: PlayerState = state.players[top.owner_index]
	if player.active_pokemon != pokemon:
		return false
	if player.deck.is_empty():
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_KEY and effect_data.get("turn", -1) == state.turn_number:
			return false
	return true


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
	var player: PlayerState = state.players[top.owner_index]
	_draw_cards_with_log(state, top.owner_index, draw_count, top, "ability")
	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "Once during your turn, if this Pokemon is Active, draw %d card(s)." % draw_count
