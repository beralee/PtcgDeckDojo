## Draw 1 card, or 2 if this Pokemon is Active. Once during your turn.
class_name AbilityBonusDrawIfActive
extends BaseEffect

const USED_KEY := "ability_bonus_draw_if_active_used"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.players[top.owner_index].deck.is_empty():
		return false
	for eff: Dictionary in pokemon.effects:
		if eff.get("type", "") == USED_KEY and eff.get("turn", -1) == state.turn_number:
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
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]
	var draw_count: int = 2 if player.active_pokemon == pokemon else 1
	player.draw_cards(draw_count)
	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "Once during your turn, draw 1 card. If this Pokemon is Active, draw 2 instead."
