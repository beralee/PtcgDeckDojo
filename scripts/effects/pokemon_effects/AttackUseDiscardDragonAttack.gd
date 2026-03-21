## 巨龙无双 - 雷吉铎拉戈VSTAR 招式效果
## 从弃牌区选择一只龙系宝可梦的招式，作为本招式使用。
## 伤害 = 被复制招式的基础伤害；附加效果 = 被复制招式在 EffectProcessor 中注册的所有效果。
class_name AttackUseDiscardDragonAttack
extends BaseEffect

var _processor: EffectProcessor

## 当前效果实例自身的 effect_id，用于防止复制自己
const _OWN_EFFECT_ID: String = "749d2f12d33057c8cc20e52c1b11bcbf"


func _init(processor: EffectProcessor) -> void:
	_processor = processor


## ==================== 交互步骤 ====================
## 让玩家从弃牌区龙系宝可梦中选择一个招式
func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		var card_data: CardData = discard_card.card_data
		if card_data == null or not card_data.is_pokemon() or card_data.energy_type != "N":
			continue
		# 不允许复制自身（防止递归）
		if card_data.effect_id == _OWN_EFFECT_ID:
			continue
		for attack_index: int in card_data.attacks.size():
			var copied_attack: Dictionary = card_data.attacks[attack_index]
			# 跳过 VSTAR 力量招式，不能被复制
			if copied_attack.get("is_vstar_power", false):
				continue
			items.append({
				"source_card": discard_card,
				"attack_index": attack_index,
				"attack": copied_attack,
			})
			labels.append("%s - %s" % [card_data.name, str(copied_attack.get("name", ""))])
	if items.is_empty():
		return []
	return [{
		"id": "copied_attack",
		"title": "选择弃牌区中龙系宝可梦的1个招式",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


## ==================== 动态后续交互步骤 ====================
## 在玩家选择了要复制的招式之后，查询被复制招式是否有自己的交互步骤
## （如幻影潜袭的伤害指示物分配），并将其追加到交互流程中。
func get_followup_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if _processor == null:
		return []
	var selected_raw: Array = resolved_context.get("copied_attack", [])
	if selected_raw.is_empty() or not (selected_raw[0] is Dictionary):
		return []
	var option: Dictionary = selected_raw[0]
	var source_card: Variant = option.get("source_card", null)
	var copied_attack_index: int = int(option.get("attack_index", -1))
	var copied_attack: Dictionary = option.get("attack", {})
	if not (source_card is CardInstance):
		return []
	var source_instance: CardInstance = source_card
	if source_instance.card_data == null or source_instance.card_data.effect_id == _OWN_EFFECT_ID:
		return []
	return _processor.get_attack_interaction_steps_by_id(
		source_instance.card_data.effect_id,
		copied_attack_index,
		card,
		copied_attack,
		state,
		AttackUseDiscardDragonAttack
	)


## ==================== 伤害计算 ====================
## 返回被复制招式的基础伤害值（作为伤害加值，因为巨龙无双本身 damage 为空）
func get_damage_bonus(_attacker: PokemonSlot, _state: GameState) -> int:
	var option: Dictionary = _get_selected_option()
	if option.is_empty():
		return 0
	var attack: Dictionary = option.get("attack", {})
	return DamageCalculator.new().parse_damage(str(attack.get("damage", "")))


## ==================== 效果执行 ====================
## 使用真正的攻击者（雷吉铎拉戈自身）执行被复制招式的全部附加效果
func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	if _processor == null:
		return
	var option: Dictionary = _get_selected_option()
	if option.is_empty():
		return
	var source_card: Variant = option.get("source_card", null)
	var copied_attack_index: int = int(option.get("attack_index", -1))
	if not (source_card is CardInstance):
		return
	var source_instance: CardInstance = source_card
	if source_instance.card_data == null:
		return
	if source_instance.card_data.effect_id == _OWN_EFFECT_ID:
		return

	var ctx: Dictionary = get_attack_interaction_context()
	# 通过 EffectProcessor 的专用方法执行被复制招式的效果
	# 使用真正的 attacker（雷吉铎拉戈），确保 owner_index 正确
	# 排除自身类型，防止递归
	_processor.execute_attack_effect_by_id(
		source_instance.card_data.effect_id,
		copied_attack_index,
		attacker,
		defender,
		state,
		[ctx],
		AttackUseDiscardDragonAttack
	)


## ==================== 工具方法 ====================
func _get_selected_option() -> Dictionary:
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("copied_attack", [])
	if selected_raw.is_empty() or not (selected_raw[0] is Dictionary):
		return {}
	return selected_raw[0]


func get_description() -> String:
	return "选择弃牌区中龙系宝可梦的1个招式，作为本招式使用。"
