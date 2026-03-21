## 抽到7张效果 - 握握抽取（皮宝宝）
## 抽牌直至手牌达到7张
class_name AttackDrawTo7
extends BaseEffect

## 目标手牌上限
const TARGET_HAND_SIZE: int = 7


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	var pi: int = top_card.owner_index
	var player: PlayerState = state.players[pi]

	# 计算需要抽的张数
	var current_hand: int = player.hand.size()
	if current_hand >= TARGET_HAND_SIZE:
		# 手牌已达到或超过7张，无需抽牌
		return

	var draw_count: int = TARGET_HAND_SIZE - current_hand

	# 抽牌（draw_count 张或直到牌库为空）
	player.draw_cards(draw_count)


func get_description() -> String:
	return "握握抽取：抽牌直到手牌达到%d张。" % TARGET_HAND_SIZE
