## 使用后回合结束并抽卡特性效果 - 洛托姆V（快速充电）
## 使用此特性后立即结束本回合，并从牌库顶抽指定数量的卡牌
## 参数: draw_count (int)
## 引擎在执行完此特性后应立即结束当前玩家的回合
class_name AbilityEndTurnDraw
extends BaseEffect

## 抽卡数量
var draw_count: int = 3

## 回合结束标记 key（由引擎检查此标记以决定是否结束回合）
const END_TURN_KEY: String = "ability_end_turn_draw_triggered"
## 每回合已使用标记 key
const USED_KEY: String = "ability_end_turn_draw_used"


func _init(count: int = 3) -> void:
	draw_count = count


## 检查特性是否可以使用（每回合限用1次）
func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == USED_KEY and eff.get("turn") == state.turn_number:
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

	# 抽指定数量的卡牌
	player.draw_cards(draw_count)

	# 标记本回合已使用
	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})

	# 在游戏状态的当前玩家效果中设置回合结束标记
	# GameStateMachine 应在 execute_ability 返回后检查此标记并结束回合
	state.get_current_player()
	# 通过在 state 中存储一个临时标记通知引擎需要结束回合
	# 引擎约定: 检查 GameState 是否存在 "force_end_turn" 标记
	# 此处利用 pokemon.effects 传递信号（引擎可在此回合结束前检查）
	pokemon.effects.append({
		"type": END_TURN_KEY,
		"turn": state.turn_number,
		"player": pi,
	})


## 检查是否触发了回合结束（供引擎调用）
func has_end_turn_triggered(pokemon: PokemonSlot, state: GameState) -> bool:
	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == END_TURN_KEY and eff.get("turn") == state.turn_number:
			return true
	return false


func get_description() -> String:
	return "特性【快速充电】：使用此特性后抽%d张牌，然后回合结束。（每回合1次）" % draw_count
