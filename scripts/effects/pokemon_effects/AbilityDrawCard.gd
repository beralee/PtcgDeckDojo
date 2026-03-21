## 抽卡特性效果 - 使用特性时从牌库抽卡
## 适用: "每回合使用1次，抽1张卡"等特性
## 参数: draw_count
class_name AbilityDrawCard
extends BaseEffect

## 抽卡数量
var draw_count: int = 1


func _init(count: int = 1) -> void:
	draw_count = count


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	var player: PlayerState = _state.players[pi]
	player.draw_cards(draw_count)


func get_description() -> String:
	return "特性：抽%d张牌" % draw_count
