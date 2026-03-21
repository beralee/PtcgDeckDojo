## 精神拥抱特性 - 沙奈朵ex
## 每回合可使用任意次。从弃牌区选1张基本超能量附着到己方超属性宝可梦上，
## 然后在被附着的宝可梦上放置2个伤害指示物。
## 不能对放置指示物后会昏厥的宝可梦使用。
class_name AbilityPsychicEmbrace
extends BaseEffect


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var player: PlayerState = state.players[top.owner_index]
	# 弃牌区需要有基本超能量
	if not _has_psychic_energy_in_discard(player):
		return false
	# 场上需要有可以接受能量的超属性宝可梦（放2个指示物后不会KO）
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_valid_target(slot):
			return true
	return false


func can_use_embrace_on_target(target: PokemonSlot) -> bool:
	return _is_valid_target(target)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	# 步骤1：选择弃牌区的超能量
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		if _is_basic_psychic_energy(discard_card):
			energy_items.append(discard_card)
			energy_labels.append(discard_card.card_data.name)
	if energy_items.is_empty():
		return []

	# 步骤2：选择己方超属性宝可梦
	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_valid_target(slot):
			target_items.append(slot)
			target_labels.append(slot.get_pokemon_name())
	if target_items.is_empty():
		return []

	return [
		{
			"id": "embrace_energy",
			"title": "选择弃牌区中1张基本超能量",
			"items": energy_items,
			"labels": energy_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "embrace_target",
			"title": "选择要附着能量的超属性宝可梦",
			"items": target_items,
			"labels": target_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	# 获取选中的能量
	var energy_raw: Array = ctx.get("embrace_energy", [])
	var energy_card: CardInstance = null
	if not energy_raw.is_empty() and energy_raw[0] is CardInstance:
		var candidate: CardInstance = energy_raw[0] as CardInstance
		if candidate in player.discard_pile and _is_basic_psychic_energy(candidate):
			energy_card = candidate
	if energy_card == null:
		# 自动选择
		for dc: CardInstance in player.discard_pile:
			if _is_basic_psychic_energy(dc):
				energy_card = dc
				break
	if energy_card == null:
		return

	# 获取选中的目标
	var target_raw: Array = ctx.get("embrace_target", [])
	var target_slot: PokemonSlot = null
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = target_raw[0] as PokemonSlot
		if candidate in player.get_all_pokemon() and _is_valid_target(candidate):
			target_slot = candidate
	if target_slot == null:
		for slot: PokemonSlot in player.get_all_pokemon():
			if _is_valid_target(slot):
				target_slot = slot
				break
	if target_slot == null:
		return

	# 执行：从弃牌区移除能量，附着到目标，放置2个伤害指示物
	player.discard_pile.erase(energy_card)
	energy_card.face_up = true
	target_slot.attached_energy.append(energy_card)
	target_slot.damage_counters += 20


func _is_basic_psychic_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.card_type == "Basic Energy" and card.card_data.energy_provides == "P"


func _has_psychic_energy_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		if _is_basic_psychic_energy(card):
			return true
	return false


func _is_valid_target(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null or top.card_data == null:
		return false
	# 必须是超属性宝可梦
	if top.card_data.energy_type != "P":
		return false
	# 放置2个伤害指示物后不能导致昏厥
	if slot.damage_counters + 20 >= slot.get_max_hp():
		return false
	return true


func get_description() -> String:
	return "特性【精神拥抱】：从弃牌区选1张基本超能量附着到己方超属性宝可梦上，放置2个伤害指示物。（每回合可任意次使用）"
