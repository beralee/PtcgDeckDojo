## 对手特性无效化特性 - 振翼发（暗夜振翼）
## 只要振翼发在战斗位，对手战斗宝可梦的特性（除暗夜振翼外）无效化
## 被动特性，由 EffectProcessor 在尝试触发特性前查询。
class_name AbilityDisableOpponentAbility
extends BaseEffect

## 特性名称标识
const ABILITY_NAME: String = "暗夜振翼"


## 被动特性无需主动执行
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需执行动作
	pass


## 检查指定玩家的战斗宝可梦是否会被对手战斗位的暗夜振翼压制。
static func is_opponent_abilities_disabled(
	state: GameState,
	checking_player_index: int
) -> bool:
	# 对手玩家索引
	var opp_index: int = 1 - checking_player_index
	var opponent: PlayerState = state.players[opp_index]

	# 只检查对手战斗位宝可梦
	var active: PokemonSlot = opponent.active_pokemon
	if active == null:
		return false

	return _has_dark_wing_ability(active)


## 检查给定宝可梦是否被暗夜振翼压制。
## 只有对手的战斗宝可梦会受影响，且自身拥有暗夜振翼时不受压制。
static func is_locked_by_dark_wing(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null:
		return false
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	if not is_opponent_abilities_disabled(state, top.owner_index):
		return false
	if slot != state.players[top.owner_index].active_pokemon:
		return false
	return not _has_dark_wing_ability(slot)


## 检查单个 PokemonSlot 是否拥有"暗夜振翼"特性
static func _has_dark_wing_ability(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var cd: CardData = top.card_data
	if cd == null:
		return false
	var abilities: Variant = cd.abilities
	if abilities == null:
		return false
	for ability: Variant in abilities:
		if ability is Dictionary:
			var ab_name: Variant = ability.get("name", "")
			if ab_name is String and (ab_name as String) == ABILITY_NAME:
				return true
	return false


func get_description() -> String:
	return "特性【暗夜振翼】：只要此宝可梦在战斗位，对手战斗宝可梦的特性全部消除。"
