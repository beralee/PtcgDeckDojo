## 手牌入库底洗牌再抽特性效果 - 贪心栗鼠（巢穴藏身）
## 将手牌全部放回牌库底部并洗牌，然后抽1张牌
## 注意: 与一般"洗牌后抽N"不同，此特性是放回牌库"底部"后洗牌
class_name AbilityShuffleHandDraw
extends BaseEffect

## 最终抽卡数量（放回后再抽）
var draw_count: int = 1

## 每回合已使用标记 key
const USED_KEY: String = "ability_shuffle_hand_draw_used"


func _init(count: int = 1) -> void:
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

	# 将手牌全部放回牌库底部
	var hand_copy: Array[CardInstance] = []
	hand_copy.append_array(player.hand)
	player.hand.clear()

	hand_copy.shuffle()
	for card: CardInstance in hand_copy:
		card.face_up = false
		player.deck.append(card)

	# 从牌库顶抽指定数量的牌
	_draw_cards_with_log(state, top.owner_index, draw_count, top, "ability")

	# 标记本回合已使用
	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "特性【巢穴藏身】：将手牌全部放回牌库底并洗牌，然后抽%d张牌。（每回合1次）" % draw_count
