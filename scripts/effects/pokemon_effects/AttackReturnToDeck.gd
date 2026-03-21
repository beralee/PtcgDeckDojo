## 自身及附属卡回牌库并洗牌效果 - 水流回转（霓虹鱼V）
## 将攻击者身上所有卡牌（宝可梦栈、附着能量、附着道具）收回牌库并洗牌
class_name AttackReturnToDeck
extends BaseEffect


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

	# 收集并直接放入牌库（不经过弃牌堆）
	for card: CardInstance in attacker.pokemon_stack:
		card.face_up = false
		player.deck.append(card)
	for card: CardInstance in attacker.attached_energy:
		card.face_up = false
		player.deck.append(card)
	if attacker.attached_tool != null:
		attacker.attached_tool.face_up = false
		player.deck.append(attacker.attached_tool)

	# 清空槽位
	attacker.pokemon_stack.clear()
	attacker.attached_energy.clear()
	attacker.attached_tool = null

	# 洗牌
	player.shuffle_deck()

	# 从场上移除
	if player.active_pokemon == attacker:
		player.active_pokemon = null
	else:
		var bench_idx: int = player.bench.find(attacker)
		if bench_idx >= 0:
			player.bench.remove_at(bench_idx)


func get_description() -> String:
	return "水流回转：将自身及所有附着卡牌放回牌库，洗牌。"
