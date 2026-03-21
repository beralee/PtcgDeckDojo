## 弗图博士的剧本 - 选择己方场上1只宝可梦回手牌，身上附属卡全部弃牌
class_name EffectProfTuro
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	## 己方至少有一只宝可梦在场（战斗区或备战区）
	var player: PlayerState = state.players[card.owner_index]
	if player.active_pokemon != null:
		return true
	for slot: PokemonSlot in player.bench:
		if not slot.pokemon_stack.is_empty():
			return true
	return false


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]

	## TODO: 需要UI交互让玩家选择要回手牌的己方宝可梦
	## 简化：优先选备战区第一只，若备战区为空则选战斗宝可梦
	var target_slot: PokemonSlot = null

	if not player.bench.is_empty():
		target_slot = player.bench[0]
	elif player.active_pokemon != null:
		target_slot = player.active_pokemon

	if target_slot == null:
		return

	## 判断目标是否为战斗宝可梦
	var is_active: bool = target_slot == player.active_pokemon

	## 将宝可梦进化链的最顶层（当前形态）卡牌放回手牌
	## 附着的能量卡、道具卡全部放入弃牌区
	## 进化链下方的卡牌也一并弃置
	var all_cards: Array[CardInstance] = target_slot.collect_all_cards()

	## 进化链最顶层卡牌回手牌
	var top_card: CardInstance = target_slot.get_top_card()
	if top_card == null:
		return

	## 将除顶层宝可梦以外的所有卡（进化来源、能量、道具）放入弃牌区
	for c: CardInstance in all_cards:
		if c == top_card:
			continue
		c.face_up = true
		player.discard_pile.append(c)

	## 顶层宝可梦回手牌
	top_card.face_up = true
	player.hand.append(top_card)

	## 从场上移除该槽位
	if is_active:
		## 战斗宝可梦撤退：需要将备战区宝可梦顶上
		## 简化处理：若备战区有宝可梦则自动换上第一只，否则战斗区置空
		player.active_pokemon = null
		if not player.bench.is_empty():
			## TODO: 需要UI交互让玩家选择哪只备战宝可梦顶上
			var new_active: PokemonSlot = player.bench[0]
			player.bench.erase(new_active)
			player.active_pokemon = new_active
	else:
		player.bench.erase(target_slot)


func get_description() -> String:
	return "选择己方场上1只宝可梦回手牌，身上附属的所有卡弃牌"
