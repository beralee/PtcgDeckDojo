class_name AttackAnyTargetDamage
extends BaseEffect

var damage_amount: int = 100


func _init(amount: int = 100) -> void:
	damage_amount = amount


func get_attack_interaction_steps(
	_card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - state.current_player_index]
	var items: Array = opponent.get_all_pokemon()
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		labels.append(slot.get_pokemon_name())
	return [{
		"id": "any_target",
		"title": "Choose 1 opponent Pokemon",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("any_target", [])
	var target: PokemonSlot = null
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot and selected_raw[0] in opponent.get_all_pokemon():
		target = selected_raw[0]
	if target == null:
		target = defender
	# 直接放置伤害指示物（不计弱点抗性），无论目标是战斗还是备战宝可梦
	target.damage_counters += damage_amount


func get_description() -> String:
	return "给对手的1只宝可梦造成%d伤害。" % damage_amount
