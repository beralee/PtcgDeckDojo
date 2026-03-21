## Recover up to N Basic Energy cards from the discard pile to the hand.
class_name EffectRecoverBasicEnergy
extends BaseEffect

var recover_count: int = 2
var discard_cost: int = 0


func _init(count: int = 2, cost: int = 0) -> void:
	recover_count = count
	discard_cost = cost


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	var other_hand_cards: int = 0
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			other_hand_cards += 1
	if other_hand_cards < discard_cost:
		return false
	for discard_card: CardInstance in player.discard_pile:
		if _is_basic_energy(discard_card):
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var steps: Array[Dictionary] = []

	if discard_cost > 0:
		var hand_items: Array = []
		var hand_labels: Array[String] = []
		for hand_card: CardInstance in player.hand:
			if hand_card == card:
				continue
			hand_items.append(hand_card)
			hand_labels.append(hand_card.card_data.name)
		steps.append({
			"id": "discard_cards",
			"title": "Choose %d cards to discard" % discard_cost,
			"items": hand_items,
			"labels": hand_labels,
			"min_select": discard_cost,
			"max_select": discard_cost,
			"allow_cancel": true,
		})

	var discard_items: Array = []
	var discard_labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		if _is_basic_energy(discard_card):
			discard_items.append(discard_card)
			discard_labels.append(discard_card.card_data.name)
	steps.append({
		"id": "recover_energy",
		"title": "Choose up to %d Basic Energy cards" % recover_count,
		"items": discard_items,
		"labels": discard_labels,
		"min_select": 1,
		"max_select": mini(recover_count, discard_items.size()),
		"allow_cancel": true,
	})
	return steps


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var discarded_cost_cards: Array[CardInstance] = _resolve_discard_cost(card, player, ctx)
	for discarded: CardInstance in discarded_cost_cards:
		player.hand.erase(discarded)
		player.discard_pile.append(discarded)

	var selected_raw: Array = ctx.get("recover_energy", [])
	var selected_energy: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.discard_pile and _is_basic_energy(entry) and entry not in discarded_cost_cards:
			selected_energy.append(entry)
			if selected_energy.size() >= recover_count:
				break

	if selected_energy.is_empty():
		for discard_card: CardInstance in player.discard_pile:
			if discard_card in discarded_cost_cards:
				continue
			if _is_basic_energy(discard_card):
				selected_energy.append(discard_card)
				if selected_energy.size() >= recover_count:
					break

	for energy_card: CardInstance in selected_energy:
		player.discard_pile.erase(energy_card)
		energy_card.face_up = true
		player.hand.append(energy_card)


func _resolve_discard_cost(card: CardInstance, player: PlayerState, ctx: Dictionary) -> Array[CardInstance]:
	var discard_cards: Array[CardInstance] = []
	if discard_cost <= 0:
		return discard_cards

	var selected_raw: Array = ctx.get("discard_cards", [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.hand and entry != card and entry not in discard_cards:
			discard_cards.append(entry)
			if discard_cards.size() >= discard_cost:
				break

	if discard_cards.size() < discard_cost:
		for hand_card: CardInstance in player.hand:
			if discard_cards.size() >= discard_cost:
				break
			if hand_card != card and hand_card not in discard_cards:
				discard_cards.append(hand_card)
	return discard_cards


func _is_basic_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.card_type == "Basic Energy"


func get_description() -> String:
	if discard_cost > 0:
		return "Discard %d cards, then recover up to %d Basic Energy cards from your discard pile." % [discard_cost, recover_count]
	return "Recover up to %d Basic Energy cards from your discard pile." % recover_count
