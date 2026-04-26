class_name TestSwissTournament
extends TestBase

const SwissTournamentScript = preload("res://scripts/tournament/SwissTournament.gd")


func test_round_count_matches_supported_sizes() -> String:
	var tournament := SwissTournamentScript.new()
	return run_checks([
		assert_eq(tournament.rounds_for_size(16), 4, "16 人瑞士轮应为 4 轮"),
		assert_eq(tournament.rounds_for_size(32), 5, "32 人瑞士轮应为 5 轮"),
		assert_eq(tournament.rounds_for_size(64), 6, "64 人瑞士轮应为 6 轮"),
		assert_eq(tournament.rounds_for_size(128), 7, "128 人瑞士轮应为 7 轮"),
	])


func test_prepare_next_round_creates_player_pairing_and_full_tables() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345)
	var pairing: Dictionary = tournament.prepare_next_round()
	return run_checks([
		assert_false(pairing.is_empty(), "准备第一轮后应返回玩家配对"),
		assert_eq(int(tournament.current_round), 1, "准备第一轮后 current_round 应为 1"),
		assert_eq(tournament.current_pairings.size(), 8, "16 人赛事第一轮应生成 8 桌配对"),
		assert_true(int(pairing.get("player_a_id", -1)) == 0 or int(pairing.get("player_b_id", -1)) == 0, "玩家配对应包含玩家本人"),
	])


func test_record_player_match_updates_points_and_summary() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345)
	tournament.prepare_next_round()
	var summary: Dictionary = tournament.record_player_match(true, "normal")
	var player := tournament._participant_by_id(0)
	return run_checks([
		assert_eq(str(summary.get("result", "")), "win", "玩家获胜后 summary 结果应为 win"),
		assert_eq(int(player.get("wins", 0)), 1, "玩家获胜后胜场应加 1"),
		assert_eq(int(player.get("points", 0)), 3, "玩家获胜后积分应为 3"),
		assert_true(bool(summary.get("is_final_round", false)) == false, "第一轮结束后不应被标为最终轮"),
	])


func test_field_uses_supported_ai_decks_and_random_modes() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345)
	var supported_ids := CardDatabase.get_supported_ai_deck_ids()
	var invalid_deck_count := 0
	var valid_mode_count := 0
	for participant: Dictionary in tournament.participants:
		if bool(participant.get("is_player", false)):
			continue
		if not supported_ids.has(int(participant.get("deck_id", 0))):
			invalid_deck_count += 1
		var ai_mode := str(participant.get("ai_mode", ""))
		if ai_mode in ["strong", "weak"]:
			valid_mode_count += 1
	return run_checks([
		assert_eq(invalid_deck_count, 0, "比赛模式 AI 参赛者只能使用 BattleSetup 短名单里的 AI 卡组"),
		assert_eq(valid_mode_count, tournament.participants.size() - 1, "所有 AI 参赛者都应被标记为 strong 或 weak"),
	])


func test_field_can_include_llm_raging_bolt_when_enabled() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345, true)
	var llm_count := 0
	var llm_deck_mismatch := 0
	for participant: Dictionary in tournament.participants:
		if str(participant.get("ai_mode", "")) != "llm":
			continue
		llm_count += 1
		if int(participant.get("deck_id", 0)) != 575718:
			llm_deck_mismatch += 1
	return run_checks([
		assert_true(llm_count >= 1, "AI 设置测试通过后，比赛参赛池应至少引入一个 LLM 猛雷鼓对手"),
		assert_eq(llm_deck_mismatch, 0, "LLM 对手目前只能使用猛雷鼓卡组 575718"),
	])


func test_strong_ai_always_beats_weak_ai_in_simulation() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345)
	tournament.participants = [
		{
			"id": 1,
			"name": "强AI",
			"deck_id": 575720,
			"is_player": false,
			"ai_mode": "strong",
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"points": 0,
			"opponent_points": 0.0,
			"opponents": [],
			"rounds": [],
		},
		{
			"id": 2,
			"name": "弱AI",
			"deck_id": 575716,
			"is_player": false,
			"ai_mode": "weak",
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"points": 0,
			"opponent_points": 0.0,
			"opponents": [],
			"rounds": [],
		},
	]
	var result: Dictionary = tournament._simulate_match(1, 2)
	return run_checks([
		assert_eq(int(result.get("winner_id", -1)), 1, "AI 对 AI 时，strong 对 weak 应固定由 strong 获胜"),
	])


func test_llm_ai_simulation_rates_match_contract() -> String:
	var tournament := SwissTournamentScript.new()
	tournament.setup("测试玩家", 575716, 16, 12345, true)
	return run_checks([
		assert_eq(float(tournament._llm_win_probability_against_mode("strong")), 0.60, "LLM 猛雷鼓遇到规则版强 AI 应按 60% 胜率模拟"),
		assert_eq(float(tournament._llm_win_probability_against_mode("weak")), 1.0, "LLM 猛雷鼓遇到弱 AI 应按 100% 胜率模拟"),
	])
