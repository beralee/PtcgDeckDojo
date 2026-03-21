## 读风抽牌效果 - 弃置1张手牌后抽3张牌
## 适用: 洛奇亚V"读风"
class_name AttackReadWindDraw
extends BaseEffect


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var player: PlayerState = state.players[pi]

	# 弃置1张手牌（简化：自动弃置第一张）
	# TODO: 需要UI交互 — 让玩家选择要弃置的手牌
	if not player.hand.is_empty():
		var to_discard: CardInstance = player.hand[0]
		player.remove_from_hand(to_discard)
		player.discard_pile.append(to_discard)

	# 抽3张牌
	player.draw_cards(3)


func get_description() -> String:
	return "弃置1张手牌，然后抽3张牌"
