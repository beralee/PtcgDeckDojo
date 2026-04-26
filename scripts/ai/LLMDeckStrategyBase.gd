class_name LLMDeckStrategyBase
extends "res://scripts/ai/DeckStrategyBase.gd"


func _get_llm_prompt_builder() -> RefCounted:
	return null


func get_llm_deck_strategy_prompt(_game_state: GameState, _player_index: int) -> PackedStringArray:
	return PackedStringArray()


func get_llm_setup_role_hint(_cd: CardData) -> String:
	return "support"


func _configure_prompt_builder(game_state: GameState, player_index: int) -> void:
	var prompt_builder := _get_llm_prompt_builder()
	if prompt_builder == null:
		return
	if prompt_builder.has_method("set_deck_strategy_prompt"):
		prompt_builder.call("set_deck_strategy_prompt", get_strategy_id(), get_llm_deck_strategy_prompt(game_state, player_index))


func _fast_choice_key(prompt_kind: String, game_state: GameState, player_index: int) -> String:
	var turn_number: int = int(game_state.turn_number) if game_state != null else -1
	return "%s:%d:%d" % [prompt_kind, player_index, turn_number]


func _fast_choice_candidates(prompt_kind: String, game_state: GameState, player_index: int) -> Array[Dictionary]:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return []
	var player: PlayerState = game_state.players[player_index]
	match prompt_kind:
		"setup_active":
			return _setup_fast_choice_candidates(player)
		"send_out":
			return _send_out_fast_choice_candidates(player)
	return []


func _setup_fast_choice_candidates(player: PlayerState) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if player == null:
		return candidates
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card == null or card.card_data == null or not card.card_data.is_basic_pokemon():
			continue
		candidates.append({
			"index": i,
			"hand_index": i,
			"name": str(card.card_data.name),
			"name_en": str(card.card_data.name_en),
			"hp": int(card.card_data.hp),
			"mechanic": str(card.card_data.mechanic),
			"energy_type": str(card.card_data.energy_type),
			"tags": Array(card.card_data.is_tags),
			"role_hint": get_llm_setup_role_hint(card.card_data),
		})
	return candidates


func _send_out_fast_choice_candidates(player: PlayerState) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if player == null:
		return candidates
	for i: int in player.bench.size():
		var slot: PokemonSlot = player.bench[i]
		if slot == null or slot.get_card_data() == null:
			continue
		var cd: CardData = slot.get_card_data()
		candidates.append({
			"index": i,
			"bench_index": i,
			"name": str(cd.name),
			"name_en": str(cd.name_en),
			"hp_remaining": slot.get_remaining_hp(),
			"max_hp": slot.get_max_hp(),
			"damage_counters": int(slot.damage_counters),
			"attached_energy_count": slot.attached_energy.size(),
			"attached_energy": _fast_energy_counts(slot),
			"attached_tool": str(slot.attached_tool.card_data.name_en if slot.attached_tool != null and slot.attached_tool.card_data != null and slot.attached_tool.card_data.name_en != "" else ""),
			"can_attack_estimate": bool(predict_attacker_damage(slot).get("can_attack", false)),
			"damage_estimate": int(predict_attacker_damage(slot).get("damage", 0)),
			"role_hint": get_llm_setup_role_hint(cd),
		})
	return candidates


