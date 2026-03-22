## 效果基类 - 所有卡牌效果脚本继承此类
class_name BaseEffect
extends RefCounted

var _attack_interaction_context: Dictionary = {}

## 效果需要的目标选择类型
enum TargetType {
	NONE,                ## 无需选择目标
	OWN_ACTIVE,          ## 己方战斗宝可梦
	OPP_ACTIVE,          ## 对方战斗宝可梦
	OWN_BENCH,           ## 己方备战宝可梦（单选）
	OPP_BENCH,           ## 对方备战宝可梦（单选）
	OWN_ANY_POKEMON,     ## 己方任意宝可梦（单选）
	OPP_ANY_POKEMON,     ## 对方任意宝可梦（单选）
	ANY_POKEMON,         ## 任意一方宝可梦（单选）
	HAND_CARD,           ## 手牌中的卡（单选）
	DISCARD_CARD,        ## 弃牌区中的卡（单选）
	ENERGY_ON_POKEMON,   ## 宝可梦上的能量
	COIN_FLIP,           ## 需要投币
	PLAYER_CHOICE,       ## 玩家自由选择
}


## 获取效果所需的目标类型
func get_target_type() -> TargetType:
	return TargetType.NONE


## 返回此效果所需的交互步骤。
## 每个步骤 Dictionary 约定:
## {
##   "id": String,
##   "title": String,
##   "items": Array,
##   "labels": Array[String],
##   "min_select": int,
##   "max_select": int,
##   "allow_cancel": bool,
## }
##
## 分配型步骤额外约定:
## {
##   "ui_mode": "card_assignment",
##   "source_items": Array,
##   "source_labels": Array[String],
##   "target_items": Array,
##   "target_labels": Array[String],
## }
func get_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


func get_attack_interaction_steps(
	_card: CardInstance,
	_attack: Dictionary,
	_state: GameState
) -> Array[Dictionary]:
	return []


## 在交互步骤被用户完成后，根据已收集的上下文返回后续交互步骤。
## 用于支持动态链式交互（如巨龙无双选择招式后，被复制招式可能需要额外交互）。
func get_followup_attack_interaction_steps(
	_card: CardInstance,
	_attack: Dictionary,
	_state: GameState,
	_resolved_context: Dictionary
) -> Array[Dictionary]:
	return []


## 从 targets 中提取交互上下文。
## 约定 BattleScene 会将收集到的选择结果作为单个 Dictionary 放入 targets[0]。
func get_interaction_context(targets: Array) -> Dictionary:
	if targets.is_empty():
		return {}
	var ctx: Variant = targets[0]
	return ctx.duplicate(false) if ctx is Dictionary else {}


func set_attack_interaction_context(targets: Array) -> void:
	_attack_interaction_context = get_interaction_context(targets)


func get_attack_interaction_context() -> Dictionary:
	return _attack_interaction_context


func clear_attack_interaction_context() -> void:
	_attack_interaction_context.clear()


func build_card_assignment_step(
	step_id: String,
	title: String,
	source_items: Array,
	source_labels: Array[String],
	target_items: Array,
	target_labels: Array[String],
	min_assignments: int,
	max_assignments: int,
	allow_cancel: bool = true
) -> Dictionary:
	return {
		"id": step_id,
		"title": title,
		"ui_mode": "card_assignment",
		"source_items": source_items,
		"source_labels": source_labels,
		"target_items": target_items,
		"target_labels": target_labels,
		"min_select": min_assignments,
		"max_select": max_assignments,
		"allow_cancel": allow_cancel,
	}


## 检查效果是否可以执行（使用前验证）
func can_execute(_card: CardInstance, _state: GameState) -> bool:
	return true


## 执行卡牌效果（训练家卡/特殊能量使用时调用）
func execute(_card: CardInstance, _targets: Array, _state: GameState) -> void:
	pass


## 使出到场上前需要的交互步骤（如崩塌的竞技场要求选择要弃掉的备战宝可梦）
func get_on_play_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


## 使出到场上时执行的效果（如竞技场进场触发）
func execute_on_play(_card: CardInstance, _state: GameState, _targets: Array = []) -> void:
	pass


## 当前在场上的竞技场是否可由玩家主动使用
func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return false


## 执行招式附加效果（攻击时调用，在基础伤害结算后）
func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


## 执行特性效果
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


## 获取效果描述（用于UI提示）
func get_description() -> String:
	return ""
