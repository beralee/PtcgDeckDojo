class_name AttackActiveEnergyCountDamage
extends BaseEffect

var damage_per_energy: int = 30


func _init(per_energy: int = 30) -> void:
	damage_per_energy = per_energy


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return 0
	var opponent: PlayerState = state.players[1 - top.owner_index]
	if opponent.active_pokemon == null:
		return 0
	return (attacker.attached_energy.size() + opponent.active_pokemon.attached_energy.size()) * damage_per_energy


func get_description() -> String:
	return "This attack does more damage for each Energy attached to both Active Pokemon."
