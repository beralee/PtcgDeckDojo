class_name ScenarioEndStateComparator
extends RefCounted


static func compare(
	ai_end_state: Dictionary,
	expected_end_state: Dictionary,
	approved_alternatives: Array
) -> Dictionary:
	var normalized_ai := _normalize_end_state(ai_end_state)
	var normalized_expected := _normalize_end_state(expected_end_state)
	var strict_diff := _diff_primary(
		normalized_ai.get("primary", {}) as Dictionary,
		normalized_expected.get("primary", {}) as Dictionary
	)
	var scenario_id := _resolve_scenario_id(normalized_ai, normalized_expected)

	if strict_diff.is_empty():
		return _build_verdict(
			scenario_id,
			"PASS",
			"strict primary match",
			"",
			false,
			[],
			normalized_ai
		)

	var alternative_match := _find_matching_alternative(normalized_ai, approved_alternatives)
	if bool(alternative_match.get("matched", false)):
		return _build_verdict(
			scenario_id,
			"PASS",
			"matched approved divergent end state",
			str(alternative_match.get("alternative_id", "")),
			false,
			[],
			normalized_ai
		)

	if _is_conservative_dominant_pass(normalized_ai, normalized_expected):
		return _build_verdict(
			scenario_id,
			"PASS",
			"dominant pass: damage-only improvement with identical strict resources",
			"",
			true,
			strict_diff,
			normalized_ai
		)

	var fail_reasons := _collect_fail_reasons(
		strict_diff,
		normalized_ai.get("primary", {}) as Dictionary,
		normalized_expected.get("primary", {}) as Dictionary
	)
	if not fail_reasons.is_empty():
		return _build_verdict(
			scenario_id,
			"FAIL",
			"; ".join(fail_reasons),
			"",
			false,
			strict_diff,
			normalized_ai
		)

	return _build_verdict(
		scenario_id,
		"DIVERGE",
		_strict_mismatch_reason(strict_diff),
		"",
		false,
		strict_diff,
		normalized_ai
	)


static func _build_verdict(
	scenario_id: String,
	status: String,
	reason: String,
	matched_alternative_id: String,
	dominant: bool,
	diff: Array,
	ai_end_state: Dictionary
) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"status": status,
		"reason": reason,
		"matched_alternative_id": matched_alternative_id,
		"dominant": dominant,
		"diff": diff,
		"ai_end_state": ai_end_state,
	}


static func _resolve_scenario_id(ai_state: Dictionary, expected_state: Dictionary) -> String:
	var expected_id := str(expected_state.get("scenario_id", ""))
	if expected_id != "":
		return expected_id
	return str(ai_state.get("scenario_id", ""))


static func _normalize_end_state(state: Dictionary) -> Dictionary:
	var primary_source := {}
	var secondary_source := {}
	var has_secondary := false
	if state.has("primary") or state.has("secondary"):
		primary_source = state.get("primary", {}) as Dictionary
		secondary_source = state.get("secondary", {}) as Dictionary
		has_secondary = not secondary_source.is_empty()
	elif state.has("tracked_player") or state.has("opponent"):
		primary_source = state

	return {
		"scenario_id": str(state.get("scenario_id", "")),
		"primary": _normalize_primary(primary_source),
		"secondary": _normalize_secondary(secondary_source),
		"has_secondary": has_secondary,
	}


static func _normalize_primary(primary: Dictionary) -> Dictionary:
	return {
		"tracked_player": _normalize_player_primary(primary.get("tracked_player", {}) as Dictionary),
		"opponent": _normalize_player_primary(primary.get("opponent", {}) as Dictionary),
	}


