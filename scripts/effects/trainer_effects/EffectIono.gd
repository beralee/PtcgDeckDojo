## 奇树 - 双方各将手牌放回牌库下方洗牌，然后各抽取与自己剩余奖赏卡张数相同数量的卡
class_name EffectIono
extends BaseEffect


func can_execute(_card: CardInstance, _state: GameState) -> bool:
	## 奇树无使用条件限制
	return true


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	## 双方同时执行：将手牌放回牌库下方洗牌，再按奖赏卡数量抽牌
	_shuffle_hand_and_draw_by_prizes(state, pi)
	_shuffle_hand_and_draw_by_prizes(state, 1 - pi)


## 将指定玩家的手牌放回牌库下方洗牌，再按剩余奖赏卡数量抽牌
func _shuffle_hand_and_draw_by_prizes(state: GameState, pi: int) -> void:
	var player: PlayerState = state.players[pi]

	## 将手牌放回牌库（放到底部）
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	for c: CardInstance in hand_copy:
		player.hand.erase(c)
		c.face_up = false
		player.deck.append(c)

	## 洗牌
	player.shuffle_deck()

	## 按剩余奖赏卡数量决定抽牌数
	var draw_count: int = player.prizes.size()

	## 抽牌
	player.draw_cards(draw_count)


func get_description() -> String:
	return "双方各将手牌放回牌库洗牌，然后各抽取与自己剩余奖赏卡张数相同数量的卡"
