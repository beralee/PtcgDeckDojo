class_name ScenarioRunner
extends RefCounted


const ScenarioCatalogScript = preload("res://tests/scenarios/ScenarioCatalog.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")
const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")

const STATE_RESTORER_PATH := "res://scripts/engine/scenario/ScenarioStateRestorer.gd"
const EQUIVALENCE_REGISTRY_PATH := "res://scripts/ai/scenario_comparator/ScenarioEquivalenceRegistry.gd"
const END_STATE_COMPARATOR_PATH := "res://scripts/ai/scenario_comparator/ScenarioEndStateComparator.gd"

const DEFAULT_MAX_STEPS := 40


func normalize_snapshot_for_restore(raw_snapshot: Variant) -> Dictionary:
	var snapshot: Dictionary = raw_snapshot if raw_snapshot is Dictionary else {}
	if snapshot.has("format_version"):
		return snapshot.duplicate(true)

	var normalized_players: Array[Dictionary] = []
	var raw_players: Array = snapshot.get("players", []) if snapshot.get("players", []) is Array else []
	for player_index: int in range(maxi(2, raw_players.size())):
		var raw_player: Dictionary = raw_players[player_index] if player_index < raw_players.size() and raw_players[player_index] is Dictionary else {}
		normalized_players.append(_normalize_player_snapshot(raw_player, player_index))

	return {
		"format_version": 1,
		"turn_number": _int_value(snapshot.get("turn_number", 0), 0),
		"current_player_index": _int_value(snapshot.get("current_player_index", 0), 0),
		"first_player_index": _int_value(snapshot.get("first_player_index", 0), 0),
		"phase": _normalize_phase_value(snapshot.get("phase", "setup")),
		"winner_index": _int_value(snapshot.get("winner_index", -1), -1),
		"win_reason": str(snapshot.get("win_reason", "")),
		"energy_attached_this_turn": _bool_value(snapshot.get("energy_attached_this_turn", false)),
		"supporter_used_this_turn": _bool_value(snapshot.get("supporter_used_this_turn", false)),
		"stadium_played_this_turn": _bool_value(snapshot.get("stadium_played_this_turn", false)),
		"retreat_used_this_turn": _bool_value(snapshot.get("retreat_used_this_turn", false)),
		"stadium_card": _normalize_card_snapshot(snapshot.get("stadium_card", {}), -1),
		"stadium_owner_index": _int_value(snapshot.get("stadium_owner_index", -1), -1),
		"stadium_effect_used_turn": _int_value(snapshot.get("stadium_effect_used_turn", -1), -1),
		"stadium_effect_used_player": _int_value(snapshot.get("stadium_effect_used_player", -1), -1),
		"stadium_effect_used_effect_id": str(snapshot.get("stadium_effect_used_effect_id", "")),
		"vstar_power_used": _normalize_bool_array(snapshot.get("vstar_power_used", [false, false]), 2, false),
		"last_knockout_turn_against": _normalize_int_array(snapshot.get("last_knockout_turn_against", [-999, -999]), 2, -999),
		"shared_turn_flags": _dictionary_value(snapshot.get("shared_turn_flags", {})),
		"players": normalized_players,
	}


func run_scenario(scenario_path: String, runtime_mode: String = "rules_only") -> Dictionary:
	var scenario: Dictionary = ScenarioCatalogScript.load_scenario(scenario_path)
	if str(scenario.get("_error", "")) != "":
		return _make_error_result(scenario_path, [str(scenario.get("_error", "unknown_error"))])
	return run_loaded_scenario(scenario, runtime_mode)


