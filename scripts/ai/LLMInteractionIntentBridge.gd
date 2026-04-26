class_name LLMInteractionIntentBridge
extends RefCounted

const HIGH_MATCH_SCORE: float = 100000.0
const LOW_MISMATCH_SCORE: float = -1000.0

const DISCARD_STEP_IDS := {
	"discard_card": true,
	"discard_cards": true,
	"discard_energy": true,
	"discard_basic_energy": true,
}

const SEARCH_STEP_IDS := {
	"search_cards": true,
	"search_pokemon": true,
	"search_future_pokemon": true,
	"search_energy": true,
}

const HAND_ENERGY_STEP_IDS := {
	"basic_energy_from_hand": true,
	"energy_card": true,
	"energy_card_id": true,
	"selected_energy_card_id": true,
}

const RECOVER_STEP_IDS := {
	"night_stretcher_choice": true,
	"recover_energy": true,
	"recover_target": true,
	"recover_card": true,
	"recover_targets": true,
}

const ASSIGNMENT_STEP_IDS := {
	"sada_assignments": true,
	"energy_assignments": true,
}

const TARGET_STEP_IDS := {
	"target_pokemon": true,
	"self_ko_target": true,
	"gust_target": true,
	"opponent_bench_target": true,
	"opponent_switch_target": true,
	"switch_target": true,
	"self_switch_target": true,
	"own_bench_target": true,
	"retreat_target": true,
	"send_out": true,
	"source_pokemon": true,
	"pivot_target": true,
}

const _ENERGY_ALIASES := {
	"lightning": "L",
	"electric": "L",
	"lightning energy": "L",
	"l": "L",
	"fighting": "F",
	"fighting energy": "F",
	"f": "F",
	"grass": "G",
	"grass energy": "G",
	"g": "G",
	"fire": "R",
	"fire energy": "R",
	"r": "R",
	"water": "W",
	"water energy": "W",
	"w": "W",
	"psychic": "P",
	"psychic energy": "P",
	"p": "P",
	"dark": "D",
	"dark energy": "D",
	"d": "D",
	"metal": "M",
	"metal energy": "M",
	"m": "M",
	"colorless": "C",
	"c": "C",
}

func pick_interaction_items(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	action_queue: Array
) -> Dictionary:
	var queue_item: Dictionary = _find_relevant_queue_item(context, action_queue)
	if queue_item.is_empty():
		return {"has_plan": false, "items": []}
	var step_id: String = str(step.get("id", ""))
	var max_select: int = int(step.get("max_select", items.size()))
	if max_select <= 0:
		max_select = items.size()
	if _queue_item_is_sada(queue_item, context) and (bool(ASSIGNMENT_STEP_IDS.get(step_id, false)) or step_id.contains("assignment")):
		var sada_picks: Array = _pick_sada_energy_sources_by_attack_need(items, step, context, max_select)
		if not sada_picks.is_empty():
			return {"has_plan": true, "items": sada_picks}
	var intent_text: String = _intent_text_for_pick_step(step_id, queue_item)
	if intent_text == "":
		return {"has_plan": false, "items": []}
	var picked: Array = _pick_items_by_intent(items, intent_text, max_select)
	if picked.is_empty():
		return {"has_plan": false, "items": []}
	return {"has_plan": true, "items": picked}


func score_interaction_target(
	item: Variant,
	step: Dictionary,
	context: Dictionary,
	action_queue: Array
) -> Dictionary:
	var queue_item: Dictionary = _find_relevant_queue_item(context, action_queue)
	if queue_item.is_empty():
		return {"has_score": false, "score": 0.0}
	var step_id: String = str(step.get("id", ""))
	if _queue_item_is_sada(queue_item, context) and item is PokemonSlot and (context.has("assignment_source") or context.has("source_card")) and (bool(ASSIGNMENT_STEP_IDS.get(step_id, false)) or step_id.contains("assignment")):
		return {"has_score": true, "score": _score_sada_assignment_target(item as PokemonSlot, context)}
	var target_text: String = _intent_text_for_target_step(step_id, queue_item, item)
	if target_text == "":
		return {"has_score": false, "score": 0.0}
	if item is PokemonSlot:
		var requested_position: String = str(queue_item.get("position", queue_item.get("bench_position", ""))).strip_edges()
		if requested_position != "":
			if _slot_position_matches(item as PokemonSlot, requested_position, context):
				return {"has_score": true, "score": HIGH_MATCH_SCORE}
			return {"has_score": true, "score": LOW_MISMATCH_SCORE}
		if _slot_position_matches(item as PokemonSlot, target_text, context):
			return {"has_score": true, "score": HIGH_MATCH_SCORE}
	if _item_matches_any_token(item, target_text):
		return {"has_score": true, "score": HIGH_MATCH_SCORE}
	return {"has_score": true, "score": LOW_MISMATCH_SCORE}


