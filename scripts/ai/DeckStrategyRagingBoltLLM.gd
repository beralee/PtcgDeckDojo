extends "res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd"

const ZenMuxClientScript = preload("res://scripts/network/ZenMuxClient.gd")
const LLMTurnPlanPromptBuilderScript = preload("res://scripts/ai/LLMTurnPlanPromptBuilder.gd")
const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")

var _llm_host_node: Node = null
var _cached_llm_plan: Dictionary = {}
var _cached_turn_number: int = -1
var _llm_pending: bool = false
var _client: RefCounted = ZenMuxClientScript.new()
var _prompt_builder: RefCounted = LLMTurnPlanPromptBuilderScript.new()
var _llm_request_count: int = 0
var _llm_success_count: int = 0
var _llm_fail_count: int = 0


func get_strategy_id() -> String:
	return "raging_bolt_ogerpon_llm"


func set_llm_host_node(node: Node) -> void:
	_llm_host_node = node


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var turn: int = int(game_state.turn_number)
	if _cached_turn_number == turn and not _cached_llm_plan.is_empty():
		return _cached_llm_plan
	if turn != _cached_turn_number:
		_cached_llm_plan.clear()
		_cached_turn_number = turn
		if not _llm_pending:
			_fire_llm_request(game_state, player_index)
	return super.build_turn_plan(game_state, player_index, context)


func _fire_llm_request(game_state: GameState, player_index: int) -> void:
	if _llm_host_node == null or not is_instance_valid(_llm_host_node):
		return
	var game_manager: Variant = AutoloadResolverScript.get_game_manager()
	if game_manager == null:
		return
	var api_config: Dictionary = game_manager.call("get_battle_review_api_config")
	var endpoint: String = str(api_config.get("endpoint", ""))
	var api_key: String = str(api_config.get("api_key", ""))
	if endpoint == "" or api_key == "":
		return
	_llm_pending = true
	_llm_request_count += 1
	var payload: Dictionary = _prompt_builder.build_request_payload(game_state, player_index)
	payload["model"] = str(api_config.get("model", ""))
	_client.set_timeout_seconds(float(api_config.get("timeout_seconds", 15.0)))
	var turn_at_request: int = int(game_state.turn_number)
	var err: int = _client.request_json(
		_llm_host_node,
		endpoint,
		api_key,
		payload,
		_on_llm_response.bind(turn_at_request)
	)
	if err != OK:
		_llm_pending = false
		_llm_fail_count += 1
		print("[LLM策略] 请求发送失败: error=%d" % err)


func _on_llm_response(response: Dictionary, turn_at_request: int) -> void:
	_llm_pending = false
	if String(response.get("status", "")) == "error":
		_llm_fail_count += 1
		print("[LLM策略] 请求失败: %s" % str(response.get("message", "unknown")))
		return
	var plan: Dictionary = _prompt_builder.parse_llm_response_to_turn_plan(response)
	if plan.is_empty():
		_llm_fail_count += 1
		print("[LLM策略] LLM返回了无效intent: %s" % str(response.get("intent", "")))
		return
	_llm_success_count += 1
	if turn_at_request == _cached_turn_number:
		_cached_llm_plan = plan
		print("[LLM策略] 回合%d: intent=%s target=%s" % [
			turn_at_request,
			str(plan.get("intent", "")),
			str(plan.get("targets", {}).get("primary_attacker_name", "")),
		])
	else:
		print("[LLM策略] 回合%d的响应已过期（当前回合%d）" % [turn_at_request, _cached_turn_number])


func get_llm_stats() -> Dictionary:
	return {
		"requests": _llm_request_count,
		"successes": _llm_success_count,
		"failures": _llm_fail_count,
	}
