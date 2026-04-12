class_name AbilityAttachBasicEnergyFromHandDraw
extends BaseEffect

const USED_FLAG_TYPE := "ability_attach_basic_energy_from_hand_draw_used"

var energy_type: String = "G"
var draw_count: int = 1


func _init(required_type: String = "G", draw_cards: int = 1) -> void:
	energy_type = required_type
	draw_count = draw_cards


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false
	var player: PlayerState = state.players[top.owner_index]
	for hand_card: CardInstance in player.hand:
		if hand_card.card_data.card_type == "Basic Energy" and hand_card.card_data.energy_provides == energy_type:
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if hand_card.card_data.card_type == "Basic Energy" and hand_card.card_data.energy_provides == energy_type:
			items.append(hand_card)
			labels.append(hand_card.card_data.name)
	return [{
		"id": "basic_energy_from_hand",
		"title": "Choose 1 Basic Energy to attach",
		"items": items,
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
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("basic_energy_from_hand", [])
	if selected_raw.is_empty() or not selected_raw[0] is CardInstance:
		return
	var energy: CardInstance = selected_raw[0]
	if energy not in player.hand:
		return
	if energy.card_data.card_type != "Basic Energy" or energy.card_data.energy_provides != energy_type:
		return
	player.hand.erase(energy)
	pokemon.attached_energy.append(energy)
	_draw_cards_with_log(state, top.owner_index, draw_count, top, "ability")
	pokemon.effects.append({"type": USED_FLAG_TYPE, "turn": state.turn_number})


func get_description() -> String:
	return "Once during your turn, attach a Basic Energy from your hand to this Pokemon and draw a card."
