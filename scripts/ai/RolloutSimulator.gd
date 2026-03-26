class_name RolloutSimulator
extends RefCounted

## 从克隆状态用 heuristic AI 快速模拟到终局。
## 内部自动克隆传入的 gsm，不修改原始状态。

const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")

var _cloner := GameStateClonerScript.new()


func run_rollout(gsm: GameStateMachine, perspective_player: int, max_steps: int = 100) -> Dictionary:
	if gsm == null or gsm.game_state == null:
		return {"winner_index": -1, "steps": 0, "completed": false}

	var cloned := _cloner.clone_gsm(gsm)
	if cloned == null or cloned.game_state == null:
		return {"winner_index": -1, "steps": 0, "completed": false}

	var player_0_ai := AIOpponentScript.new()
	player_0_ai.configure(0, 1)
	var player_1_ai := AIOpponentScript.new()
	player_1_ai.configure(1, 1)

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(cloned)

	var steps: int = 0
	while steps < max_steps:
		if cloned.game_state.is_game_over():
			return {
				"winner_index": cloned.game_state.winner_index,
				"steps": steps,
				"completed": true,
			}
		var progressed: bool = false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				var prompt_owner: int = bridge.get_pending_prompt_owner()
				var prompt_ai: AIOpponent = player_0_ai if prompt_owner == 0 else player_1_ai
				progressed = prompt_ai.run_single_step(bridge, cloned)
			if not progressed:
				return {"winner_index": -1, "steps": steps + 1, "completed": false}
		else:
			var current: int = cloned.game_state.current_player_index
			var current_ai: AIOpponent = player_0_ai if current == 0 else player_1_ai
			progressed = current_ai.run_single_step(bridge, cloned)
			if not progressed:
				return {"winner_index": -1, "steps": steps + 1, "completed": false}
		steps += 1
	return {"winner_index": -1, "steps": max_steps, "completed": false}
