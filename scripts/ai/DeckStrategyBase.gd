class_name DeckStrategyBase
extends RefCounted


func get_strategy_id() -> String:
	return ""


func get_signature_names() -> Array[String]:
	return []


func get_state_encoder_class() -> GDScript:
	return null


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {}


func plan_opening_setup(_player: PlayerState) -> Dictionary:
	return {}


func score_action_absolute(_action: Dictionary, _game_state: GameState, _player_index: int) -> float:
	return 0.0


func score_action(_action: Dictionary, _context: Dictionary) -> float:
	return 0.0


func evaluate_board(_game_state: GameState, _player_index: int) -> float:
	return 0.0


func predict_attacker_damage(_slot: PokemonSlot, _extra_context: int = 0) -> Dictionary:
	return {"damage": 0, "can_attack": false, "description": ""}


func get_discard_priority(_card: CardInstance) -> int:
	return 0


func get_discard_priority_contextual(_card: CardInstance, _game_state: GameState, _player_index: int) -> int:
	return 0


func get_search_priority(_card: CardInstance) -> int:
	return 0


func score_interaction_target(_item: Variant, _step: Dictionary, _context: Dictionary = {}) -> float:
	return 0.0


# ============================================================
#  名称解析工具（优先返回英文名，兼容中英文卡牌数据）
# ============================================================

func _slot_name(slot: PokemonSlot) -> String:
	## 获取宝可梦槽位的名称，优先返回英文名
	if slot == null:
		return ""
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return ""
	if cd.name_en != "":
		return cd.name_en
	return cd.name


func _cname(card: Variant) -> String:
	## 获取卡牌实例的名称，优先返回英文名
	if card is CardInstance:
		var ci: CardInstance = card as CardInstance
		if ci.card_data != null:
			if ci.card_data.name_en != "":
				return ci.card_data.name_en
			return ci.card_data.name
	return ""


func _slot_is(slot: PokemonSlot, names: Array) -> bool:
	## 检查槽位宝可梦名称是否在列表中（同时匹配中英文）
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	return cd.name in names or cd.name_en in names


func _count_name_on_field(player: PlayerState, target_name: String) -> int:
	## 计算场上指定名称的宝可梦数量（同时匹配中英文）
	var count: int = 0
	if player.active_pokemon != null:
		if _slot_is(player.active_pokemon, [target_name]):
			count += 1
	for slot: PokemonSlot in player.bench:
		if slot != null and _slot_is(slot, [target_name]):
			count += 1
	return count
