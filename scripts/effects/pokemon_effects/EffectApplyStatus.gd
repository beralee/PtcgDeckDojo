class_name EffectApplyStatus
extends BaseEffect

var status_name: String = "poisoned"
var require_coin: bool = false
var attack_index_to_match: int = -1


func _init(status: String = "poisoned", coin: bool = false, match_attack_index: int = -1) -> void:
	status_name = status
	require_coin = coin
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	if require_coin:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if rng.randi_range(0, 1) == 0:
			return
	defender.set_status(status_name, true)


func get_description() -> String:
	var status_cn: Dictionary = {
		"poisoned": "中毒",
		"burned": "灼伤",
		"asleep": "睡眠",
		"paralyzed": "麻痹",
		"confused": "混乱",
	}
	var name: String = status_cn.get(status_name, status_name)
	if require_coin:
		return "掷币正面使对方宝可梦%s" % name
	return "使对方宝可梦%s" % name
