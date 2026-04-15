class_name AIInteractionPlanner
extends RefCounted

const AIHandoffScoringScript = preload("res://scripts/ai/AIHandoffScoring.gd")


func pick_item_indices(
	deck_strategy: RefCounted,
	items: Array,
	step: Dictionary,
	selected_count: int,
	context: Dictionary = {}
) -> PackedInt32Array:
	var result := PackedInt32Array()
	if items.is_empty() or selected_count <= 0:
		return result
	var scored: Array[Dictionary] = []
	var score_context: Dictionary = context.duplicate(true)
	score_context["all_items"] = items
	for i: int in items.size():
		scored.append({
			"index": i,
			"score": _score_target(deck_strategy, items[i], step, score_context),
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


func pick_best_legal_target_index(
	deck_strategy: RefCounted,
	target_items: Array,
	excluded_targets: Array,
	step: Dictionary,
	context: Dictionary = {}
) -> int:
	if target_items.is_empty():
		return -1
	var best_index: int = -1
	var best_score: float = -INF
	var score_context: Dictionary = context.duplicate(true)
	score_context["all_items"] = target_items
	for i: int in target_items.size():
		if i in excluded_targets:
			continue
		var score: float = _score_target(deck_strategy, target_items[i], step, score_context)
		if best_index < 0 or score > best_score:
			best_index = i
			best_score = score
	return best_index


func _score_target(
	deck_strategy: RefCounted,
	item: Variant,
	step: Dictionary,
	context: Dictionary
) -> float:
	return AIHandoffScoringScript.score_strategy_target(deck_strategy, item, step, context)
