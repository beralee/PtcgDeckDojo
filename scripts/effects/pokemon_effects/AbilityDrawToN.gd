## 抽到N张特性效果 - 通用"将手牌补到N张"特性
## 适用:
##   梦幻ex（再起动）  draw_to=3, once_per_turn=true
##   大尾狸（勤奋门牙）draw_to=5, once_per_turn=true
## 参数: draw_to_count (int), once_per_turn (bool)
class_name AbilityDrawToN
extends BaseEffect

## 目标手牌数量（补足至此数量）
var draw_to_count: int = 3
## 是否每回合限用1次
var once_per_turn: bool = true

## 每回合已使用标记的 key（存入 PokemonSlot.effects）
const USED_KEY: String = "ability_draw_to_n_used"


func _init(draw_to: int = 3, once: bool = true) -> void:
	draw_to_count = draw_to
	once_per_turn = once


## 检查特性是否可以使用
func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	# 若每回合限用1次，检查本回合是否已用过
	if once_per_turn:
		for eff: Dictionary in pokemon.effects:
			if eff.get("type") == USED_KEY and eff.get("turn") == state.turn_number:
				return false

	# 检查当前手牌是否已达到或超过目标数量
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var player: PlayerState = state.players[top.owner_index]
	return player.hand.size() < draw_to_count


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

	# 计算需要抽的张数
	var current_count: int = player.hand.size()
	if current_count >= draw_to_count:
		return

	var need: int = draw_to_count - current_count
	player.draw_cards(need)

	# 若每回合限用1次，记录本回合已使用
	if once_per_turn:
		pokemon.effects.append({
			"type": USED_KEY,
			"turn": state.turn_number,
		})


func get_description() -> String:
	var limit_str: String = "（每回合1次）" if once_per_turn else ""
	return "特性：将手牌补足到%d张%s。" % [draw_to_count, limit_str]
