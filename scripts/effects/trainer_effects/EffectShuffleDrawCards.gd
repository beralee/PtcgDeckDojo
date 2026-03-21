## 洗手抽牌效果 - 将手牌放回牌库洗牌后抽 N 张
## 适用: 奇树（洗手牌回牌库抽同等数量）、Iono（双方洗手回牌库按剩余奖赏卡数抽）等
## 参数: draw_count, draw_by_prizes, affect_opponent
class_name EffectShuffleDrawCards
extends BaseEffect

## 固定抽牌数（draw_by_prizes=false 时使用；-1=与洗回数量相同）
var draw_count: int = -1
## 按剩余奖赏卡数量抽牌
var draw_by_prizes: bool = false
## 是否同时影响对手
var affect_opponent: bool = false


func _init(count: int = -1, by_prizes: bool = false, opp: bool = false) -> void:
	draw_count = count
	draw_by_prizes = by_prizes
	affect_opponent = opp


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	_shuffle_and_draw(state, pi)
	if affect_opponent:
		_shuffle_and_draw(state, 1 - pi)


func _shuffle_and_draw(state: GameState, pi: int) -> void:
	var player: PlayerState = state.players[pi]

	# 将手牌放回牌库
	var hand_size: int = player.hand.size()
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	for c: CardInstance in hand_copy:
		player.hand.erase(c)
		c.face_up = false
		player.deck.append(c)

	# 洗牌
	player.shuffle_deck()

	# 决定抽牌数量
	var count: int = draw_count
	if draw_by_prizes:
		count = player.prizes.size()
	elif count == -1:
		count = hand_size

	# 抽牌
	player.draw_cards(count)


func get_description() -> String:
	if draw_by_prizes:
		if affect_opponent:
			return "双方将手牌放回牌库洗牌，按剩余奖赏卡数量抽牌"
		return "将手牌放回牌库洗牌，按剩余奖赏卡数量抽牌"
	if draw_count == -1:
		return "将手牌放回牌库洗牌，抽同等数量的牌"
	return "将手牌放回牌库洗牌，抽%d张" % draw_count
