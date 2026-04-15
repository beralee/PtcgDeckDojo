class_name AIHandoffScoring
extends RefCounted


static func is_handoff_step(step: Dictionary) -> bool:
	var step_id: String = str(step.get("id", ""))
	return step_id in [
		"send_out",
		"switch_target",
		"self_switch_target",
		"own_bench_target",
		"opponent_switch_target",
		"pivot_target",
		"heavy_baton_target",
	]


static func score_strategy_target(
	deck_strategy: RefCounted,
	item: Variant,
	step: Dictionary,
	context: Dictionary = {}
) -> float:
	if deck_strategy == null:
		return 0.0
	if is_handoff_step(step) and deck_strategy.has_method("score_handoff_target"):
		return float(deck_strategy.call("score_handoff_target", item, step, context))
	if deck_strategy.has_method("score_interaction_target"):
		return float(deck_strategy.call("score_interaction_target", item, step, context))
	return 0.0
