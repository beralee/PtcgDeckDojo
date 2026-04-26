class_name AIStepResolver
extends RefCounted

const AIInteractionPlannerScript = preload("res://scripts/ai/AIInteractionPlanner.gd")
const AIInteractionFeatureEncoderScript = preload("res://scripts/ai/AIInteractionFeatureEncoder.gd")
const AIHandoffScoringScript = preload("res://scripts/ai/AIHandoffScoring.gd")

## Optional injected deck strategy that guides interaction target choices.
var deck_strategy: RefCounted = null
var interaction_scorer: RefCounted = null
var decision_exporter: RefCounted = null

var _interaction_planner = AIInteractionPlannerScript.new()
var _interaction_feature_encoder = AIInteractionFeatureEncoderScript.new()


func set_deck_strategy(strategy: RefCounted) -> void:
	deck_strategy = strategy


func _build_turn_plan(game_state: GameState, player_index: int, extra_context: Dictionary = {}) -> Dictionary:
	if deck_strategy == null:
		return {}
	if game_state == null:
		return {}
	var plan_context: Dictionary = extra_context.duplicate(true)
	if deck_strategy.has_method("build_turn_contract"):
		return deck_strategy.call("build_turn_contract", game_state, player_index, plan_context)
	if not deck_strategy.has_method("build_turn_plan"):
		return {}
	return deck_strategy.call("build_turn_plan", game_state, player_index, plan_context)


func resolve_pending_step(
	battle_scene: Control,
	_gsm: GameStateMachine,
	player_index: int,
	state_features: Array[float] = []
) -> bool:
	if battle_scene == null:
		return false
	if str(battle_scene.get("_pending_choice")) != "effect_interaction":
		return false
	var steps: Array[Dictionary] = battle_scene.get("_pending_effect_steps")
	var step_index: int = int(battle_scene.get("_pending_effect_step_index"))
	if step_index < 0 or step_index >= steps.size():
		return false
	var step: Dictionary = steps[step_index]
	var chooser_player: int = int(battle_scene.call("_resolve_effect_step_chooser_player", step))
	if chooser_player != player_index:
		return false
	var interaction_context: Dictionary = battle_scene.get("_pending_effect_context")
	var pending_ability_index_variant: Variant = battle_scene.get("_pending_effect_ability_index")
	var pending_ability_index: int = int(pending_ability_index_variant) if pending_ability_index_variant != null else -1
	var strategy_context := {
		"game_state": _gsm.game_state if _gsm != null else null,
		"player_index": player_index,
		"pending_effect_kind": str(battle_scene.get("_pending_effect_kind")),
		"pending_effect_card": battle_scene.get("_pending_effect_card"),
		"pending_effect_slot": battle_scene.get("_pending_effect_slot"),
		"pending_effect_ability_index": pending_ability_index,
	}
	var turn_contract := _build_turn_plan(
		_gsm.game_state if _gsm != null else null,
		player_index,
		{
			"step_id": str(step.get("id", "")),
			"prompt_kind": "effect_interaction",
			"interaction_context": interaction_context,
		}
	)
	strategy_context["turn_plan"] = turn_contract
	strategy_context["turn_contract"] = turn_contract
	if bool(battle_scene.call("_effect_step_uses_counter_distribution_ui", step)):
		return _resolve_counter_distribution_step(battle_scene, step, strategy_context, state_features)
	if bool(battle_scene.call("_effect_step_uses_field_assignment_ui", step)):
		return _resolve_field_assignment_step(battle_scene, step, strategy_context, state_features)
	if bool(battle_scene.call("_effect_step_uses_field_slot_ui", step)):
		return _resolve_field_slot_step(battle_scene, step, strategy_context, interaction_context, state_features)
	if str(step.get("ui_mode", "")) == "card_assignment":
		return _resolve_dialog_assignment_step(battle_scene, step, strategy_context, state_features)
	return _resolve_dialog_step(battle_scene, step, strategy_context, interaction_context, state_features)


