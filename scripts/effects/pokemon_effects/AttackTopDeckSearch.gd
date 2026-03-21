## 看牌库顶选卡效果 - 查看牌库顶若干张，选取符合条件的卡加入手牌，其余放回顶部
## 适用: 骑拉帝纳V"深渊探求"(看顶2张选1)、铁哑铃"磁力抬升"(看顶2张选1道具)
## 参数: look_count, pick_count, card_filter
class_name AttackTopDeckSearch
extends BaseEffect

## 查看牌库顶的张数
var look_count: int = 2
## 最多选取加入手牌的张数
var pick_count: int = 1
## 卡牌类型过滤（空 = 任意类型；例如 "Tool" 只选道具卡）
var card_filter: String = ""


func _init(look: int = 2, pick: int = 1, filter: String = "") -> void:
	look_count = look
	pick_count = pick
	card_filter = filter


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var player: PlayerState = state.players[pi]

	if player.deck.is_empty():
		return

	# 从牌库顶取出最多 look_count 张
	var actual_look: int = min(look_count, player.deck.size())
	var looked: Array = []
	for _i: int in actual_look:
		looked.append(player.deck.pop_back())

	# TODO: 需要UI交互 — 自动选取前 pick_count 张符合过滤条件的卡
	var picked: Array = []
	var returned: Array = []

	for card: CardInstance in looked:
		if picked.size() < pick_count and _matches_filter(card):
			picked.append(card)
		else:
			returned.append(card)

	# 将选取的卡加入手牌
	for card: CardInstance in picked:
		player.hand.append(card)

	# 将剩余的卡按原顺序放回牌库顶（reversed 以保持原始顺序）
	returned.reverse()
	for card: CardInstance in returned:
		player.deck.append(card)


## 判断卡牌是否符合过滤条件
func _matches_filter(card: CardInstance) -> bool:
	if card_filter == "":
		return true
	if card.card_data == null:
		return false
	return card.card_data.card_type == card_filter


func get_description() -> String:
	var filter_str: String = card_filter if card_filter != "" else "任意"
	return "查看牌库顶%d张，选取%d张%s卡加入手牌，其余放回顶部" % [look_count, pick_count, filter_str]
