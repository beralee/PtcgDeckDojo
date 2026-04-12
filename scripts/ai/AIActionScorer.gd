class_name AIActionScorer
extends RefCounted

const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const ACTION_SCORER_SCORE_SCALE: float = 50.0

var _model: RefCounted = NeuralNetInferenceScript.new()
var _loaded: bool = false
var _overall_runtime_weight: float = 0.0
var _per_kind_runtime_weight: Dictionary = {}


func is_loaded() -> bool:
	return _loaded


func load_weights(path: String) -> bool:
	if _model == null:
		_model = NeuralNetInferenceScript.new()
	_loaded = _model.has_method("load_weights") and bool(_model.call("load_weights", path))
	_load_runtime_weights(path)
	return _loaded


func score(state_features: Array, action_vector: Array) -> float:
	if not _loaded or _model == null or not _model.has_method("predict"):
		return 0.5
	var merged: Array = []
	for value: Variant in state_features:
		merged.append(float(value))
	for value: Variant in action_vector:
		merged.append(float(value))
	return float(_model.call("predict", merged))


func score_delta(state_features: Array, action_vector: Array, action_kind: String = "") -> float:
	var runtime_weight: float = get_runtime_weight(action_kind)
	if runtime_weight <= 0.0:
		return 0.0
	return (score(state_features, action_vector) - 0.5) * ACTION_SCORER_SCORE_SCALE * runtime_weight


func get_runtime_weight(action_kind: String = "") -> float:
	var weight: float = _overall_runtime_weight
	if action_kind != "" and _per_kind_runtime_weight.has(action_kind):
		weight = min(weight, float(_per_kind_runtime_weight.get(action_kind, 0.0)))
	return max(0.0, min(1.0, weight))


func _load_runtime_weights(weights_path: String) -> void:
	_overall_runtime_weight = 0.0
	_per_kind_runtime_weight.clear()
	if weights_path == "":
		return
	var metrics_path := weights_path.get_base_dir().path_join("decision_metrics.json")
	if not FileAccess.file_exists(metrics_path):
		return
	var file := FileAccess.open(metrics_path, FileAccess.READ)
	if file == null:
		return
	var payload: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (payload is Dictionary):
		return
	var metrics := payload as Dictionary
	var overall_variant: Variant = metrics.get("overall", {})
	if overall_variant is Dictionary:
		_overall_runtime_weight = _runtime_weight_from_summary(overall_variant)
	var by_action_kind_variant: Variant = metrics.get("by_action_kind", {})
	if by_action_kind_variant is Dictionary:
		for action_kind_variant: Variant in (by_action_kind_variant as Dictionary).keys():
			var action_kind := str(action_kind_variant)
			var summary_variant: Variant = (by_action_kind_variant as Dictionary).get(action_kind_variant, {})
			if summary_variant is Dictionary:
				_per_kind_runtime_weight[action_kind] = _runtime_weight_from_summary(summary_variant)


func _runtime_weight_from_summary(summary_variant: Variant) -> float:
	if not (summary_variant is Dictionary):
		return 0.0
	var summary := summary_variant as Dictionary
	var decision_count: int = int(summary.get("decision_count", 0))
	if decision_count < 32:
		return 0.0
	var top1_gain: float = float(summary.get("top1_gain_vs_heuristic", 0.0))
	var top3_gain: float = float(summary.get("top3_gain_vs_heuristic", 0.0))
	var composite_gain: float = top1_gain * 0.8 + top3_gain * 0.2
	if composite_gain <= -0.05:
		return 0.0
	if composite_gain <= 0.0:
		return 0.15
	if composite_gain >= 0.10:
		return 1.0
	return 0.15 + (composite_gain / 0.10) * 0.85
