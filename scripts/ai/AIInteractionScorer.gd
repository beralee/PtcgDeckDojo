class_name AIInteractionScorer
extends RefCounted

const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const INTERACTION_SCORER_SCORE_SCALE: float = 0.35

var _model: RefCounted = NeuralNetInferenceScript.new()
var _loaded: bool = false
var _runtime_weight: float = 0.0


func is_loaded() -> bool:
	return _loaded


func load_weights(path: String) -> bool:
	if _model == null:
		_model = NeuralNetInferenceScript.new()
	_loaded = _model.has_method("load_weights") and bool(_model.call("load_weights", path))
	_load_runtime_weight(path)
	return _loaded


func score(state_features: Array, interaction_vector: Array) -> float:
	if not _loaded or _model == null or not _model.has_method("predict"):
		return 0.5
	var merged: Array = []
	for value: Variant in state_features:
		merged.append(float(value))
	for value: Variant in interaction_vector:
		merged.append(float(value))
	return float(_model.call("predict", merged))


func score_delta(state_features: Array, interaction_vector: Array) -> float:
	if _runtime_weight <= 0.0:
		return 0.0
	return (score(state_features, interaction_vector) - 0.5) * INTERACTION_SCORER_SCORE_SCALE * _runtime_weight


func get_runtime_weight() -> float:
	return _runtime_weight


func _load_runtime_weight(weights_path: String) -> void:
	_runtime_weight = 0.0
	if weights_path == "":
		return
	var metrics_path := weights_path.get_base_dir().path_join("interaction_metrics.json")
	if not FileAccess.file_exists(metrics_path):
		return
	var file := FileAccess.open(metrics_path, FileAccess.READ)
	if file == null:
		return
	var payload: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (payload is Dictionary):
		return
	var overall_variant: Variant = (payload as Dictionary).get("overall", {})
	if not (overall_variant is Dictionary):
		return
	var overall := overall_variant as Dictionary
	var decision_count: int = int(overall.get("decision_count", 0))
	if decision_count < 32:
		return
	var top1_gain: float = float(overall.get("top1_gain_vs_strategy", overall.get("top1_gain_vs_teacher", 0.0)))
	var top3_gain: float = float(overall.get("top3_gain_vs_strategy", overall.get("top3_gain_vs_teacher", 0.0)))
	var composite_gain: float = top1_gain * 0.8 + top3_gain * 0.2
	if composite_gain <= -0.05:
		_runtime_weight = 0.0
	elif composite_gain <= 0.0:
		_runtime_weight = 0.15
	elif composite_gain >= 0.10:
		_runtime_weight = 1.0
	else:
		_runtime_weight = 0.15 + (composite_gain / 0.10) * 0.85