func run_loaded_scenario(scenario: Dictionary, runtime_mode: String = "rules_only") -> Dictionary:
	var scenario_path: String = str(scenario.get("_path", ""))
	var validation_errors := _validate_loaded_scenario(scenario)
	if not validation_errors.is_empty():
		return _make_error_result(scenario_path, validation_errors, scenario)

	var restorer_call := _load_callable_dependency(STATE_RESTORER_PATH, "restore")
	if not bool(restorer_call.get("ok", false)):
		return _make_error_result(scenario_path, [str(restorer_call.get("error", "missing_state_restorer"))], scenario)

	var registry_call := _load_callable_dependency(EQUIVALENCE_REGISTRY_PATH, "extract_primary")
	if not bool(registry_call.get("ok", false)):
		return _make_error_result(scenario_path, [str(registry_call.get("error", "missing_equivalence_registry"))], scenario)

	var comparator_call := _load_callable_dependency(END_STATE_COMPARATOR_PATH, "compare")
	if not bool(comparator_call.get("ok", false)):
		return _make_error_result(scenario_path, [str(comparator_call.get("error", "missing_end_state_comparator"))], scenario)

	var normalized_start_snapshot: Dictionary = normalize_snapshot_for_restore(scenario.get("state_at_turn_start", {}))
	var restore_result: Variant = _invoke_dependency(restorer_call, [normalized_start_snapshot])
	if not (restore_result is Dictionary):
		return _make_error_result(scenario_path, ["state_restorer_returned_non_dictionary"], scenario)
	var restore_payload: Dictionary = restore_result
	var restore_errors: Array[String] = _string_array(restore_payload.get("errors", []))
	if not restore_errors.is_empty():
		return _make_error_result(scenario_path, restore_errors, scenario)
	var gsm: GameStateMachine = restore_payload.get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return _make_error_result(scenario_path, ["state_restorer_did_not_return_gsm"], scenario)

	var tracked_player_index: int = int(scenario.get("tracked_player_index", -1))
	var runtime_result: Dictionary = _run_single_turn(gsm, tracked_player_index, int(scenario.get("deck_id", -1)), runtime_mode, restorer_call, scenario.get("runtime_oracles", {}))
	if not _string_array(runtime_result.get("errors", [])).is_empty():
		return _make_error_result(scenario_path, _string_array(runtime_result.get("errors", [])), scenario, runtime_result)
	var comparison_state: GameState = _build_comparison_game_state(gsm, tracked_player_index, runtime_result)

	var primary_end: Variant = _invoke_dependency(registry_call, [comparison_state, tracked_player_index])
	if not (primary_end is Dictionary):
		return _make_error_result(scenario_path, ["equivalence_registry_returned_non_dictionary"], scenario, runtime_result)

	var secondary_end: Dictionary = {}
	var secondary_call := _load_callable_dependency(EQUIVALENCE_REGISTRY_PATH, "extract_secondary")
	if bool(secondary_call.get("ok", false)):
		var secondary_variant: Variant = _invoke_dependency(secondary_call, [comparison_state, tracked_player_index])
		if secondary_variant is Dictionary:
			secondary_end = secondary_variant

	var ai_end_state := {
		"scenario_id": str(scenario.get("scenario_id", "")),
		"primary": primary_end,
		"secondary": secondary_end,
	}
	var expected_end_state: Dictionary = _resolve_expected_end_state(scenario, restorer_call, registry_call)
	var approved_alternatives: Array = scenario.get("approved_divergent_end_states", [])
	var verdict_variant: Variant = _invoke_dependency(comparator_call, [ai_end_state, expected_end_state, approved_alternatives])
	if not (verdict_variant is Dictionary):
		return _make_error_result(scenario_path, ["end_state_comparator_returned_non_dictionary"], scenario, runtime_result)

	var verdict: Dictionary = verdict_variant
	verdict["scenario_path"] = scenario_path
	verdict["runtime_mode"] = runtime_mode
	verdict["ai_end_state"] = ai_end_state
	verdict["runtime_result"] = runtime_result
	verdict["scenario_id"] = str(scenario.get("scenario_id", ""))
	return verdict


func run_all(scenarios_dir: String, runtime_mode: String = "rules_only") -> Dictionary:
	var results: Array[Dictionary] = []
	var status_counts := {
		"PASS": 0,
		"DIVERGE": 0,
		"FAIL": 0,
		"ERROR": 0,
	}
	for path: String in ScenarioCatalogScript.list_scenario_files(scenarios_dir):
		var result: Dictionary = run_scenario(path, runtime_mode)
		results.append(result)
		var status: String = str(result.get("status", "ERROR"))
		status_counts[status] = int(status_counts.get(status, 0)) + 1
	return {
		"scenarios_dir": scenarios_dir,
		"runtime_mode": runtime_mode,
		"results": results,
		"status_counts": status_counts,
		"scenario_count": results.size(),
	}


