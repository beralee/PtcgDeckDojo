class_name AIActionScorer
extends RefCounted

const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")

var _model: RefCounted = NeuralNetInferenceScript.new()
var _loaded: bool = false


func is_loaded() -> bool:
	return _loaded


func load_weights(path: String) -> bool:
	if _model == null:
		_model = NeuralNetInferenceScript.new()
	_loaded = _model.has_method("load_weights") and bool(_model.call("load_weights", path))
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
