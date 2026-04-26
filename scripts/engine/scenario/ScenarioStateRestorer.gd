class_name ScenarioStateRestorer
extends RefCounted

const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")


const ScenarioStateSnapshotScript = preload("res://scripts/engine/scenario/ScenarioStateSnapshot.gd")


static func restore(raw_snapshot: Dictionary) -> Dictionary:
	var snapshot := _extract_snapshot(raw_snapshot)
	var errors: Array[String] = ScenarioStateSnapshotScript.validate(snapshot)
	if not errors.is_empty():
		return {
			"gsm": null,
			"errors": errors,
		}

	var gsm := GameStateMachine.new()
	gsm.action_log.clear()
	gsm.game_state = _restore_game_state(snapshot)
	_register_restored_pokemon_effects(gsm)
	_seed_expected_card_totals(gsm)
	return {
		"gsm": gsm,
		"errors": [],
	}


static func apply_hidden_zone_override(game_state: GameState, override_players_variant: Variant) -> Array[String]:
	var errors: Array[String] = []
	if game_state == null:
		errors.append("missing_game_state")
		return errors
	if not (override_players_variant is Array):
		errors.append("invalid_hidden_zone_override_players")
		return errors
	var override_players: Array = override_players_variant
	for player_variant: Variant in override_players:
		if not (player_variant is Dictionary):
			errors.append("invalid_hidden_zone_override_player")
			continue
		var player_snapshot: Dictionary = player_variant
		var player_index: int = int(player_snapshot.get("player_index", -1))
		if player_index < 0 or player_index >= game_state.players.size():
			errors.append("invalid_hidden_zone_override_player_index")
			continue
		var player: PlayerState = game_state.players[player_index]
		player.hand = _restore_card_list(player_snapshot.get("hand", []), player_index)
		player.deck = _restore_card_list(player_snapshot.get("deck", []), player_index)
		player.shuffle_count = int(player_snapshot.get("shuffle_count", player.shuffle_count))
	return errors


static func _extract_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var snapshot_variant: Variant = raw_snapshot.get("state", raw_snapshot)
	return snapshot_variant if snapshot_variant is Dictionary else {}


static func _restore_game_state(snapshot: Dictionary) -> GameState:
	var state := GameState.new()
	state.turn_number = int(snapshot.get("turn_number", 0))
	state.current_player_index = int(snapshot.get("current_player_index", 0))
	state.first_player_index = int(snapshot.get("first_player_index", 0))
	state.phase = _restore_phase(snapshot.get("phase", "setup"))
	state.winner_index = int(snapshot.get("winner_index", -1))
	state.win_reason = str(snapshot.get("win_reason", ""))
	state.energy_attached_this_turn = bool(snapshot.get("energy_attached_this_turn", false))
	state.supporter_used_this_turn = bool(snapshot.get("supporter_used_this_turn", false))
	state.stadium_played_this_turn = bool(snapshot.get("stadium_played_this_turn", false))
	state.retreat_used_this_turn = bool(snapshot.get("retreat_used_this_turn", false))
	state.stadium_owner_index = int(snapshot.get("stadium_owner_index", -1))
	state.stadium_card = _restore_card_instance(snapshot.get("stadium_card", {}), state.stadium_owner_index)
	state.stadium_effect_used_turn = int(snapshot.get("stadium_effect_used_turn", -1))
	state.stadium_effect_used_player = int(snapshot.get("stadium_effect_used_player", -1))
	state.stadium_effect_used_effect_id = str(snapshot.get("stadium_effect_used_effect_id", ""))

	var vstar_variant: Variant = snapshot.get("vstar_power_used", [false, false])
	if vstar_variant is Array:
		state.vstar_power_used = _restore_bool_array(vstar_variant as Array, 2, false)

	var knockout_variant: Variant = snapshot.get("last_knockout_turn_against", [-999, -999])
	if knockout_variant is Array:
		state.last_knockout_turn_against = _restore_int_array(knockout_variant as Array, 2, -999)

	var shared_flags_variant: Variant = snapshot.get("shared_turn_flags", {})
	state.shared_turn_flags = shared_flags_variant.duplicate(true) if shared_flags_variant is Dictionary else {}

	var players_variant: Variant = snapshot.get("players", [])
	if players_variant is Array:
		for player_variant: Variant in players_variant:
			if player_variant is Dictionary:
				state.players.append(_restore_player_state(player_variant as Dictionary))

	return state


