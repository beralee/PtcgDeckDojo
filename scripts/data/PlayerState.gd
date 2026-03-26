## 玩家状态 - 对战中一方玩家的完整状态
class_name PlayerState
extends RefCounted

static var _forced_shuffle_seed: int = -1
static var _forced_shuffle_counter: int = 0

## 玩家索引 (0 或 1)
var player_index: int = 0
## 牌库（顶部为 index 0）
var deck: Array[CardInstance] = []
## 手牌
var hand: Array[CardInstance] = []
## 奖赏卡
var prizes: Array[CardInstance] = []
## 奖赏区固定槽位布局（允许 null）
var prize_layout: Array = []
## 弃牌区
var discard_pile: Array[CardInstance] = []
## 放逐区
var lost_zone: Array[CardInstance] = []
## 战斗宝可梦
var active_pokemon: PokemonSlot = null
## 备战区（最多5个槽位）
var bench: Array[PokemonSlot] = []


## 从牌库顶抽1张卡加入手牌，返回抽到的卡（牌库为空返回 null）
func draw_card() -> CardInstance:
	if deck.is_empty():
		return null
	var card: CardInstance = deck.pop_front()
	card.face_up = true
	hand.append(card)
	return card


## 从牌库顶抽 N 张卡加入手牌，返回实际抽到的卡列表
func draw_cards(count: int) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in count:
		var card := draw_card()
		if card == null:
			break
		drawn.append(card)
	return drawn


## 从手牌中移除指定卡牌
func remove_from_hand(card: CardInstance) -> bool:
	var idx := hand.find(card)
	if idx == -1:
		return false
	hand.remove_at(idx)
	return true


## 将卡牌放入弃牌区
func discard_card(card: CardInstance) -> void:
	card.face_up = true
	discard_pile.append(card)


## 从手牌打出卡牌到弃牌区
func play_card_to_discard(card: CardInstance) -> bool:
	if not remove_from_hand(card):
		return false
	discard_card(card)
	return true


## 备战区是否已满（5只）
func is_bench_full() -> bool:
	return bench.size() >= 5


## 获取所有场上宝可梦（战斗 + 备战）
func get_all_pokemon() -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	if active_pokemon:
		result.append(active_pokemon)
	result.append_array(bench)
	return result


## 场上是否有宝可梦
func has_pokemon_in_play() -> bool:
	return active_pokemon != null or not bench.is_empty()


## 手牌中的基础宝可梦
func get_basic_pokemon_in_hand() -> Array[CardInstance]:
	var basics: Array[CardInstance] = []
	for card in hand:
		if card.is_basic_pokemon():
			basics.append(card)
	return basics


## 手牌中是否有基础宝可梦
func has_basic_pokemon_in_hand() -> bool:
	for card in hand:
		if card.is_basic_pokemon():
			return true
	return false


func set_prizes(cards: Array[CardInstance]) -> void:
	prizes = cards.duplicate()
	reset_prize_layout()


func reset_prize_layout() -> void:
	prize_layout.clear()
	for prize_card: CardInstance in prizes:
		prize_layout.append(prize_card)


func get_prize_layout() -> Array:
	if prize_layout.is_empty() and not prizes.is_empty():
		reset_prize_layout()
	return prize_layout


func get_prize_at_slot(slot_index: int) -> CardInstance:
	var layout: Array = get_prize_layout()
	if slot_index < 0 or slot_index >= layout.size():
		return null
	var candidate: Variant = layout[slot_index]
	return candidate as CardInstance if candidate is CardInstance else null


## 拿取一张奖赏卡加入手牌，返回拿到的卡
func take_prize(index: int = 0) -> CardInstance:
	if index < 0 or index >= prizes.size():
		return null
	return take_prize_card(prizes[index])


func take_prize_from_slot(slot_index: int) -> CardInstance:
	var card: CardInstance = get_prize_at_slot(slot_index)
	if card == null:
		return null
	return take_prize_card(card)


func take_prize_card(card: CardInstance) -> CardInstance:
	if card == null or not (card in prizes):
		return null
	prizes.erase(card)
	var layout: Array = get_prize_layout()
	var slot_index: int = layout.find(card)
	if slot_index >= 0:
		layout[slot_index] = null
	card.face_up = true
	hand.append(card)
	return card


## 所有奖赏卡是否已拿完
func all_prizes_taken() -> bool:
	return prizes.is_empty()


## 洗牌
func set_forced_shuffle_seed(seed: int) -> void:
	PlayerState._forced_shuffle_seed = seed
	PlayerState._forced_shuffle_counter = 0


func clear_forced_shuffle_seed() -> void:
	PlayerState._forced_shuffle_seed = -1
	PlayerState._forced_shuffle_counter = 0


func shuffle_deck() -> void:
	var rng := RandomNumberGenerator.new()
	if PlayerState._forced_shuffle_seed >= 0:
		rng.seed = PlayerState._forced_shuffle_seed + PlayerState._forced_shuffle_counter
		PlayerState._forced_shuffle_counter += 1
	else:
		rng.randomize()
	# Fisher-Yates 洗牌
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: CardInstance = deck[i]
		deck[i] = deck[j]
		deck[j] = temp


## 将指定卡牌从弃牌区移回牌库（不洗牌）
func return_to_deck(card: CardInstance) -> bool:
	var idx := discard_pile.find(card)
	if idx == -1:
		return false
	discard_pile.remove_at(idx)
	card.face_up = false
	deck.append(card)
	return true
