## GameState 单元测试
class_name TestGameState
extends TestBase


func _make_game_state() -> GameState:
	var gs := GameState.new()
	var p0 := PlayerState.new()
	p0.player_index = 0
	var p1 := PlayerState.new()
	p1.player_index = 1
	gs.players = [p0, p1]
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.turn_number = 1
	return gs


func test_initial_phase() -> String:
	var gs := GameState.new()
	return assert_eq(gs.phase, GameState.GamePhase.SETUP, "初始阶段为SETUP")


func test_get_current_player() -> String:
	var gs := _make_game_state()
	return assert_eq(gs.get_current_player().player_index, 0, "当前玩家0")


func test_get_opponent_player() -> String:
	var gs := _make_game_state()
	return assert_eq(gs.get_opponent_player().player_index, 1, "对手玩家1")


func test_get_player() -> String:
	var gs := _make_game_state()
	return run_checks([
		assert_eq(gs.get_player(0).player_index, 0, "玩家0"),
		assert_eq(gs.get_player(1).player_index, 1, "玩家1"),
	])


func test_is_first_turn_of_first_player() -> String:
	var gs := _make_game_state()
	return assert_true(gs.is_first_turn_of_first_player(), "第1回合先攻方")


func test_not_first_turn() -> String:
	var gs := _make_game_state()
	gs.turn_number = 2
	return assert_false(gs.is_first_turn_of_first_player(), "第2回合非首回合")


func test_not_first_player() -> String:
	var gs := _make_game_state()
	gs.current_player_index = 1
	return assert_false(gs.is_first_turn_of_first_player(), "后攻方非先攻首回合")


func test_reset_turn_flags() -> String:
	var gs := _make_game_state()
	gs.energy_attached_this_turn = true
	gs.supporter_used_this_turn = true
	gs.stadium_played_this_turn = true
	gs.retreat_used_this_turn = true
	gs.reset_turn_flags()
	return run_checks([
		assert_false(gs.energy_attached_this_turn, "能量重置"),
		assert_false(gs.supporter_used_this_turn, "支援者重置"),
		assert_false(gs.stadium_played_this_turn, "竞技场重置"),
		assert_false(gs.retreat_used_this_turn, "撤退重置"),
	])


func test_switch_player() -> String:
	var gs := _make_game_state()
	gs.switch_player()
	return assert_eq(gs.current_player_index, 1, "切换到玩家1")


func test_switch_player_back() -> String:
	var gs := _make_game_state()
	gs.switch_player()
	gs.switch_player()
	return assert_eq(gs.current_player_index, 0, "切换回玩家0")


func test_advance_turn_first_to_second() -> String:
	var gs := _make_game_state()
	# 先攻(0)回合结束 -> 切换到后攻(1)，turn_number 不变（因为回到先攻方才+1）
	gs.advance_turn()
	return run_checks([
		assert_eq(gs.current_player_index, 1, "切换到后攻"),
		assert_eq(gs.turn_number, 1, "回合数不变"),
		assert_false(gs.energy_attached_this_turn, "标志重置"),
	])


func test_advance_turn_second_to_first() -> String:
	var gs := _make_game_state()
	gs.advance_turn()  # 0->1
	gs.advance_turn()  # 1->0, turn_number+1
	return run_checks([
		assert_eq(gs.current_player_index, 0, "回到先攻"),
		assert_eq(gs.turn_number, 2, "回合数+1"),
	])


func test_advance_turn_full_cycle() -> String:
	var gs := _make_game_state()
	# 4次 advance: 0->1(T1) -> 0(T2) -> 1(T2) -> 0(T3)
	gs.advance_turn()
	gs.advance_turn()
	gs.advance_turn()
	gs.advance_turn()
	return run_checks([
		assert_eq(gs.current_player_index, 0, "玩家0"),
		assert_eq(gs.turn_number, 3, "第3回合"),
	])


func test_set_game_over() -> String:
	var gs := _make_game_state()
	gs.set_game_over(0, "对手牌库为空")
	return run_checks([
		assert_eq(gs.phase, GameState.GamePhase.GAME_OVER, "阶段为GAME_OVER"),
		assert_eq(gs.winner_index, 0, "胜者0"),
		assert_eq(gs.win_reason, "对手牌库为空", "胜因"),
		assert_true(gs.is_game_over(), "游戏结束"),
	])


func test_not_game_over() -> String:
	var gs := _make_game_state()
	return assert_false(gs.is_game_over(), "初始未结束")


func test_vstar_power_tracking() -> String:
	var gs := _make_game_state()
	return run_checks([
		assert_false(gs.vstar_power_used[0], "玩家0未用VSTAR"),
		assert_false(gs.vstar_power_used[1], "玩家1未用VSTAR"),
	])


func test_vstar_power_used() -> String:
	var gs := _make_game_state()
	gs.vstar_power_used[0] = true
	return run_checks([
		assert_true(gs.vstar_power_used[0], "玩家0已用VSTAR"),
		assert_false(gs.vstar_power_used[1], "玩家1未用VSTAR"),
	])


func test_stadium_card_initial() -> String:
	var gs := _make_game_state()
	return run_checks([
		assert_null(gs.stadium_card, "初始无竞技场"),
		assert_eq(gs.stadium_owner_index, -1, "初始无持有者"),
	])
