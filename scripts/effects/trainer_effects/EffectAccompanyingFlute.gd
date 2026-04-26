class_name EffectAccompanyingFlute
extends BaseEffect

const LOOK_COUNT := 5
const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")


func can_execute(card: CardInstance, state: GameState) -> bool:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	return not opponent.deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var looked_cards: Array[CardInstance] = _get_looked_cards(opponent)
	if looked_cards.is_empty():
		return []
	var basics: Array = []
	var labels: Array[String] = []
	var reveal_labels: Array[String] = []
	for deck_card: CardInstance in looked_cards:
		reveal_labels.append(deck_card.card_data.name if deck_card.card_data != null else "")
		if deck_card.card_data != null and deck_card.card_data.is_basic_pokemon():
			basics.append(deck_card)
			labels.append(deck_card.card_data.name)
	var title: String = "查看对手牌库上方%d张：%s" % [looked_cards.size(), ", ".join(reveal_labels)]
	var bench_space: int = BenchLimit.get_available_bench_space(state, opponent)
	if basics.is_empty() or bench_space <= 0:
		return [{
			"id": "accompanying_flute_continue",
			"title": "%s\n没有可放置的基础宝可梦。" % title,
			"items": ["continue"],
			"labels": ["继续"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]
	return [{
		"id": "bench_basic_pokemon",
		"title": "%s\n选择任意数量的基础宝可梦放到对手备战区" % title,
		"items": basics,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(bench_space, basics.size()),
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var looked_cards: Array[CardInstance] = _get_looked_cards(opponent)
	if looked_cards.is_empty():
		return
	var bench_space: int = BenchLimit.get_available_bench_space(state, opponent)
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("bench_basic_pokemon", [])
	for entry: Variant in selected_raw:
		if bench_space <= 0:
			break
		if not (entry is CardInstance):
			continue
		var deck_card: CardInstance = entry
		if deck_card not in opponent.deck or deck_card not in looked_cards or deck_card.card_data == null or not deck_card.card_data.is_basic_pokemon():
			continue
		opponent.deck.erase(deck_card)
		deck_card.face_up = true
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(deck_card)
		slot.turn_played = state.turn_number
		opponent.bench.append(slot)
		bench_space -= 1
	opponent.shuffle_deck()


func get_description() -> String:
	return "将对手牌库上方5张卡牌翻到正面，选择其中任意数量的基础宝可梦，放于对手的备战区。将剩余的卡牌放回牌库并重洗牌库。"


func _get_looked_cards(player: PlayerState) -> Array[CardInstance]:
	var looked_cards: Array[CardInstance] = []
	var count: int = mini(LOOK_COUNT, player.deck.size())
	for idx: int in count:
		looked_cards.append(player.deck[idx])
	return looked_cards
