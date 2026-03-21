## 深钵镇 - 竞技场
## 双方每回合1次，可从牌库中检索1只基础宝可梦（除规则宝可梦外）放到备战区。洗牌。
class_name EffectArtazon
extends BaseEffect


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	# 备战区需要有空位
	if player.is_bench_full():
		return false
	# 牌库中需要有非规则基础宝可梦
	for deck_card: CardInstance in player.deck:
		if _is_valid_pokemon(deck_card):
			return true
	return false


func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if _is_valid_pokemon(deck_card):
			items.append(deck_card)
			labels.append(deck_card.card_data.name)
	if items.is_empty():
		return []
	return [{
		"id": "artazon_pokemon",
		"title": "选择1只基础宝可梦放到备战区",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(_card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = state.current_player_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("artazon_pokemon", [])

	var chosen: CardInstance = null
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var candidate: CardInstance = selected_raw[0] as CardInstance
		if candidate in player.deck and _is_valid_pokemon(candidate):
			chosen = candidate
	if chosen == null:
		for deck_card: CardInstance in player.deck:
			if _is_valid_pokemon(deck_card):
				chosen = deck_card
				break
	if chosen == null:
		return
	if player.is_bench_full():
		return

	player.deck.erase(chosen)
	chosen.face_up = true
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(chosen)
	slot.turn_played = state.turn_number
	player.bench.append(slot)
	player.shuffle_deck()


func _is_valid_pokemon(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	if not card.card_data.is_pokemon():
		return false
	if card.card_data.stage != "Basic":
		return false
	# 排除规则宝可梦（ex, V, VSTAR, VMAX, Radiant等）
	var mechanic: String = card.card_data.mechanic
	if mechanic != "" and mechanic != "none":
		return false
	return true


func get_description() -> String:
	return "竞技场【深钵镇】：每回合1次，从牌库检索1只基础宝可梦（除规则宝可梦外）放到备战区。"