static func _restore_player_state(snapshot: Dictionary) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = int(snapshot.get("player_index", 0))
	player.hand = _restore_card_list(snapshot.get("hand", []), player.player_index)
	player.deck = _restore_card_list(snapshot.get("deck", []), player.player_index)
	player.prizes = _restore_card_list(snapshot.get("prizes", []), player.player_index)
	player.discard_pile = _restore_card_list(snapshot.get("discard", snapshot.get("discard_pile", [])), player.player_index)
	player.lost_zone = _restore_card_list(snapshot.get("lost_zone", []), player.player_index)
	player.active_pokemon = _restore_slot(snapshot.get("active", {}), player.player_index)
	player.shuffle_count = int(snapshot.get("shuffle_count", 0))

	var bench_variant: Variant = snapshot.get("bench", [])
	if bench_variant is Array:
		for slot_variant: Variant in bench_variant:
			var slot: PokemonSlot = _restore_slot(slot_variant, player.player_index)
			if slot != null:
				player.bench.append(slot)

	player.prize_layout = _restore_prize_layout(snapshot.get("prize_layout", []), player.prizes)
	if player.prize_layout.is_empty() and not player.prizes.is_empty():
		player.reset_prize_layout()

	return player


static func _restore_prize_layout(layout_variant: Variant, prizes: Array[CardInstance]) -> Array:
	var restored: Array = []
	if not (layout_variant is Array):
		return restored
	for entry_variant: Variant in layout_variant:
		if entry_variant == null:
			restored.append(null)
			continue
		if not (entry_variant is Dictionary):
			restored.append(null)
			continue
		var prize_snapshot: Dictionary = entry_variant
		var instance_id: int = int(prize_snapshot.get("instance_id", -1))
		restored.append(_find_card_by_instance_id(prizes, instance_id))
	return restored


static func _find_card_by_instance_id(cards: Array[CardInstance], instance_id: int) -> CardInstance:
	if instance_id < 0:
		return null
	for card: CardInstance in cards:
		if card != null and card.instance_id == instance_id:
			return card
	return null


static func _restore_card_list(cards_variant: Variant, fallback_owner_index: int) -> Array[CardInstance]:
	var restored: Array[CardInstance] = []
	if not (cards_variant is Array):
		return restored
	for card_variant: Variant in cards_variant:
		var card: CardInstance = _restore_card_instance(card_variant, fallback_owner_index)
		if card != null:
			restored.append(card)
	return restored


static func _restore_slot(slot_variant: Variant, fallback_owner_index: int) -> PokemonSlot:
	if not (slot_variant is Dictionary):
		return null
	var slot_snapshot: Dictionary = slot_variant
	if slot_snapshot.is_empty():
		return null

	var slot := PokemonSlot.new()
	slot.pokemon_stack = _restore_card_list(slot_snapshot.get("pokemon_stack", []), fallback_owner_index)
	slot.attached_energy = _restore_card_list(slot_snapshot.get("attached_energy", []), fallback_owner_index)
	slot.attached_tool = _restore_card_instance(slot_snapshot.get("attached_tool", {}), fallback_owner_index)
	slot.damage_counters = int(slot_snapshot.get("damage_counters", 0))
	slot.turn_played = int(slot_snapshot.get("turn_played", -1))
	slot.turn_evolved = int(slot_snapshot.get("turn_evolved", -1))
	var status_variant: Variant = slot_snapshot.get("status_conditions", {})
	slot.status_conditions = status_variant.duplicate(true) if status_variant is Dictionary else slot.status_conditions
	var effects_variant: Variant = slot_snapshot.get("effects", [])
	slot.effects = _restore_dictionary_array(effects_variant)

	var top_card := slot.get_top_card()
	if top_card != null and top_card.card_data != null:
		top_card.card_data.retreat_cost = int(slot_snapshot.get("retreat_cost", top_card.card_data.retreat_cost))

	return slot


static func _restore_card_instance(card_variant: Variant, fallback_owner_index: int) -> CardInstance:
	if not (card_variant is Dictionary):
		return null
	var card_snapshot: Dictionary = card_variant
	if card_snapshot.is_empty():
		return null

	var owner_index: int = int(card_snapshot.get("owner_index", fallback_owner_index))
	var card_data := _restore_card_data(card_snapshot)
	var card := CardInstance.create(card_data, owner_index)
	var instance_id: int = int(card_snapshot.get("instance_id", card.instance_id))
	card.instance_id = instance_id
	card.face_up = bool(card_snapshot.get("face_up", false))
	if instance_id >= CardInstance._next_id:
		CardInstance._next_id = instance_id + 1
	return card


static func _restore_card_data(card_snapshot: Dictionary) -> CardData:
	var source := card_snapshot.duplicate(true)
	if not source.has("name") and source.has("card_name"):
		source["name"] = str(source.get("card_name", ""))
	_backfill_card_metadata_from_database(source)
	return CardData.from_dict(source)


