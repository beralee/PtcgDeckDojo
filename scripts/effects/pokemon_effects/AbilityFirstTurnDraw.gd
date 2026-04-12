## 首回合重抽特性效果 - 怒鹦哥ex（英武重抽）
## 仅在对战开始的最初回合（先攻方第一回合）可使用
## 弃置全部手牌，从牌库重新抽指定数量的卡牌
## 参数: draw_count (int)
class_name AbilityFirstTurnDraw
extends BaseEffect

## 重新抽卡数量
var draw_count: int = 6

## 已使用标记 key（整局只能用1次，通过 effects 存储）
const USED_KEY: String = "ability_first_turn_draw_used"


func _init(count: int = 6) -> void:
	draw_count = count


## 检查特性是否可以使用
## 条件: 必须是该玩家自己的第一回合，且本特性尚未使用过
func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var owner_index: int = top.owner_index
	if state.current_player_index != owner_index:
		return false

	# 先后手都只允许在自己的第一个回合使用
	var required_turn: int = 1 if owner_index == state.first_player_index else 2
	if state.turn_number != required_turn:
		return false

	# 检查是否已使用过（整局只能使用1次）
	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == USED_KEY:
			return false

	return true


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]

	# 将手牌全部弃置（放入弃牌区）
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	_discard_cards_from_hand_with_log(state, pi, hand_copy, top, "ability")

	# 从牌库抽指定数量的牌
	_draw_cards_with_log(state, top.owner_index, draw_count, top, "ability")

	# 标记此特性已使用（整局生效，不限回合号）
	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "特性【英武重抽】：仅最初回合可用。弃置全部手牌，从牌库抽%d张牌。" % draw_count
