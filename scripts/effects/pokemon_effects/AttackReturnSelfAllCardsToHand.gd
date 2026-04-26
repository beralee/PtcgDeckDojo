class_name AttackReturnSelfAllCardsToHand
extends BaseEffect

const REPLACEMENT_STEP_ID := "return_self_replacement"


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if player.bench.is_empty():
		return []
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		items.append(slot)
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [{
		"id": REPLACEMENT_STEP_ID,
		"title": "选择新的战斗宝可梦",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var replacement: PokemonSlot = _resolve_replacement(player)

	for card: CardInstance in attacker.collect_all_cards():
		card.face_up = true
		player.hand.append(card)

	attacker.pokemon_stack.clear()
	attacker.attached_energy.clear()
	attacker.attached_tool = null
	attacker.damage_counters = 0
	attacker.clear_all_status()

	if player.active_pokemon == attacker:
		player.active_pokemon = replacement
		if replacement != null:
			player.bench.erase(replacement)
	else:
		player.bench.erase(attacker)


func get_description() -> String:
	return "将这只宝可梦以及附在它身上的所有卡，全部返回手牌。"


func _resolve_replacement(player: PlayerState) -> PokemonSlot:
	if player == null or player.bench.is_empty():
		return null
	var ctx: Dictionary = get_attack_interaction_context()
	var raw: Array = ctx.get(REPLACEMENT_STEP_ID, [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var selected: PokemonSlot = raw[0]
		if selected in player.bench:
			return selected
	return player.bench[0]
