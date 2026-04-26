class_name AttackEnergyCountDamage
extends BaseEffect

var energy_type: String = ""
var damage_per_energy: int = 40
var count_all_own: bool = false
var attack_index_to_match: int = -1


func _init(
	e_type: String = "",
	dmg_per_e: int = 40,
	all_own: bool = false,
	match_attack_index: int = -1
) -> void:
	energy_type = e_type
	damage_per_energy = dmg_per_e
	count_all_own = all_own
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or defender == null or state == null:
		return
	if not applies_to_attack_index(attack_index):
		return
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return

	var player_index: int = top_card.owner_index
	var energy_count: int = 0
	if count_all_own:
		var player: PlayerState = state.players[player_index]
		for slot: PokemonSlot in player.get_all_pokemon():
			energy_count += _count_matching_energy(slot)
	else:
		energy_count = _count_matching_energy(attacker)

	defender.damage_counters += damage_per_energy * energy_count


func _count_matching_energy(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	if energy_type == "":
		return slot.get_total_energy_count()
	return slot.count_energy_of_type(energy_type)


func get_description() -> String:
	var type_label: String = energy_type if energy_type != "" else "any"
	var scope_label: String = "own field" if count_all_own else "self"
	return "%s: +%d damage for each %s Energy" % [
		scope_label,
		damage_per_energy,
		type_label,
	]