func _run_single_turn(
	gsm: GameStateMachine,
	tracked_player_index: int,
	deck_id: int,
	runtime_mode: String,
	restorer_call: Dictionary,
	runtime_oracles: Dictionary
) -> Dictionary:
	if tracked_player_index < 0 or tracked_player_index >= gsm.game_state.players.size():
		return {"errors": ["invalid_tracked_player_index"]}
	var preflight_errors: Array[String] = _advance_forced_turn_start_phases(gsm, tracked_player_index)
	if not preflight_errors.is_empty():
		return {"errors": preflight_errors}
	var ai := AIOpponentScript.new()
	ai.player_index = tracked_player_index
	ai.decision_runtime_mode = runtime_mode
	# 关键：先用真实 deck 解析策略；空 minimal deck 的 signature 匹配会全失败
	var registry := DeckStrategyRegistryScript.new()
	var strategy: RefCounted = null
	if deck_id > 0:
		# 优先 autoload（FunctionalTestRunner 等 Scene 模式）
		var card_db: Node = AutoloadResolverScript.get_card_database()
		var real_deck: DeckData = null
		if card_db != null and card_db.has_method("get_deck"):
			real_deck = card_db.get_deck(deck_id)
		if real_deck == null:
			# 回退：直接从 JSON 加载（-s SceneTree 模式下 autoload 不可达）
			real_deck = _load_deck_from_bundled(deck_id)
		if real_deck != null:
			strategy = registry.resolve_strategy_for_deck(real_deck)
	if strategy == null:
		# 最终回退: 从 tracked player 场上可见 Pokemon 探测策略
		var tracked_player: PlayerState = gsm.game_state.players[tracked_player_index]
		strategy = registry.create_strategy_for_player(tracked_player)
	if strategy == null:
		# 最后兜底: 旧 minimal deck 路径（可能无法匹配，但保留旧行为兼容）
		strategy = registry.resolve_strategy_for_deck(_make_minimal_deck(deck_id))
	if strategy != null and ai.has_method("set_deck_strategy"):
		ai.call("set_deck_strategy", strategy)

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()
	var start_turn: int = int(gsm.game_state.turn_number)
	var steps: int = 0
	var progressed_any: bool = false
	var applied_oracle_keys: Dictionary = {}

	while steps < DEFAULT_MAX_STEPS:
		if gsm.game_state == null:
			break
		if gsm.game_state.is_game_over():
			break
		if int(gsm.game_state.current_player_index) != tracked_player_index:
			break
		var progressed: bool = false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				progressed = ai.run_single_step(bridge, gsm)
		else:
			progressed = ai.run_single_step(bridge, gsm)
		if not progressed:
			break
		progressed_any = true
		steps += 1
		var oracle_errors: Array[String] = _apply_runtime_oracles_if_needed(gsm, runtime_oracles, restorer_call, applied_oracle_keys)
		if not oracle_errors.is_empty():
			bridge.free()
			return {
				"errors": oracle_errors,
				"steps": steps,
				"start_turn": start_turn,
				"turn_number": int(gsm.game_state.turn_number) if gsm.game_state != null else -1,
				"current_player_index": int(gsm.game_state.current_player_index) if gsm.game_state != null else -1,
			}
		if int(gsm.game_state.current_player_index) != tracked_player_index:
			break
		if int(gsm.game_state.turn_number) != start_turn:
			break

	bridge.free()
	return {
		"errors": [] if progressed_any else ["scenario_turn_made_no_progress"],
		"steps": steps,
		"start_turn": start_turn,
		"turn_number": int(gsm.game_state.turn_number) if gsm.game_state != null else -1,
		"current_player_index": int(gsm.game_state.current_player_index) if gsm.game_state != null else -1,
	}


