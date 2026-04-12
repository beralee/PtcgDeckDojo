class_name DeckIdentityTracker
extends RefCounted

const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")

const SPEC_EVENT_KEYS: Array[String] = [
	"miraidon_bench_developed",
	"electric_generator_resolved",
	"miraidon_attack_ready",
	"gardevoir_stage2_online",
	"psychic_embrace_resolved",
	"gardevoir_energy_loop_online",
	"charizard_stage2_online",
	"charizard_evolution_support_used",
	"charizard_attack_ready",
]

const MIRAIDON_EX_UID := "CSV1C_050"
const ELECTRIC_GENERATOR_UID := "CSV1C_107"
const GARDEVOIR_EX_UID := "CSV2C_055"
const RARE_CANDY_UID := "CSVH1C_045"
const CHARMELEON_UID := "CSV5C_015"
const CHARIZARD_EX_UID := "CSV5C_075"

static var _card_name_lookup_ready: bool = false
static var _card_name_lookup: Dictionary = {}


func build_identity_hits(deck_key: String, action_log: Array[GameAction], state: GameState = null) -> Dictionary:
	var hits := _make_deck_hits(deck_key)
	if hits.is_empty():
		return {}

	_scan_state(deck_key, state, hits)
	_scan_action_log(deck_key, action_log, state, hits)
	return hits


func _make_deck_hits(deck_key: String) -> Dictionary:
	var hits: Dictionary = {}
	match deck_key:
		"miraidon":
			hits["miraidon_bench_developed"] = false
			hits["electric_generator_resolved"] = false
			hits["miraidon_attack_ready"] = false
		"gardevoir":
			hits["gardevoir_stage2_online"] = false
			hits["psychic_embrace_resolved"] = false
			hits["gardevoir_energy_loop_online"] = false
		"charizard_ex":
			hits["charizard_stage2_online"] = false
			hits["charizard_evolution_support_used"] = false
			hits["charizard_attack_ready"] = false
		_:
			return {}
	return hits


func _scan_state(deck_key: String, state: GameState, hits: Dictionary) -> void:
	if state == null or state.players.is_empty():
		return

	for player_variant: Variant in state.players:
		if not player_variant is PlayerState:
			continue
		var player_state := player_variant as PlayerState
		if deck_key == "miraidon" and not bool(hits.get("miraidon_bench_developed", false)):
			if _state_has_lightning_bench_development(player_state):
				hits["miraidon_bench_developed"] = true
		if deck_key == "gardevoir":
			if not bool(hits.get("gardevoir_stage2_online", false)) and _state_has_named_stage2(player_state, GARDEVOIR_EX_UID):
				hits["gardevoir_stage2_online"] = true
		if deck_key == "charizard_ex":
			if not bool(hits.get("charizard_stage2_online", false)) and _state_has_named_stage2(player_state, CHARIZARD_EX_UID):
				hits["charizard_stage2_online"] = true


func _scan_action_log(deck_key: String, action_log: Array[GameAction], state: GameState, hits: Dictionary) -> void:
	var board_states: Dictionary = {}
	var psychic_embrace_player_indices: Dictionary = {}

	for action_variant: Variant in action_log:
		if not action_variant is GameAction:
			continue
		var action := action_variant as GameAction
		var player_index: int = int(action.player_index)
		if player_index < 0:
			continue

		if not board_states.has(player_index):
			board_states[player_index] = []
		var board: Array = board_states[player_index]
		_apply_board_action(board, action)

		match deck_key:
			"miraidon":
				if not bool(hits.get("electric_generator_resolved", false)) and _action_matches_name(action, "card_name", _get_electric_generator_aliases()):
					hits["electric_generator_resolved"] = true
				if not bool(hits.get("miraidon_attack_ready", false)) and _action_matches_name(action, "attack_name", _get_miraidon_attack_aliases()):
					hits["miraidon_attack_ready"] = true
				if not bool(hits.get("miraidon_bench_developed", false)) and _board_has_lightning_bench_development(board):
					hits["miraidon_bench_developed"] = true
			"gardevoir":
				if not bool(hits.get("gardevoir_stage2_online", false)) and _action_is_evolve_into(action, GARDEVOIR_EX_UID):
					hits["gardevoir_stage2_online"] = true
				if not bool(hits.get("psychic_embrace_resolved", false)) and _action_matches_name(action, "ability_name", _get_psychic_embrace_aliases()):
					hits["psychic_embrace_resolved"] = true
					psychic_embrace_player_indices[player_index] = true
				if not bool(hits.get("gardevoir_energy_loop_online", false)) \
						and bool(psychic_embrace_player_indices.get(player_index, false)) \
						and _action_type_is(action, GameAction.ActionType.ATTACK):
					hits["gardevoir_energy_loop_online"] = true
			"charizard_ex":
				if not bool(hits.get("charizard_stage2_online", false)) and _action_is_evolve_into(action, CHARIZARD_EX_UID):
					hits["charizard_stage2_online"] = true
				if not bool(hits.get("charizard_evolution_support_used", false)) and (_action_matches_name(action, "card_name", _get_rare_candy_aliases()) or _action_is_evolve_into(action, CHARMELEON_UID) or _action_is_evolve_into(action, CHARIZARD_EX_UID)):
					hits["charizard_evolution_support_used"] = true
				if not bool(hits.get("charizard_attack_ready", false)) and _action_matches_name(action, "attack_name", _get_charizard_attack_aliases()):
					hits["charizard_attack_ready"] = true


