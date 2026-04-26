extends Node

const GameStateMachineScript = preload("res://scripts/engine/GameStateMachine.gd")
const EffectProcessorScript = preload("res://scripts/engine/EffectProcessor.gd")

var exit_code: int = 0


func _ready() -> void:
	call_deferred("_finalize")


func _finalize() -> void:
	GameStateMachineScript.cleanup_live_instances_for_tests()
	EffectProcessorScript.cleanup_live_instances_for_tests()
	for _i in 24:
		await get_tree().process_frame
	get_tree().quit(exit_code)
