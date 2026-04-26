class_name AttackAttachDarkFromDeckAndPoisonSelf
extends BaseEffect

const STEP_ID := "deck_dark_energy"

var max_count: int = 2


func _init(count: int = 2) -> void:
	max_count = count


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if deck_card == null or deck_card.card_data == null:
			continue
		if deck_card.card_data.card_type != "Basic Energy":
			continue
		if deck_card.card_data.energy_provides != "D":
			continue
		items.append(deck_card)
		labels.append(deck_card.card_data.name)
	if items.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "选择最多%d张基本恶能量附于这只宝可梦身上" % mini(max_count, items.size()),
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(max_count, items.size()),
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return
	var pi := attacker.get_top_card().owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_attack_interaction_context()
	var selected: Array[CardInstance] = []
	for entry: Variant in ctx.get(STEP_ID, []):
		if not (entry is CardInstance):
			continue
		var card := entry as CardInstance
		if card in selected:
			continue
		if card not in player.deck:
			continue
		if card.card_data == null or card.card_data.card_type != "Basic Energy":
			continue
		if card.card_data.energy_provides != "D":
			continue
		selected.append(card)
		if selected.size() >= max_count:
			break
	if selected.is_empty():
		for deck_card: CardInstance in player.deck:
			if deck_card == null or deck_card.card_data == null:
				continue
			if deck_card.card_data.card_type != "Basic Energy":
				continue
			if deck_card.card_data.energy_provides != "D":
				continue
			selected.append(deck_card)
			if selected.size() >= max_count:
				break
	for energy_card: CardInstance in selected:
		player.deck.erase(energy_card)
		energy_card.face_up = true
		attacker.attached_energy.append(energy_card)
	player.shuffle_deck()
	if not selected.is_empty():
		attacker.status_conditions["poisoned"] = true


func get_description() -> String:
	return "从牌库附最多2张基本恶能量给自己；若附着成功，则这只宝可梦陷入中毒。"