func _apply_board_action(board: Array, action: GameAction) -> void:
	match action.action_type:
		GameAction.ActionType.SETUP_PLACE_ACTIVE, GameAction.ActionType.SETUP_PLACE_BENCH, GameAction.ActionType.PLAY_POKEMON:
			var card_name := _get_action_name(action, ["card_name"])
			var card_data := _lookup_card_data(card_name)
			if card_data != null:
				board.append(card_data)
		GameAction.ActionType.EVOLVE:
			var evolution_name := _get_action_name(action, ["evolution", "card_name"])
			var evolution_data := _lookup_card_data(evolution_name)
			if evolution_data != null:
				var base_name := str(evolution_data.evolves_from)
				var base_index := _find_board_card_index(board, base_name)
				if base_index >= 0:
					board.remove_at(base_index)
					board.append(evolution_data)
		GameAction.ActionType.KNOCKOUT:
			var pokemon_name := _get_action_name(action, ["pokemon_name"])
			var knockout_index := _find_board_card_index(board, pokemon_name)
			if knockout_index >= 0:
				board.remove_at(knockout_index)


func _find_board_card_index(board: Array, card_name: String) -> int:
	var normalized_name := _normalize_name(card_name)
	if normalized_name == "":
		return -1
	for idx in board.size():
		var card_data: CardData = board[idx] if board[idx] is CardData else null
		if card_data == null:
			continue
		if _matches_card_name(card_data, normalized_name):
			return idx
	return -1


func _board_has_lightning_bench_development(board: Array) -> bool:
	if board.size() < 3:
		return false
	var lightning_basic_count: int = 0
	for card_variant: Variant in board:
		var card_data: CardData = card_variant if card_variant is CardData else null
		if card_data == null:
			continue
		if card_data.is_basic_pokemon() and card_data.energy_type == "L":
			lightning_basic_count += 1
	if lightning_basic_count >= 2:
		return true
	return false


func _state_has_lightning_bench_development(player_state: PlayerState) -> bool:
	if player_state == null:
		return false
	var board := player_state.get_all_pokemon()
	if board.size() < 3:
		return false
	var lightning_basic_count: int = 0
	for slot: PokemonSlot in board:
		var card_data := slot.get_card_data()
		if card_data != null and card_data.is_basic_pokemon() and card_data.energy_type == "L":
			lightning_basic_count += 1
	if lightning_basic_count >= 2:
		return true
	return false


func _state_has_named_stage2(player_state: PlayerState, uid: String) -> bool:
	if player_state == null:
		return false
	for slot: PokemonSlot in player_state.get_all_pokemon():
		var card_data := slot.get_card_data()
		if card_data != null and card_data.get_uid() == uid:
			return true
	return false


func _action_type_is(action: GameAction, action_type: GameAction.ActionType) -> bool:
	return action != null and action.action_type == action_type


func _action_is_evolve_into(action: GameAction, uid: String) -> bool:
	if action == null or action.action_type != GameAction.ActionType.EVOLVE:
		return false
	var evolution_name := _get_action_name(action, ["evolution", "card_name"])
	var evolution_data := _lookup_card_data(evolution_name)
	return evolution_data != null and evolution_data.get_uid() == uid


func _action_matches_name(action: GameAction, field_name: String, aliases: Array[String]) -> bool:
	return _matches_name(_get_action_name(action, [field_name]), aliases)


func _matches_name(value: String, aliases: Array[String]) -> bool:
	var normalized_value := _normalize_name(value)
	if normalized_value == "":
		return false
	for alias: String in aliases:
		if normalized_value == _normalize_name(alias):
			return true
	return false


func _matches_card_name(card_data: CardData, normalized_name: String) -> bool:
	if card_data == null or normalized_name == "":
		return false
	if normalized_name == _normalize_name(card_data.name):
		return true
	if normalized_name == _normalize_name(card_data.name_en):
		return true
	return false


func _get_action_name(action: GameAction, field_names: Array[String]) -> String:
	if action == null:
		return ""
	for field_name: String in field_names:
		if action.data.has(field_name):
			return str(action.data.get(field_name, ""))
	return ""


func _normalize_name(value: String) -> String:
	return value.strip_edges().to_lower()


func _lookup_card_data(card_name: String) -> CardData:
	var normalized_name := _normalize_name(card_name)
	if normalized_name == "":
		return null
	_ensure_card_name_lookup()
	var card_variant: Variant = _card_name_lookup.get(normalized_name, null)
	return card_variant if card_variant is CardData else null


