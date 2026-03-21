## 可选弃置竞技场效果 - 攻击时可选择弃置场上的竞技场卡
## 适用: 大比鸟ex"狂风呼啸"、洛奇亚V"气旋俯冲"、洛奇亚VSTAR"风暴俯冲"
## 参数: discard_stadium（简化：始终弃置，若场上有竞技场）
class_name AttackOptionalDiscardStadium
extends BaseEffect

## 是否弃置竞技场（简化：始终为 true，存在即弃置）
var discard_stadium: bool = true


func _init(do_discard: bool = true) -> void:
	discard_stadium = do_discard


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if not discard_stadium:
		return
	if state.stadium_card == null:
		return

	# TODO: 需要UI交互 — 自动选择弃置竞技场
	# 将竞技场卡放入其拥有者的弃牌堆
	var owner_idx: int = state.stadium_owner_index
	if owner_idx >= 0 and owner_idx < state.players.size():
		var owner_player: PlayerState = state.players[owner_idx]
		owner_player.discard_pile.append(state.stadium_card)

	# 清除场上竞技场
	state.stadium_card = null
	state.stadium_owner_index = -1


func get_description() -> String:
	return "可以弃置场上的竞技场"