static func _normalize_player_primary(player: Dictionary) -> Dictionary:
	var hand: Array[String] = []
	var raw_hand: Variant = player.get("hand", player.get("hand_names", []))
	if raw_hand is Array:
		for card_variant: Variant in raw_hand:
			hand.append(str(card_variant))
	hand.sort()

	var raw_bench: Variant = player.get("bench", [])
	var bench: Array = []
	if raw_bench is Array:
		for slot_variant: Variant in raw_bench:
			bench.append(_normalize_slot(_as_dictionary(slot_variant)))

	return {
		"active": _normalize_slot(player.get("active", {}) as Dictionary),
		"bench": bench,
		"hand": hand,
		"prize_count": int(player.get("prize_count", player.get("prizes_remaining", 0))),
	}


static func _normalize_slot(slot: Dictionary) -> Dictionary:
	if slot == null or slot.is_empty():
		return {}

	var evolution_stack: Array[String] = []
	var raw_stack: Variant = slot.get("evolution_stack", slot.get("pokemon_stack", []))
	if raw_stack is Array:
		for card_variant: Variant in raw_stack:
			evolution_stack.append(str(card_variant))

	var raw_energy_types: Variant = slot.get("energy_types", slot.get("energy_type_counts", {}))
	var energy_types := {}
	if raw_energy_types is Dictionary:
		for key_variant: Variant in raw_energy_types.keys():
			energy_types[str(key_variant)] = int((raw_energy_types as Dictionary).get(key_variant, 0))

	return {
		"pokemon_name": str(slot.get("pokemon_name", "")),
		"evolution_stack": evolution_stack,
		"energy_count": int(slot.get("energy_count", slot.get("total_energy", 0))),
		"energy_types": _sort_count_dict(energy_types),
		"tool_name": str(slot.get("tool_name", slot.get("tool", ""))),
		"damage": int(slot.get("damage", slot.get("damage_counters", 0))),
	}


static func _normalize_secondary(secondary: Dictionary) -> Dictionary:
	if secondary == null or secondary.is_empty():
		return {}
	return {
		"tracked_player": _normalize_player_secondary(secondary.get("tracked_player", {}) as Dictionary),
		"opponent": _normalize_player_secondary(secondary.get("opponent", {}) as Dictionary),
	}


static func _normalize_player_secondary(player: Dictionary) -> Dictionary:
	var discard_card_names: Array[String] = []
	var raw_discard: Variant = player.get("discard_card_names", player.get("discard_names", []))
	if raw_discard is Array:
		for card_variant: Variant in raw_discard:
			discard_card_names.append(str(card_variant))
	discard_card_names.sort()

	return {
		"total_remaining_hp": int(player.get("total_remaining_hp", player.get("remaining_hp_total", 0))),
		"total_energy": int(player.get("total_energy", player.get("board_energy_total", 0))),
		"discard_card_names": discard_card_names,
	}


static func _diff_primary(actual_primary: Dictionary, expected_primary: Dictionary) -> Array:
	var diff: Array = []
	_compare_player_primary("primary.tracked_player", actual_primary.get("tracked_player", {}) as Dictionary, expected_primary.get("tracked_player", {}) as Dictionary, diff)
	_compare_player_primary("primary.opponent", actual_primary.get("opponent", {}) as Dictionary, expected_primary.get("opponent", {}) as Dictionary, diff)
	return diff


static func _compare_player_primary(path: String, actual_player: Dictionary, expected_player: Dictionary, diff: Array) -> void:
	_compare_slot("%s.active" % path, actual_player.get("active", {}) as Dictionary, expected_player.get("active", {}) as Dictionary, diff)
	_compare_bench("%s.bench" % path, actual_player.get("bench", []) as Array, expected_player.get("bench", []) as Array, diff)

	var actual_hand := _sorted_string_array(actual_player.get("hand", []))
	var expected_hand := _sorted_string_array(expected_player.get("hand", []))
	if actual_hand != expected_hand:
		diff.append({
			"path": "%s.hand" % path,
			"kind": "hand_mismatch",
			"expected": expected_hand,
			"actual": actual_hand,
		})

	var actual_prize_count := int(actual_player.get("prize_count", 0))
	var expected_prize_count := int(expected_player.get("prize_count", 0))
	if actual_prize_count != expected_prize_count:
		diff.append({
			"path": "%s.prize_count" % path,
			"kind": "prize_mismatch",
			"expected": expected_prize_count,
			"actual": actual_prize_count,
		})


