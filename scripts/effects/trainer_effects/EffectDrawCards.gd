## 抽牌效果 - 从牌库抽 N 张牌
## 适用: 博士的研究（弃手牌抽7）、奇巴纳（抽3）等
## 参数: draw_count, discard_hand_first
class_name EffectDrawCards
extends BaseEffect

var draw_count: int = 1
var discard_hand_first: bool = false


func _init(count: int = 1, discard_first: bool = false) -> void:
	draw_count = count
	discard_hand_first = discard_first


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]

	if discard_hand_first:
		# 弃掉所有手牌（卡牌本身已被从手牌移除，不在 hand 中）
		var hand_copy: Array[CardInstance] = player.hand.duplicate()
		for c: CardInstance in hand_copy:
			player.hand.erase(c)
			player.discard_pile.append(c)

	# 抽牌
	player.draw_cards(draw_count)


func get_description() -> String:
	if discard_hand_first:
		return "弃掉手牌，抽%d张" % draw_count
	return "抽%d张牌" % draw_count
