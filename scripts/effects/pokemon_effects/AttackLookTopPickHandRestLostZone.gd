## 查看牌库顶部N张卡牌，选择M张加入手牌，其余放入放逐区
## 参数:
##   look_count  查看的卡牌数量（默认4）
##   pick_count  选择加入手牌的数量（默认2）
class_name AttackLookTopPickHandRestLostZone
extends BaseEffect

var look_count: int = 4
var pick_count: int = 2


func _init(look: int = 4, pick: int = 2) -> void:
	look_count = look
	pick_count = pick


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return []

	var actual_look: int = mini(look_count, player.deck.size())
	var looked: Array[CardInstance] = []
	for i: int in range(actual_look):
		looked.append(player.deck[i])

	var labels: Array[String] = []
	for c: CardInstance in looked:
		labels.append(c.card_data.name)

	var actual_pick: int = mini(pick_count, looked.size())
	return [{
		"id": "look_top_pick",
		"title": "选择 %d 张卡牌加入手牌（其余放入放逐区）" % actual_pick,
		"items": looked,
		"labels": labels,
		"min_select": actual_pick,
		"max_select": actual_pick,
		"allow_cancel": false,
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
	if player.deck.is_empty():
		return

	var actual_look: int = mini(look_count, player.deck.size())
	var looked: Array[CardInstance] = []
	for _i in range(actual_look):
		looked.append(player.deck.pop_front())

	# 获取玩家交互选择
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("look_top_pick", [])
	var selected_ids: Dictionary = {}
	for entry: Variant in selected_raw:
		if entry is CardInstance:
			selected_ids[(entry as CardInstance).instance_id] = true

	var kept: Array[CardInstance] = []
	var banished: Array[CardInstance] = []

	if not selected_ids.is_empty():
		# 使用玩家选择
		for card: CardInstance in looked:
			card.face_up = true
			if selected_ids.has(card.instance_id) and kept.size() < pick_count:
				kept.append(card)
			else:
				banished.append(card)
	else:
		# 向后兼容：无交互时自动选前N张
		for card: CardInstance in looked:
			card.face_up = true
			if kept.size() < pick_count:
				kept.append(card)
			else:
				banished.append(card)

	for card: CardInstance in kept:
		player.hand.append(card)
	for card: CardInstance in banished:
		player.lost_zone.append(card)


func get_description() -> String:
	return "查看自己牌库上方%d张卡牌，选择其中%d张加入手牌，其余放入放逐区。" % [look_count, pick_count]
