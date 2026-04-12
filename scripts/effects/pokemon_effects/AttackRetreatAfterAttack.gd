## 攻击后替换效果 - 攻击结束后将攻击方换入备战区，从备战区选一只宝可梦出战
## 适用: 某些"攻击后切换宝可梦"效果的招式
class_name AttackRetreatAfterAttack
extends BaseEffect

func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var player: PlayerState = state.players[pi]

	# 备战区必须有宝可梦才能替换
	if player.bench.is_empty():
		return

	# TODO: 需要UI交互 — 自动选择备战区第一只宝可梦替换出战
	var new_active: PokemonSlot = player.bench[0]

	# 将当前出战宝可梦移至备战区
	player.bench.remove_at(0)
	player.active_pokemon.clear_on_leave_active()
	player.bench.append(player.active_pokemon)

	# 将选定的备战宝可梦设为出战
	player.active_pokemon = new_active


func get_description() -> String:
	return "攻击后将自身换入备战区，从备战区选一只宝可梦出战"
