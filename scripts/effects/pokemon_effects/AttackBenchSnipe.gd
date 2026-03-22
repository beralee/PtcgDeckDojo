class_name AttackBenchSnipe
extends BaseEffect

var snipe_damage: int = 90
var snipe_count: int = 2
var also_self_damage: int = 0
var attack_index_to_match: int = -1


func _init(damage: int = 90, count: int = 2, self_dmg: int = 0, match_attack_index: int = -1) -> void:
	snipe_damage = damage
	snipe_count = count
	also_self_damage = self_dmg
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	var pi: int = attacker.get_top_card().owner_index
	var opp_player: PlayerState = state.players[1 - pi]
	var targets_hit := 0
	for slot: PokemonSlot in opp_player.bench:
		if targets_hit >= snipe_count:
			break
		if AbilityBenchImmune.has_bench_immune(slot):
			continue
		if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(slot, state):
			continue
		slot.damage_counters += snipe_damage
		targets_hit += 1
	if also_self_damage > 0:
		attacker.damage_counters += also_self_damage


func get_description() -> String:
	var base: String = "对对方%d只备战宝可梦各造成%d伤害" % [snipe_count, snipe_damage]
	if also_self_damage > 0:
		return base + "，并对自己造成%d伤害" % also_self_damage
	return base
