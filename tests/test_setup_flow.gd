## 准备阶段流程测试 - 验证 setup_place_active / bench / complete 的完整流程
class_name TestSetupFlow
extends TestBase


## 构建含有足够基础宝可梦的 GSM（绕过 CardDatabase）
func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.first_player_index = 0
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.SETUP

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		# 7张基础宝可梦手牌（模拟初始手牌已发完）
		for i: int in 7:
			var cd := CardData.new()
			cd.name = "宝可梦P%d_%d" % [pi, i]
			cd.card_type = "Pokemon"
			cd.stage = "Basic"
			cd.hp = 60 + i * 10
			cd.energy_type = "R"
			cd.retreat_cost = 1
			cd.attacks = [{"name": "撞击", "cost": "R", "damage": "10", "is_vstar_power": false}]
			var inst := CardInstance.create(cd, pi)
			inst.face_up = true
			player.hand.append(inst)
		# 剩余43张在牌库
		for i: int in 43:
			var cd := CardData.new()
			cd.name = "牌库宝可梦P%d_%d" % [pi, i]
			cd.card_type = "Pokemon"
			cd.stage = "Basic"
			cd.hp = 50
			cd.energy_type = "W"
			cd.retreat_cost = 0
			cd.attacks = []
			player.deck.append(CardInstance.create(cd, pi))
		gsm.game_state.players.append(player)
	return gsm


## 测试：玩家0放置战斗宝可梦后，active_pokemon 不为空
func test_setup_place_active_sets_active() -> String:
	var gsm := _make_gsm()
	var player0: PlayerState = gsm.game_state.players[0]
	var card: CardInstance = player0.hand[0]
	var initial_hand_size: int = player0.hand.size()

	var result: bool = gsm.setup_place_active_pokemon(0, card)
	return run_checks([
		assert_eq(result, true, "放置战斗宝可梦应返回 true"),
		assert_not_null(player0.active_pokemon, "active_pokemon 不应为 null"),
		assert_eq(player0.active_pokemon.get_pokemon_name(), card.card_data.name, "active pokemon 名称正确"),
		assert_eq(player0.hand.size(), initial_hand_size - 1, "手牌减少1张"),
	])


## 测试：放置战斗宝可梦后，_refresh_slot_label 能正确读取
func test_setup_active_slot_readable() -> String:
	var gsm := _make_gsm()
	var player0: PlayerState = gsm.game_state.players[0]
	var card: CardInstance = player0.hand[0]
	gsm.setup_place_active_pokemon(0, card)

	var slot: PokemonSlot = player0.active_pokemon
	return run_checks([
		assert_not_null(slot, "slot 不为 null"),
		assert_false(slot.pokemon_stack.is_empty(), "pokemon_stack 不为空"),
		assert_eq(slot.get_pokemon_name(), card.card_data.name, "get_pokemon_name 正确"),
		assert_eq(slot.get_max_hp(), card.card_data.hp, "get_max_hp 正确"),
		assert_eq(slot.get_remaining_hp(), card.card_data.hp, "get_remaining_hp 正确（无伤害）"),
	])


## 测试：玩家0放置备战宝可梦
func test_setup_place_bench() -> String:
	var gsm := _make_gsm()
	var player0: PlayerState = gsm.game_state.players[0]

	# 先放战斗宝可梦
	gsm.setup_place_active_pokemon(0, player0.hand[0])

	# 再放备战宝可梦
	var bench_card: CardInstance = player0.hand[0]  # hand[1] 变 hand[0] 因为已移除一张
	var result: bool = gsm.setup_place_bench_pokemon(0, bench_card)
	return run_checks([
		assert_eq(result, true, "放置备战宝可梦应返回 true"),
		assert_eq(player0.bench.size(), 1, "备战区有1只宝可梦"),
		assert_eq(player0.bench[0].get_pokemon_name(), bench_card.card_data.name, "备战宝可梦名称正确"),
	])