func _intent_text_for_pick_step(step_id: String, queue_item: Dictionary) -> String:
	var nested_intent: String = _nested_interaction_text(queue_item, step_id)
	if nested_intent != "":
		return nested_intent
	if bool(DISCARD_STEP_IDS.get(step_id, false)):
		var discard_choice: String = str(queue_item.get("discard_choice", "")).strip_edges()
		if discard_choice != "":
			return discard_choice
		return str(queue_item.get("discard_energy_type", "")).strip_edges()
	if bool(SEARCH_STEP_IDS.get(step_id, false)):
		return str(queue_item.get("search_target", "")).strip_edges()
	if bool(HAND_ENERGY_STEP_IDS.get(step_id, false)):
		var hand_energy: String = str(queue_item.get("energy_card", queue_item.get("energy_card_id", ""))).strip_edges()
		if hand_energy != "":
			return hand_energy
		return str(queue_item.get("energy_type", "")).strip_edges()
	if bool(RECOVER_STEP_IDS.get(step_id, false)):
		var recover_choice: String = str(queue_item.get("recover_target", queue_item.get("recover_card", ""))).strip_edges()
		if recover_choice != "":
			return recover_choice
		return str(queue_item.get("search_target", "")).strip_edges()
	if bool(ASSIGNMENT_STEP_IDS.get(step_id, false)) or step_id.contains("assignment"):
		return str(queue_item.get("search_target", "")).strip_edges()
	return ""


func _intent_text_for_target_step(step_id: String, queue_item: Dictionary, item: Variant) -> String:
	var nested_intent: String = _nested_interaction_text(queue_item, step_id)
	if nested_intent != "":
		return nested_intent
	if item is PokemonSlot:
		var direct_target: String = str(queue_item.get("target", "")).strip_edges()
		if direct_target != "":
			return direct_target
		var bench_target: String = str(queue_item.get("bench_target", "")).strip_edges()
		if bench_target != "":
			return bench_target
		if bool(TARGET_STEP_IDS.get(step_id, false)):
			return str(queue_item.get("target", queue_item.get("bench_target", ""))).strip_edges()
	if item is CardInstance:
		var pick_text: String = _intent_text_for_pick_step(step_id, queue_item)
		if pick_text != "":
			return pick_text
	return ""


func _nested_interaction_text(queue_item: Dictionary, step_id: String) -> String:
	var interactions: Variant = queue_item.get("interactions", {})
	if interactions is Dictionary:
		var spec: Variant = (interactions as Dictionary).get(step_id, null)
		if spec == null:
			spec = _find_policy_interaction_spec(interactions as Dictionary, step_id)
		var text := _interaction_spec_to_text(spec)
		if text != "":
			return text
	var selection_policy: Variant = queue_item.get("selection_policy", {})
	if selection_policy is Dictionary:
		return _selection_policy_text_for_step(selection_policy as Dictionary, step_id)
	return ""


func _interaction_spec_to_text(spec: Variant) -> String:
	if spec is Dictionary:
		var dict: Dictionary = spec
		for key: String in ["prefer", "cards", "targets", "search_target", "discard_choice", "energy_type", "target", "card", "resource"]:
			if not dict.has(key):
				continue
			var text := _interaction_spec_to_text(dict.get(key))
			if text != "":
				return text
	if spec is Array:
		var parts: Array[String] = []
		for entry: Variant in spec:
			var text: String = str(entry).strip_edges()
			if text != "":
				parts.append(text)
		return ",".join(parts)
	return str(spec).strip_edges() if spec != null else ""


