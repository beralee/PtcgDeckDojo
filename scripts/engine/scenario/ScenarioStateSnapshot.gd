class_name ScenarioStateSnapshot
extends RefCounted


const FORMAT_VERSION: int = 1
const PLAYER_COUNT: int = 2


static func capture(game_state: GameState) -> Dictionary:
	if game_state == null:
		return {}

	return {
		"format_version": FORMAT_VERSION,
		"turn_number": game_state.turn_number,
		"current_player_index": game_state.current_player_index,
		"first_player_index": game_state.first_player_index,
		"phase": _phase_name(game_state.phase),
		"winner_index": game_state.winner_index,
		"win_reason": game_state.win_reason,
		"energy_attached_this_turn": game_state.energy_attached_this_turn,
		"supporter_used_this_turn": game_state.supporter_used_this_turn,
		"stadium_played_this_turn": game_state.stadium_played_this_turn,
		"retreat_used_this_turn": game_state.retreat_used_this_turn,
		"stadium_card": _capture_card_instance(game_state.stadium_card),
		"stadium_owner_index": game_state.stadium_owner_index,
		"stadium_effect_used_turn": game_state.stadium_effect_used_turn,
		"stadium_effect_used_player": game_state.stadium_effect_used_player,
		"stadium_effect_used_effect_id": game_state.stadium_effect_used_effect_id,
		"vstar_power_used": _normalize_bool_array(game_state.vstar_power_used, PLAYER_COUNT),
		"last_knockout_turn_against": _normalize_int_array(game_state.last_knockout_turn_against, PLAYER_COUNT, -999),
		"shared_turn_flags": game_state.shared_turn_flags.duplicate(true),
		"players": _capture_players(game_state.players),
	}


