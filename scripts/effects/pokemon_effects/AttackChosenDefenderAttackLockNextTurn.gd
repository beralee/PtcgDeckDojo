class_name AttackChosenDefenderAttackLockNextTurn
extends BaseEffect

const STEP_ID := "defender_attack_name_lock"

var attack_index_to_match: int = -1


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
	var defender: PokemonSlot = state.players[1 - card.owner_index].active_pokemon
	if defender == null:
		return []
	var items: Array = []
	var labels: Array[String] = []
	for attack: Dictionary in defender.get_attacks():
		var attack_name: String = str(attack.get("name", ""))
		items.append(attack_name)
		labels.append(attack_name)
	if items.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "Choose one attack the Defending Pokemon cannot use next turn",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	if attacker == null or defender == null:
		return
	if EffectMistEnergy.has_mist_energy(defender):
		return
	var attack_name: String = _resolve_attack_name(defender)
	if attack_name == "":
		return
	defender.effects.append({
		"type": "defender_attack_lock",
		"attack_name": attack_name,
		"turn": state.turn_number,
	})


func _resolve_attack_name(defender: PokemonSlot) -> String:
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	if not selected_raw.is_empty():
		var selected_name: String = str(selected_raw[0])
		for attack: Dictionary in defender.get_attacks():
			if str(attack.get("name", "")) == selected_name:
				return selected_name
	var attacks: Array = defender.get_attacks()
	if attacks.is_empty():
		return ""
	return str((attacks[0] as Dictionary).get("name", ""))
