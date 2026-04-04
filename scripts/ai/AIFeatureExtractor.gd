class_name AIFeatureExtractor
extends RefCounted

const NEST_BALL_EFFECT_ID: String = "1af63a7e2cb7a79215474ad8db8fd8fd"

const AIActionFeatureEncoderScript = preload("res://scripts/ai/AIActionFeatureEncoder.gd")

var _action_feature_encoder = AIActionFeatureEncoderScript.new()


func build_context(gsm: GameStateMachine, player_index: int, action: Dictionary) -> Dictionary:
	var features: Dictionary = _action_feature_encoder.build_features(gsm, player_index, action)
	features["action_vector"] = _action_feature_encoder.build_vector(gsm, player_index, action)
	features["action_vector_schema"] = _action_feature_encoder.get_schema()
	return features
