class_name AbilityRecoverDiscardItemsVSTAR
extends BaseEffect

const STEP_ID := "discard_items"

var max_count: int = 2


func _init(recover_max: int = 2) -> void:
	max_count = recover_max


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var pi := pokemon.get_top_card().owner_index
	if state.vstar_power_used[pi]:
		return false
	for card: CardInstance in state.players[pi].discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Item":
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		if discard_card == null or discard_card.card_data == null:
			continue
		if discard_card.card_data.card_type != "Item":
			continue
		items.append(discard_card)
		labels.append(discard_card.card_data.name)
	if items.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "选择最多%d张物品卡加入手牌" % mini(max_count, items.size()),
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(max_count, items.size()),
		"allow_cancel": true,
	}]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return
	var pi := pokemon.get_top_card().owner_index
	if state.vstar_power_used[pi]:
		return
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	for entry: Variant in ctx.get(STEP_ID, []):
		if not (entry is CardInstance):
			continue
		var card := entry as CardInstance
		if card in selected:
			continue
		if card not in player.discard_pile:
			continue
		if card.card_data == null or card.card_data.card_type != "Item":
			continue
		selected.append(card)
		if selected.size() >= max_count:
			break
	if selected.is_empty():
		for discard_card: CardInstance in player.discard_pile:
			if discard_card == null or discard_card.card_data == null:
				continue
			if discard_card.card_data.card_type != "Item":
				continue
			selected.append(discard_card)
			if selected.size() >= max_count:
				break
	for card: CardInstance in selected:
		player.discard_pile.erase(card)
		card.face_up = true
		player.hand.append(card)
	state.vstar_power_used[pi] = true


func get_description() -> String:
	return "VSTAR力量：从弃牌区选择最多%d张物品卡加入手牌。" % max_count
