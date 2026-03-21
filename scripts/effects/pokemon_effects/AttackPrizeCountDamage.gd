## 按对手已拿奖赏卡数追加伤害
class_name AttackPrizeCountDamage
extends BaseEffect

var damage_per_prize: int = 30


func _init(per_prize: int = 30) -> void:
	damage_per_prize = per_prize


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return 0
	var opponent: PlayerState = state.players[1 - top_card.owner_index]
	var prizes_taken: int = maxi(0, 6 - opponent.prizes.size())
	return prizes_taken * damage_per_prize


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "对手每拿走1张奖赏卡，伤害增加%d。" % damage_per_prize