func _fast_energy_counts(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var energy_type := str(card.card_data.energy_provides)
		counts[energy_type] = int(counts.get(energy_type, 0)) + 1
	return counts


func _snapshot_turn_flags(snapshot: Dictionary) -> Dictionary:
	return {
		"energy_attached_this_turn": bool(snapshot.get("energy_attached_this_turn", false)),
		"supporter_used_this_turn": bool(snapshot.get("supporter_used_this_turn", false)),
		"retreat_used_this_turn": bool(snapshot.get("retreat_used_this_turn", false)),
		"stadium_played_this_turn": bool(snapshot.get("stadium_played_this_turn", false)),
	}


func _card_instance_id_list(cards: Array[CardInstance]) -> Array[String]:
	var result: Array[String] = []
	for card: CardInstance in cards:
		if card == null:
			continue
		result.append("c%d" % int(card.instance_id))
	return result


func _card_name_list(cards: Array[CardInstance]) -> Array[String]:
	var result: Array[String] = []
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			continue
		result.append(str(card.card_data.name_en if card.card_data.name_en != "" else card.card_data.name))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			result.append(str(raw))
	return result


func _array_difference(lhs: Array[String], rhs: Array[String]) -> Array[String]:
	var remaining := {}
	for value: String in rhs:
		remaining[value] = int(remaining.get(value, 0)) + 1
	var result: Array[String] = []
	for value: String in lhs:
		var count := int(remaining.get(value, 0))
		if count > 0:
			remaining[value] = count - 1
		else:
			result.append(value)
	return result


func _match_card_name(q: Dictionary, action: Dictionary) -> bool:
	var q_card: String = str(q.get("card", "")).strip_edges()
	if q_card == "":
		return true
	var card: Variant = action.get("card")
	if not (card is CardInstance) or (card as CardInstance).card_data == null:
		return false
	return _name_contains(str((card as CardInstance).card_data.name), q_card) \
		or _name_contains(str((card as CardInstance).card_data.name_en), q_card)


func _match_attach_energy(q: Dictionary, action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _match_card_name(q, action):
		return false
	var q_energy: String = str(q.get("energy_type", ""))
	if q_energy != "":
		var card: Variant = action.get("card")
		if not (card is CardInstance) or (card as CardInstance).card_data == null:
			return false
		if not _energy_type_matches(q_energy, str((card as CardInstance).card_data.energy_provides)):
			return false
	return _match_target_slot(q, action, game_state, player_index)


func _match_card_and_target(q: Dictionary, action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _match_card_name(q, action) and _match_target_slot(q, action, game_state, player_index)


func _match_target_slot(q: Dictionary, action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var q_pos: String = str(q.get("position", q.get("target_position", ""))).strip_edges()
	var q_target: String = str(q.get("target", "")).strip_edges()
	var target_slot: Variant = action.get("target_slot")
	if not (target_slot is PokemonSlot):
		return q_pos == "" and q_target == ""
	if q_pos != "" and q_pos != _resolve_slot_position(target_slot as PokemonSlot, game_state, player_index):
		return false
	if q_target != "" and not _name_contains(str((target_slot as PokemonSlot).get_pokemon_name()), q_target):
		return false
	return true


func _match_ability(q: Dictionary, action: Dictionary, game_state: GameState, _player_index: int) -> bool:
	var q_pokemon: String = str(q.get("pokemon", "")).strip_edges()
	var q_ability: String = str(q.get("ability", "")).strip_edges()
	var source_slot: Variant = action.get("source_slot")
	if not (source_slot is PokemonSlot):
		return false
	if q_pokemon != "" and not _name_contains(str((source_slot as PokemonSlot).get_pokemon_name()), q_pokemon):
		return false
	var ability_index: int = int(action.get("ability_index", -1))
	var cd: CardData = (source_slot as PokemonSlot).get_card_data()
	if q_ability != "" and cd != null and ability_index >= 0 and ability_index < cd.abilities.size():
		return _name_contains(str((cd.abilities[ability_index] as Dictionary).get("name", "")), q_ability)
	return int(q.get("ability_index", ability_index)) == ability_index if q.has("ability_index") else true


func _match_attack(q: Dictionary, action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var attack_index: int = int(action.get("attack_index", -1))
	if q.has("attack_index") and int(q.get("attack_index", -99)) != attack_index:
		return false
	var q_attack_name: String = str(q.get("attack_name", "")).strip_edges()
	if q_attack_name == "":
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return true
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null or active.get_card_data() == null:
		return true
	var attacks: Array = active.get_card_data().attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return true
	return _name_contains(str(attacks[attack_index].get("name", "")), q_attack_name)


func _match_retreat(q: Dictionary, action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var q_bench_pos: String = str(q.get("bench_position", q.get("position", ""))).strip_edges()
	var q_bench_target: String = str(q.get("bench_target", q.get("target", ""))).strip_edges()
	var bench_index: int = int(action.get("bench_index", -1))
	if q_bench_pos != "" and q_bench_pos != "bench_%d" % bench_index:
		return false
	if q_bench_target == "" or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return true
	var player: PlayerState = game_state.players[player_index]
	if bench_index < 0 or bench_index >= player.bench.size():
		return true
	var bench_slot: PokemonSlot = player.bench[bench_index]
	if bench_slot == null:
		return true
	return _name_contains(str(bench_slot.get_pokemon_name()), q_bench_target)


func _resolve_slot_position(slot: PokemonSlot, game_state: GameState, player_index: int) -> String:
	if slot == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return ""
	var player: PlayerState = game_state.players[player_index]
	if slot == player.active_pokemon:
		return "active"
	for i: int in player.bench.size():
		if slot == player.bench[i]:
			return "bench_%d" % i
	return ""


func _name_contains(full_name: String, query: String) -> bool:
	if query.strip_edges() == "":
		return true
	var normalized_full := full_name.strip_edges().to_lower()
	var normalized_query := query.strip_edges().to_lower()
	return normalized_full == normalized_query \
		or normalized_full.contains(normalized_query) \
		or normalized_query.contains(normalized_full)


func _energy_type_matches(q_energy: String, provides: String) -> bool:
	var q := _energy_symbol_for_llm_base(q_energy)
	var p := _energy_symbol_for_llm_base(provides)
	return q != "" and p != "" and q == p


func _energy_symbol_for_llm_base(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	match normalized:
		"lightning", "l":
			return "L"
		"fighting", "f":
			return "F"
		"grass", "g":
			return "G"
		"fire", "r":
			return "R"
		"water", "w":
			return "W"
		"psychic", "p":
			return "P"
		"darkness", "dark", "d":
			return "D"
		"metal", "m":
			return "M"
		"colorless", "c":
			return "C"
		"dragon", "n":
			return "N"
	return ""