func _resolve_dialog_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	interaction_context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var items: Array = step.get("items", [])
	var legal_pool: Dictionary = _build_legal_item_pool(items, step, interaction_context)
	var legal_items: Array = legal_pool.get("items", [])
	var legal_indices: Array = legal_pool.get("indices", [])
	var min_select: int = int(step.get("min_select", 1))
	var max_select: int = int(step.get("max_select", 1))
	if not legal_items.is_empty() and deck_strategy != null and deck_strategy.has_method("pick_interaction_items"):
		var strategy_picks: Variant = deck_strategy.call("pick_interaction_items", legal_items, step, context)
		if strategy_picks is Array and not (strategy_picks as Array).is_empty():
			var explicit_indices := PackedInt32Array()
			for picked_item: Variant in (strategy_picks as Array):
				var legal_idx: int = legal_items.find(picked_item)
				if legal_idx >= 0 and legal_idx < legal_indices.size():
					explicit_indices.append(int(legal_indices[legal_idx]))
			if explicit_indices.size() >= min_select:
				battle_scene.call("_handle_effect_interaction_choice", explicit_indices)
				return true
	var selected_count: int = _baseline_pick_count(legal_items.size(), min_select, max_select)
	if legal_items.is_empty() or selected_count <= 0:
		battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array())
		return true
	var picked_legal_indices: PackedInt32Array = _pick_item_indices(
		legal_items,
		step,
		selected_count,
		context,
		state_features
	)
	var selected_indices := PackedInt32Array()
	for legal_index: int in picked_legal_indices:
		if legal_index >= 0 and legal_index < legal_indices.size():
			selected_indices.append(int(legal_indices[legal_index]))
	_record_interaction_decision(
		legal_items,
		step,
		context,
		state_features,
		picked_legal_indices,
		"dialog"
	)
	battle_scene.call("_handle_effect_interaction_choice", selected_indices)
	return true


func _resolve_field_slot_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	interaction_context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var items: Array = step.get("items", [])
	var legal_pool: Dictionary = _build_legal_item_pool(items, step, interaction_context)
	var legal_items: Array = legal_pool.get("items", [])
	var legal_indices: Array = legal_pool.get("indices", [])
	var selected_count: int = _baseline_pick_count(
		legal_items.size(),
		int(step.get("min_select", 1)),
		int(step.get("max_select", 1))
	)
	if legal_items.is_empty() or selected_count <= 0:
		if str(battle_scene.get("_field_interaction_mode")) == "slot_select":
			battle_scene.call("_finalize_field_slot_selection")
		return true
	var picked_legal_indices: PackedInt32Array = _pick_item_indices(
		legal_items,
		step,
		selected_count,
		context,
		state_features
	)
	for legal_index: int in picked_legal_indices:
		if legal_index >= 0 and legal_index < legal_indices.size():
			battle_scene.call("_handle_field_slot_select_index", int(legal_indices[legal_index]))
	_record_interaction_decision(
		legal_items,
		step,
		context,
		state_features,
		picked_legal_indices,
		"field_slot"
	)
	if str(battle_scene.get("_field_interaction_mode")) == "slot_select":
		battle_scene.call("_finalize_field_slot_selection")
	return true


func _resolve_counter_distribution_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var total_counters: int = int(step.get("total_counters", 0))
	var target_items: Array = step.get("target_items", [])
	if total_counters <= 0 or target_items.is_empty():
		return false
	var picked := PackedInt32Array()
	var best_index: int = _best_legal_target_index(target_items, [], step, context, state_features)
	if best_index < 0:
		best_index = 0
	picked.append(best_index)
	_record_interaction_decision(
		target_items,
		step,
		context,
		state_features,
		picked,
		"counter_distribution"
	)
	battle_scene.call("_on_counter_distribution_amount_chosen", total_counters)
	battle_scene.call("_handle_counter_distribution_target", best_index)
	return true


func _resolve_field_assignment_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var assignment_plan: Dictionary = _build_assignment_source_plan(
		step.get("source_items", []),
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step,
		context,
		state_features
	)
	var assignments_made: int = _assign_sources_to_targets(
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step.get("source_items", []),
		step.get("target_items", []),
		step.get("source_exclude_targets", {}),
		func(source_index: int, target_index: int) -> void:
			battle_scene.call("_on_field_assignment_source_chosen", source_index)
			battle_scene.call("_handle_field_assignment_target_index", target_index),
		step,
		context,
		state_features,
		assignment_plan
	)
	if assignments_made <= 0 and not bool(assignment_plan.get("handled", false)):
		return false
	if str(battle_scene.get("_field_interaction_mode")) == "assignment":
		battle_scene.call("_finalize_field_assignment_selection")
	return true


