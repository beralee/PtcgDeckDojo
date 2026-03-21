## 捩木 - 从弃牌区选1只基础宝可梦，与己方场上1只基础宝可梦互换
## 被换下的基础宝可梦放弃牌区，换上的宝可梦继承原位置上的所有附属卡和状态
class_name EffectThorton
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]

	## 弃牌区必须有基础宝可梦
	var has_basic_in_discard: bool = false
	for c: CardInstance in player.discard_pile:
		if c.card_data.is_basic_pokemon():
			has_basic_in_discard = true
			break

	if not has_basic_in_discard:
		return false

	## 场上必须有基础宝可梦（战斗区或备战区的顶层为基础宝可梦）
	if player.active_pokemon != null:
		var active_data: CardData = player.active_pokemon.get_card_data()
		if active_data != null and active_data.is_basic_pokemon():
			return true

	for slot: PokemonSlot in player.bench:
		var slot_data: CardData = slot.get_card_data()
		if slot_data != null and slot_data.is_basic_pokemon():
			return true

	return false


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]

	## TODO: 需要UI交互让玩家从弃牌区选择基础宝可梦
	## 简化：自动选弃牌区第一张基础宝可梦
	var from_discard: CardInstance = null
	for c: CardInstance in player.discard_pile:
		if c.card_data.is_basic_pokemon():
			from_discard = c
			break

	if from_discard == null:
		return

	## TODO: 需要UI交互让玩家选择场上哪只基础宝可梦被替换
	## 简化：优先选备战区第一只基础宝可梦，若无则选战斗宝可梦（若也是基础）
	var target_slot: PokemonSlot = null
	var is_active: bool = false

	for slot: PokemonSlot in player.bench:
		var slot_data: CardData = slot.get_card_data()
		if slot_data != null and slot_data.is_basic_pokemon():
			target_slot = slot
			break

	if target_slot == null and player.active_pokemon != null:
		var active_data: CardData = player.active_pokemon.get_card_data()
		if active_data != null and active_data.is_basic_pokemon():
			target_slot = player.active_pokemon
			is_active = true

	if target_slot == null:
		return

	## 从弃牌区移除选中的宝可梦卡
	player.discard_pile.erase(from_discard)

	## 将场上目标槽位的最顶层基础宝可梦卡放入弃牌区
	## 只弃置顶层宝可梦卡本身，附属卡和状态保留在槽位上
	var old_top: CardInstance = target_slot.get_top_card()
	if old_top != null:
		target_slot.pokemon_stack.erase(old_top)
		old_top.face_up = true
		player.discard_pile.append(old_top)

	## 将弃牌区取来的基础宝可梦替换进槽位（作为新的底层/顶层卡）
	from_discard.face_up = true
	## 若进化链已清空（原本是基础宝可梦独占），直接作为新顶层
	## 若进化链还有其他卡（不应出现，因为条件要求顶层是基础宝可梦），仍插入顶部
	target_slot.pokemon_stack.append(from_discard)

	## 被替换后槽位保留原有的能量、道具、伤害计数器和特殊状态
	## （规则说明：继承全部附属卡和状态）


func get_description() -> String:
	return "从弃牌区选1只基础宝可梦，与场上1只基础宝可梦互换，继承所有附属卡和状态"
