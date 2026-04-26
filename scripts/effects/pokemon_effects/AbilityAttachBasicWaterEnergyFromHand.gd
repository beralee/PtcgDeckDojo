class_name AbilityAttachBasicWaterEnergyFromHand
extends BaseEffect

const ENERGY_STEP_ID := "basic_water_energy_from_hand"
const TARGET_STEP_ID := "attach_target"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	var player: PlayerState = state.players[top.owner_index]
	if player.get_all_pokemon().is_empty():
		return false
	for hand_card: CardInstance in player.hand:
		if _is_basic_water_energy(hand_card):
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if _is_basic_water_energy(hand_card):
			energy_items.append(hand_card)
			energy_labels.append(hand_card.card_data.name)

	var target_items: Array = player.get_all_pokemon()
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append(slot.get_pokemon_name())

	if energy_items.is_empty() or target_items.is_empty():
		return []
	return [
		{
			"id": ENERGY_STEP_ID,
			"title": "选择1张手牌中的基本水能量",
			"items": energy_items,
			"labels": energy_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": TARGET_STEP_ID,
			"title": "选择要附着能量的自己的宝可梦",
			"items": target_items,
			"labels": target_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


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

	var selected_energy: CardInstance = _first_valid_energy(ctx.get(ENERGY_STEP_ID, []), player)
	if selected_energy == null:
		for hand_card: CardInstance in player.hand:
			if _is_basic_water_energy(hand_card):
				selected_energy = hand_card
				break
	if selected_energy == null:
		return

	var target_slot: PokemonSlot = _first_valid_target(ctx.get(TARGET_STEP_ID, []), player)
	if target_slot == null:
		target_slot = player.active_pokemon
	if target_slot == null:
		return

	player.hand.erase(selected_energy)
	target_slot.attached_energy.append(selected_energy)


func _first_valid_energy(raw: Array, player: PlayerState) -> CardInstance:
	for entry: Variant in raw:
		if entry is CardInstance and entry in player.hand and _is_basic_water_energy(entry):
			return entry
	return null


func _first_valid_target(raw: Array, player: PlayerState) -> PokemonSlot:
	var own_slots: Array = player.get_all_pokemon()
	for entry: Variant in raw:
		if entry is PokemonSlot and entry in own_slots:
			return entry
	return null


func _is_basic_water_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.card_type == "Basic Energy" and card.card_data.energy_provides == "W"


func get_description() -> String:
	return "极低温：在自己的回合可以使用任意次，选择手牌中的1张基本水能量附着于自己的宝可梦。"