func _ensure_card_name_lookup() -> void:
	if _card_name_lookup_ready:
		return
	_card_name_lookup_ready = true
	_card_name_lookup.clear()
	var card_database = AutoloadResolverScript.get_card_database()
	if card_database == null:
		return

	for card_data: CardData in card_database.get_all_cards():
		if card_data == null:
			continue
		_register_card_name(card_data.name, card_data)
		_register_card_name(card_data.name_en, card_data)

	_register_aliases(_get_miraidon_aliases(), _lookup_card_data_by_uid(MIRAIDON_EX_UID))
	_register_aliases(_get_electric_generator_aliases(), _lookup_card_data_by_uid(ELECTRIC_GENERATOR_UID))
	_register_aliases(_get_gardevoir_aliases(), _lookup_card_data_by_uid(GARDEVOIR_EX_UID))
	_register_aliases(_get_psychic_embrace_aliases(), _lookup_card_data_by_uid(GARDEVOIR_EX_UID))
	_register_aliases(_get_charizard_aliases(), _lookup_card_data_by_uid(CHARIZARD_EX_UID))
	_register_aliases(_get_charizard_attack_aliases(), _lookup_card_data_by_uid(CHARIZARD_EX_UID))
	_register_aliases(_get_rare_candy_aliases(), _lookup_card_data_by_uid(RARE_CANDY_UID))


func _register_aliases(aliases: Array[String], card_data: CardData) -> void:
	if card_data == null:
		return
	for alias: String in aliases:
		_register_card_name(alias, card_data)


func _register_card_name(raw_name: String, card_data: CardData) -> void:
	var normalized := _normalize_name(raw_name)
	if normalized == "" or _card_name_lookup.has(normalized):
		return
	_card_name_lookup[normalized] = card_data


func _lookup_card_data_by_uid(uid: String) -> CardData:
	if uid == "":
		return null
	var card_database = AutoloadResolverScript.get_card_database()
	if card_database == null:
		return null
	for card_data: CardData in card_database.get_all_cards():
		if card_data != null and card_data.get_uid() == uid:
			return card_data
	return null


func _get_miraidon_aliases() -> Array[String]:
	var aliases: Array[String] = ["Miraidon ex", "Photon Blaster"]
	var card_data := _lookup_card_data_by_uid(MIRAIDON_EX_UID)
	if card_data != null:
		aliases.append(card_data.name)
		aliases.append(card_data.name_en)
		if not card_data.attacks.is_empty():
			aliases.append(str(card_data.attacks[0].get("name", "")))
	return _compact_aliases(aliases)


func _get_miraidon_attack_aliases() -> Array[String]:
	return _get_miraidon_aliases()


func _get_electric_generator_aliases() -> Array[String]:
	var aliases: Array[String] = ["Electric Generator"]
	var card_data := _lookup_card_data_by_uid(ELECTRIC_GENERATOR_UID)
	if card_data != null:
		aliases.append(card_data.name)
		aliases.append(card_data.name_en)
	return _compact_aliases(aliases)


func _get_gardevoir_aliases() -> Array[String]:
	var aliases: Array[String] = ["Gardevoir ex", "Miracle Force"]
	var card_data := _lookup_card_data_by_uid(GARDEVOIR_EX_UID)
	if card_data != null:
		aliases.append(card_data.name)
		aliases.append(card_data.name_en)
		if not card_data.attacks.is_empty():
			aliases.append(str(card_data.attacks[0].get("name", "")))
	return _compact_aliases(aliases)


func _get_psychic_embrace_aliases() -> Array[String]:
	var aliases: Array[String] = ["Psychic Embrace"]
	var card_data := _lookup_card_data_by_uid(GARDEVOIR_EX_UID)
	if card_data != null and not card_data.abilities.is_empty():
		aliases.append(str(card_data.abilities[0].get("name", "")))
	return _compact_aliases(aliases)


func _get_charizard_aliases() -> Array[String]:
	var aliases: Array[String] = ["Charizard ex"]
	var card_data := _lookup_card_data_by_uid(CHARIZARD_EX_UID)
	if card_data != null:
		aliases.append(card_data.name)
		aliases.append(card_data.name_en)
	return _compact_aliases(aliases)


func _get_charizard_attack_aliases() -> Array[String]:
	var aliases: Array[String] = ["Burning Darkness"]
	var card_data := _lookup_card_data_by_uid(CHARIZARD_EX_UID)
	if card_data != null and not card_data.attacks.is_empty():
		aliases.append(str(card_data.attacks[0].get("name", "")))
	return _compact_aliases(aliases)


func _get_rare_candy_aliases() -> Array[String]:
	var aliases: Array[String] = ["Rare Candy"]
	var card_data := _lookup_card_data_by_uid(RARE_CANDY_UID)
	if card_data != null:
		aliases.append(card_data.name)
		aliases.append(card_data.name_en)
	return _compact_aliases(aliases)


func _compact_aliases(aliases: Array[String]) -> Array[String]:
	var compacted: Array[String] = []
	for alias: String in aliases:
		if alias == "":
			continue
		if alias in compacted:
			continue
		compacted.append(alias)
	return compacted