func _selection_policy_text_for_step(selection_policy: Dictionary, step_id: String) -> String:
	var spec: Variant = _find_selection_policy_spec(selection_policy, step_id)
	var text := _normalize_policy_text(_interaction_spec_to_text(spec), step_id)
	if text != "":
		return text
	return _normalize_policy_text(str(spec).strip_edges() if spec != null else "", step_id)


func _find_selection_policy_spec(selection_policy: Dictionary, step_id: String) -> Variant:
	if bool(DISCARD_STEP_IDS.get(step_id, false)):
		for key: String in ["discard", "discard_policy", "discard_prefer", "discard_cards", "discard_card", "resource"]:
			if selection_policy.has(key):
				return selection_policy.get(key)
	if bool(SEARCH_STEP_IDS.get(step_id, false)):
		for key: String in ["search", "search_energy", "search_targets", "search_cards", "find"]:
			if selection_policy.has(key):
				return selection_policy.get(key)
	if bool(HAND_ENERGY_STEP_IDS.get(step_id, false)):
		for key: String in [step_id, "energy_card_id", "selected_energy_card_id", "energy_card", "resource", "energy_type", "prefer"]:
			if selection_policy.has(key):
				return selection_policy.get(key)
	if bool(RECOVER_STEP_IDS.get(step_id, false)):
		for key: String in [step_id, "recover_target", "recover_card", "recover_targets", "recover_energy", "target", "resource", "prefer", "search_targets"]:
			if selection_policy.has(key):
				return selection_policy.get(key)
	if bool(ASSIGNMENT_STEP_IDS.get(step_id, false)) or step_id.contains("assignment"):
		for key: String in ["assignments", "energy_assignments", "sada_assignments", "acceleration_assignments", "target"]:
			if selection_policy.has(key):
				return selection_policy.get(key)
	if bool(TARGET_STEP_IDS.get(step_id, false)):
		for key: String in [step_id, "target", "target_position", "gust_target", "opponent_bench_target", "opponent_switch_target", "switch_target", "self_switch_target", "own_bench_target", "retreat_target", "send_out"]:
			if selection_policy.has(key):
				return selection_policy.get(key)
	return null


func _normalize_policy_text(text: String, step_id: String) -> String:
	var lower := text.strip_edges().to_lower()
	if lower == "":
		return ""
	if bool(HAND_ENERGY_STEP_IDS.get(step_id, false)):
		if lower.contains("grass"):
			return "Grass Energy"
		if lower.contains("lightning") or lower.contains("electric"):
			return "Lightning Energy"
		if lower.contains("fighting"):
			return "Fighting Energy"
	if bool(DISCARD_STEP_IDS.get(step_id, false)):
		if lower in ["expendable_energy_or_duplicate_basic", "expendable_energy", "duplicate_basic_energy"]:
			return "Grass Energy,Lightning Energy,Fighting Energy"
	if bool(SEARCH_STEP_IDS.get(step_id, false)):
		if lower == "missing_attack_energy":
			return "Lightning Energy,Fighting Energy,Grass Energy"
	if bool(RECOVER_STEP_IDS.get(step_id, false)):
		if lower in ["basic_attack_energy_or_core_basic_pokemon", "attack_energy", "missing_attack_energy"]:
			return "Lightning Energy,Fighting Energy,Grass Energy,Raging Bolt ex,Teal Mask Ogerpon ex"
	return text