func _resolve_dialog_assignment_step(
	battle_scene: Control,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> bool:
	var assignment_plan: Dictionary = _build_assignment_source_plan(
		step.get("source_items", []),
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step,
		context,
		state_features
	)
	var assignments_made: int = _assign_sources_to_targets(
		int(step.get("min_select", 0)),
		int(step.get("max_select", 0)),
		step.get("source_items", []),
		step.get("target_items", []),
		step.get("source_exclude_targets", {}),
		func(source_index: int, target_index: int) -> void:
			battle_scene.call("_on_assignment_source_chosen", source_index)
			battle_scene.call("_on_assignment_target_chosen", target_index),
		step,
		context,
		state_features,
		assignment_plan
	)
	if assignments_made <= 0 and not bool(assignment_plan.get("handled", false)):
		return false
	battle_scene.call("_confirm_assignment_dialog")
	return true


func _build_assignment_source_plan(
	source_items: Array,
	min_assignments: int,
	max_assignments: int,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> Dictionary:
	var explicit_plan: Dictionary = _pick_explicit_interaction_items_with_empty_support(
		source_items,
		step,
		max_assignments,
		context
	)
	if bool(explicit_plan.get("has_plan", false)):
		var selected_items: Array = explicit_plan.get("items", [])
		var selected_indices: Array[int] = []
		for wanted: Variant in selected_items:
			var source_index: int = source_items.find(wanted)
			if source_index >= 0 and not selected_indices.has(source_index):
				selected_indices.append(source_index)
		if selected_indices.is_empty():
			return {
				"handled": min_assignments <= 0,
				"has_explicit_plan": true,
				"selected_source_indices": selected_indices,
			}
		return {
			"handled": true,
			"has_explicit_plan": true,
			"selected_source_indices": selected_indices,
		}
	return {
		"handled": false,
		"has_explicit_plan": false,
		"selected_source_indices": [],
		"selected_count": _baseline_pick_count(source_items.size(), min_assignments, max_assignments),
	}


func _assign_sources_to_targets(
	min_assignments: int,
	max_assignments: int,
	source_items: Array,
	target_items: Array,
	source_exclude_targets: Dictionary,
	apply_assignment: Callable,
	step: Dictionary = {},
	context: Dictionary = {},
	state_features: Array[float] = [],
	assignment_plan: Dictionary = {}
) -> int:
	if source_items.is_empty() or target_items.is_empty() or not apply_assignment.is_valid():
		return 0
	var explicit_source_indices: Array = assignment_plan.get("selected_source_indices", [])
	var has_explicit_plan: bool = bool(assignment_plan.get("has_explicit_plan", false))
	var target_assignment_count: int = explicit_source_indices.size() if has_explicit_plan else int(assignment_plan.get("selected_count", _baseline_pick_count(source_items.size(), min_assignments, max_assignments)))
	if target_assignment_count <= 0:
		return 0
	var assignments_made: int = 0
	var picked_targets := PackedInt32Array()
	var pending_assignment_counts: Dictionary = {}
	var pending_assignments: Array[Dictionary] = []
	var source_indices: Array = explicit_source_indices if has_explicit_plan else range(source_items.size())
	for source_index_variant: Variant in source_indices:
		var source_index: int = int(source_index_variant)
		if assignments_made >= target_assignment_count:
			break
		var excluded_targets: Array = source_exclude_targets.get(source_index, [])
		var assignment_context: Dictionary = context.duplicate(true)
		assignment_context["assignment_source"] = source_items[source_index]
		assignment_context["assignment_source_index"] = source_index
		assignment_context["source_card"] = source_items[source_index]
		assignment_context["pending_assignment_counts"] = pending_assignment_counts.duplicate()
		assignment_context["pending_assignments"] = pending_assignments.duplicate(true)
		var chosen_target_index: int = _best_legal_target_index(
			target_items,
			excluded_targets,
			step,
			assignment_context,
			state_features
		)
		if chosen_target_index < 0:
			continue
		apply_assignment.call(source_index, chosen_target_index)
		picked_targets.append(chosen_target_index)
		var chosen_target: Variant = target_items[chosen_target_index]
		if chosen_target is PokemonSlot:
			var chosen_slot := chosen_target as PokemonSlot
			var target_id := int(chosen_slot.get_instance_id())
			pending_assignment_counts[target_id] = int(pending_assignment_counts.get(target_id, 0)) + 1
		pending_assignments.append({
			"source": source_items[source_index],
			"target": chosen_target,
		})
		assignments_made += 1
		_record_interaction_decision(
			target_items,
			step,
			assignment_context,
			state_features,
			PackedInt32Array([chosen_target_index]),
			"assignment"
		)
	return assignments_made


func _pick_explicit_interaction_items_with_empty_support(
	items: Array,
	step: Dictionary,
	max_select: int,
	context: Dictionary = {}
) -> Dictionary:
	if deck_strategy == null or not deck_strategy.has_method("pick_interaction_items"):
		return {"has_plan": false, "items": []}
	var planned: Variant = deck_strategy.call("pick_interaction_items", items, {"id": str(step.get("id", "")), "max_select": max_select}, context)
	if not (planned is Array):
		return {"has_plan": false, "items": []}
	var planned_items: Array = planned
	if not planned_items.is_empty():
		return {"has_plan": true, "items": planned_items}
	if _should_preserve_empty_interaction_selection(step, context):
		return {"has_plan": true, "items": []}
	return {"has_plan": false, "items": []}


func _should_preserve_empty_interaction_selection(step: Dictionary, context: Dictionary = {}) -> bool:
	if deck_strategy == null or not deck_strategy.has_method("should_preserve_empty_interaction_selection"):
		return false
	return bool(deck_strategy.call("should_preserve_empty_interaction_selection", step, context))


func _first_legal_target_index(target_count: int, excluded_targets: Array) -> int:
	for target_index: int in target_count:
		if target_index in excluded_targets:
			continue
		return target_index
	return -1


func _best_legal_target_index(
	target_items: Array,
	excluded_targets: Array,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> int:
	if target_items.is_empty():
		return -1
	var best_index: int = -1
	var best_score: float = -INF
	for i: int in target_items.size():
		if i in excluded_targets:
			continue
		var score: float = _score_interaction_candidate(target_items[i], step, context, state_features)
		if best_index < 0 or score > best_score:
			best_index = i
			best_score = score
	if best_index < 0:
		return _first_legal_target_index(target_items.size(), excluded_targets)
	return best_index


func _pick_item_indices(
	items: Array,
	step: Dictionary,
	selected_count: int,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> PackedInt32Array:
	var result := PackedInt32Array()
	if items.is_empty() or selected_count <= 0:
		return result
	var scored: Array[Dictionary] = []
	for i: int in items.size():
		scored.append({
			"index": i,
			"score": _score_interaction_candidate(items[i], step, context, state_features),
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("score", 0.0))
		var score_b: float = float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return int(a.get("index", -1)) < int(b.get("index", -1))
		return score_a > score_b
	)
	for i: int in mini(selected_count, scored.size()):
		result.append(int(scored[i].get("index", -1)))
	return result


func _score_interaction_candidate(
	item: Variant,
	step: Dictionary,
	context: Dictionary = {},
	state_features: Array[float] = []
) -> float:
	var strategy_score: float = _score_strategy_target(item, step, context)
	var learned_score: float = _score_with_interaction_scorer(item, step, context, state_features, strategy_score)
	return strategy_score + learned_score


func _score_with_interaction_scorer(
	item: Variant,
	step: Dictionary,
	context: Dictionary,
	state_features: Array[float],
	strategy_score: float
) -> float:
	if interaction_scorer == null or not interaction_scorer.has_method("score_delta"):
		return 0.0
	var feature_context := _build_interaction_feature_context(context, strategy_score)
	var interaction_vector: Array[float] = _interaction_feature_encoder.build_vector(item, step, feature_context)
	return float(interaction_scorer.call("score_delta", state_features, interaction_vector))


func _build_interaction_feature_context(context: Dictionary, strategy_score: float) -> Dictionary:
	var feature_context: Dictionary = context.duplicate(true)
	feature_context["strategy_score"] = strategy_score
	return feature_context


func _record_interaction_decision(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	state_features: Array[float],
	chosen_indices: PackedInt32Array,
	resolution_kind: String
) -> void:
	if decision_exporter == null or not decision_exporter.has_method("record_interaction_decision"):
		return
	var candidates: Array[Dictionary] = []
	for item_index: int in items.size():
		var item_context: Dictionary = context.duplicate(true)
		item_context["all_items"] = items
		var strategy_score: float = _score_strategy_target(items[item_index], step, item_context)
		var feature_context := _build_interaction_feature_context(context, strategy_score)
		feature_context["all_items"] = items
		var interaction_features: Dictionary = _interaction_feature_encoder.build_features(items[item_index], step, feature_context)
		candidates.append({
			"index": item_index,
			"chosen": item_index in chosen_indices,
			"item_name": _item_name(items[item_index]),
			"strategy_score": strategy_score,
			"interaction_features": interaction_features,
			"interaction_vector": _interaction_feature_encoder.build_vector(items[item_index], step, feature_context),
		})
	decision_exporter.call("record_interaction_decision", {
		"player_index": int(context.get("player_index", -1)),
		"turn_number": int(context.get("game_state").turn_number if context.get("game_state", null) != null else -1),
		"state_features": state_features,
		"resolution_kind": resolution_kind,
		"step_id": str(step.get("id", "")),
		"step_type": str(step.get("type", step.get("ui_mode", ""))),
		"step_label": str(step.get("title", step.get("prompt", ""))),
		"candidates": candidates,
		"chosen_indices": Array(chosen_indices),
	})


func _score_strategy_target(
	item: Variant,
	step: Dictionary,
	context: Dictionary = {}
) -> float:
	if deck_strategy == null:
		return 0.0
	var score_context: Dictionary = context.duplicate(true)
	score_context["all_items"] = context.get("all_items", [])
	return AIHandoffScoringScript.score_strategy_target(deck_strategy, item, step, score_context)


func _item_name(item: Variant) -> String:
	if item is CardInstance and (item as CardInstance).card_data != null:
		return str((item as CardInstance).card_data.name)
	if item is PokemonSlot:
		return (item as PokemonSlot).get_pokemon_name()
	if item == null:
		return ""
	return str(item)


func _baseline_pick_count(item_count: int, min_select: int, max_select: int) -> int:
	if item_count <= 0:
		return 0
	var target_count: int = item_count
	if max_select > 0:
		target_count = mini(target_count, max_select)
	if min_select > 0:
		target_count = maxi(target_count, min_select)
	return clampi(target_count, 1, item_count)


func _build_legal_item_pool(items: Array, step: Dictionary, interaction_context: Dictionary) -> Dictionary:
	var legal_items: Array = []
	var legal_indices: Array = []
	var excluded_items: Array = _collect_excluded_step_items(step, interaction_context)
	for index: int in items.size():
		var item: Variant = items[index]
		if item in excluded_items:
			continue
		legal_items.append(item)
		legal_indices.append(index)
	return {
		"items": legal_items,
		"indices": legal_indices,
	}


func _collect_excluded_step_items(step: Dictionary, interaction_context: Dictionary) -> Array:
	if interaction_context.is_empty():
		return []
	var excluded: Array = []
	var step_ids: Array[String] = []
	var single_step_id: String = str(step.get("exclude_selected_from_step_id", "")).strip_edges()
	if single_step_id != "":
		step_ids.append(single_step_id)
	for key_variant: Variant in step.get("exclude_selected_from_step_ids", []):
		var key: String = str(key_variant).strip_edges()
		if key != "" and not step_ids.has(key):
			step_ids.append(key)
	for step_id: String in step_ids:
		var selected_items: Variant = interaction_context.get(step_id, [])
		if not selected_items is Array:
			continue
		for item: Variant in selected_items:
			if not excluded.has(item):
				excluded.append(item)
	return excluded
