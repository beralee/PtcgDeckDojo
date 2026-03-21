## 从弃牌区复活指定宝可梦到备战区 - 渡魂（夜巡灵）
## 从弃牌区选择最多 max_count 张符合名称过滤的宝可梦放到备战区
class_name AttackReviveFromDiscardToBench
extends BaseEffect

var max_count: int = 1
var required_name: String = ""


func _init(count: int = 1, card_name: String = "") -> void:
	max_count = count
	required_name = card_name


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var bench_space: int = 5 - player.bench.size()
	if bench_space <= 0:
		return []
	var actual_max: int = mini(max_count, bench_space)
	var items: Array = []
	var labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		if not discard_card.card_data.is_pokemon():
			continue
		if required_name != "" and discard_card.card_data.name != required_name:
			continue
		items.append(discard_card)
		labels.append(discard_card.card_data.name)
	if items.is_empty():
		return []
	var name_str: String = "「%s」" % required_name if required_name != "" else "宝可梦"
	return [{
		"id": "revive_from_discard",
		"title": "从弃牌区选择最多%d张%s放到备战区" % [actual_max, name_str],
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(actual_max, items.size()),
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]

	var bench_space: int = 5 - player.bench.size()
	if bench_space <= 0:
		return

	var actual_max: int = mini(max_count, bench_space)

	# 从交互上下文获取玩家选择
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("revive_from_discard", [])
	var chosen: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var card: CardInstance = entry
		if card not in player.discard_pile:
			continue
		if not card.card_data.is_pokemon():
			continue
		if required_name != "" and card.card_data.name != required_name:
			continue
		if card not in chosen:
			chosen.append(card)
			if chosen.size() >= actual_max:
				break

	# 如果没有交互选择，回退到自动选择
	if chosen.is_empty() and selected_raw.is_empty():
		for discard_card: CardInstance in player.discard_pile:
			if not discard_card.card_data.is_pokemon():
				continue
			if required_name != "" and discard_card.card_data.name != required_name:
				continue
			chosen.append(discard_card)
			if chosen.size() >= actual_max:
				break

	for card: CardInstance in chosen:
		if player.is_bench_full():
			break
		player.discard_pile.erase(card)
		card.face_up = true
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(card)
		slot.turn_played = state.turn_number
		player.bench.append(slot)


func get_description() -> String:
	var name_str: String = "「%s」" % required_name if required_name != "" else "宝可梦"
	return "从弃牌区选择最多%d张%s放到备战区。" % [max_count, name_str]
