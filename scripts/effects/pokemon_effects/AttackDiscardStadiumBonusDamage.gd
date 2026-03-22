class_name AttackDiscardStadiumBonusDamage
extends BaseEffect

const STEP_ID := "discard_stadium_bonus"

var damage_bonus: int = 120
var attack_index_to_match: int = -1


func _init(bonus: int = 120, match_attack_index: int = -1) -> void:
	damage_bonus = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	_card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var attack_index: int = int(attack.get("_override_attack_index", attack.get("index", attack_index_to_match)))
	if not applies_to_attack_index(attack_index) or state.stadium_card == null:
		return []
	return [{
		"id": STEP_ID,
		"title": "Discard the Stadium for +%d damage?" % damage_bonus,
		"items": ["keep", "discard"],
		"labels": ["Keep the Stadium", "Discard the Stadium"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func get_damage_bonus(_attacker: PokemonSlot, _state: GameState) -> int:
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	if not selected_raw.is_empty() and str(selected_raw[0]) == "discard":
		return damage_bonus
	return 0


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index) or state.stadium_card == null:
		return
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	if selected_raw.is_empty() or str(selected_raw[0]) != "discard":
		return
	var owner_index: int = state.stadium_owner_index
	if owner_index >= 0 and owner_index < state.players.size():
		state.players[owner_index].discard_pile.append(state.stadium_card)
	state.stadium_card = null
	state.stadium_owner_index = -1


func get_description() -> String:
	return "You may discard the Stadium in play. If you do, this attack does more damage."
