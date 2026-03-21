class_name AttackLostZoneKO
extends BaseEffect

var min_lost_zone_count: int = 10


func _init(min_count: int = 10) -> void:
	min_lost_zone_count = min_count


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return

	var player_index: int = top_card.owner_index
	var player: PlayerState = state.players[player_index]
	if player.lost_zone.size() < min_lost_zone_count:
		return
	if state.vstar_power_used[player_index]:
		return

	state.vstar_power_used[player_index] = true
	attacker.effects.append({
		"type": "vstar_power_used",
		"player_index": player_index,
		"turn": state.turn_number,
	})

	var max_hp: int = defender.get_max_hp()
	if max_hp <= 0:
		max_hp = 9999
	defender.damage_counters = max_hp


func get_description() -> String:
	return "Lost Zone KO VSTAR Power."
