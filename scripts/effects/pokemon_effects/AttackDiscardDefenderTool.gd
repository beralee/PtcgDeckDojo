## 狙落 - 钥圈儿
## 在造成伤害前，将对手战斗宝可梦身上的宝可梦道具放入弃牌区。
class_name AttackDiscardDefenderTool
extends BaseEffect


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if defender == null or defender.attached_tool == null:
		return
	var tool_card: CardInstance = defender.attached_tool
	defender.attached_tool = null
	var defender_top: CardInstance = defender.get_top_card()
	if defender_top != null:
		var opp_player: PlayerState = state.players[defender_top.owner_index]
		opp_player.discard_card(tool_card)
	else:
		tool_card.face_up = false


func get_description() -> String:
	return "在造成伤害前，弃掉对手战斗宝可梦的道具。"
