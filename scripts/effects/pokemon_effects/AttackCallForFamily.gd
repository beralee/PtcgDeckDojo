## 检索基础宝可梦到备战区效果 - 呼朋引伴（泡沫栗鼠）
## 从牌库检索最多 search_count 只基础宝可梦放置到备战区
## 参数:
##   search_count  最多检索的基础宝可梦数量（默认1）
##   energy_filter 属性过滤（空字符串=任意属性）
class_name AttackCallForFamily
extends BaseEffect

## 最多检索的基础宝可梦数量
var search_count: int = 1
## 属性过滤（空字符串=任意属性）
var energy_filter: String = ""


func _init(count: int = 1, e_filter: String = "") -> void:
	search_count = count
	energy_filter = e_filter


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var bench_space: int = 5 - player.bench.size()
	if bench_space <= 0 or player.deck.is_empty():
		return []

	var actual_max: int = mini(search_count, bench_space)
	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if _is_matching_basic_pokemon(deck_card):
			items.append(deck_card)
			labels.append(deck_card.card_data.name)
	if items.is_empty():
		return []

	var filter_str: String = "【%s】" % energy_filter if energy_filter != "" else ""
	return [{
		"id": "search_basic_pokemon",
		"title": "从牌库中选择最多%d只%s基础宝可梦放到备战区" % [actual_max, filter_str],
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
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	var pi: int = top_card.owner_index
	var player: PlayerState = state.players[pi]

	var bench_space: int = 5 - player.bench.size()
	if bench_space <= 0:
		player.shuffle_deck()
		return

	var actual_count: int = mini(search_count, bench_space)

	# 从交互上下文获取玩家选择
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("search_basic_pokemon", [])
	var chosen: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_matching_basic_pokemon(entry):
			if entry not in chosen:
				chosen.append(entry)
				if chosen.size() >= actual_count:
					break

	# 如果没有交互选择，回退到自动选择
	if chosen.is_empty() and selected_raw.is_empty():
		for deck_card: CardInstance in player.deck:
			if _is_matching_basic_pokemon(deck_card):
				chosen.append(deck_card)
				if chosen.size() >= actual_count:
					break

	if chosen.is_empty():
		player.shuffle_deck()
		return

	# 从牌库移除并放置到备战区
	for poke_card: CardInstance in chosen:
		player.deck.erase(poke_card)
		if player.is_bench_full():
			break
		poke_card.face_up = true
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(poke_card)
		slot.turn_played = state.turn_number
		player.bench.append(slot)

	player.shuffle_deck()


## 判断单张卡牌是否为符合条件的基础宝可梦
func _is_matching_basic_pokemon(card: CardInstance) -> bool:
	var cd: CardData = card.card_data
	if cd == null:
		return false
	if not cd.is_basic_pokemon():
		return false
	if energy_filter == "":
		return true
	return cd.energy_type == energy_filter


func get_description() -> String:
	var filter_str: String = energy_filter if energy_filter != "" else "任意属性"
	return "从牌库检索最多%d只%s基础宝可梦放到备战区，洗牌。" % [search_count, filter_str]
