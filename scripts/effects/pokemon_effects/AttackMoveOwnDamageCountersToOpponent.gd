class_name AttackMoveOwnDamageCountersToOpponent
extends BaseEffect

const STEP_ID := "cresselia_damage_target"

var damage_per_pokemon: int = 20
var attack_index_to_match: int = -1


func _init(amount: int = 20, match_attack_index: int = -1) -> void:
	damage_per_pokemon = amount
	attack_index_to_match = match_attack_index


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in opponent.get_all_pokemon():
		items.append(slot)
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	if items.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "Choose an opponent Pokemon to receive moved damage counters",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var target: PokemonSlot = _resolve_target(opponent)
	if target == null:
		return
	var moved_total: int = 0
	for slot: PokemonSlot in player.get_all_pokemon():
		var moved: int = mini(damage_per_pokemon, slot.damage_counters)
		if moved <= 0:
			continue
		slot.damage_counters -= moved
		moved_total += moved
	target.damage_counters += moved_total


func _resolve_target(opponent: PlayerState) -> PokemonSlot:
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var selected: PokemonSlot = selected_raw[0]
		if selected in opponent.get_all_pokemon():
			return selected
	var all_targets: Array[PokemonSlot] = opponent.get_all_pokemon()
	return all_targets[0] if not all_targets.is_empty() else null