func _apply_runtime_oracles_if_needed(
	gsm: GameStateMachine,
	runtime_oracles: Dictionary,
	restorer_call: Dictionary,
	applied_oracle_keys: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	if gsm == null or gsm.game_state == null:
		return errors
	if gsm.action_log.is_empty():
		return errors
	var hidden_zone_overrides: Array = runtime_oracles.get("hidden_zone_overrides", []) if runtime_oracles.get("hidden_zone_overrides", []) is Array else []
	if hidden_zone_overrides.is_empty():
		return errors
	var latest_variant: Variant = gsm.action_log[gsm.action_log.size() - 1]
	if not (latest_variant is GameAction):
		return errors
	var latest_action: GameAction = latest_variant
	var latest_card_name: String = str(latest_action.data.get("card_name", "")).strip_edges()
	for override_variant: Variant in hidden_zone_overrides:
		if not (override_variant is Dictionary):
			continue
		var override: Dictionary = override_variant
		var trigger: Dictionary = override.get("trigger", {}) if override.get("trigger", {}) is Dictionary else {}
		var override_key := "%s:%s:%s:%s" % [
			str(trigger.get("action_type", "")),
			str(trigger.get("player_index", "")),
			str(trigger.get("card_name", "")),
			str(override.get("source_snapshot_event_index", "")),
		]
		if applied_oracle_keys.has(override_key):
			continue
		if int(trigger.get("action_type", -1)) != int(latest_action.action_type):
			continue
		if int(trigger.get("player_index", -1)) != int(latest_action.player_index):
			continue
		if str(trigger.get("card_name", "")).strip_edges() != latest_card_name:
			continue
		var apply_result: Variant = _invoke_dependency(restorer_call, [gsm.game_state, override.get("players", [])], "apply_hidden_zone_override")
		if not (apply_result is Array):
			errors.append("hidden_zone_oracle_apply_failed")
			continue
		for error_variant: Variant in apply_result:
			var error_text: String = str(error_variant).strip_edges()
			if error_text != "":
				errors.append(error_text)
		applied_oracle_keys[override_key] = true
	return errors


func _build_comparison_game_state(gsm: GameStateMachine, tracked_player_index: int, runtime_result: Dictionary) -> GameState:
	if gsm == null or gsm.game_state == null:
		return null
	var cloner := GameStateClonerScript.new()
	var cloned_gsm: GameStateMachine = cloner.clone_gsm(gsm)
	if cloned_gsm == null or cloned_gsm.game_state == null:
		return gsm.game_state
	var state: GameState = cloned_gsm.game_state
	var start_turn: int = int(runtime_result.get("start_turn", int(state.turn_number)))
	_rewind_next_turn_draw_if_needed(state, gsm.action_log, tracked_player_index, start_turn)
	return state


func _rewind_next_turn_draw_if_needed(state: GameState, action_log: Array, tracked_player_index: int, start_turn: int) -> void:
	if state == null or tracked_player_index < 0:
		return
	var next_player_index: int = int(state.current_player_index)
	if next_player_index == tracked_player_index:
		return
	if int(state.turn_number) <= start_turn:
		return
	if state.phase not in [GameState.GamePhase.DRAW, GameState.GamePhase.MAIN]:
		return
	var last_draw: GameAction = _find_latest_turn_start_draw(action_log, next_player_index, int(state.turn_number))
	if last_draw == null:
		return
	var card_names: Array[String] = []
	for name_variant: Variant in last_draw.data.get("card_names", []):
		card_names.append(str(name_variant))
	if card_names.is_empty():
		return
	var next_player: PlayerState = state.players[next_player_index]
	for drawn_name: String in card_names:
		var removed: bool = false
		for i: int in range(next_player.hand.size() - 1, -1, -1):
			var card: CardInstance = next_player.hand[i]
			if card == null or card.card_data == null:
				continue
			if str(card.card_data.name) != drawn_name:
				continue
			next_player.hand.remove_at(i)
			removed = true
			break
		if not removed and not next_player.hand.is_empty():
			next_player.hand.pop_back()


func _find_latest_turn_start_draw(action_log: Array, player_index: int, turn_number: int) -> GameAction:
	for i: int in range(action_log.size() - 1, -1, -1):
		var action: Variant = action_log[i]
		if not (action is GameAction):
			continue
		var game_action: GameAction = action
		if game_action.player_index != player_index:
			continue
		if game_action.turn_number != turn_number:
			continue
		if game_action.action_type != GameAction.ActionType.DRAW_CARD:
			continue
		return game_action
	return null


func _advance_forced_turn_start_phases(gsm: GameStateMachine, tracked_player_index: int) -> Array[String]:
	if gsm == null or gsm.game_state == null:
		return ["invalid_game_state_machine"]
	if int(gsm.game_state.current_player_index) != tracked_player_index:
		return []
	if gsm.game_state.phase == GameState.GamePhase.DRAW:
		if not gsm.game_state.is_first_turn_of_first_player():
			var player: PlayerState = gsm.game_state.players[tracked_player_index]
			var drawn: Array[CardInstance] = player.draw_cards(1)
			if drawn.is_empty():
				gsm.game_state.set_game_over(1 - tracked_player_index, "deck_out")
				return []
		gsm.game_state.phase = GameState.GamePhase.MAIN
	return []


func _make_minimal_deck(deck_id: int) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = "scenario_%d" % deck_id
	deck.total_cards = 60
	deck.cards = []
	return deck


func _load_deck_from_bundled(deck_id: int) -> DeckData:
	## 直接从 res://data/bundled_user/decks/<id>.json 加载，绕过 autoload
	## 用于 -s SceneTree 模式（run_scenario_suite.gd）
	if deck_id <= 0:
		return null
	var path: String = "res://data/bundled_user/decks/%d.json" % deck_id
	if not FileAccess.file_exists(path):
		path = "res://data/bundled_user/ai_decks/%d.json" % deck_id
		if not FileAccess.file_exists(path):
			return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return null
	if not (json.data is Dictionary):
		return null
	return DeckData.from_dict(json.data)


func _validate_loaded_scenario(scenario: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(scenario.get("_error", "")) != "":
		errors.append(str(scenario.get("_error", "")))
	if str(scenario.get("scenario_id", "")) == "":
		errors.append("missing_scenario_id")
	if not scenario.has("deck_id"):
		errors.append("missing_deck_id")
	if not scenario.has("tracked_player_index"):
		errors.append("missing_tracked_player_index")
	if not (scenario.get("state_at_turn_start", null) is Dictionary):
		errors.append("missing_state_at_turn_start")
	if not (scenario.get("expected_end_state", null) is Dictionary):
		errors.append("missing_expected_end_state")
	var approved: Variant = scenario.get("approved_divergent_end_states", [])
	if not (approved is Array):
		errors.append("approved_divergent_end_states_must_be_array")
	return errors


func _resolve_expected_end_state(
	scenario: Dictionary,
	restorer_call: Dictionary,
	registry_call: Dictionary
) -> Dictionary:
	var explicit_expected: Dictionary = scenario.get("expected_end_state", {})
	if _expected_end_state_present(explicit_expected):
		var with_id := explicit_expected.duplicate(true)
		if not with_id.has("scenario_id"):
			with_id["scenario_id"] = str(scenario.get("scenario_id", ""))
		return with_id

	var source: Dictionary = scenario.get("expected_end_state_source", {})
	var source_state: Variant = source.get("state", {})
	if not (source_state is Dictionary):
		return explicit_expected

	var normalized_end_snapshot: Dictionary = normalize_snapshot_for_restore(source_state)
	var restored_variant: Variant = _invoke_dependency(restorer_call, [normalized_end_snapshot])
	if not (restored_variant is Dictionary):
		return explicit_expected
	var restored: Dictionary = restored_variant
	if not _string_array(restored.get("errors", [])).is_empty():
		return explicit_expected
	var gsm: GameStateMachine = restored.get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return explicit_expected

	var tracked_player_index: int = int(scenario.get("tracked_player_index", -1))
	var primary_variant: Variant = _invoke_dependency(registry_call, [gsm.game_state, tracked_player_index])
	if not (primary_variant is Dictionary):
		return explicit_expected
	var secondary: Dictionary = {}
	var secondary_call := _load_callable_dependency(EQUIVALENCE_REGISTRY_PATH, "extract_secondary")
	if bool(secondary_call.get("ok", false)):
		var secondary_variant: Variant = _invoke_dependency(secondary_call, [gsm.game_state, tracked_player_index])
		if secondary_variant is Dictionary:
			secondary = secondary_variant
	return {
		"scenario_id": str(scenario.get("scenario_id", "")),
		"primary": primary_variant,
		"secondary": secondary,
	}


func _expected_end_state_present(expected_end_state: Dictionary) -> bool:
	if expected_end_state.is_empty():
		return false
	var primary: Dictionary = expected_end_state.get("primary", {})
	var secondary: Dictionary = expected_end_state.get("secondary", {})
	return not primary.is_empty() or not secondary.is_empty()


func _normalize_player_snapshot(raw_player: Dictionary, fallback_player_index: int) -> Dictionary:
	var player_index: int = _int_value(raw_player.get("player_index", fallback_player_index), fallback_player_index)
	var prizes: Array[Dictionary] = _normalize_card_list(raw_player.get("prizes", []), player_index)
	return {
		"player_index": player_index,
		"active": _normalize_slot_snapshot(raw_player.get("active", {}), player_index),
		"bench": _normalize_slot_list(raw_player.get("bench", []), player_index),
		"hand": _normalize_card_list(raw_player.get("hand", []), player_index),
		"deck": _normalize_card_list(raw_player.get("deck", []), player_index),
		"discard": _normalize_card_list(raw_player.get("discard", raw_player.get("discard_pile", [])), player_index),
		"prizes": prizes,
		"prize_layout": _normalize_prize_layout(raw_player.get("prize_layout", []), player_index),
		"lost_zone": _normalize_card_list(raw_player.get("lost_zone", []), player_index),
		"shuffle_count": _int_value(raw_player.get("shuffle_count", 0), 0),
	}


func _normalize_prize_layout(raw_layout: Variant, fallback_owner_index: int) -> Array:
	if not (raw_layout is Array):
		return []
	var normalized: Array = []
	for item: Variant in raw_layout:
		if item == null:
			normalized.append(null)
		else:
			normalized.append(_normalize_card_snapshot(item, fallback_owner_index))
	return normalized


func _normalize_slot_list(raw_slots: Variant, fallback_owner_index: int) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if not (raw_slots is Array):
		return normalized
	for slot_variant: Variant in raw_slots:
		normalized.append(_normalize_slot_snapshot(slot_variant, fallback_owner_index))
	return normalized


func _normalize_slot_snapshot(raw_slot: Variant, fallback_owner_index: int) -> Dictionary:
	if not (raw_slot is Dictionary):
		return {}
	var slot: Dictionary = raw_slot
	if slot.is_empty():
		return {}
	return {
		"pokemon_name": str(slot.get("pokemon_name", "")),
		"prize_count": _int_value(slot.get("prize_count", 0), 0),
		"damage_counters": _int_value(slot.get("damage_counters", 0), 0),
		"remaining_hp": _int_value(slot.get("remaining_hp", 0), 0),
		"max_hp": _int_value(slot.get("max_hp", 0), 0),
		"retreat_cost": _int_value(slot.get("retreat_cost", 0), 0),
		"attached_energy": _normalize_card_list(slot.get("attached_energy", []), fallback_owner_index),
		"attached_tool": _normalize_card_snapshot(slot.get("attached_tool", {}), fallback_owner_index),
		"status_conditions": _dictionary_value(slot.get("status_conditions", {})),
		"effects": _array_value(slot.get("effects", [])),
		"turn_played": _int_value(slot.get("turn_played", -1), -1),
		"turn_evolved": _int_value(slot.get("turn_evolved", -1), -1),
		"pokemon_stack": _normalize_card_list(slot.get("pokemon_stack", []), fallback_owner_index),
	}


func _normalize_card_list(raw_cards: Variant, fallback_owner_index: int) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if not (raw_cards is Array):
		return normalized
	for card_variant: Variant in raw_cards:
		normalized.append(_normalize_card_snapshot(card_variant, fallback_owner_index))
	return normalized


func _normalize_card_snapshot(raw_card: Variant, fallback_owner_index: int) -> Dictionary:
	if not (raw_card is Dictionary):
		return {}
	var card: Dictionary = raw_card.duplicate(true)
	if card.is_empty():
		return {}
	card["instance_id"] = _int_value(card.get("instance_id", -1), -1)
	card["owner_index"] = _int_value(card.get("owner_index", fallback_owner_index), fallback_owner_index)
	card["face_up"] = _bool_value(card.get("face_up", false))
	if not card.has("name") and card.has("card_name"):
		card["name"] = str(card.get("card_name", ""))
	if card.has("hp"):
		card["hp"] = _int_value(card.get("hp", 0), 0)
	if card.has("retreat_cost"):
		card["retreat_cost"] = _int_value(card.get("retreat_cost", 0), 0)
	if card.has("abilities") and card.get("abilities") is Array:
		card["abilities"] = _array_value(card.get("abilities", []))
	if card.has("attacks") and card.get("attacks") is Array:
		card["attacks"] = _array_value(card.get("attacks", []))
	if card.has("is_tags") and card.get("is_tags") is Array:
		card["is_tags"] = _array_value(card.get("is_tags", []))
	return card


func _normalize_phase_value(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float:
		return int(round(value))
	var text := str(value).strip_edges()
	return int(text) if text.is_valid_int() else text.to_lower()


func _normalize_bool_array(value: Variant, expected_size: int, fallback: bool) -> Array[bool]:
	var items: Array = value if value is Array else []
	var normalized: Array[bool] = []
	for index: int in range(expected_size):
		normalized.append(_bool_value(items[index], fallback) if index < items.size() else fallback)
	return normalized


func _normalize_int_array(value: Variant, expected_size: int, fallback: int) -> Array[int]:
	var items: Array = value if value is Array else []
	var normalized: Array[int] = []
	for index: int in range(expected_size):
		normalized.append(_int_value(items[index], fallback) if index < items.size() else fallback)
	return normalized


func _array_value(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _dictionary_value(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _int_value(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float:
		return int(round(value))
	var text := str(value).strip_edges()
	return int(text) if text.is_valid_int() else fallback


func _bool_value(value: Variant, fallback: bool = false) -> bool:
	if value is bool:
		return value
	var text := str(value).strip_edges().to_lower()
	if text in ["true", "1"]:
		return true
	if text in ["false", "0"]:
		return false
	return fallback


func _load_callable_dependency(path: String, method_name: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {
			"ok": false,
			"error": "missing_dependency:%s" % path,
		}
	var script: Variant = load(path)
	if script == null:
		return {
			"ok": false,
			"error": "failed_to_load_dependency:%s" % path,
		}
	if script is Object and (script as Object).has_method(method_name):
		return {
			"ok": true,
			"callable_target": script,
			"method_name": method_name,
		}
	if script is GDScript and (script as GDScript).can_instantiate():
		var instance: Variant = (script as GDScript).new()
		if instance is Object and (instance as Object).has_method(method_name):
			return {
				"ok": true,
				"callable_target": instance,
				"method_name": method_name,
			}
	return {
		"ok": false,
		"error": "dependency_missing_method:%s:%s" % [path, method_name],
	}


func _invoke_dependency(binding: Dictionary, args: Array = [], method_override: String = "") -> Variant:
	var target: Variant = binding.get("callable_target", null)
	var method_name: String = method_override if method_override != "" else str(binding.get("method_name", ""))
	if target == null or method_name == "":
		return null
	return target.callv(method_name, args)


func _make_error_result(
	scenario_path: String,
	errors: Array[String],
	scenario: Dictionary = {},
	runtime_result: Dictionary = {}
) -> Dictionary:
	return {
		"status": "ERROR",
		"scenario_path": scenario_path,
		"scenario_id": str(scenario.get("scenario_id", "")),
		"errors": errors,
		"runtime_result": runtime_result,
	}


func _string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			strings.append(str(item))
	return strings