static func validate(raw_snapshot: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var snapshot := _extract_snapshot(raw_snapshot)
	if snapshot.is_empty():
		errors.append("snapshot is empty")
		return errors

	_require_int(snapshot, "turn_number", errors)
	_require_int(snapshot, "current_player_index", errors)
	_require_int(snapshot, "first_player_index", errors)
	if not snapshot.has("phase"):
		errors.append("phase is required")
	else:
		var phase_value: Variant = snapshot.get("phase")
		if not (phase_value is String) and not (phase_value is int):
			errors.append("phase must be String or int")
	_require_int(snapshot, "winner_index", errors)
	_require_value(snapshot, "win_reason", TYPE_STRING, errors)
	_require_value(snapshot, "energy_attached_this_turn", TYPE_BOOL, errors)
	_require_value(snapshot, "supporter_used_this_turn", TYPE_BOOL, errors)
	_require_value(snapshot, "stadium_played_this_turn", TYPE_BOOL, errors)
	_require_value(snapshot, "retreat_used_this_turn", TYPE_BOOL, errors)
	_require_value(snapshot, "stadium_owner_index", TYPE_INT, errors)
	_require_value(snapshot, "stadium_effect_used_turn", TYPE_INT, errors)
	_require_value(snapshot, "stadium_effect_used_player", TYPE_INT, errors)
	_require_value(snapshot, "stadium_effect_used_effect_id", TYPE_STRING, errors)

	var players_variant: Variant = snapshot.get("players", [])
	if not (players_variant is Array):
		errors.append("players must be an Array")
		return errors
	var players: Array = players_variant
	if players.size() != PLAYER_COUNT:
		errors.append("players must contain exactly %d entries" % PLAYER_COUNT)
	for player_index: int in range(players.size()):
		if not (players[player_index] is Dictionary):
			errors.append("players[%d] must be a Dictionary" % player_index)
			continue
		_validate_player(players[player_index] as Dictionary, player_index, errors)

	_validate_card(snapshot.get("stadium_card", {}), "stadium_card", errors, true)
	_validate_bool_array(snapshot.get("vstar_power_used", []), "vstar_power_used", PLAYER_COUNT, errors)
	_validate_int_array(snapshot.get("last_knockout_turn_against", []), "last_knockout_turn_against", PLAYER_COUNT, errors)
	if snapshot.has("shared_turn_flags") and not (snapshot.get("shared_turn_flags") is Dictionary):
		errors.append("shared_turn_flags must be a Dictionary")

	return errors


static func _capture_players(players: Array[PlayerState]) -> Array[Dictionary]:
	var captured: Array[Dictionary] = []
	for player_index: int in range(PLAYER_COUNT):
		var player: PlayerState = players[player_index] if player_index < players.size() else null
		captured.append(_capture_player(player, player_index))
	return captured


static func _capture_player(player: PlayerState, fallback_player_index: int) -> Dictionary:
	if player == null:
		return {
			"player_index": fallback_player_index,
			"active": {},
			"bench": [],
			"hand": [],
			"deck": [],
			"discard": [],
			"prizes": [],
			"prize_layout": [],
			"lost_zone": [],
			"shuffle_count": 0,
		}

	return {
		"player_index": player.player_index,
		"active": _capture_slot(player.active_pokemon),
		"bench": _capture_slot_list(player.bench),
		"hand": _capture_card_list(player.hand),
		"deck": _capture_card_list(player.deck),
		"discard": _capture_card_list(player.discard_pile),
		"prizes": _capture_card_list(player.prizes),
		"prize_layout": _capture_prize_layout(player.get_prize_layout()),
		"lost_zone": _capture_card_list(player.lost_zone),
		"shuffle_count": player.shuffle_count,
	}


static func _capture_prize_layout(layout: Array) -> Array:
	var captured: Array = []
	for entry: Variant in layout:
		if entry is CardInstance:
			captured.append(_capture_card_instance(entry as CardInstance))
		else:
			captured.append(null)
	return captured


static func _capture_slot_list(slots: Array[PokemonSlot]) -> Array[Dictionary]:
	var captured: Array[Dictionary] = []
	for slot: PokemonSlot in slots:
		captured.append(_capture_slot(slot))
	return captured


static func _capture_slot(slot: PokemonSlot) -> Dictionary:
	if slot == null:
		return {}

	return {
		"pokemon_name": slot.get_pokemon_name(),
		"prize_count": slot.get_prize_count(),
		"damage_counters": slot.damage_counters,
		"remaining_hp": slot.get_remaining_hp(),
		"max_hp": slot.get_max_hp(),
		"retreat_cost": slot.get_retreat_cost(),
		"attached_energy": _capture_card_list(slot.attached_energy),
		"attached_tool": _capture_card_instance(slot.attached_tool),
		"status_conditions": slot.status_conditions.duplicate(true),
		"effects": slot.effects.duplicate(true),
		"turn_played": slot.turn_played,
		"turn_evolved": slot.turn_evolved,
		"pokemon_stack": _capture_card_list(slot.pokemon_stack),
	}


static func _capture_card_list(cards: Array[CardInstance]) -> Array[Dictionary]:
	var captured: Array[Dictionary] = []
	for card: CardInstance in cards:
		captured.append(_capture_card_instance(card))
	return captured


static func _capture_card_instance(card: CardInstance) -> Dictionary:
	if card == null:
		return {}

	var card_data_dict: Dictionary = {}
	if card.card_data != null:
		card_data_dict = card.card_data.to_dict()
	var captured := {
		"instance_id": card.instance_id,
		"owner_index": card.owner_index,
		"face_up": card.face_up,
		"card_name": str(card_data_dict.get("name", "")),
	}
	for key: Variant in card_data_dict.keys():
		captured[str(key)] = _duplicate_variant(card_data_dict.get(key))
	return captured


static func _phase_name(phase: GameState.GamePhase) -> String:
	match int(phase):
		GameState.GamePhase.SETUP:
			return "setup"
		GameState.GamePhase.MULLIGAN:
			return "mulligan"
		GameState.GamePhase.SETUP_PLACE:
			return "setup_place"
		GameState.GamePhase.DRAW:
			return "draw"
		GameState.GamePhase.MAIN:
			return "main"
		GameState.GamePhase.ATTACK:
			return "attack"
		GameState.GamePhase.POKEMON_CHECK:
			return "pokemon_check"
		GameState.GamePhase.BETWEEN_TURNS:
			return "between_turns"
		GameState.GamePhase.KNOCKOUT_REPLACE:
			return "knockout_replace"
		GameState.GamePhase.GAME_OVER:
			return "game_over"
		_:
			return "setup"


static func _normalize_bool_array(values: Array, expected_size: int) -> Array[bool]:
	var normalized: Array[bool] = []
	for index: int in range(expected_size):
		normalized.append(bool(values[index]) if index < values.size() else false)
	return normalized


static func _normalize_int_array(values: Array, expected_size: int, fallback: int) -> Array[int]:
	var normalized: Array[int] = []
	for index: int in range(expected_size):
		normalized.append(int(values[index]) if index < values.size() else fallback)
	return normalized


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


static func _extract_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var snapshot_variant: Variant = raw_snapshot.get("state", raw_snapshot)
	return snapshot_variant if snapshot_variant is Dictionary else {}


static func _validate_player(player: Dictionary, player_array_index: int, errors: Array[String]) -> void:
	var prefix := "players[%d]" % player_array_index
	_require_int(player, "player_index", errors, prefix)
	_require_array(player, "bench", errors, prefix)
	_require_array(player, "hand", errors, prefix)
	_require_array(player, "deck", errors, prefix)
	if player.has("discard"):
		_require_array(player, "discard", errors, prefix)
	elif player.has("discard_pile"):
		_require_array(player, "discard_pile", errors, prefix)
	else:
		errors.append("%s.discard is required" % prefix)
	_require_array(player, "prizes", errors, prefix)
	_require_array(player, "lost_zone", errors, prefix)
	_require_int(player, "shuffle_count", errors, prefix)

	var active_variant: Variant = player.get("active", {})
	if not (active_variant is Dictionary):
		errors.append("%s.active must be a Dictionary" % prefix)
	else:
		_validate_slot(active_variant as Dictionary, "%s.active" % prefix, errors, true)

	var bench_variant: Variant = player.get("bench", [])
	if bench_variant is Array:
		for bench_index: int in range((bench_variant as Array).size()):
			var slot_variant: Variant = (bench_variant as Array)[bench_index]
			if not (slot_variant is Dictionary):
				errors.append("%s.bench[%d] must be a Dictionary" % [prefix, bench_index])
				continue
			_validate_slot(slot_variant as Dictionary, "%s.bench[%d]" % [prefix, bench_index], errors, false)

	_validate_card_array(player.get("hand", []), "%s.hand" % prefix, errors)
	_validate_card_array(player.get("deck", []), "%s.deck" % prefix, errors)
	_validate_card_array(player.get("discard", player.get("discard_pile", [])), "%s.discard" % prefix, errors)
	_validate_card_array(player.get("prizes", []), "%s.prizes" % prefix, errors)
	_validate_card_array(player.get("lost_zone", []), "%s.lost_zone" % prefix, errors)

	if player.has("prize_layout"):
		var prize_layout_variant: Variant = player.get("prize_layout", [])
		if not (prize_layout_variant is Array):
			errors.append("%s.prize_layout must be an Array" % prefix)
		else:
			for layout_index: int in range((prize_layout_variant as Array).size()):
				_validate_card((prize_layout_variant as Array)[layout_index], "%s.prize_layout[%d]" % [prefix, layout_index], errors, true)


static func _validate_slot(slot_variant: Dictionary, path: String, errors: Array[String], allow_empty: bool) -> void:
	if slot_variant.is_empty():
		if not allow_empty:
			errors.append("%s must not be empty" % path)
		return

	_require_array(slot_variant, "pokemon_stack", errors, path)
	_require_array(slot_variant, "attached_energy", errors, path)
	_require_int(slot_variant, "damage_counters", errors, path)
	_require_int(slot_variant, "turn_played", errors, path)
	_require_int(slot_variant, "turn_evolved", errors, path)
	if slot_variant.has("status_conditions") and not (slot_variant.get("status_conditions") is Dictionary):
		errors.append("%s.status_conditions must be a Dictionary" % path)
	if slot_variant.has("effects") and not (slot_variant.get("effects") is Array):
		errors.append("%s.effects must be an Array" % path)

	_validate_card(slot_variant.get("attached_tool", {}), "%s.attached_tool" % path, errors, true)
	_validate_card_array(slot_variant.get("pokemon_stack", []), "%s.pokemon_stack" % path, errors)
	_validate_card_array(slot_variant.get("attached_energy", []), "%s.attached_energy" % path, errors)


static func _validate_card_array(cards_variant: Variant, path: String, errors: Array[String]) -> void:
	if not (cards_variant is Array):
		errors.append("%s must be an Array" % path)
		return
	for card_index: int in range((cards_variant as Array).size()):
		_validate_card((cards_variant as Array)[card_index], "%s[%d]" % [path, card_index], errors, false)


static func _validate_card(card_variant: Variant, path: String, errors: Array[String], allow_empty: bool) -> void:
	if card_variant == null:
		return
	if not (card_variant is Dictionary):
		errors.append("%s must be a Dictionary" % path)
		return
	var card: Dictionary = card_variant
	if card.is_empty():
		if not allow_empty:
			errors.append("%s must not be empty" % path)
		return

	_require_int(card, "instance_id", errors, path)
	_require_int(card, "owner_index", errors, path)
	_require_value(card, "face_up", TYPE_BOOL, errors, path)
	if not card.has("name") and not card.has("card_name"):
		errors.append("%s must include name or card_name" % path)


static func _validate_bool_array(value: Variant, path: String, expected_size: int, errors: Array[String]) -> void:
	if not (value is Array):
		errors.append("%s must be an Array" % path)
		return
	var items: Array = value
	if items.size() != expected_size:
		errors.append("%s must contain %d entries" % [path, expected_size])
	for index: int in range(items.size()):
		if not (items[index] is bool):
			errors.append("%s[%d] must be a bool" % [path, index])


static func _validate_int_array(value: Variant, path: String, expected_size: int, errors: Array[String]) -> void:
	if not (value is Array):
		errors.append("%s must be an Array" % path)
		return
	var items: Array = value
	if items.size() != expected_size:
		errors.append("%s must contain %d entries" % [path, expected_size])
	for index: int in range(items.size()):
		if not (items[index] is int):
			errors.append("%s[%d] must be an int" % [path, index])


static func _require_array(container: Dictionary, key: String, errors: Array[String], prefix: String = "") -> void:
	if not container.has(key):
		errors.append(_path(prefix, key) + " is required")
		return
	if not (container.get(key) is Array):
		errors.append(_path(prefix, key) + " must be an Array")


static func _require_int(container: Dictionary, key: String, errors: Array[String], prefix: String = "") -> void:
	_require_value(container, key, TYPE_INT, errors, prefix)


static func _require_value(container: Dictionary, key: String, expected_type: int, errors: Array[String], prefix: String = "") -> void:
	if not container.has(key):
		errors.append(_path(prefix, key) + " is required")
		return
	if typeof(container.get(key)) != expected_type:
		errors.append("%s must be %s" % [_path(prefix, key), type_string(expected_type)])


static func _path(prefix: String, key: String) -> String:
	return key if prefix == "" else "%s.%s" % [prefix, key]
