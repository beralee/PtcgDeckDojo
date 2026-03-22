class_name AbilityFlowerSelecting
extends BaseEffect

const USED_FLAG_TYPE := "ability_flower_selecting_used"
const STEP_ID := "flower_selecting_pick"

var look_count: int = 2
var pick_count: int = 1
var active_only: bool = true


func _init(look: int = 2, pick: int = 1, require_active: bool = true) -> void:
	look_count = look
	pick_count = pick
	active_only = require_active


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	var player: PlayerState = state.players[top.owner_index]
	if active_only and player.active_pokemon != pokemon:
		return false
	if player.deck.is_empty():
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and int(effect_data.get("turn", -1)) == state.turn_number:
			return false
	return true


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return []
	var looked: Array = []
	var labels: Array[String] = []
	for idx: int in range(mini(look_count, player.deck.size())):
		var deck_card: CardInstance = player.deck[idx]
		looked.append(deck_card)
		labels.append(deck_card.card_data.name)
	var actual_pick: int = mini(pick_count, looked.size())
	if actual_pick <= 0:
		return []
	return [{
		"id": STEP_ID,
		"title": "Choose %d card(s) to put into your hand" % actual_pick,
		"items": looked,
		"labels": labels,
		"min_select": actual_pick,
		"max_select": actual_pick,
		"allow_cancel": false,
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
	var looked: Array[CardInstance] = []
	for _i: int in range(mini(look_count, player.deck.size())):
		looked.append(player.deck.pop_front())

	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var selected_ids: Dictionary = {}
	for entry: Variant in selected_raw:
		if entry is CardInstance:
			selected_ids[(entry as CardInstance).instance_id] = true

	var chosen: Array[CardInstance] = []
	var banished: Array[CardInstance] = []
	for card: CardInstance in looked:
		card.face_up = true
		if selected_ids.has(card.instance_id) and chosen.size() < pick_count:
			chosen.append(card)
		else:
			banished.append(card)

	if chosen.is_empty():
		for card: CardInstance in looked:
			if chosen.size() < pick_count:
				chosen.append(card)
			elif card not in banished:
				banished.append(card)

	for card: CardInstance in chosen:
		if card in banished:
			banished.erase(card)
		player.hand.append(card)
	for card: CardInstance in banished:
		player.lost_zone.append(card)

	pokemon.effects.append({
		"type": USED_FLAG_TYPE,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "Look at the top cards of your deck, put one into your hand, and put the rest in the Lost Zone."
