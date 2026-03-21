class_name EffectJammingTower
extends BaseEffect


func suppresses_tool_effects() -> bool:
	return true


func get_description() -> String:
	return "All Pokemon Tools lose their effects."
