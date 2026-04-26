class_name TestLLMRagingBoltDuelTool
extends TestBase

const DuelToolPath := "res://scripts/ai/LLMRagingBoltDuelTool.gd"
const SelfPlayToolPath := "res://scripts/tools/RagingBoltLLMSelfPlayTool.gd"
const SelfPlayRunnerPath := "res://scripts/tools/run_raging_bolt_llm_self_play.gd"
const DuelRunnerPath := "res://scripts/tools/run_llm_raging_bolt_duel.gd"


func test_duel_tool_loads_and_exposes_default_matchup() -> String:
	if not ResourceLoader.exists(DuelToolPath):
		return "LLMRagingBoltDuelTool script should exist"
	var script: Variant = load(DuelToolPath)
	if not script is GDScript:
		return "LLMRagingBoltDuelTool should load as GDScript"
	var tool: Node = (script as GDScript).new()
	var options: Dictionary = tool.call("build_default_options")
	tool.queue_free()
	return run_checks([
		assert_eq(int(options.get("miraidon_deck_id", -1)), 575720, "Tool should default player 0 to Miraidon"),
		assert_eq(int(options.get("raging_bolt_deck_id", -1)), 575718, "Tool should default player 1 to Raging Bolt"),
		assert_eq(str(options.get("output_root", "")), "user://match_records/ai_duels", "Tool should record AI-vs-AI duel logs under a dedicated root"),
		assert_true(bool(options.get("record_match", false)), "Tool should record match logs by default"),
	])


func test_duel_tool_exposes_llm_raging_bolt_self_play_options() -> String:
	if not ResourceLoader.exists(DuelToolPath):
		return "LLMRagingBoltDuelTool script should exist"
	var script: Variant = load(DuelToolPath)
	if not script is GDScript:
		return "LLMRagingBoltDuelTool should load as GDScript"
	var tool: Node = (script as GDScript).new()
	var options: Dictionary = tool.call("build_self_play_options")
	tool.queue_free()
	return run_checks([
		assert_eq(str(options.get("mode", "")), "llm_raging_bolt_self_play", "Tool should expose a dedicated self-play mode"),
		assert_eq(int(options.get("player_0_deck_id", -1)), 575718, "Self-play player 0 should use Raging Bolt"),
		assert_eq(int(options.get("player_1_deck_id", -1)), 575718, "Self-play player 1 should use Raging Bolt"),
		assert_eq(str(options.get("player_0_strategy_id", "")), "raging_bolt_ogerpon_llm", "Self-play player 0 should use the LLM strategy"),
		assert_eq(str(options.get("player_1_strategy_id", "")), "raging_bolt_ogerpon_llm", "Self-play player 1 should use the LLM strategy"),
		assert_true(tool.has_method("run_llm_raging_bolt_self_play"), "Tool should expose the self-play runner method"),
	])


func test_standalone_self_play_runner_scripts_load() -> String:
	if not ResourceLoader.exists(SelfPlayToolPath):
		return "RagingBoltLLMSelfPlayTool script should exist"
	if not ResourceLoader.exists(SelfPlayRunnerPath):
		return "run_raging_bolt_llm_self_play script should exist"
	if not ResourceLoader.exists(DuelRunnerPath):
		return "run_llm_raging_bolt_duel script should exist"
	var tool_script: Variant = load(SelfPlayToolPath)
	var runner_script: Variant = load(SelfPlayRunnerPath)
	var duel_runner_script: Variant = load(DuelRunnerPath)
	if not tool_script is GDScript:
		return "RagingBoltLLMSelfPlayTool should load as GDScript"
	var tool: RefCounted = (tool_script as GDScript).new()
	return run_checks([
		assert_not_null(tool, "RagingBoltLLMSelfPlayTool should instantiate"),
		assert_true(tool.has_method("run"), "Standalone self-play tool should expose run(options, tree)"),
		assert_true(runner_script is GDScript, "Standalone self-play CLI runner should load as GDScript"),
		assert_true(duel_runner_script is GDScript, "LLMRagingBoltDuelTool CLI runner should load as GDScript"),
	])