static func _backfill_card_metadata_from_database(source: Dictionary) -> void:
	var set_code: String = str(source.get("set_code", "")).strip_edges()
	var card_index: String = str(source.get("card_index", "")).strip_edges()
	if set_code == "" or card_index == "":
		return
	if str(source.get("name_en", "")).strip_edges() != "":
		return
	var card_database: Node = AutoloadResolverScript.get_card_database()
	if card_database == null or not is_instance_valid(card_database):
		return
	var canonical: Variant = card_database.call("get_card", set_code, card_index)
	if not (canonical is CardData):
		return
	var canonical_card: CardData = canonical
	if str(source.get("name", "")).strip_edges() == "":
		source["name"] = canonical_card.name
	source["name_en"] = canonical_card.name_en
	if str(source.get("description", "")).strip_edges() == "":
		source["description"] = canonical_card.description
	if str(source.get("label", "")).strip_edges() == "":
		source["label"] = canonical_card.label
	if str(source.get("set_code_en", "")).strip_edges() == "":
		source["set_code_en"] = canonical_card.set_code_en
	if str(source.get("card_index_en", "")).strip_edges() == "":
		source["card_index_en"] = canonical_card.card_index_en


static func _restore_dictionary_array(value: Variant) -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	if not (value is Array):
		return restored
	for entry: Variant in value:
		if entry is Dictionary:
			restored.append((entry as Dictionary).duplicate(true))
	return restored


static func _restore_phase(value: Variant) -> GameState.GamePhase:
	if value is int:
		return int(value)
	var text := str(value).strip_edges().to_lower()
	if text.is_valid_int():
		return int(text)
	match text:
		"setup":
			return GameState.GamePhase.SETUP
		"mulligan":
			return GameState.GamePhase.MULLIGAN
		"setup_place":
			return GameState.GamePhase.SETUP_PLACE
		"draw":
			return GameState.GamePhase.DRAW
		"main":
			return GameState.GamePhase.MAIN
		"attack":
			return GameState.GamePhase.ATTACK
		"pokemon_check":
			return GameState.GamePhase.POKEMON_CHECK
		"between_turns":
			return GameState.GamePhase.BETWEEN_TURNS
		"knockout_replace":
			return GameState.GamePhase.KNOCKOUT_REPLACE
		"game_over":
			return GameState.GamePhase.GAME_OVER
		_:
			return GameState.GamePhase.SETUP


static func _restore_bool_array(values: Array, expected_size: int, fallback: bool) -> Array[bool]:
	var restored: Array[bool] = []
	for index: int in range(expected_size):
		restored.append(bool(values[index]) if index < values.size() else fallback)
	return restored


static func _restore_int_array(values: Array, expected_size: int, fallback: int) -> Array[int]:
	var restored: Array[int] = []
	for index: int in range(expected_size):
		restored.append(int(values[index]) if index < values.size() else fallback)
	return restored


static func _seed_expected_card_totals(gsm: GameStateMachine) -> void:
	var expected_totals: Array[int] = []
	for player_index: int in range(gsm.game_state.players.size()):
		expected_totals.append(gsm.count_player_total_cards(player_index))
	gsm.set("_expected_card_totals", expected_totals)


static func _register_restored_pokemon_effects(gsm: GameStateMachine) -> void:
	if gsm == null or gsm.game_state == null or gsm.effect_processor == null:
		return
	for player_variant: Variant in gsm.game_state.players:
		if not (player_variant is PlayerState):
			continue
		var player: PlayerState = player_variant
		for card: CardInstance in player.hand:
			_register_card_if_pokemon(gsm, card)
		for card: CardInstance in player.deck:
			_register_card_if_pokemon(gsm, card)
		for card: CardInstance in player.prizes:
			_register_card_if_pokemon(gsm, card)
		for card: CardInstance in player.discard_pile:
			_register_card_if_pokemon(gsm, card)
		for card: CardInstance in player.lost_zone:
			_register_card_if_pokemon(gsm, card)
		if player.active_pokemon != null:
			for card: CardInstance in player.active_pokemon.collect_all_cards():
				_register_card_if_pokemon(gsm, card)
		for slot: PokemonSlot in player.bench:
			if slot == null:
				continue
			for card: CardInstance in slot.collect_all_cards():
				_register_card_if_pokemon(gsm, card)


static func _register_card_if_pokemon(gsm: GameStateMachine, card: CardInstance) -> void:
	if gsm == null or gsm.effect_processor == null or card == null or card.card_data == null:
		return
	if not card.card_data.is_pokemon():
		return
	gsm.effect_processor.register_pokemon_card(card.card_data)
