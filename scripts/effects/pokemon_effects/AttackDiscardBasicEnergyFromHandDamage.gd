## Discard any number of Basic Energy cards from hand. Damage scales with the discard count.
class_name AttackDiscardBasicEnergyFromHandDamage
extends BaseEffect

var damage_per_card: int = 50


func _init(damage: int = 50) -> void:
	damage_per_card = damage


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if not _is_basic_energy(hand_card):
			continue
		items.append(hand_card)
		labels.append(hand_card.card_data.name)
	if items.is_empty():
		return []
	return [{
		"id": "discard_basic_energy",
		"title": "选择要弃置的基本能量",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": items.size(),
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var discarded_cards: Array[CardInstance] = []
	var ctx: Dictionary = get_attack_interaction_context()
	if ctx.has("discard_basic_energy"):
		var selected_raw: Array = ctx.get("discard_basic_energy", [])
		for entry: Variant in selected_raw:
			if not entry is CardInstance:
				continue
			var selected_card: CardInstance = entry
			if selected_card in discarded_cards:
				continue
			if selected_card in player.hand and _is_basic_energy(selected_card):
				discarded_cards.append(selected_card)
	else:
		for hand_card: CardInstance in player.hand:
			if _is_basic_energy(hand_card):
				discarded_cards.append(hand_card)

	discarded_cards = _discard_cards_from_hand_with_log(state, top.owner_index, discarded_cards, top, "attack")

	# Base damage has already applied one 50x segment.
	var total_damage: int = discarded_cards.size() * damage_per_card
	var delta: int = total_damage - damage_per_card
	defender.damage_counters = max(0, defender.damage_counters + delta)


func _is_basic_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.card_type == "Basic Energy"


func get_description() -> String:
	return "Discard any number of Basic Energy cards from your hand. This attack does %d damage for each card discarded." % damage_per_card
