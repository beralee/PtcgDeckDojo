## 瞬步特性效果 - 雷公V（瞬步）
## 每回合可使用一次：从牌库抽1张卡
## 主动特性，玩家选择使用时由游戏状态机调用 execute_ability
class_name AbilityThunderousCharge
extends BaseEffect

## 已使用标记的效果类型键（存储在 pokemon.effects 中）
const USED_FLAG_TYPE: String = "ability_used_thunderous"


## 检查此回合是否已使用过瞬步特性
func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var owner_index: int = top.owner_index
	if state.current_player_index != owner_index:
		return false
	var player: PlayerState = state.players[owner_index]
	if player.active_pokemon != pokemon:
		return false
	if player.deck.is_empty():
		return false

	# 遍历 pokemon.effects，查找本回合的使用记录
	for eff: Dictionary in pokemon.effects:
		var eff_type: Variant = eff.get("type", "")
		var eff_turn: Variant = eff.get("turn", -1)
		if eff_type == USED_FLAG_TYPE and eff_turn == state.turn_number:
			return false
	return true


## 执行瞬步特性：从牌库抽1张卡，并记录本回合已使用
func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	# 检查本回合是否已使用
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]

	# 抽1张卡
	_draw_cards_with_log(state, pi, 1, top, "ability")

	# 记录本回合已使用标记，防止同一回合重复使用
	var used_flag: Dictionary = {
		"type": USED_FLAG_TYPE,
		"turn": state.turn_number
	}
	pokemon.effects.append(used_flag)


func get_description() -> String:
	return "特性【瞬步】：每回合可使用1次，从牌库抽1张卡。"