static func _compare_bench(path: String, actual_bench: Array, expected_bench: Array, diff: Array) -> void:
	var actual_groups := _group_slots_by_identity(actual_bench)
	var expected_groups := _group_slots_by_identity(expected_bench)
	var all_keys := _merged_sorted_keys(actual_groups, expected_groups)

	for key: String in all_keys:
		var actual_group := _sorted_slots_for_pairing(actual_groups.get(key, []) as Array)
		var expected_group := _sorted_slots_for_pairing(expected_groups.get(key, []) as Array)
		var pair_count := mini(actual_group.size(), expected_group.size())
		for i in range(pair_count):
			_compare_slot("%s[%s#%d]" % [path, key, i], actual_group[i] as Dictionary, expected_group[i] as Dictionary, diff)
		for i in range(pair_count, expected_group.size()):
			diff.append({
				"path": "%s[%s#%d]" % [path, key, i],
				"kind": "slot_missing",
				"expected": expected_group[i],
				"actual": {},
			})
		for i in range(pair_count, actual_group.size()):
			diff.append({
				"path": "%s[%s#%d]" % [path, key, i],
				"kind": "slot_extra",
				"expected": {},
				"actual": actual_group[i],
			})


static func _compare_slot(path: String, actual_slot: Dictionary, expected_slot: Dictionary, diff: Array) -> void:
	var normalized_actual := _normalize_slot(actual_slot)
	var normalized_expected := _normalize_slot(expected_slot)
	if normalized_actual.is_empty() and normalized_expected.is_empty():
		return
	if normalized_actual.is_empty() or normalized_expected.is_empty():
		diff.append({
			"path": path,
			"kind": "slot_presence",
			"expected": normalized_expected,
			"actual": normalized_actual,
		})
		return

	_compare_slot_field(path, "pokemon_name", normalized_actual, normalized_expected, diff)
	_compare_slot_field(path, "evolution_stack", normalized_actual, normalized_expected, diff)
	_compare_slot_field(path, "energy_count", normalized_actual, normalized_expected, diff)
	_compare_slot_field(path, "energy_types", normalized_actual, normalized_expected, diff)
	_compare_slot_field(path, "tool_name", normalized_actual, normalized_expected, diff)
	_compare_slot_field(path, "damage", normalized_actual, normalized_expected, diff)


static func _compare_slot_field(path: String, field: String, actual_slot: Dictionary, expected_slot: Dictionary, diff: Array) -> void:
	var actual_value: Variant = actual_slot.get(field)
	var expected_value: Variant = expected_slot.get(field)
	if actual_value == expected_value:
		return
	diff.append({
		"path": "%s.%s" % [path, field],
		"kind": "slot_field_mismatch",
		"expected": expected_value,
		"actual": actual_value,
	})


static func _find_matching_alternative(ai_end_state: Dictionary, approved_alternatives: Array) -> Dictionary:
	for index in range(approved_alternatives.size()):
		var alt_variant: Variant = approved_alternatives[index]
		if not alt_variant is Dictionary:
			continue
		var alternative: Dictionary = alt_variant
		var alternative_payload: Dictionary = _as_dictionary(alternative.get("end_state", alternative))
		var normalized_alt := _normalize_end_state(alternative_payload)
		var alt_diff := _diff_primary(
			ai_end_state.get("primary", {}) as Dictionary,
			normalized_alt.get("primary", {}) as Dictionary
		)
		if alt_diff.is_empty():
			var alternative_id := str(alternative.get("alternative_id", alternative.get("id", "approved_alt_%d" % index)))
			return {
				"matched": true,
				"alternative_id": alternative_id,
			}
	return {"matched": false}


