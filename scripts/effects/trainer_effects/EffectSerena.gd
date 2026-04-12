## 莎莉娜 - 二选一效果
## 模式1：弃最多3张手牌，然后抽牌直到手牌达到5张
## 模式2：选择对手备战区1只宝可梦V与对手战斗宝可梦互换
## 简化实现：自动执行模式1（弃手抽牌）
class_name EffectSerena
extends BaseEffect

## 手牌目标数量（弃牌后抽到这个数量）
const DRAW_UP_TO: int = 5
## 最多弃置手牌数
const MAX_DISCARD: int = 3


func can_execute(_card: CardInstance, _state: GameState) -> bool:
	## 莎莉娜无使用前置条件（模式1始终可选）
	return true


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]

	## 简化：自动执行模式1（弃手抽牌）
	## TODO: 需要UI交互让玩家选择执行模式1还是模式2
	## TODO: 模式1需要UI交互让玩家选择弃哪些手牌（最多3张）
	## TODO: 模式2需要UI交互让玩家选择对手备战区的宝可梦V目标

	_execute_mode_draw(player, state, card)


## 模式1：弃最多3张手牌，然后抽牌直到手牌达到5张
func _execute_mode_draw(player: PlayerState, state: GameState, source_card: CardInstance) -> void:
	## 计算当前手牌数与目标数的差值
	var current_hand: int = player.hand.size()

	## 若手牌不足目标数，不需要弃牌，直接抽牌
	if current_hand < DRAW_UP_TO:
		var draw_count: int = DRAW_UP_TO - current_hand
		_draw_cards_with_log(state, player.player_index, draw_count, source_card, "trainer")
		return

	## 手牌已达到或超过目标数时，弃置最多3张手牌后再抽同等数量
	## 简化：自动弃置手牌最后N张（最多3张）
	var discard_count: int = mini(MAX_DISCARD, current_hand)
	## 只有弃牌后手牌数低于目标数才有意义抽牌
	## 实际应由玩家决定弃几张，简化为弃至手牌降到目标数以下
	discard_count = mini(discard_count, current_hand - DRAW_UP_TO + MAX_DISCARD)
	discard_count = maxi(0, discard_count)

	for _i: int in discard_count:
		if player.hand.is_empty():
			break
		var discarded: CardInstance = player.hand.back()
		_discard_cards_from_hand_with_log(state, player.player_index, [discarded], source_card, "trainer")

	## 抽牌直到手牌达到5张
	var new_hand: int = player.hand.size()
	if new_hand < DRAW_UP_TO:
		_draw_cards_with_log(state, player.player_index, DRAW_UP_TO - new_hand, source_card, "trainer")


func get_description() -> String:
	return "弃最多%d张手牌后抽牌至%d张（简化：自动执行弃手抽牌模式）" % [MAX_DISCARD, DRAW_UP_TO]
