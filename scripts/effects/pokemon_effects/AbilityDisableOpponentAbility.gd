## 对手特性无效化特性 - 振翼发（暗夜振翼）
## 只要振翼发在战斗位，对手场上所有宝可梦的特性无效化
## 被动特性，由 EffectProcessor 在尝试触发对手特性前调用 is_opponent_abilities_disabled()
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


## 检查指定玩家（checking_player_index）的特性是否被对手的振翼发压制
## 逻辑：检查对手（1 - checking_player_index）的战斗位是否有拥有"暗夜振翼"的宝可梦
## 只有对手战斗位的振翼发才能触发此效果，备战区无效
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
			if ab_name is String and (ab_name as String).contains(ABILITY_NAME):
				return true
	return false


func get_description() -> String:
	return "特性【暗夜振翼】：只要此宝可梦在战斗位，对手场上所有宝可梦的特性无效化。"
