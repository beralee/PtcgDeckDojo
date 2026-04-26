class_name ScenarioEquivalenceRegistry
extends RefCounted


static func extract_primary(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null:
		return {}
	if player_index < 0 or player_index >= game_state.players.size():
		return {}
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return {}

	return {
		"tracked_player": _extract_player_primary(game_state.get_player(player_index)),
		"opponent": _extract_player_primary(game_state.get_player(opponent_index)),
	}


static func extract_secondary(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null:
		return {}
	if player_index < 0 or player_index >= game_state.players.size():
		return {}
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return {}

	return {
		"tracked_player": _extract_player_secondary(game_state.get_player(player_index)),
		"opponent": _extract_player_secondary(game_state.get_player(opponent_index)),
	}


static func _extract_player_primary(player: PlayerState) -> Dictionary:
	if player == null:
		return {
			"active": {},
			"bench": [],
			"hand": [],
			"prize_count": 0,
		}

	return {
		"active": _extract_slot_primary(player.active_pokemon),
		"bench": _sort_slot_summaries(_extract_bench_primary(player.bench)),
		"hand": _sorted_card_names(player.hand),
		"prize_count": player.prizes.size(),
	}


static func _extract_player_secondary(player: PlayerState) -> Dictionary:
	if player == null:
		return {
			"total_remaining_hp": 0,
			"total_energy": 0,
			"discard_card_names": [],
		}

	var total_remaining_hp := 0
	var total_energy := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		total_remaining_hp += slot.get_remaining_hp()
		total_energy += slot.get_total_energy_count()

	return {
		"total_remaining_hp": total_remaining_hp,
		"total_energy": total_energy,
		"discard_card_names": _sorted_card_names(player.discard_pile),
	}


static func _extract_bench_primary(bench: Array) -> Array:
	var summaries: Array = []
	for slot_variant: Variant in bench:
		if slot_variant is PokemonSlot:
			summaries.append(_extract_slot_primary(slot_variant as PokemonSlot))
	return summaries


static func _extract_slot_primary(slot: PokemonSlot) -> Dictionary:
	if slot == null or slot.pokemon_stack.is_empty():
		return {}

	var energy_types := {}
	for energy: CardInstance in slot.attached_energy:
		var bucket := _energy_bucket(energy)
		energy_types[bucket] = int(energy_types.get(bucket, 0)) + 1

	return {
		"pokemon_name": slot.get_pokemon_name(),
		"evolution_stack": _card_names(slot.pokemon_stack),
		"energy_count": slot.get_total_energy_count(),
		"energy_types": _sort_count_dict(energy_types),
		"tool_name": _card_name(slot.attached_tool),
		"damage": slot.damage_counters,
	}


static func _card_names(cards: Array) -> Array[String]:
	var names: Array[String] = []
	for card_variant: Variant in cards:
		names.append(_card_name(card_variant as CardInstance))
	return names


static func _sorted_card_names(cards: Array) -> Array[String]:
	var names := _card_names(cards)
	names.sort()
	return names


static func _card_name(card: CardInstance) -> String:
	if card == null:
		return ""
	return card.get_name()


static func _energy_bucket(card: CardInstance) -> String:
	if card == null:
		return ""
	if card.card_data == null:
		return card.get_name()
	var provided := String(card.card_data.energy_provides)
	if provided != "":
		return provided
	return card.get_name()


static func _sort_count_dict(counts: Dictionary) -> Dictionary:
	var keys: Array[String] = []
	for key_variant: Variant in counts.keys():
		keys.append(str(key_variant))
	keys.sort()

	var sorted := {}
	for key: String in keys:
		sorted[key] = int(counts.get(key, 0))
	return sorted


static func _sort_slot_summaries(summaries: Array) -> Array:
	var keyed: Array = []
	for summary_variant: Variant in summaries:
		var summary: Dictionary = summary_variant if summary_variant is Dictionary else {}
		keyed.append({
			"key": _slot_canonical(summary),
			"value": summary,
		})
	keyed.sort_custom(Callable(ScenarioEquivalenceRegistry, "_sort_keyed_values"))

	var sorted: Array = []
	for item_variant: Variant in keyed:
		var item: Dictionary = item_variant if item_variant is Dictionary else {}
		sorted.append(item.get("value", {}))
	return sorted


static func _slot_canonical(slot: Dictionary) -> String:
	if slot.is_empty():
		return "{}"
	return JSON.stringify({
		"pokemon_name": String(slot.get("pokemon_name", "")),
		"evolution_stack": slot.get("evolution_stack", []),
		"energy_count": int(slot.get("energy_count", 0)),
		"energy_types": _sort_count_dict(slot.get("energy_types", {}) as Dictionary),
		"tool_name": String(slot.get("tool_name", "")),
		"damage": int(slot.get("damage", 0)),
	})


static func _sort_keyed_values(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("key", "")) < str(right.get("key", ""))