static func _is_conservative_dominant_pass(ai_state: Dictionary, expected_state: Dictionary) -> bool:
	var ai_primary := ai_state.get("primary", {}) as Dictionary
	var expected_primary := expected_state.get("primary", {}) as Dictionary
	var ai_secondary := ai_state.get("secondary", {}) as Dictionary
	var expected_secondary := expected_state.get("secondary", {}) as Dictionary
	if not bool(ai_state.get("has_secondary", false)) or not bool(expected_state.get("has_secondary", false)):
		return false

	for side: String in ["tracked_player", "opponent"]:
		var ai_player: Dictionary = ai_primary.get(side, {}) as Dictionary
		var expected_player: Dictionary = expected_primary.get(side, {}) as Dictionary
		if _sorted_string_array(ai_player.get("hand", [])) != _sorted_string_array(expected_player.get("hand", [])):
			return false
		if int(ai_player.get("prize_count", 0)) != int(expected_player.get("prize_count", 0)):
			return false

	var tracked_primary_ok := _primary_side_matches_except_damage(
		ai_primary.get("tracked_player", {}) as Dictionary,
		expected_primary.get("tracked_player", {}) as Dictionary
	)
	var opponent_primary_ok := _primary_side_matches_except_damage(
		ai_primary.get("opponent", {}) as Dictionary,
		expected_primary.get("opponent", {}) as Dictionary
	)
	if not tracked_primary_ok or not opponent_primary_ok:
		return false

	var tracked_secondary_ai := ai_secondary.get("tracked_player", {}) as Dictionary
	var tracked_secondary_expected := expected_secondary.get("tracked_player", {}) as Dictionary
	var opponent_secondary_ai := ai_secondary.get("opponent", {}) as Dictionary
	var opponent_secondary_expected := expected_secondary.get("opponent", {}) as Dictionary

	if not _secondary_resources_match_except_hp(tracked_secondary_ai, tracked_secondary_expected):
		return false
	if not _secondary_resources_match_except_hp(opponent_secondary_ai, opponent_secondary_expected):
		return false

	var tracked_hp_better := int(tracked_secondary_ai.get("total_remaining_hp", 0)) >= int(tracked_secondary_expected.get("total_remaining_hp", 0))
	var opponent_hp_better := int(opponent_secondary_ai.get("total_remaining_hp", 0)) <= int(opponent_secondary_expected.get("total_remaining_hp", 0))
	if not tracked_hp_better or not opponent_hp_better:
		return false

	return _has_strict_damage_improvement(
		ai_primary.get("tracked_player", {}) as Dictionary,
		expected_primary.get("tracked_player", {}) as Dictionary,
		true
	) or _has_strict_damage_improvement(
		ai_primary.get("opponent", {}) as Dictionary,
		expected_primary.get("opponent", {}) as Dictionary,
		false
	)


static func _primary_side_matches_except_damage(ai_player: Dictionary, expected_player: Dictionary) -> bool:
	if _normalize_slot(ai_player.get("active", {}) as Dictionary).is_empty() != _normalize_slot(expected_player.get("active", {}) as Dictionary).is_empty():
		return false
	if not _slots_match_except_damage(ai_player.get("active", {}) as Dictionary, expected_player.get("active", {}) as Dictionary):
		return false
	return _bench_matches_except_damage(ai_player.get("bench", []) as Array, expected_player.get("bench", []) as Array)


static func _bench_matches_except_damage(ai_bench: Array, expected_bench: Array) -> bool:
	var ai_groups := _group_slots_by_identity(ai_bench)
	var expected_groups := _group_slots_by_identity(expected_bench)
	var all_keys := _merged_sorted_keys(ai_groups, expected_groups)
	for key: String in all_keys:
		var ai_group := _sorted_slots_for_pairing(ai_groups.get(key, []) as Array)
		var expected_group := _sorted_slots_for_pairing(expected_groups.get(key, []) as Array)
		if ai_group.size() != expected_group.size():
			return false
		for i in range(ai_group.size()):
			if not _slots_match_except_damage(ai_group[i] as Dictionary, expected_group[i] as Dictionary):
				return false
	return true