func _find_policy_interaction_spec(interactions: Dictionary, step_id: String) -> Variant:
	if bool(DISCARD_STEP_IDS.get(step_id, false)):
		for key: String in ["discard_cards", "discard_card", "discard_energy", "discard_basic_energy", "attack_energy_discard"]:
			if interactions.has(key):
				return interactions.get(key)
	if bool(SEARCH_STEP_IDS.get(step_id, false)):
		for key: String in ["search_cards", "search_pokemon", "search_item", "search_tool", "search_energy", "search_supporter", "stage2_card"]:
			if interactions.has(key):
				return interactions.get(key)
	if bool(HAND_ENERGY_STEP_IDS.get(step_id, false)):
		for key: String in [step_id, "energy_card_id", "selected_energy_card_id", "energy_card", "basic_energy_from_hand", "energy_type"]:
			if interactions.has(key):
				return interactions.get(key)
	if bool(RECOVER_STEP_IDS.get(step_id, false)):
		for key: String in [step_id, "recover_target", "recover_card", "recover_targets", "recover_energy", "target", "search_targets"]:
			if interactions.has(key):
				return interactions.get(key)
	if bool(ASSIGNMENT_STEP_IDS.get(step_id, false)) or step_id.contains("assignment"):
		for key: String in ["energy_assignments", "sada_assignments", "electric_generator_assignments", "tool_target"]:
			if interactions.has(key):
				return interactions.get(key)
	if step_id in ["embrace_energy", "embrace_target"]:
		for key: String in [step_id, "psychic_embrace_assignments", "energy_assignments"]:
			if interactions.has(key):
				return interactions.get(key)
	if bool(TARGET_STEP_IDS.get(step_id, false)):
		for key: String in [step_id, "target_pokemon", "self_ko_target", "gust_target", "opponent_bench_target", "opponent_switch_target", "switch_target", "self_switch_target", "own_bench_target", "retreat_target", "send_out"]:
			if interactions.has(key):
				return interactions.get(key)
	return null


func _queue_item_is_sada(queue_item: Dictionary, context: Dictionary) -> bool:
	var card_text := "%s %s" % [str(queue_item.get("card", "")), str(queue_item.get("pokemon", ""))]
	var pending_card: Variant = context.get("pending_effect_card", null)
	if pending_card is CardInstance and (pending_card as CardInstance).card_data != null:
		var cd: CardData = (pending_card as CardInstance).card_data
		card_text += " %s %s %s" % [str(cd.name), str(cd.name_en), str(cd.effect_id)]
	var lower := card_text.to_lower()
	return lower.contains("professor sada") or lower.contains("sada") or lower.contains("奥琳") or lower.contains("651276c51911345aa091c1c7b87f3f4f")


func _pick_sada_energy_sources_by_attack_need(items: Array, _step: Dictionary, context: Dictionary, max_select: int) -> Array:
	var ranked := _rank_sada_energy_sources(items, context)
	var picked: Array = []
	var require_cost_filling := false
	for entry: Dictionary in ranked:
		if float(entry.get("score", 0.0)) >= 50000.0:
			require_cost_filling = true
			break
	for entry: Dictionary in ranked:
		if picked.size() >= max_select:
			break
		var score := float(entry.get("score", 0.0))
		if score <= 0.0:
			continue
		if require_cost_filling and score < 50000.0:
			continue
		var card: Variant = entry.get("card", null)
		if card != null and not picked.has(card):
			picked.append(card)
	return picked


func _rank_sada_energy_sources(items: Array, context: Dictionary) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is CardInstance):
			continue
		var card: CardInstance = item as CardInstance
		if card.card_data == null or not card.card_data.is_energy():
			continue
		var symbol := _normalize_energy_token(str(card.card_data.energy_provides))
		if symbol == "":
			continue
		ranked.append({
			"card": card,
			"symbol": symbol,
			"score": _best_sada_source_score(symbol, context),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.get("score", 0.0))
		var score_b := float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return str(a.get("symbol", "")) < str(b.get("symbol", ""))
		return score_a > score_b
	)
	return ranked


