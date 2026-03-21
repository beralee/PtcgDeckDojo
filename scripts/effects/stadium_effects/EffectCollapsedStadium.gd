## 崩塌的竞技场 - 双方备战区上限变为4只；场地放置时若任一方超过4只需弃掉多余宝可梦
## 持续效果: 限制双方备战区上限为4（由 RuleValidator 使用 get_bench_limit 查询）
## 放置时触发: execute() 中检查并弃掉超出上限的备战宝可梦
class_name EffectCollapsedStadium
extends BaseEffect

## 竞技场生效时的备战区上限
const BENCH_LIMIT: int = 4


## 获取此竞技场下的备战区宝可梦上限
func get_bench_limit() -> int:
	return BENCH_LIMIT


## 放置竞技场时执行：检查双方备战区，若超过上限则弃掉多余宝可梦
## 超出部分的宝可梦（及其所有附属卡）被放入弃牌区
## 注意：弃掉的宝可梦不计为被击倒，不触发奖赏卡
func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	# 双方玩家各自检查
	for pi: int in 2:
		var player: PlayerState = state.players[pi]
		# 计算超出数量
		var excess: int = player.bench.size() - BENCH_LIMIT
		if excess <= 0:
			continue
		# 从备战区末尾弃掉多余宝可梦（末尾为最后放上场的）
		for _i: int in excess:
			if player.bench.is_empty():
				break
			# 弃掉最后一只备战宝可梦
			var slot: PokemonSlot = player.bench.pop_back()
			var all_cards: Array[CardInstance] = slot.collect_all_cards()
			for c: CardInstance in all_cards:
				player.discard_card(c)


func execute_on_play(card: CardInstance, state: GameState) -> void:
	execute(card, [], state)


func get_description() -> String:
	return "双方备战区上限变为%d只；放置时超出部分的宝可梦被弃掉" % BENCH_LIMIT