## 测试：setup_complete 在双方都有 active 时返回 true 并开始游戏
func test_setup_complete_starts_game() -> String:
	var gsm := _make_gsm()
	var p0: PlayerState = gsm.game_state.players[0]
	var p1: PlayerState = gsm.game_state.players[1]

	gsm.setup_place_active_pokemon(0, p0.hand[0])
	gsm.setup_place_active_pokemon(1, p1.hand[0])

	var result: bool = gsm.setup_complete(0)
	return run_checks([
		assert_eq(result, true, "setup_complete 应返回 true"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "阶段应进入 MAIN"),
		assert_eq(gsm.game_state.turn_number, 1, "回合数应为1"),
		assert_eq(p0.prizes.size(), 6, "玩家0奖赏卡6张"),
		assert_eq(p1.prizes.size(), 6, "玩家1奖赏卡6张"),
	])


## 测试：setup_complete 在只有一方有 active 时返回 false
func test_setup_complete_requires_both() -> String:
	var gsm := _make_gsm()
	var p0: PlayerState = gsm.game_state.players[0]

	gsm.setup_place_active_pokemon(0, p0.hand[0])
	# 玩家1没有放置

	var result: bool = gsm.setup_complete(0)
	return run_checks([
		assert_eq(result, false, "只有一方完成时 setup_complete 应返回 false"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.SETUP, "阶段仍为 SETUP"),
	])


## 测试：准备完成后战斗宝可梦翻面
func test_setup_complete_flips_cards_face_up() -> String:
	var gsm := _make_gsm()
	var p0: PlayerState = gsm.game_state.players[0]
	var p1: PlayerState = gsm.game_state.players[1]

	var card0: CardInstance = p0.hand[0]
	var card1: CardInstance = p1.hand[0]
	gsm.setup_place_active_pokemon(0, card0)
	gsm.setup_place_active_pokemon(1, card1)
	# 此时反面放置
	assert_eq(card0.face_up, false, "放置时反面")

	gsm.setup_complete(0)
	return run_checks([
		assert_eq(p0.active_pokemon.get_top_card().face_up, true, "setup_complete 后正面朝上"),
		assert_eq(p1.active_pokemon.get_top_card().face_up, true, "玩家1也正面朝上"),
	])


## 测试：主阶段可以放基础宝可梦到备战区
func test_play_basic_to_bench_in_main() -> String:
	var gsm := _make_gsm()
	var p0: PlayerState = gsm.game_state.players[0]
	var p1: PlayerState = gsm.game_state.players[1]

	# 完成准备阶段
	gsm.setup_place_active_pokemon(0, p0.hand[0])
	gsm.setup_place_active_pokemon(1, p1.hand[0])
	gsm.setup_complete(0)

	# 此时应在主阶段，current_player 为先攻方(0)
	var gs: GameState = gsm.game_state
	assert_eq(gs.phase, GameState.GamePhase.MAIN, "")

	var bench_card: CardInstance = p0.hand[0]
	var result: bool = gsm.play_basic_to_bench(0, bench_card)
	return run_checks([
		assert_eq(result, true, "主阶段可放备战宝可梦"),
		assert_eq(p0.bench.size(), 1, "备战区有1只宝可梦"),
	])


## 测试：非当前玩家无法放备战宝可梦
func test_play_basic_to_bench_wrong_player_fails() -> String:
	var gsm := _make_gsm()
	var p0: PlayerState = gsm.game_state.players[0]
	var p1: PlayerState = gsm.game_state.players[1]

	gsm.setup_place_active_pokemon(0, p0.hand[0])
	gsm.setup_place_active_pokemon(1, p1.hand[0])
	gsm.setup_complete(0)

	# 当前是玩家0的回合，玩家1尝试放备战宝可梦应失败
	var bench_card: CardInstance = p1.hand[0]
	var result: bool = gsm.play_basic_to_bench(1, bench_card)
	return run_checks([
		assert_eq(result, false, "非当前玩家不能放备战宝可梦"),
		assert_eq(p1.bench.size(), 0, "备战区仍为空"),
	])