func _best_sada_source_score(symbol: String, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var best_score := 0.0
	for slot: PokemonSlot in player.get_all_pokemon():
		var score := _score_sada_symbol_for_slot(symbol, slot, context)
		if score > best_score:
			best_score = score
	return best_score


func _score_sada_assignment_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null:
		return LOW_MISMATCH_SCORE
	var pending_counts: Dictionary = context.get("pending_assignment_counts", {}) if context.get("pending_assignment_counts", {}) is Dictionary else {}
	if int(pending_counts.get(int(slot.get_instance_id()), 0)) > 0:
		return LOW_MISMATCH_SCORE
	var source: Variant = context.get("assignment_source", context.get("source_card", null))
	var symbol := ""
	if source is CardInstance and (source as CardInstance).card_data != null:
		symbol = _normalize_energy_token(str((source as CardInstance).card_data.energy_provides))
	var score := _score_sada_symbol_for_slot(symbol, slot, context)
	return LOW_MISMATCH_SCORE if score <= 0.0 else score


func _score_sada_symbol_for_slot(symbol: String, slot: PokemonSlot, context: Dictionary) -> float:
	if symbol == "" or slot == null or slot.get_card_data() == null:
		return 0.0
	var cd: CardData = slot.get_card_data()
	if not cd.is_ancient_pokemon():
		return 0.0
	var best := 0.0
	for attack_index: int in cd.attacks.size():
		var attack: Dictionary = cd.attacks[attack_index]
		var cost := str(attack.get("cost", ""))
		var missing := _missing_attack_cost_symbol_codes(cost, _slot_energy_counts_by_symbol(slot))
		if not missing.has(symbol):
			continue
		var attack_score := 70000.0
		if attack_index > 0:
			attack_score += 10000.0
		if _slot_position(slot, context) == "active":
			attack_score += 12000.0
		var damage := _first_int_in_string(str(attack.get("damage", "")))
		attack_score += float(mini(damage, 300))
		if _text_has_any(("%s %s" % [str(cd.name), str(cd.name_en)]).to_lower(), ["raging bolt", "猛雷鼓"]):
			attack_score += 8000.0
		if attack_score > best:
			best = attack_score
	if best > 0.0:
		return best
	# Extra Energy can still increase some Ancient attacks, but it must never beat filling a real cost gap.
	var text := ""
	for attack: Dictionary in cd.attacks:
		text += " %s %s" % [str(attack.get("name", "")), str(attack.get("text", ""))]
	if _text_has_any(text.to_lower(), ["energy", "能量", "70x", "70×"]):
		return 1200.0 + (400.0 if _slot_position(slot, context) == "active" else 0.0)
	return 0.0


func _slot_energy_counts_by_symbol(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	if slot == null:
		return counts
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var symbol := _normalize_energy_token(str(card.card_data.energy_provides))
		if symbol == "":
			continue
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


func _missing_attack_cost_symbol_codes(cost: String, attached_counts: Dictionary) -> Array[String]:
	var remaining := {}
	var total_attached := 0
	for raw_key: Variant in attached_counts.keys():
		var key := str(raw_key)
		var count := int(attached_counts.get(key, 0))
		remaining[key] = count
		total_attached += count
	var missing: Array[String] = []
	var colorless_needed := 0
	for i: int in cost.length():
		var symbol := _normalize_energy_token(cost.substr(i, 1))
		if symbol == "":
			continue
		if symbol == "C":
			colorless_needed += 1
			continue
		var count := int(remaining.get(symbol, 0))
		if count > 0:
			remaining[symbol] = count - 1
			total_attached -= 1
		else:
			missing.append(symbol)
	if colorless_needed > total_attached:
		for i: int in colorless_needed - total_attached:
			missing.append("C")
	return missing


func _slot_position(slot: PokemonSlot, context: Dictionary) -> String:
	var game_state: GameState = context.get("game_state")
	if game_state == null or slot == null:
		return ""
	for player: PlayerState in game_state.players:
		if player == null:
			continue
		if slot == player.active_pokemon:
			return "active"
		for i: int in player.bench.size():
			if slot == player.bench[i]:
				return "bench_%d" % i
	return ""


func _first_int_in_string(text: String) -> int:
	var digits := ""
	for i: int in text.length():
		var ch := text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits.is_valid_int() else 0


func _text_has_any(text: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if text.contains(needle.to_lower()):
			return true
	return false


func _find_relevant_queue_item(context: Dictionary, action_queue: Array) -> Dictionary:
	if action_queue.is_empty():
		return {}
	var pending_card: Variant = context.get("pending_effect_card", null)
	var pending_kind: String = str(context.get("pending_effect_kind", ""))
	for raw: Variant in action_queue:
		if not (raw is Dictionary):
			continue
		var queue_item: Dictionary = raw
		if _queue_item_matches_pending_effect(queue_item, pending_card, pending_kind):
			return queue_item
	return {}


func _queue_item_matches_pending_effect(queue_item: Dictionary, pending_card: Variant, pending_kind: String) -> bool:
	var q_type: String = str(queue_item.get("type", ""))
	if pending_kind == "trainer" and q_type != "play_trainer":
		return false
	if pending_kind in ["ability", "stadium"] and q_type not in ["use_ability", "play_stadium"]:
		return false
	if pending_kind in ["attack", "granted_attack"] and q_type not in ["attack"]:
		return false
	if pending_card is CardInstance and (pending_card as CardInstance).card_data != null:
		var card: CardInstance = pending_card as CardInstance
		var card_hint: String = str(queue_item.get("card", ""))
		var pokemon_hint: String = str(queue_item.get("pokemon", ""))
		if card_hint != "":
			return _card_matches_token(card, card_hint)
		if pokemon_hint != "":
			return _card_matches_token(card, pokemon_hint)
		return q_type in ["attack", "granted_attack"]
	return false


func _pick_items_by_intent(items: Array, intent_text: String, max_select: int) -> Array:
	var tokens: Array[String] = _split_intent_tokens(intent_text)
	var picked: Array = []
	var used_indices: Dictionary = {}
	for token: String in tokens:
		for index: int in items.size():
			if bool(used_indices.get(index, false)):
				continue
			if _item_matches_token(items[index], token):
				picked.append(items[index])
				used_indices[index] = true
				break
		if picked.size() >= max_select:
			return picked
	if picked.is_empty():
		for index: int in items.size():
			if _item_matches_any_token(items[index], intent_text):
				picked.append(items[index])
				if picked.size() >= max_select:
					break
	return picked


func _item_matches_any_token(item: Variant, intent_text: String) -> bool:
	for token: String in _split_intent_tokens(intent_text):
		if _item_matches_token(item, token):
			return true
	return false


func _item_matches_token(item: Variant, token: String) -> bool:
	if item is CardInstance:
		return _card_matches_token(item as CardInstance, token)
	if item is PokemonSlot:
		return _slot_matches_token(item as PokemonSlot, token)
	return _text_matches(str(item), token)


func _card_matches_token(card: CardInstance, token: String) -> bool:
	if card == null or card.card_data == null:
		return false
	var normalized_token := token.strip_edges().to_lower()
	if normalized_token == "c%d" % int(card.instance_id) or normalized_token == str(card.instance_id):
		return true
	if _text_matches(str(card.card_data.name), token):
		return true
	if _text_matches(str(card.card_data.name_en), token):
		return true
	if card.card_data.is_energy():
		return _energy_matches_token(str(card.card_data.energy_provides), token)
	return false


func _slot_matches_token(slot: PokemonSlot, token: String) -> bool:
	if slot == null or slot.get_top_card() == null:
		return false
	if _text_matches(str(slot.get_pokemon_name()), token):
		return true
	var cd: CardData = slot.get_card_data()
	if cd != null and _text_matches(str(cd.name_en), token):
		return true
	return false


func _slot_position_matches(slot: PokemonSlot, position: String, context: Dictionary) -> bool:
	if position == "":
		return false
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for player: PlayerState in game_state.players:
		if player == null:
			continue
		if position == "active" and slot == player.active_pokemon:
			return true
		for i: int in player.bench.size():
			if position == "bench_%d" % i and slot == player.bench[i]:
				return true
	return false


func _text_matches(value: String, token: String) -> bool:
	var lhs: String = value.strip_edges().to_lower()
	var rhs: String = token.strip_edges().to_lower()
	if lhs == "" or rhs == "":
		return false
	return lhs.contains(rhs) or rhs.contains(lhs)


func _energy_matches_token(energy_code: String, token: String) -> bool:
	var normalized: String = _normalize_energy_token(token)
	if normalized == "":
		return false
	return normalized == energy_code


func _normalize_energy_token(token: String) -> String:
	var lower: String = token.strip_edges().to_lower()
	if lower == "":
		return ""
	if _ENERGY_ALIASES.has(lower):
		return str(_ENERGY_ALIASES.get(lower, ""))
	for key: String in _ENERGY_ALIASES.keys():
		if lower.contains(key):
			return str(_ENERGY_ALIASES.get(key, ""))
	return ""


func _split_intent_tokens(intent_text: String) -> Array[String]:
	var normalized: String = intent_text.replace("/", ",")
	var tokens: Array[String] = []
	for raw: String in normalized.split(",", false):
		var token: String = raw.strip_edges()
		if token != "":
			tokens.append(token)
	return tokens