static func _slots_match_except_damage(ai_slot: Dictionary, expected_slot: Dictionary) -> bool:
	var normalized_ai := _normalize_slot(ai_slot)
	var normalized_expected := _normalize_slot(expected_slot)
	if normalized_ai.is_empty() and normalized_expected.is_empty():
		return true
	if normalized_ai.is_empty() or normalized_expected.is_empty():
		return false

	for field: String in ["pokemon_name", "evolution_stack", "energy_count", "energy_types", "tool_name"]:
		if normalized_ai.get(field) != normalized_expected.get(field):
			return false
	return true


static func _secondary_resources_match_except_hp(ai_secondary: Dictionary, expected_secondary: Dictionary) -> bool:
	return (
		int(ai_secondary.get("total_energy", 0)) == int(expected_secondary.get("total_energy", 0))
		and _sorted_string_array(ai_secondary.get("discard_card_names", [])) == _sorted_string_array(expected_secondary.get("discard_card_names", []))
	)


static func _has_strict_damage_improvement(ai_player: Dictionary, expected_player: Dictionary, is_tracked_player: bool) -> bool:
	var active_improved := _slot_damage_improved(
		ai_player.get("active", {}) as Dictionary,
		expected_player.get("active", {}) as Dictionary,
		is_tracked_player
	)
	if active_improved:
		return true

	var ai_groups := _group_slots_by_identity(ai_player.get("bench", []) as Array)
	var expected_groups := _group_slots_by_identity(expected_player.get("bench", []) as Array)
	var all_keys := _merged_sorted_keys(ai_groups, expected_groups)
	for key: String in all_keys:
		var ai_group := _sorted_slots_for_pairing(ai_groups.get(key, []) as Array)
		var expected_group := _sorted_slots_for_pairing(expected_groups.get(key, []) as Array)
		if ai_group.size() != expected_group.size():
			return false
		for i in range(ai_group.size()):
			if _slot_damage_improved(ai_group[i] as Dictionary, expected_group[i] as Dictionary, is_tracked_player):
				return true
	return false


static func _slot_damage_improved(ai_slot: Dictionary, expected_slot: Dictionary, is_tracked_player: bool) -> bool:
	var normalized_ai := _normalize_slot(ai_slot)
	var normalized_expected := _normalize_slot(expected_slot)
	if normalized_ai.is_empty() or normalized_expected.is_empty():
		return false

	var ai_damage := int(normalized_ai.get("damage", 0))
	var expected_damage := int(normalized_expected.get("damage", 0))
	if is_tracked_player:
		return ai_damage < expected_damage
	return ai_damage > expected_damage


