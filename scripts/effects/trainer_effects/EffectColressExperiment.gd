class_name EffectColressExperiment
extends BaseEffect

const STEP_ID := "colress_pick"

var look_count: int = 5
var pick_count: int = 3


func _init(look: int = 5, pick: int = 3) -> void:
	look_count = look
	pick_count = pick


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


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
	return [{
		"id": STEP_ID,
		"title": "Choose %d card(s) to put into your hand" % actual_pick,
		"items": looked,
		"labels": labels,
		"min_select": actual_pick,
		"max_select": actual_pick,
		"allow_cancel": false,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return

	var looked: Array[CardInstance] = []
	for _i: int in range(mini(look_count, player.deck.size())):
		looked.append(player.deck.pop_front())

	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var selected_ids: Dictionary = {}
	for entry: Variant in selected_raw:
		if entry is CardInstance:
			selected_ids[(entry as CardInstance).instance_id] = true

	var kept: Array[CardInstance] = []
	var banished: Array[CardInstance] = []
	for deck_card: CardInstance in looked:
		deck_card.face_up = true
		if selected_ids.has(deck_card.instance_id) and kept.size() < pick_count:
			kept.append(deck_card)
		else:
			banished.append(deck_card)

	if kept.is_empty():
		for deck_card: CardInstance in looked:
			if kept.size() < mini(pick_count, looked.size()):
				kept.append(deck_card)
			elif deck_card not in banished:
				banished.append(deck_card)

	for kept_card: CardInstance in kept:
		if kept_card in banished:
			banished.erase(kept_card)
		player.hand.append(kept_card)
	for banished_card: CardInstance in banished:
		player.lost_zone.append(banished_card)


func get_description() -> String:
	return "Look at the top 5 cards of your deck, put 3 into your hand, and put the rest in the Lost Zone."