static func _collect_fail_reasons(diff: Array, actual_primary: Dictionary, expected_primary: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	var tracked_actual := actual_primary.get("tracked_player", {}) as Dictionary
	var tracked_expected := expected_primary.get("tracked_player", {}) as Dictionary
	var opponent_actual := actual_primary.get("opponent", {}) as Dictionary
	var opponent_expected := expected_primary.get("opponent", {}) as Dictionary

	if int(tracked_actual.get("prize_count", 0)) > int(tracked_expected.get("prize_count", 0)):
		reasons.append("tracked player prize race regressed")
	if int(opponent_actual.get("prize_count", 0)) < int(opponent_expected.get("prize_count", 0)):
		reasons.append("opponent prize race improved beyond expected line")

	for diff_variant: Variant in diff:
		if not diff_variant is Dictionary:
			continue
		var item: Dictionary = diff_variant
		var path := str(item.get("path", ""))
		var expected_value: Variant = item.get("expected")
		var actual_value: Variant = item.get("actual")

		if path.begins_with("primary.tracked_player.active") or path.begins_with("primary.tracked_player.bench"):
			if path.ends_with(".pokemon_name") or path.ends_with(".evolution_stack") or item.get("kind", "") in ["slot_presence", "slot_missing", "slot_extra"]:
				_append_unique(reasons, "tracked player board identity regressed")
			elif path.ends_with(".energy_count") and int(actual_value) < int(expected_value):
				_append_unique(reasons, "tracked player energy count regressed")
			elif path.ends_with(".energy_types") and _count_dict_regressed(actual_value as Dictionary, expected_value as Dictionary):
				_append_unique(reasons, "tracked player energy typing regressed")
			elif path.ends_with(".tool_name") and str(expected_value) != "" and str(actual_value) != str(expected_value):
				_append_unique(reasons, "tracked player tool assignment regressed")

	return reasons


static func _strict_mismatch_reason(diff: Array) -> String:
	if diff.is_empty():
		return ""
	var first_path := ""
	var first_variant: Variant = diff[0]
	if first_variant is Dictionary:
		first_path = str((first_variant as Dictionary).get("path", ""))
	return "strict end-state mismatch on %d fields (first: %s)" % [diff.size(), first_path]


static func _count_dict_regressed(actual: Dictionary, expected: Dictionary) -> bool:
	for key_variant: Variant in expected.keys():
		var key := str(key_variant)
		if int(actual.get(key, 0)) < int(expected.get(key, 0)):
			return true
	return false


static func _append_unique(items: Array[String], value: String) -> void:
	if value not in items:
		items.append(value)


static func _group_slots_by_identity(bench: Array) -> Dictionary:
	var groups := {}
	for slot_variant: Variant in bench:
		if not slot_variant is Dictionary:
			continue
		var slot := _normalize_slot(_as_dictionary(slot_variant))
		var key := _slot_identity(slot)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(slot)
	return groups


static func _slot_identity(slot: Dictionary) -> String:
	if slot.is_empty():
		return "__empty__"
	var evolution_stack := _string_array_preserve_order(slot.get("evolution_stack", []))
	return "%s|%s" % [
		str(slot.get("pokemon_name", "")),
		">".join(evolution_stack),
	]


static func _sorted_slots_for_pairing(slots: Array) -> Array:
	var keyed: Array = []
	for slot_variant: Variant in slots:
		var slot := _normalize_slot(_as_dictionary(slot_variant))
		keyed.append({
			"key": _slot_pairing_key(slot),
			"value": slot,
		})
	keyed.sort_custom(Callable(ScenarioEndStateComparator, "_sort_keyed_values"))

	var sorted: Array = []
	for item_variant: Variant in keyed:
		var item: Dictionary = item_variant if item_variant is Dictionary else {}
		sorted.append(item.get("value", {}))
	return sorted


static func _slot_pairing_key(slot: Dictionary) -> String:
	return JSON.stringify({
		"pokemon_name": str(slot.get("pokemon_name", "")),
		"evolution_stack": slot.get("evolution_stack", []),
		"energy_count": int(slot.get("energy_count", 0)),
		"energy_types": _sort_count_dict(slot.get("energy_types", {}) as Dictionary),
		"tool_name": str(slot.get("tool_name", "")),
		"damage": int(slot.get("damage", 0)),
	})


static func _merged_sorted_keys(left: Dictionary, right: Dictionary) -> Array[String]:
	var key_dict := {}
	for key_variant: Variant in left.keys():
		key_dict[str(key_variant)] = true
	for key_variant: Variant in right.keys():
		key_dict[str(key_variant)] = true
	var keys: Array[String] = []
	for key_variant: Variant in key_dict.keys():
		keys.append(str(key_variant))
	keys.sort()
	return keys


static func _sorted_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value_variant: Variant in values:
			result.append(str(value_variant))
	result.sort()
	return result


static func _string_array_preserve_order(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value_variant: Variant in values:
			result.append(str(value_variant))
	return result


static func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _sort_count_dict(counts: Dictionary) -> Dictionary:
	var keys: Array[String] = []
	for key_variant: Variant in counts.keys():
		keys.append(str(key_variant))
	keys.sort()

	var sorted := {}
	for key: String in keys:
		sorted[key] = int(counts.get(key, 0))
	return sorted


static func _sort_keyed_values(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("key", "")) < str(right.get("key", ""))
