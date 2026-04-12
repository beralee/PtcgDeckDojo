## GameStateMachine tests
class_name TestGameStateMachine
extends TestBase

const AbilityAttachFromDeckEffect = preload("res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd")
const AttackSearchDeckToTopEffect = preload("res://scripts/effects/pokemon_effects/AttackSearchDeckToTop.gd")
const AttackBenchCountDamageEffect = preload("res://scripts/effects/pokemon_effects/AttackBenchCountDamage.gd")
const AttackGreninjaExMirageBarrageEffect = preload("res://scripts/effects/pokemon_effects/AttackGreninjaExMirageBarrage.gd")


class ScriptedRuleValidator extends RuleValidator:
	var scripted_results: Array[bool] = []
	var call_index: int = 0

	func _init(results: Array[bool] = []) -> void:
		scripted_results = results.duplicate()

	func has_basic_pokemon_in_hand(_player: PlayerState) -> bool:
		if call_index < scripted_results.size():
			var result := scripted_results[call_index]
			call_index += 1
			return result
		call_index += 1
		return true


class CountingCoinFlipper extends CoinFlipper:
	var next_result: bool = true
	var flip_calls: int = 0

	func _init(result: bool = true) -> void:
		next_result = result

	func flip() -> bool:
		flip_calls += 1
		coin_flipped.emit(next_result)
		return next_result

## 创建包含 60 张基础宝可梦的测试卡组数据
func _make_test_deck_data(deck_id: int) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = "测试卡组%d" % deck_id
	# Build a 60-card test deck without CardDatabase
	deck.cards = []
	var pokemon_types := ["R", "W", "G", "L", "P", "F"]
	for i: int in 60:
		deck.cards.append({
			"set_code": "TEST",
			"card_index": "%03d" % (i + 1),
			"count": 1,
			"card_type": "Pokemon",
			"name": "测试宝可梦%d" % i,
		})
	deck.total_cards = 60
	return deck


func _make_real_test_deck_data(deck_id: int, set_code: String = "CSV6C", card_index: String = "065") -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = "真实测试卡组%d" % deck_id
	deck.cards = [{
		"set_code": set_code,
		"card_index": card_index,
		"count": 60,
	}]
	deck.total_cards = 60
	return deck


func _make_basic_pokemon_card_data(name: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = 60
	cd.energy_type = "C"
	return cd


func _make_gsm_with_decks() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	# 直接注入 PlayerState 和牌库，绕过 DeckData -> CardDatabase 流程。
	gsm.game_state = GameState.new()
	gsm.game_state.first_player_index = 0
	gsm.game_state.current_player_index = 0

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi

		# 构建 60 张基础宝可梦的牌库。
		for i: int in 60:
			var cd := CardData.new()
			cd.name = "宝可梦%d" % i
			cd.card_type = "Pokemon"
			cd.stage = "Basic"
			cd.hp = 60
			cd.energy_type = "R"
			cd.retreat_cost = 1
			cd.attacks = [{"name": "招式", "cost": "R", "damage": "10", "is_vstar_power": false}]
			player.deck.append(CardInstance.create(cd, pi))

		player.shuffle_deck()
		gsm.game_state.players.append(player)

	return gsm


func test_gsm_instantiate() -> String:
	var gsm := GameStateMachine.new()
	return run_checks([
		assert_eq(gsm != null, true, "GameStateMachine should instantiate"),
		assert_eq(gsm.rule_validator != null, true, "RuleValidator should initialize"),
		assert_eq(gsm.damage_calculator != null, true, "DamageCalculator should initialize"),
		assert_eq(gsm.effect_processor != null, true, "EffectProcessor should initialize"),
		assert_eq(gsm.coin_flipper != null, true, "CoinFlipper should initialize"),
	])


func test_start_game_force_player0_first_skips_coin_flip() -> String:
	var gsm := GameStateMachine.new()
	var flipper := CountingCoinFlipper.new(false)
	gsm.coin_flipper = flipper
	gsm.effect_processor = EffectProcessor.new(flipper)

	var deck_1 := _make_real_test_deck_data(1, "CSV6C", "065")
	var deck_2 := _make_real_test_deck_data(2, "CSV1C", "060")
	gsm.start_game(deck_1, deck_2, 0)

	return run_checks([
		assert_eq(flipper.flip_calls, 0, "强制玩家1先攻时不应触发投硬币"),
		assert_eq(gsm.game_state.first_player_index, 0, "强制玩家1先攻时 first_player_index 应为 0"),
		assert_eq(gsm.game_state.current_player_index, 0, "强制玩家1先攻时 current_player_index 应为 0"),
	])


func test_start_game_random_first_uses_coin_flip() -> String:
	var gsm := GameStateMachine.new()
	var flipper := CountingCoinFlipper.new(false)
	gsm.coin_flipper = flipper
	gsm.effect_processor = EffectProcessor.new(flipper)

	var deck_1 := _make_real_test_deck_data(1, "CSV6C", "065")
	var deck_2 := _make_real_test_deck_data(2, "CSV1C", "060")
	gsm.start_game(deck_1, deck_2, -1)

	return run_checks([
		assert_eq(flipper.flip_calls, 1, "随机先后攻时应触发一次投硬币"),
		assert_eq(gsm.game_state.first_player_index, 1, "投币为反面时应由玩家2先攻"),
		assert_eq(gsm.game_state.current_player_index, 1, "随机决定玩家2先攻时 current_player_index 应同步为 1"),
	])


func test_draw_cards() -> String:
	var gsm := _make_gsm_with_decks()
	var player: PlayerState = gsm.game_state.players[0]
	var initial_deck_size: int = player.deck.size()

	var drawn: Array[CardInstance] = gsm.draw_card(0, 3)
	return run_checks([
		assert_eq(drawn.size(), 3, "Should draw 3 cards"),
		assert_eq(player.hand.size(), 3, "Hand should increase by 3"),
		assert_eq(player.deck.size(), initial_deck_size - 3, "Deck should decrease by 3"),
	])


func test_draw_card_action_includes_all_drawn_card_names() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	for card_name: String in ["Draw A", "Draw B", "Draw C", "Draw D", "Draw E", "Draw F", "Draw G"]:
		var cd := CardData.new()
		cd.name = card_name
		cd.card_type = "Pokemon"
		cd.stage = "Basic"
		cd.hp = 60
		cd.energy_type = "C"
		gsm.game_state.players[0].deck.append(CardInstance.create(cd, 0))

	var drawn: Array[CardInstance] = gsm.draw_card(0, 7)
	var draw_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)

	return run_checks([
		assert_eq(drawn.size(), 7, "Should draw 7 cards for metadata logging"),
		assert_not_null(draw_action, "Draw action should be logged"),
		assert_eq(draw_action.data.get("count", 0), 7, "Draw action count should stay correct"),
		assert_eq(
			draw_action.data.get("card_names", []),
			["Draw A", "Draw B", "Draw C", "Draw D", "Draw E", "Draw F", "Draw G"],
			"Draw action should record drawn card names in order"
		),
	])


func test_turn_start_draw_action_includes_drawn_card_names() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var top_cd := CardData.new()
	top_cd.name = "Turn Start Draw"
	top_cd.card_type = "Pokemon"
	top_cd.stage = "Basic"
	top_cd.hp = 60
	top_cd.energy_type = "C"
	gsm.game_state.players[1].deck = [CardInstance.create(top_cd, 1)]

	gsm._start_turn()
	var draw_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)

	return run_checks([
		assert_not_null(draw_action, "Turn-start draw should log a DRAW_CARD action"),
		assert_eq(draw_action.data.get("count", 0), 1, "Turn-start draw count should remain 1"),
		assert_eq(draw_action.data.get("card_names", []), ["Turn Start Draw"], "Turn-start draw should record the drawn card name"),
	])


func test_first_player_first_turn_skips_turn_start_draw() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var top_cd := CardData.new()
	top_cd.name = "Should Stay In Deck"
	top_cd.card_type = "Pokemon"
	top_cd.stage = "Basic"
	top_cd.hp = 60
	top_cd.energy_type = "C"
	gsm.game_state.players[0].deck = [CardInstance.create(top_cd, 0)]

	gsm._start_turn()
	var draw_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)

	return run_checks([
		assert_null(draw_action, "First player's first turn should not log a DRAW_CARD action"),
		assert_eq(gsm.game_state.players[0].hand.size(), 0, "First player's first turn should not add a card to hand"),
		assert_eq(gsm.game_state.players[0].deck.size(), 1, "First player's first turn should leave the deck unchanged"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "Skipping the draw should still advance into main phase"),
		assert_eq(gsm.game_state.turn_number, 1, "Turn number should still advance to the first turn"),
	])


func test_professors_research_play_trainer_logs_drawn_cards_for_reveal_animation() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var professor_cd := CardData.new()
	professor_cd.name = "Professor's Research"
	professor_cd.card_type = "Supporter"
	professor_cd.effect_id = "aecd80ca2722885c3d062a2255346f3e"
	var professor := CardInstance.create(professor_cd, 0)

	var filler_cd := CardData.new()
	filler_cd.name = "Discard Filler"
	filler_cd.card_type = "Pokemon"
	filler_cd.stage = "Basic"
	filler_cd.hp = 60
	filler_cd.energy_type = "C"
	var filler := CardInstance.create(filler_cd, 0)
	gsm.game_state.players[0].hand = [professor, filler]

	var expected_names: Array[String] = []
	for draw_index: int in 7:
		var deck_cd := CardData.new()
		deck_cd.name = "Research Draw %d" % [draw_index + 1]
		deck_cd.card_type = "Pokemon"
		deck_cd.stage = "Basic"
		deck_cd.hp = 60
		deck_cd.energy_type = "C"
		var deck_card := CardInstance.create(deck_cd, 0)
		expected_names.append(deck_cd.name)
		gsm.game_state.players[0].deck.append(deck_card)

	var played: bool = gsm.play_trainer(0, professor, [])
	var draw_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)
	var logged_count: int = int(draw_action.data.get("count", -1)) if draw_action != null else -1
	var logged_names: Array = draw_action.data.get("card_names", []) if draw_action != null else []

	return run_checks([
		assert_true(played, "Professor's Research should resolve successfully in main phase"),
		assert_not_null(draw_action, "Professor's Research should emit a DRAW_CARD action for reveal animation"),
		assert_eq(logged_count, 7, "Professor's Research should log a seven-card draw"),
		assert_eq(logged_names, expected_names, "Professor's Research should log the exact drawn card order"),
	])


func test_professors_research_logs_hand_discard_action_for_reveal_animation() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var professor_cd := CardData.new()
	professor_cd.name = "Professor's Research"
	professor_cd.card_type = "Supporter"
	professor_cd.effect_id = "aecd80ca2722885c3d062a2255346f3e"
	var professor := CardInstance.create(professor_cd, 0)
	var filler_a := CardInstance.create(_make_basic_pokemon_card_data("Discard A"), 0)
	var filler_b := CardInstance.create(_make_basic_pokemon_card_data("Discard B"), 0)
	gsm.game_state.players[0].hand = [professor, filler_a, filler_b]

	for draw_index: int in 7:
		gsm.game_state.players[0].deck.append(CardInstance.create(_make_basic_pokemon_card_data("Draw %d" % [draw_index + 1]), 0))

	var played: bool = gsm.play_trainer(0, professor, [])
	var discard_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DISCARD)

	return run_checks([
		assert_true(played, "Professor's Research should still resolve"),
		assert_not_null(discard_action, "Professor's Research should emit a DISCARD action for the hand cards"),
		assert_eq(discard_action.data.get("source_zone", ""), "hand", "Discard reveal should mark the cards as coming from hand"),
		assert_eq(discard_action.data.get("count", 0), 2, "Professor's Research should log the two discarded hand cards"),
		assert_eq(discard_action.data.get("card_names", []), ["Discard A", "Discard B"], "Professor's Research should log the discarded hand cards in order"),
	])


func test_ultra_ball_logs_hand_discard_action_for_reveal_animation() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 3

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var ultra_cd := CardData.new()
	ultra_cd.name = "Ultra Ball"
	ultra_cd.card_type = "Item"
	ultra_cd.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var ultra_ball := CardInstance.create(ultra_cd, 0)
	var discard_a := CardInstance.create(_make_basic_pokemon_card_data("Ultra Cost A"), 0)
	var discard_b := CardInstance.create(_make_basic_pokemon_card_data("Ultra Cost B"), 0)
	var target := CardInstance.create(_make_basic_pokemon_card_data("Search Target"), 0)
	gsm.game_state.players[0].hand = [ultra_ball, discard_a, discard_b]
	gsm.game_state.players[0].deck = [target]

	var played: bool = gsm.play_trainer(0, ultra_ball, [{"discard_cards": [discard_a, discard_b], "search_pokemon": [target]}])
	var discard_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DISCARD)

	return run_checks([
		assert_true(played, "Ultra Ball should still resolve"),
		assert_not_null(discard_action, "Ultra Ball should emit a DISCARD action for its paid hand cost"),
		assert_eq(discard_action.data.get("source_zone", ""), "hand", "Ultra Ball discard animation should be marked as hand-origin"),
		assert_eq(discard_action.data.get("count", 0), 2, "Ultra Ball should log both discarded cost cards"),
		assert_eq(discard_action.data.get("card_names", []), ["Ultra Cost A", "Ultra Cost B"], "Ultra Ball should preserve discard order in the reveal metadata"),
	])


func test_arven_logs_public_item_and_tool_names() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 3

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var arven_cd := CardData.new()
	arven_cd.name = "派帕"
	arven_cd.card_type = "Supporter"
	arven_cd.effect_id = "5bdbc985f9aa2e6f248b53f6f35d1d37"
	var arven := CardInstance.create(arven_cd, 0)
	gsm.game_state.players[0].hand = [arven]

	var item_cd := CardData.new()
	item_cd.name = "高级球"
	item_cd.card_type = "Item"
	var item_card := CardInstance.create(item_cd, 0)

	var tool_cd := CardData.new()
	tool_cd.name = "勇气护符"
	tool_cd.card_type = "Tool"
	var tool_card := CardInstance.create(tool_cd, 0)
	gsm.game_state.players[0].deck = [item_card, tool_card]

	var played: bool = gsm.play_trainer(0, arven, [{
		"search_item": [item_card],
		"search_tool": [tool_card],
	}])
	var reveal_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.PUBLIC_REVEAL)

	return run_checks([
		assert_true(played, "Arven should resolve successfully"),
		assert_not_null(reveal_action, "Arven should emit a PUBLIC_REVEAL action for the searched cards"),
		assert_eq(reveal_action.data.get("card_names", []), ["高级球", "勇气护符"], "Arven should log both revealed card names in order"),
		assert_eq(reveal_action.data.get("public_result_labels", []), ["物品", "宝可梦道具"], "Arven should record both public category labels"),
		assert_eq(reveal_action.description, "玩家1通过派帕公开加入手牌：物品「高级球」、宝可梦道具「勇气护符」", "Arven should show the revealed item and tool in readable Chinese"),
	])


func test_draw_cards_for_effect_logs_exact_drawn_card_names() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	for card_name: String in ["Effect Draw A", "Effect Draw B", "Effect Draw C"]:
		var cd := CardData.new()
		cd.name = card_name
		cd.card_type = "Pokemon"
		cd.stage = "Basic"
		cd.hp = 60
		cd.energy_type = "C"
		gsm.game_state.players[0].deck.append(CardInstance.create(cd, 0))

	var source_cd := CardData.new()
	source_cd.name = "Effect Source"
	source_cd.card_type = "Supporter"
	var source_card := CardInstance.create(source_cd, 0)

	var drawn: Array[CardInstance] = gsm.draw_cards_for_effect(0, 3, source_card, "trainer")
	var draw_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)

	return run_checks([
		assert_eq(drawn.size(), 3, "Shared effect draw helper should draw the requested cards"),
		assert_not_null(draw_action, "Shared effect draw helper should emit a DRAW_CARD action"),
		assert_eq(draw_action.data.get("count", 0), 3, "Shared effect draw helper should log the drawn count"),
		assert_eq(
			draw_action.data.get("card_names", []),
			["Effect Draw A", "Effect Draw B", "Effect Draw C"],
			"Shared effect draw helper should log the exact drawn card order"
		),
		assert_eq(draw_action.data.get("source_kind", ""), "trainer", "Shared effect draw helper should preserve source kind metadata"),
		assert_eq(draw_action.data.get("source_card_name", ""), "Effect Source", "Shared effect draw helper should preserve source card metadata"),
	])


func test_draw_cards_for_effect_uses_chinese_description() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	gsm.game_state.players[0].deck.append(CardInstance.create(_make_basic_pokemon_card_data("抽牌测试"), 0))

	var source_cd := CardData.new()
	source_cd.name = "测试来源"
	source_cd.card_type = "Supporter"
	var source_card := CardInstance.create(source_cd, 0)

	gsm.draw_cards_for_effect(0, 1, source_card, "trainer")
	var draw_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)

	return run_checks([
		assert_not_null(draw_action, "Shared effect draw helper should still log the draw action"),
		assert_eq(draw_action.description, "玩家1从牌库抽了1张牌", "Shared effect draw helper should use readable Chinese log copy"),
	])


func test_move_public_cards_to_hand_for_effect_logs_public_reveal() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var source_cd := CardData.new()
	source_cd.name = "高级球"
	source_cd.card_type = "Item"
	var source_card := CardInstance.create(source_cd, 0)

	var searched_card := CardInstance.create(_make_basic_pokemon_card_data("喷火龙ex"), 0)
	gsm.game_state.players[0].deck = [searched_card]

	var moved := gsm.move_public_cards_to_hand_for_effect(0, [searched_card], source_card, "trainer", "search_to_hand", ["宝可梦"])
	var reveal_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.PUBLIC_REVEAL)

	return run_checks([
		assert_eq(moved.size(), 1, "Public reveal helper should move the selected card to hand"),
		assert_not_null(reveal_action, "Public reveal helper should emit a PUBLIC_REVEAL action"),
		assert_eq(reveal_action.data.get("card_names", []), ["喷火龙ex"], "Public reveal helper should record the revealed card name"),
		assert_eq(reveal_action.data.get("public_result_labels", []), ["宝可梦"], "Public reveal helper should preserve the public label"),
		assert_eq(reveal_action.description, "玩家1通过高级球公开加入手牌：宝可梦「喷火龙ex」", "Public reveal helper should produce readable Chinese summary copy"),
	])


func test_draw_cards_for_effect_skips_draw_log_when_count_is_zero() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var source_cd := CardData.new()
	source_cd.name = "Zero Source"
	source_cd.card_type = "Supporter"
	var source_card := CardInstance.create(source_cd, 0)
	var initial_log_size := gsm.action_log.size()
	var drawn: Array[CardInstance] = gsm.draw_cards_for_effect(0, 0, source_card, "trainer")
	var draw_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)

	return run_checks([
		assert_eq(drawn.size(), 0, "Shared effect draw helper should no-op for zero-card draws"),
		assert_eq(gsm.action_log.size(), initial_log_size, "Shared effect draw helper should not append a DRAW_CARD action for zero-card draws"),
		assert_null(draw_action, "No DRAW_CARD action should exist after a zero-card effect draw"),
	])


func test_iono_play_trainer_logs_draw_card_actions_for_both_players() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var iono_cd := CardData.new()
	iono_cd.name = "Iono"
	iono_cd.card_type = "Supporter"
	iono_cd.effect_id = "af514f82d182aeae5327b2c360df703d"
	var iono := CardInstance.create(iono_cd, 0)
	gsm.game_state.players[0].hand = [iono]
	gsm.game_state.players[0].prizes.resize(4)
	gsm.game_state.players[1].prizes.resize(3)

	for idx: int in 6:
		var player_cd := CardData.new()
		player_cd.name = "Iono Player Deck %d" % [idx + 1]
		player_cd.card_type = "Pokemon"
		player_cd.stage = "Basic"
		player_cd.hp = 60
		player_cd.energy_type = "C"
		gsm.game_state.players[0].deck.append(CardInstance.create(player_cd, 0))

	for idx: int in 5:
		var opponent_cd := CardData.new()
		opponent_cd.name = "Iono Opponent Deck %d" % [idx + 1]
		opponent_cd.card_type = "Pokemon"
		opponent_cd.stage = "Basic"
		opponent_cd.hp = 60
		opponent_cd.energy_type = "C"
		gsm.game_state.players[1].deck.append(CardInstance.create(opponent_cd, 1))

	var played: bool = gsm.play_trainer(0, iono, [])
	var draw_actions: Array[GameAction] = _get_actions_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)
	var first_draw: GameAction = draw_actions[0] if draw_actions.size() > 0 else null
	var second_draw: GameAction = draw_actions[1] if draw_actions.size() > 1 else null

	return run_checks([
		assert_true(played, "Iono should resolve successfully in main phase"),
		assert_eq(draw_actions.size(), 2, "Iono should log one DRAW_CARD action for each player"),
		assert_eq(first_draw.player_index if first_draw != null else -1, 0, "The user's Iono draw should be logged first"),
		assert_eq(second_draw.player_index if second_draw != null else -1, 1, "The opponent's Iono draw should also be logged"),
		assert_eq(int(first_draw.data.get("count", -1)) if first_draw != null else -1, 4, "Iono should log the user's prize-count draw"),
		assert_eq(int(second_draw.data.get("count", -1)) if second_draw != null else -1, 3, "Iono should log the opponent's prize-count draw"),
		assert_eq((first_draw.data.get("card_names", []) as Array).size() if first_draw != null else -1, 4, "Iono should include reveal metadata for the user's draw"),
		assert_eq((second_draw.data.get("card_names", []) as Array).size() if second_draw != null else -1, 3, "Iono should include reveal metadata for the opponent's draw"),
	])


func test_trekking_shoes_discard_branch_logs_reveal_draw() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var shoes_cd := CardData.new()
	shoes_cd.name = "Trekking Shoes"
	shoes_cd.card_type = "Item"
	shoes_cd.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
	var shoes := CardInstance.create(shoes_cd, 0)
	gsm.game_state.players[0].hand = [shoes]

	var top_cd := CardData.new()
	top_cd.name = "Top Card"
	top_cd.card_type = "Pokemon"
	top_cd.stage = "Basic"
	top_cd.hp = 60
	top_cd.energy_type = "C"
	var draw_cd := CardData.new()
	draw_cd.name = "Draw After Discard"
	draw_cd.card_type = "Pokemon"
	draw_cd.stage = "Basic"
	draw_cd.hp = 60
	draw_cd.energy_type = "C"
	gsm.game_state.players[0].deck = [
		CardInstance.create(top_cd, 0),
		CardInstance.create(draw_cd, 0),
	]

	var played: bool = gsm.play_trainer(0, shoes, [{"trekking_choice": ["discard"]}])
	var draw_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)

	return run_checks([
		assert_true(played, "Trekking Shoes should resolve when the deck is not empty"),
		assert_not_null(draw_action, "Discarding the top card with Trekking Shoes should log the replacement draw"),
		assert_eq(int(draw_action.data.get("count", -1)) if draw_action != null else -1, 1, "Trekking Shoes replacement draw should log one card"),
		assert_eq(draw_action.data.get("card_names", []) if draw_action != null else [], ["Draw After Discard"], "Trekking Shoes should log the exact replacement draw card"),
	])


func test_gift_energy_knockout_logs_exact_drawn_cards_for_reveal() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var knocked_out_player: PlayerState = gsm.game_state.players[1]
	var active_cd := CardData.new()
	active_cd.name = "Gift Holder"
	active_cd.card_type = "Pokemon"
	active_cd.stage = "Basic"
	active_cd.hp = 120
	active_cd.energy_type = "C"
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 1))
	active_slot.damage_counters = 999

	var gift_cd := CardData.new()
	gift_cd.name = "Gift Energy"
	gift_cd.card_type = "Special Energy"
	gift_cd.energy_provides = "C"
	gift_cd.effect_id = "dbb3f3d2ef2f3372bc8b21336e6c9bc6"
	active_slot.attached_energy.append(CardInstance.create(gift_cd, 1))
	knocked_out_player.active_pokemon = active_slot

	for idx: int in 4:
		var draw_cd := CardData.new()
		draw_cd.name = "Gift Draw %d" % [idx + 1]
		draw_cd.card_type = "Pokemon"
		draw_cd.stage = "Basic"
		draw_cd.hp = 60
		draw_cd.energy_type = "C"
		knocked_out_player.deck.append(CardInstance.create(draw_cd, 1))

	var resolved: bool = gsm._finalize_knockout(1, active_slot, true)
	var draw_action := _get_last_action_of_type(gsm.action_log, GameAction.ActionType.DRAW_CARD)

	return run_checks([
		assert_true(resolved, "Gift Energy knockout fixture should resolve"),
		assert_not_null(draw_action, "Gift Energy should emit a DRAW_CARD action for reveal"),
		assert_eq(int(draw_action.data.get("count", -1)) if draw_action != null else -1, 4, "Gift Energy should log the exact number drawn up to seven cards in hand"),
		assert_eq(draw_action.data.get("card_names", []) if draw_action != null else [], ["Gift Draw 1", "Gift Draw 2", "Gift Draw 3", "Gift Draw 4"], "Gift Energy should log the exact drawn card order"),
	])


func test_both_players_mulligan_do_not_redraw_initial_hands_twice() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.rule_validator = ScriptedRuleValidator.new([false, false, true, true])

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for i: int in 7:
			var hand_cd := CardData.new()
			hand_cd.name = "Opening%d_%d" % [pi, i]
			hand_cd.card_type = "Item"
			player.hand.append(CardInstance.create(hand_cd, pi))
		for i: int in 7:
			var deck_cd := CardData.new()
			deck_cd.name = "Deck%d_%d" % [pi, i]
			deck_cd.card_type = "Pokemon"
			deck_cd.stage = "Basic"
			deck_cd.hp = 60
			player.deck.append(CardInstance.create(deck_cd, pi))
		gsm.game_state.players.append(player)

	gsm._check_mulligan()

	return run_checks([
		assert_eq(gsm.game_state.players[0].hand.size(), 7, "Player 0 should end mulligan with 7 cards"),
		assert_eq(gsm.game_state.players[1].hand.size(), 7, "Player 1 should end mulligan with 7 cards"),
		assert_eq(gsm.game_state.players[0].deck.size(), 7, "Player 0 deck should not double-draw"),
		assert_eq(gsm.game_state.players[1].deck.size(), 7, "Player 1 deck should not double-draw"),
	])


func test_both_players_impossible_mulligan_stops_without_recursion() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for i: int in 7:
			var hand_cd := CardData.new()
			hand_cd.name = "Opening%d_%d" % [pi, i]
			hand_cd.card_type = "Item"
			player.hand.append(CardInstance.create(hand_cd, pi))
		for i: int in 7:
			var deck_cd := CardData.new()
			deck_cd.name = "Deck%d_%d" % [pi, i]
			deck_cd.card_type = "Supporter"
			player.deck.append(CardInstance.create(deck_cd, pi))
		gsm.game_state.players.append(player)

	gsm._check_mulligan()

	return run_checks([
		assert_eq(gsm.game_state.phase, GameState.GamePhase.GAME_OVER, "双方都不可能抽到基础宝可梦时应终止无效开局"),
		assert_eq(gsm.game_state.winner_index, -1, "双方都无基础宝可梦时不应强行指定胜者"),
		assert_str_contains(gsm.game_state.win_reason, "无基础宝可梦", "应记录无法完成 Mulligan 的原因"),
	])


func test_play_basic_to_bench() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[0]
	# Give the player one Basic Pokemon from the deck.
	var card: CardInstance = player.deck.pop_back()
	player.hand.append(card)
	# Set up the active Pokemon directly to avoid bench-capacity checks.
	var active_cd := CardData.new()
	active_cd.card_type = "Pokemon"
	active_cd.stage = "Basic"
	active_cd.hp = 60
	active_cd.energy_type = "R"
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))
	player.active_pokemon = active_slot

	var result: bool = gsm.play_basic_to_bench(0, card)
	return run_checks([
		assert_eq(result, true, "Bench placement should succeed"),
		assert_eq(player.bench.size(), 1, "Bench should contain 1 Pokemon"),
		assert_eq(player.hand.size(), 0, "鎵嬬墝鍑忓皯"),
	])


func test_play_basic_to_bench_respects_collapsed_stadium_limit() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	var stadium_cd := CardData.new()
	stadium_cd.name = "Collapsed Stadium"
	stadium_cd.card_type = "Stadium"
	stadium_cd.effect_id = "fb3628071280487676f79281696ffbd9"
	var stadium := CardInstance.create(stadium_cd, 0)
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 0

	var active_cd := CardData.new()
	active_cd.card_type = "Pokemon"
	active_cd.stage = "Basic"
	active_cd.hp = 60
	active_cd.energy_type = "R"
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))
	player.active_pokemon = active_slot

	player.bench.clear()
	for i: int in 4:
		var bench_cd := CardData.new()
		bench_cd.name = "Bench%d" % i
		bench_cd.card_type = "Pokemon"
		bench_cd.stage = "Basic"
		bench_cd.hp = 60
		bench_cd.energy_type = "R"
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
		player.bench.append(bench_slot)

	var card: CardInstance = player.deck.pop_back()
	player.hand.append(card)
	var result: bool = gsm.play_basic_to_bench(0, card)

	return run_checks([
		assert_false(result, "Collapsed Stadium在场时，第5只基础宝可梦不应能直接放到备战区"),
		assert_eq(player.bench.size(), 4, "Collapsed Stadium在场时备战区应保持4只"),
		assert_true(card in player.hand, "放置失败时卡牌应留在手牌"),
	])


func test_play_basic_to_bench_triggers_bench_enter_ability() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()

	var active_cd := CardData.new()
	active_cd.name = "Active"
	active_cd.card_type = "Pokemon"
	active_cd.stage = "Basic"
	active_cd.hp = 70
	active_cd.energy_type = "W"
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))
	player.active_pokemon = active_slot

	var supporter_cd := CardData.new()
	supporter_cd.name = "Supporter"
	supporter_cd.card_type = "Supporter"
	player.deck.append(CardInstance.create(supporter_cd, 0))
	player.deck.append(CardInstance.create(active_cd, 0))

	var lumineon_cd := CardData.new()
	lumineon_cd.name = "Lumineon"
	lumineon_cd.card_type = "Pokemon"
	lumineon_cd.stage = "Basic"
	lumineon_cd.hp = 120
	lumineon_cd.energy_type = "W"
	lumineon_cd.effect_id = "lumineon_test"
	lumineon_cd.abilities = [{"name": "Luminous Sign", "text": ""}]
	gsm.effect_processor.register_effect("lumineon_test", AbilityOnBenchEnter.new("search_supporter"))
	var lumineon := CardInstance.create(lumineon_cd, 0)
	player.hand.append(lumineon)

	var result: bool = gsm.play_basic_to_bench(0, lumineon)
	return run_checks([
		assert_eq(result, true, "Lumineon V should bench successfully"),
		assert_eq(player.bench.size(), 1, "Lumineon V should enter the bench"),
		assert_true(player.hand.any(func(card: CardInstance) -> bool: return card.card_data.card_type == "Supporter"), "Luminous Sign should add a Supporter to hand"),
	])


func test_attach_energy() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[0]

	var poke_cd := CardData.new()
	poke_cd.card_type = "Pokemon"
	poke_cd.stage = "Basic"
	poke_cd.hp = 60
	poke_cd.energy_type = "R"
	CardInstance.reset_id_counter()
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(poke_cd, 0))
	player.active_pokemon = active_slot

	var e_cd := CardData.new()
	e_cd.card_type = "Basic Energy"
	e_cd.energy_provides = "R"
	var energy := CardInstance.create(e_cd, 0)
	player.hand.append(energy)

	var result: bool = gsm.attach_energy(0, energy, active_slot)
	return run_checks([
		assert_eq(result, true, "闄勭潃鑳介噺鎴愬姛"),
		assert_eq(active_slot.attached_energy.size(), 1, "Pokemon should have one attached Energy"),
		assert_eq(player.hand.size(), 0, "鎵嬬墝鍑忓皯"),
		assert_eq(gsm.game_state.energy_attached_this_turn, true, "Energy attachment flag should be set"),
	])


func test_attach_energy_twice_fails() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.energy_attached_this_turn = true  # already attached this turn
	var player: PlayerState = gsm.game_state.players[0]

	var poke_cd := CardData.new()
	poke_cd.card_type = "Pokemon"
	poke_cd.stage = "Basic"
	poke_cd.hp = 60
	CardInstance.reset_id_counter()
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(poke_cd, 0))
	player.active_pokemon = active_slot

	var e_cd := CardData.new()
	e_cd.card_type = "Basic Energy"
	e_cd.energy_provides = "R"
	var energy := CardInstance.create(e_cd, 0)
	player.hand.append(energy)

	var result: bool = gsm.attach_energy(0, energy, active_slot)
	return run_checks([
		assert_eq(result, false, "Second energy attachment should fail"),
	])


func test_retreat() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[0]
	CardInstance.reset_id_counter()

	var active_cd := CardData.new()
	active_cd.card_type = "Pokemon"
	active_cd.stage = "Basic"
	active_cd.hp = 60
	active_cd.energy_type = "R"
	active_cd.retreat_cost = 1
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))

	var e_cd := CardData.new()
	e_cd.card_type = "Basic Energy"
	e_cd.energy_provides = "R"
	var energy := CardInstance.create(e_cd, 0)
	active_slot.attached_energy.append(energy)
	player.active_pokemon = active_slot

	# Bench Pokemon
	var bench_cd := CardData.new()
	bench_cd.card_type = "Pokemon"
	bench_cd.stage = "Basic"
	bench_cd.hp = 80
	bench_cd.energy_type = "W"
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
	player.bench.append(bench_slot)

	var energy_to_discard: Array[CardInstance] = [energy]
	var result: bool = gsm.retreat(0, energy_to_discard, bench_slot)
	return run_checks([
		assert_eq(result, true, "Retreat should succeed"),
		assert_eq(player.active_pokemon == bench_slot, true, "Bench Pokemon should become the active Pokemon"),
		assert_eq(player.bench.size(), 1, "Former active should move to the bench"),
		assert_eq(player.discard_pile.size(), 1, "Discarded Energy should enter discard pile"),
		assert_eq(gsm.game_state.retreat_used_this_turn, true, "Retreat flag should be set"),
	])


func test_retreat_uses_effective_cost_modifier() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[0]
	CardInstance.reset_id_counter()

	var active_cd := CardData.new()
	active_cd.name = "怒鹦哥ex"
	active_cd.card_type = "Pokemon"
	active_cd.stage = "Basic"
	active_cd.hp = 160
	active_cd.energy_type = "C"
	active_cd.retreat_cost = 1
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))

	var tool_cd := CardData.new()
	tool_cd.name = "Emergency Board"
	tool_cd.card_type = "Tool"
	tool_cd.effect_id = "0b4cc131a19862f92acf71494f29a0ed"
	active_slot.attached_tool = CardInstance.create(tool_cd, 0)
	player.active_pokemon = active_slot

	var bench_cd := CardData.new()
	bench_cd.name = "Bench"
	bench_cd.card_type = "Pokemon"
	bench_cd.stage = "Basic"
	bench_cd.hp = 70
	bench_cd.energy_type = "W"
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
	player.bench.append(bench_slot)

	var result: bool = gsm.retreat(0, [], bench_slot)
	return run_checks([
		assert_eq(gsm.effect_processor.get_effective_retreat_cost(active_slot, gsm.game_state), 0, "Emergency Board should reduce the retreat cost to 0"),
		assert_eq(result, true, "Zero-cost retreat should succeed"),
		assert_eq(player.active_pokemon, bench_slot, "Bench Pokemon should become active"),
		assert_eq(player.discard_pile.size(), 0, "A retreat with cost 0 should not discard Energy"),
	])


func test_dreepy_rescue_board_allows_zero_cost_retreat_after_attachment() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.discard_pile.clear()

	var dreepy_cd: CardData = CardDatabase.get_card("CSV8C", "157")
	var rescue_board_cd: CardData = CardDatabase.get_card("CSV7C", "185")

	var active_slot := PokemonSlot.new()
	if dreepy_cd != null:
		active_slot.pokemon_stack.append(CardInstance.create(dreepy_cd, 0))
	player.active_pokemon = active_slot

	var bench_cd := CardData.new()
	bench_cd.name = "Bench"
	bench_cd.card_type = "Pokemon"
	bench_cd.stage = "Basic"
	bench_cd.hp = 70
	bench_cd.energy_type = "P"
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
	player.bench = [bench_slot]

	var rescue_board: CardInstance = null
	if rescue_board_cd != null:
		rescue_board = CardInstance.create(rescue_board_cd, 0)
		player.hand.append(rescue_board)

	var attached: bool = gsm.attach_tool(0, rescue_board, active_slot) if rescue_board != null else false
	var retreat_cost: int = gsm.effect_processor.get_effective_retreat_cost(active_slot, gsm.game_state)
	var retreated: bool = gsm.retreat(0, [], bench_slot)

	return run_checks([
		assert_not_null(dreepy_cd, "CSV8C_157 Dreepy should exist in the card database"),
		assert_not_null(rescue_board_cd, "CSV7C_185 Rescue Board should exist in the card database"),
		assert_true(attached, "Rescue Board should attach to Dreepy through the normal tool attachment flow"),
		assert_eq(retreat_cost, 0, "Rescue Board should reduce Dreepy's retreat cost from 1 to 0"),
		assert_true(retreated, "Dreepy should be able to retreat for free after Rescue Board attaches"),
		assert_eq(player.active_pokemon, bench_slot, "The selected Benched Pokemon should become Active after the retreat"),
		assert_true(active_slot in player.bench, "The former Active Dreepy should move to the Bench after retreating"),
		assert_eq(active_slot.attached_tool, rescue_board, "Rescue Board should remain attached to Dreepy after it retreats"),
		assert_eq(player.discard_pile.size(), 0, "A zero-cost Rescue Board retreat should not discard any cards"),
	])


func test_retreat_accepts_double_turbo_as_two_energy_units() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	var player: PlayerState = gsm.game_state.players[0]
	CardInstance.reset_id_counter()

	var active_cd := CardData.new()
	active_cd.name = "Double Turbo Runner"
	active_cd.card_type = "Pokemon"
	active_cd.stage = "Basic"
	active_cd.hp = 80
	active_cd.energy_type = "C"
	active_cd.retreat_cost = 2
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))

	var dte_cd := CardData.new()
	dte_cd.name = "Double Turbo Energy"
	dte_cd.card_type = "Special Energy"
	dte_cd.energy_provides = "C"
	dte_cd.effect_id = "9c04dd0addf56a7b2c88476bc8e45c0e"
	var dte := CardInstance.create(dte_cd, 0)
	active_slot.attached_energy.append(dte)
	player.active_pokemon = active_slot

	var bench_cd := CardData.new()
	bench_cd.name = "Bench"
	bench_cd.card_type = "Pokemon"
	bench_cd.stage = "Basic"
	bench_cd.hp = 70
	bench_cd.energy_type = "W"
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
	player.bench.append(bench_slot)

	var result: bool = gsm.retreat(0, [dte], bench_slot)
	return run_checks([
		assert_eq(result, true, "Double Turbo Energy should pay a retreat cost of 2"),
		assert_eq(player.active_pokemon, bench_slot, "Retreat should complete successfully"),
		assert_eq(player.discard_pile.size(), 1, "Only 1 Double Turbo Energy should be discarded"),
	])


func test_forest_seal_stone_grants_search_ability_to_attached_v() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()

	var attacker_cd := CardData.new()
	attacker_cd.name = "Raikou V"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 200
	attacker_cd.energy_type = "L"
	attacker_cd.mechanic = "V"
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	player.active_pokemon = attacker_slot

	var search_target := CardInstance.create(_make_test_energy("L"), 0)
	player.deck.append(search_target)
	player.deck.append(CardInstance.create(_make_test_energy("R"), 0))

	var tool_cd := CardData.new()
	tool_cd.name = "Forest Seal Stone"
	tool_cd.card_type = "Tool"
	tool_cd.effect_id = AbilityVSTARSearch.FOREST_SEAL_EFFECT_ID
	attacker_slot.attached_tool = CardInstance.create(tool_cd, 0)

	var granted_entries: Array[Dictionary] = gsm.effect_processor.get_granted_abilities(attacker_slot, gsm.game_state)
	var source_card: CardInstance = gsm.effect_processor.get_ability_source_card(attacker_slot, 0, gsm.game_state)
	var result: bool = gsm.use_ability(0, attacker_slot, 0, [{
		"search_cards": [search_target],
	}])

	return run_checks([
		assert_eq(granted_entries.size(), 1, "Forest Seal Stone should grant one usable ability"),
		assert_eq(source_card, attacker_slot.attached_tool, "Granted ability source should be the attached tool"),
		assert_eq(result, true, "Granted ability should be usable"),
		assert_true(search_target in player.hand, "Granted ability should add the chosen card to hand"),
		assert_true(gsm.game_state.vstar_power_used[0], "Forest Seal Stone should consume the player's VSTAR power"),
	])


func test_use_attack_passes_interaction_context_to_attack_effects() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	player.deck.clear()

	var chosen_top := CardInstance.create(_make_test_energy("M"), 0)
	var filler_a := CardInstance.create(_make_test_energy("R"), 0)
	var filler_b := CardInstance.create(_make_test_energy("W"), 0)
	player.deck.append(filler_a)
	player.deck.append(chosen_top)
	player.deck.append(filler_b)

	var attacker_cd := CardData.new()
	attacker_cd.name = "Beldum"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 70
	attacker_cd.energy_type = "M"
	attacker_cd.effect_id = "beldum_test"
	attacker_cd.attacks = [{"name": "Magnetic Lift", "cost": "C", "damage": "", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy("M"), 0))
	player.active_pokemon = attacker_slot
	gsm.effect_processor.register_attack_effect("beldum_test", AttackSearchDeckToTopEffect.new(1))

	var defender_cd := CardData.new()
	defender_cd.name = "Dummy"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 80
	defender_cd.energy_type = "C"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var result: bool = gsm.use_attack(0, 0, [{
		"search_cards": [chosen_top],
	}])
	return run_checks([
		assert_eq(result, true, "Magnetic Lift should execute successfully"),
		assert_eq(player.deck[0], chosen_top, "Selected card should move to the top of the deck"),
	])


func test_use_attack_deals_damage_and_advances_turn() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var attacker_cd := CardData.new()
	attacker_cd.name = "Attacker"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 110
	attacker_cd.energy_type = "L"
	attacker_cd.attacks = [{"name": "Quick Bolt", "cost": "C", "damage": "40", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))

	var lightning_cd := CardData.new()
	lightning_cd.card_type = "Basic Energy"
	lightning_cd.energy_provides = "L"
	attacker_slot.attached_energy.append(CardInstance.create(lightning_cd, 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Defender"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 100
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	gsm.game_state.players[1].deck.append(CardInstance.create(defender_cd, 1))
	for pi: int in 2:
		for i: int in 2:
			gsm.game_state.players[pi].prizes.append(CardInstance.create(defender_cd, pi))

	var result: bool = gsm.use_attack(0, 0)
	return run_checks([
		assert_eq(result, true, "Attack should be usable with enough Energy"),
		assert_eq(defender_slot.damage_counters, 40, "Attack should deal damage to the defender"),
		assert_eq(gsm.game_state.current_player_index, 1, "Turn should pass to the opponent after attacking"),
		assert_eq(gsm.game_state.turn_number, 3, "Attack should advance the turn"),
	])


func test_use_ability_end_turn_draw_advances_turn() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()

	var rotom_cd := CardData.new()
	rotom_cd.name = "Rotom V"
	rotom_cd.card_type = "Pokemon"
	rotom_cd.stage = "Basic"
	rotom_cd.hp = 190
	rotom_cd.energy_type = "L"
	rotom_cd.mechanic = "V"
	rotom_cd.effect_id = "rotom_v_end_turn_draw_test"
	rotom_cd.abilities = [{"name": "Instant Charge", "text": ""}]
	var rotom_slot := PokemonSlot.new()
	rotom_slot.pokemon_stack.append(CardInstance.create(rotom_cd, 0))
	player.active_pokemon = rotom_slot
	gsm.effect_processor.register_effect(rotom_cd.effect_id, AbilityEndTurnDraw.new(3))

	for i: int in 4:
		player.deck.append(CardInstance.create(_make_test_energy("L"), 0))

	var opponent_cd := CardData.new()
	opponent_cd.name = "Opponent"
	opponent_cd.card_type = "Pokemon"
	opponent_cd.stage = "Basic"
	opponent_cd.hp = 80
	opponent_cd.energy_type = "W"
	var opponent_slot := PokemonSlot.new()
	opponent_slot.pokemon_stack.append(CardInstance.create(opponent_cd, 1))
	gsm.game_state.players[1].active_pokemon = opponent_slot
	gsm.game_state.players[1].deck.append(CardInstance.create(_make_test_energy("W"), 1))
	for pi: int in 2:
		for i: int in 2:
			gsm.game_state.players[pi].prizes.append(CardInstance.create(opponent_cd, pi))

	var result: bool = gsm.use_ability(0, rotom_slot, 0)
	return run_checks([
		assert_eq(result, true, "End-turn draw ability should execute successfully"),
		assert_eq(player.hand.size(), 3, "End-turn draw ability should draw three cards"),
		assert_eq(gsm.game_state.current_player_index, 1, "Turn should pass to the opponent after the ability resolves"),
		assert_eq(gsm.game_state.turn_number, 3, "Using the ability should advance to the next turn"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "Opponent turn should enter the main phase"),
		assert_eq(gsm.game_state.players[1].hand.size(), 1, "Opponent should take the normal start-of-turn draw"),
	])


func test_can_use_attack_counts_special_energy_provided_energy() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0

	var attacker_cd := CardData.new()
	attacker_cd.name = "Special Energy User"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 120
	attacker_cd.energy_type = "C"
	attacker_cd.attacks = [{"name": "Twin Cost", "cost": "CC", "damage": "20", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))

	var double_cd := CardData.new()
	double_cd.name = "Double Turbo Energy"
	double_cd.card_type = "Special Energy"
	double_cd.energy_provides = "C"
	double_cd.effect_id = "9c04dd0addf56a7b2c88476bc8e45c0e"
	attacker_slot.attached_energy.append(CardInstance.create(double_cd, 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Bench Dummy"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 60
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	return run_checks([
		assert_eq(gsm.can_use_attack(0, 0), true, "Special Energy providing 2 Colorless should satisfy the CC cost"),
		assert_eq(gsm.get_attack_unusable_reason(0, 0), "", "Satisfied attack costs should not report a reason"),
	])


func test_knockout_replace_advances_after_send_out() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var attacker_cd := CardData.new()
	attacker_cd.name = "Finisher"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 120
	attacker_cd.energy_type = "R"
	attacker_cd.attacks = [{"name": "KO", "cost": "C", "damage": "200", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy("R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Victim"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 80
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].bench.append(bench_slot)
	gsm.game_state.players[1].deck.append(CardInstance.create(defender_cd, 1))
	for pi: int in 2:
		for i: int in 2:
			gsm.game_state.players[pi].prizes.append(CardInstance.create(defender_cd, pi))

	var attacked: bool = gsm.use_attack(0, 0)
	var take_prize_result: bool = gsm.resolve_take_prize(0, 0)
	var send_out_result: bool = gsm.send_out_pokemon(1, bench_slot)
	return run_checks([
		assert_eq(attacked, true, "Knockout attack should resolve successfully"),
		assert_eq(take_prize_result, true, "Knockout flow should pause for manual prize selection before replacement"),
		assert_eq(gsm.game_state.current_player_index, 1, "After replacement, the defending player should take the next turn"),
		assert_eq(send_out_result, true, "Defending player should be able to send out a replacement"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "After replacement the phase should return to MAIN"),
	])


func test_heavy_baton_transfers_basic_energy_before_knockout_discard() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	var heavy_baton_choices: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		if choice_type == "heavy_baton_target":
			heavy_baton_choices.append(data)
	)

	var attacker_cd := CardData.new()
	attacker_cd.name = "Finisher"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 120
	attacker_cd.energy_type = "R"
	attacker_cd.attacks = [{"name": "KO", "cost": "C", "damage": "200", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy("R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Heavy Baton Target"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 180
	defender_cd.energy_type = "F"
	defender_cd.retreat_cost = 4
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))

	var tool_cd := CardData.new()
	tool_cd.name = "Heavy Baton"
	tool_cd.card_type = "Tool"
	tool_cd.effect_id = "heavy_baton_test"
	defender_slot.attached_tool = CardInstance.create(tool_cd, 1)

	for energy_type: String in ["F", "F", "F", "F"]:
		defender_slot.attached_energy.append(CardInstance.create(_make_test_energy(energy_type), 1))
	gsm.effect_processor.register_effect("heavy_baton_test", EffectToolHeavyBaton.new())
	gsm.game_state.players[1].active_pokemon = defender_slot

	var bench_cd := CardData.new()
	bench_cd.name = "Bench Receiver"
	bench_cd.card_type = "Pokemon"
	bench_cd.stage = "Basic"
	bench_cd.hp = 90
	bench_cd.energy_type = "F"
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 1))
	gsm.game_state.players[1].bench.append(bench_slot)

	var second_bench_slot := PokemonSlot.new()
	second_bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 1))
	gsm.game_state.players[1].bench.append(second_bench_slot)
	gsm.game_state.players[1].deck.append(CardInstance.create(bench_cd, 1))

	for pi: int in 2:
		for i: int in 2:
			gsm.game_state.players[pi].prizes.append(CardInstance.create(bench_cd, pi))

	var attacked: bool = gsm.use_attack(0, 0)
	var heavy_baton_choice: Dictionary = heavy_baton_choices[0] if not heavy_baton_choices.is_empty() else {}
	var available_targets_raw: Array = heavy_baton_choice.get("bench", [])
	var available_targets: Array[PokemonSlot] = []
	for target: Variant in available_targets_raw:
		if target is PokemonSlot:
			available_targets.append(target)
	var resolved: bool = gsm.resolve_heavy_baton_choice(1, second_bench_slot)
	return run_checks([
		assert_eq(attacked, true, "Attack should succeed before knockout"),
		assert_eq(available_targets.size(), 2, "Heavy Baton should require choosing among multiple bench targets"),
		assert_eq(heavy_baton_choice.get("player", -1), 1, "Heavy Baton choice should belong to the knocked out player"),
		assert_eq(resolved, true, "Resolving the Heavy Baton choice should continue the knockout flow"),
		assert_eq(second_bench_slot.attached_energy.size(), 3, "Heavy Baton should move Energy to the chosen bench Pokemon"),
		assert_eq(bench_slot.attached_energy.size(), 0, "The unchosen bench Pokemon should not receive Energy"),
		assert_eq(gsm.game_state.players[1].discard_pile.filter(func(card: CardInstance) -> bool: return card.card_data.card_type == "Basic Energy").size(), 1, "Unmoved Basic Energy should go to the discard pile"),
	])


func test_attack_extra_prize_takes_one_additional_prize_on_knockout() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var attacker_cd := CardData.new()
	attacker_cd.name = "铁臂膀ex"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 230
	attacker_cd.energy_type = "L"
	attacker_cd.effect_id = "iron_hands_test"
	attacker_cd.attacks = [{"name": "澶氳阿娆惧緟", "cost": "LLCC", "damage": "120", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	for energy_type: String in ["L", "L", "C", "C"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy(energy_type), 0))
	gsm.effect_processor.register_attack_effect("iron_hands_test", AttackExtraPrize.new(1))
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Prize Dummy"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 120
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	gsm.game_state.players[1].deck.append(CardInstance.create(defender_cd, 1))
	for i: int in 4:
		gsm.game_state.players[0].prizes.append(CardInstance.create(defender_cd, 0))
	for i: int in 6:
		gsm.game_state.players[1].prizes.append(CardInstance.create(defender_cd, 1))

	var attacked: bool = gsm.use_attack(0, 0)
	var took_first: bool = gsm.resolve_take_prize(0, 1)
	var took_second: bool = gsm.resolve_take_prize(0, 3)
	return run_checks([
		assert_eq(attacked, true, "铁臂膀ex should use Amp You Very Much successfully"),
		assert_eq(took_first, true, "First prize should be taken by explicit player selection"),
		assert_eq(took_second, true, "Second prize should also require explicit player selection"),
		assert_eq(gsm.game_state.players[0].hand.size(), 2, "Amp You Very Much should take two prize cards total"),
		assert_eq(gsm.game_state.players[0].prizes.size(), 2, "Prize pile should shrink by two"),
	])


func test_knockout_waits_for_prize_selection_before_replacement() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var choice_events: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		choice_events.append({"type": choice_type, "data": data.duplicate(true)})
	)

	var attacker_cd := CardData.new()
	attacker_cd.name = "Prize Picker"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 120
	attacker_cd.energy_type = "P"
	attacker_cd.attacks = [{"name": "Hit", "cost": "P", "damage": "120", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy("P"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Defender"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 120
	attacker_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].bench.append(replacement)
	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(defender_cd, 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(defender_cd, 1))

	var attacked: bool = gsm.use_attack(0, 0)
	var take_prize_event: Dictionary = choice_events[0] if not choice_events.is_empty() else {}
	var before_hand: int = gsm.game_state.players[0].hand.size()
	var before_prizes: int = gsm.game_state.players[0].prizes.size()
	var took_prize: bool = gsm.resolve_take_prize(0, 3)

	return run_checks([
		assert_true(attacked, "Attack should succeed"),
		assert_eq(str(take_prize_event.get("type", "")), "take_prize", "Knockout should pause on prize selection first"),
		assert_eq(before_hand, 0, "Prize cards should not be auto-added before the player chooses"),
		assert_eq(before_prizes, 6, "Prize pile should stay untouched until selection"),
		assert_true(took_prize, "Resolving the chosen prize slot should succeed"),
		assert_eq(gsm.game_state.players[0].hand.size(), 1, "Chosen prize should enter hand after selection"),
		assert_eq(gsm.game_state.players[0].prizes.size(), 5, "Prize count should shrink after selection"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.KNOCKOUT_REPLACE, "Game should wait for the defender to send out a replacement"),
	])


func test_attack_extra_prize_marker_clears_when_target_survives() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var attacker_cd := CardData.new()
	attacker_cd.name = "铁臂膀ex"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 230
	attacker_cd.energy_type = "L"
	attacker_cd.effect_id = "iron_hands_test_survive"
	attacker_cd.attacks = [{"name": "澶氳阿娆惧緟", "cost": "LLCC", "damage": "40", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	for energy_type: String in ["L", "L", "C", "C"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy(energy_type), 0))
	gsm.effect_processor.register_attack_effect("iron_hands_test_survive", AttackExtraPrize.new(1))
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Survivor"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 120
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	gsm.game_state.players[1].deck.append(CardInstance.create(defender_cd, 1))
	for i: int in 4:
		gsm.game_state.players[0].prizes.append(CardInstance.create(defender_cd, 0))
	for i: int in 6:
		gsm.game_state.players[1].prizes.append(CardInstance.create(defender_cd, 1))

	var attacked: bool = gsm.use_attack(0, 0)
	defender_slot.damage_counters = 120
	gsm.game_state.phase = GameState.GamePhase.POKEMON_CHECK
	gsm._check_all_knockouts()
	var took_prize: bool = gsm.resolve_take_prize(0, 0)

	return run_checks([
		assert_eq(attacked, true, "Amp You Very Much should still be usable when it does not KO"),
		assert_true(took_prize, "Later knockout should still require a manual prize selection"),
		assert_eq(defender_slot.effects.filter(func(effect: Dictionary) -> bool: return effect.get("type", "") == "extra_prize").size(), 0, "Extra prize marker should clear if the target survives"),
		assert_eq(gsm.game_state.players[0].hand.size(), 1, "Later knockouts should not incorrectly draw extra prize cards"),
	])


func test_iron_hands_amp_you_very_much_turn_advances_and_attack_is_usable_next_turn() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var iron_hands_cd: CardData = CardDatabase.get_card("CSV6C", "051")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(iron_hands_cd, 0))
	for energy_type: String in ["L", "L", "C", "C"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy(energy_type), 0))
	gsm.effect_processor.register_pokemon_card(iron_hands_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Amp Target"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 120
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	var replacement_slot := PokemonSlot.new()
	replacement_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].bench.append(replacement_slot)
	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(defender_cd, 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(defender_cd, 1))

	var attacked: bool = gsm.use_attack(0, 1)
	var took_first: bool = gsm.resolve_take_prize(0, 0)
	var took_second: bool = gsm.resolve_take_prize(0, 1)
	var sent_out: bool = gsm.send_out_pokemon(1, replacement_slot)
	var advanced_to_opponent: bool = gsm.game_state.current_player_index == 1 and gsm.game_state.phase == GameState.GamePhase.MAIN
	var hand_after_prizes: int = gsm.game_state.players[0].hand.size()
	gsm.end_turn(1)
	var next_turn_attack_usable: bool = gsm.can_use_attack(0, 1)
	var unusable_reason: String = gsm.get_attack_unusable_reason(0, 1)

	return run_checks([
		assert_not_null(iron_hands_cd, "CSV6C_051 should exist in the card database"),
		assert_true(attacked, "CSV6C_051 Amp You Very Much should resolve successfully"),
		assert_true(took_first, "CSV6C_051 should let the player take the first prize manually"),
		assert_true(took_second, "CSV6C_051 should let the player take the second prize manually"),
		assert_true(sent_out, "The defending player should be able to send out a replacement after Amp You Very Much"),
		assert_true(advanced_to_opponent, "After replacement, the turn should pass to the opponent"),
		assert_eq(hand_after_prizes, 2, "CSV6C_051 should take exactly 2 prize cards after a knockout"),
		assert_true(next_turn_attack_usable, "CSV6C_051 should still be able to use Amp You Very Much on its next turn"),
		assert_eq(unusable_reason, "", "CSV6C_051 should not carry a stale unusable reason into the next turn"),
	])


func test_iron_hands_arm_press_knockout_advances_turn_after_prize_and_replacement() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var iron_hands_cd: CardData = CardDatabase.get_card("CSV6C", "051")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(iron_hands_cd, 0))
	for energy_type: String in ["L", "L", "C"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy(energy_type), 0))
	gsm.effect_processor.register_pokemon_card(iron_hands_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Arm Press Target"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 160
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	var replacement_slot := PokemonSlot.new()
	replacement_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].bench.append(replacement_slot)
	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(defender_cd, 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(defender_cd, 1))

	var attacked: bool = gsm.use_attack(0, 0)
	var took_prize: bool = gsm.resolve_take_prize(0, 0)
	var hand_after_first_prize: int = gsm.game_state.players[0].hand.size()
	var pending_after_first_prize: int = gsm.get("_pending_prize_remaining")
	var sent_out: bool = gsm.send_out_pokemon(1, replacement_slot)

	return run_checks([
		assert_not_null(iron_hands_cd, "CSV6C_051 should exist in the card database"),
		assert_true(attacked, "CSV6C_051 Arm Press should resolve successfully"),
		assert_true(took_prize, "CSV6C_051 Arm Press knockout should still wait for manual prize selection"),
		assert_eq(hand_after_first_prize, 1, "CSV6C_051 Arm Press should only award 1 prize on a normal knockout"),
		assert_eq(pending_after_first_prize, 0, "CSV6C_051 Arm Press should not leave a second prize pending"),
		assert_true(sent_out, "The defending player should be able to send out a replacement after Arm Press"),
		assert_eq(gsm.game_state.players[0].hand.size(), 1, "CSV6C_051 Arm Press should take only 1 prize card"),
		assert_eq(gsm.game_state.current_player_index, 1, "After Arm Press knockout and replacement, the turn should pass to the opponent"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "The opponent should start their turn in MAIN after drawing"),
	])


func test_send_out_pokemon_rejects_replacement_while_prizes_are_still_pending() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var iron_hands_cd: CardData = CardDatabase.get_card("CSV6C", "051")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(iron_hands_cd, 0))
	for energy_type: String in ["L", "L", "C", "C"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy(energy_type), 0))
	gsm.effect_processor.register_pokemon_card(iron_hands_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Pending Prize Target"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 120
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot
	var replacement_slot := PokemonSlot.new()
	replacement_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].bench.append(replacement_slot)
	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(defender_cd, 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(defender_cd, 1))

	var attacked: bool = gsm.use_attack(0, 1)
	var took_first: bool = gsm.resolve_take_prize(0, 0)
	var sent_out_early: bool = gsm.send_out_pokemon(1, replacement_slot)

	return run_checks([
		assert_true(attacked, "CSV6C_051 Amp You Very Much should create a multi-prize knockout fixture"),
		assert_true(took_first, "CSV6C_051 should still allow the first prize to be taken"),
		assert_eq(int(gsm.get("_pending_prize_remaining")), 1, "After the first prize, one more prize should still be pending"),
		assert_false(sent_out_early, "The defending player should not be able to send out before all pending prizes are taken"),
		assert_eq(gsm.game_state.current_player_index, 0, "The turn should not advance while prize selection is still pending"),
	])


func test_dragapult_phantom_dive_awards_prizes_for_active_and_bench_knockouts() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	for energy_type: String in ["R", "P"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy(energy_type), 0))
	gsm.effect_processor.register_pokemon_card(dragapult_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var active_target_cd := CardData.new()
	active_target_cd.name = "Active Prize Target"
	active_target_cd.card_type = "Pokemon"
	active_target_cd.stage = "Basic"
	active_target_cd.hp = 200
	active_target_cd.energy_type = "W"
	var active_target := PokemonSlot.new()
	active_target.pokemon_stack.append(CardInstance.create(active_target_cd, 1))
	gsm.game_state.players[1].active_pokemon = active_target

	var bench_target_cd := CardData.new()
	bench_target_cd.name = "Bench Prize Target"
	bench_target_cd.card_type = "Pokemon"
	bench_target_cd.stage = "Basic"
	bench_target_cd.hp = 60
	bench_target_cd.energy_type = "W"
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(bench_target_cd, 1))
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(active_target_cd, 1))
	gsm.game_state.players[1].bench = [bench_target, replacement]
	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(active_target_cd, 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(active_target_cd, 1))

	var attacked: bool = gsm.use_attack(0, 1, [{
		"bench_damage_counters": [
			{"target": bench_target, "amount": 60},
		],
	}])
	var took_first_prize: bool = gsm.resolve_take_prize(0, 0)
	var send_out_ok: bool = gsm.send_out_pokemon(1, replacement)
	var second_prize_pending: int = int(gsm.get("_pending_prize_remaining"))
	var bench_removed_after_replacement: bool = bench_target not in gsm.game_state.players[1].bench
	var took_second_prize: bool = gsm.resolve_take_prize(0, 1)

	return run_checks([
		assert_not_null(dragapult_cd, "CSV8C_159 should exist in the card database"),
		assert_true(attacked, "CSV8C_159 Phantom Dive should resolve successfully"),
		assert_true(took_first_prize, "CSV8C_159 should allow the first prize from the Active knockout"),
		assert_true(send_out_ok, "CSV8C_159 should still let the defending player send out a replacement"),
		assert_eq(second_prize_pending, 1, "CSV8C_159 should queue the Bench knockout prize after replacement"),
		assert_true(bench_removed_after_replacement, "CSV8C_159 should remove the knocked-out Benched Pokemon from play"),
		assert_true(took_second_prize, "CSV8C_159 should allow the second prize from the Bench knockout"),
		assert_eq(gsm.game_state.players[0].hand.size(), 2, "CSV8C_159 should award 2 prizes total for simultaneous 1-prize knockouts"),
		assert_eq(gsm.game_state.current_player_index, 1, "After both CSV8C_159 knockouts finish resolving, the turn should pass to the opponent"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "After both CSV8C_159 knockouts, the opponent should begin their turn in MAIN"),
	])


func test_dragapult_phantom_dive_does_not_prompt_send_out_when_only_knocked_out_bench_remains() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	for energy_type: String in ["R", "P"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy(energy_type), 0))
	gsm.effect_processor.register_pokemon_card(dragapult_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var active_target_cd := CardData.new()
	active_target_cd.name = "Active Prize Target"
	active_target_cd.card_type = "Pokemon"
	active_target_cd.stage = "Basic"
	active_target_cd.hp = 200
	active_target_cd.energy_type = "W"
	var active_target := PokemonSlot.new()
	active_target.pokemon_stack.append(CardInstance.create(active_target_cd, 1))
	gsm.game_state.players[1].active_pokemon = active_target

	var bench_target_cd := CardData.new()
	bench_target_cd.name = "Only Bench Target"
	bench_target_cd.card_type = "Pokemon"
	bench_target_cd.stage = "Basic"
	bench_target_cd.hp = 60
	bench_target_cd.energy_type = "W"
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(bench_target_cd, 1))
	gsm.game_state.players[1].bench = [bench_target]
	for i: int in 2:
		gsm.game_state.players[0].prizes.append(CardInstance.create(active_target_cd, 0))
	for i: int in 6:
		gsm.game_state.players[1].prizes.append(CardInstance.create(active_target_cd, 1))

	var attacked: bool = gsm.use_attack(0, 1, [{
		"bench_damage_counters": [
			{"target": bench_target, "amount": 60},
		],
	}])
	var took_first_prize: bool = gsm.resolve_take_prize(0, 0)
	var pending_prize_after_first: int = int(gsm.get("_pending_prize_remaining"))
	var phase_after_first: int = gsm.game_state.phase
	var invalid_send_out: bool = gsm.send_out_pokemon(1, bench_target)
	var took_second_prize: bool = gsm.resolve_take_prize(0, 1)
	var winner_index: int = gsm.game_state.winner_index

	return run_checks([
		assert_not_null(dragapult_cd, "CSV8C_159 should exist in the card database"),
		assert_true(attacked, "CSV8C_159 Phantom Dive should resolve the double-KO fixture"),
		assert_true(took_first_prize, "The first prize from the Active knockout should still be taken manually"),
		assert_eq(pending_prize_after_first, 1, "After the first prize, the Bench knockout prize should queue immediately"),
		assert_eq(phase_after_first, GameState.GamePhase.POKEMON_CHECK, "Without a live replacement, the game should continue knockout checks instead of entering replacement"),
		assert_false(invalid_send_out, "A knocked-out Benched Pokemon must not be accepted as a replacement"),
		assert_true(took_second_prize, "The second prize should still be claimable without a replacement step"),
		assert_eq(gsm.game_state.players[0].prizes.size(), 0, "CSV8C_159 should take both remaining prizes in this fixture"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.GAME_OVER, "Taking the final queued prize should end the game"),
		assert_eq(winner_index, 0, "The attacking player should win after taking both remaining prizes"),
	])


func test_dragapult_phantom_dive_active_knockout_hands_turn_to_opponent_after_replacement() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(dragapult_cd, 0))
	for energy_type: String in ["R", "P"]:
		attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy(energy_type), 0))
	gsm.effect_processor.register_pokemon_card(dragapult_cd)
	gsm.game_state.players[0].active_pokemon = attacker_slot

	var active_target_cd := CardData.new()
	active_target_cd.name = "Active Prize Target"
	active_target_cd.card_type = "Pokemon"
	active_target_cd.stage = "Basic"
	active_target_cd.hp = 200
	active_target_cd.energy_type = "W"
	var active_target := PokemonSlot.new()
	active_target.pokemon_stack.append(CardInstance.create(active_target_cd, 1))
	gsm.game_state.players[1].active_pokemon = active_target

	var replacement_cd := CardData.new()
	replacement_cd.name = "Replacement"
	replacement_cd.card_type = "Pokemon"
	replacement_cd.stage = "Basic"
	replacement_cd.hp = 120
	replacement_cd.energy_type = "W"
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(replacement_cd, 1))
	gsm.game_state.players[1].bench = [replacement]
	for i: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(active_target_cd, 0))
		gsm.game_state.players[1].prizes.append(CardInstance.create(active_target_cd, 1))

	var attacked: bool = gsm.use_attack(0, 1, [{
		"bench_damage_counters": [
			{"target": replacement, "amount": 60},
		],
	}])
	var took_prize: bool = gsm.resolve_take_prize(0, 0)
	var replacement_sent: bool = gsm.send_out_pokemon(1, replacement)

	return run_checks([
		assert_not_null(dragapult_cd, "CSV8C_159 should exist in the card database"),
		assert_true(attacked, "CSV8C_159 Phantom Dive should resolve successfully"),
		assert_true(took_prize, "CSV8C_159 should still let the attacking player take the prize from the Active knockout"),
		assert_true(replacement_sent, "CSV8C_159 should still let the defending player send out a replacement"),
		assert_eq(replacement.damage_counters, 60, "CSV8C_159 should keep the assigned Bench damage counters on the replacement Pokemon"),
		assert_eq(gsm.game_state.players[1].active_pokemon, replacement, "CSV8C_159 should promote the chosen replacement after the Active knockout"),
		assert_eq(int(gsm.get("_pending_prize_remaining")), 0, "CSV8C_159 should not leave prize selection pending after the Active-only knockout"),
		assert_eq(gsm.game_state.current_player_index, 1, "After the Active-only CSV8C_159 knockout finishes, the turn should pass to the opponent"),
		assert_eq(gsm.game_state.phase, GameState.GamePhase.MAIN, "After the Active-only CSV8C_159 knockout, the opponent should begin their turn in MAIN"),
	])


func test_evolve_charizard_triggers_infernal_reign_and_attaches_fire_energy() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()

	var charmeleon_cd := CardData.new()
	charmeleon_cd.name = "Charmeleon"
	charmeleon_cd.card_type = "Pokemon"
	charmeleon_cd.stage = "Stage 1"
	charmeleon_cd.hp = 100
	charmeleon_cd.energy_type = "R"
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(charmeleon_cd, 0))
	active_slot.turn_played = 1
	player.active_pokemon = active_slot

	var bench_a_cd := CardData.new()
	bench_a_cd.name = "澶囨垬A"
	bench_a_cd.card_type = "Pokemon"
	bench_a_cd.stage = "Basic"
	bench_a_cd.hp = 90
	bench_a_cd.energy_type = "R"
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(bench_a_cd, 0))
	player.bench.append(bench_a)
	var bench_b_cd := CardData.new()
	bench_b_cd.name = "澶囨垬B"
	bench_b_cd.card_type = "Pokemon"
	bench_b_cd.stage = "Basic"
	bench_b_cd.hp = 100
	bench_b_cd.energy_type = "R"
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(bench_b_cd, 0))
	player.bench.append(bench_b)

	var charizard_cd := CardData.new()
	charizard_cd.name = "鍠风伀榫檈x"
	charizard_cd.card_type = "Pokemon"
	charizard_cd.stage = "Stage 2"
	charizard_cd.hp = 330
	charizard_cd.energy_type = "R"
	charizard_cd.mechanic = "ex"
	charizard_cd.effect_id = "charizard_infernal_reign_test"
	charizard_cd.evolves_from = "Charmeleon"
	charizard_cd.abilities = [{"name": "烈焰支配", "text": ""}]
	gsm.effect_processor.register_effect(
		"charizard_infernal_reign_test",
		AbilityAttachFromDeckEffect.new("R", 3, "own", true, false)
	)
	var evolution := CardInstance.create(charizard_cd, 0)
	player.hand.append(evolution)

	var fire_a := CardInstance.create(_make_test_energy("R"), 0)
	var fire_b := CardInstance.create(_make_test_energy("R"), 0)
	var fire_c := CardInstance.create(_make_test_energy("R"), 0)
	player.deck.append(fire_a)
	player.deck.append(fire_b)
	player.deck.append(fire_c)
	for i: int in 3:
		player.deck.append(CardInstance.create(_make_test_energy("W"), 0))
	player.deck.append(CardInstance.create(_make_test_energy("W"), 0))

	var evolved: bool = gsm.evolve_pokemon(0, evolution, active_slot)
	var steps: Array[Dictionary] = gsm.get_evolve_ability_interaction_steps(active_slot)
	var ability_used: bool = gsm.use_ability(0, active_slot, 0, [{
		"energy_assignments": [
			{"source": fire_a, "target": active_slot},
			{"source": fire_b, "target": bench_a},
			{"source": fire_c, "target": bench_b},
		],
	}])
	return run_checks([
		assert_eq(evolved, true, "Charizard ex should evolve successfully"),
		assert_eq(active_slot.get_pokemon_name(), "鍠风伀榫檈x", "The evolved Pokemon should be Charizard ex"),
		assert_eq(steps.size(), 1, "Infernal Reign should use one reusable assignment step"),
		assert_eq(str(steps[0].get("ui_mode", "")), "card_assignment", "Infernal Reign should use card_assignment UI mode"),
		assert_eq(active_slot.attached_energy.size(), 1, "One Fire Energy should be assigned to the active Pokemon"),
		assert_eq(bench_a.attached_energy.size(), 1, "One Fire Energy should be assignable to bench target A"),
		assert_eq(bench_b.attached_energy.size(), 1, "One Fire Energy should be assignable to bench target B"),
		assert_eq(ability_used, true, "Infernal Reign should resolve from assignment context"),
		assert_eq(player.deck.filter(func(card: CardInstance) -> bool: return card.card_data.card_type == "Basic Energy" and card.card_data.energy_provides == "R").size(), 0, "All selected Fire Energy should leave the deck"),
	])


func test_second_player_first_turn_cannot_evolve_setup_pokemon() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.first_player_index = 0
	gsm.game_state.current_player_index = 1

	var player: PlayerState = gsm.game_state.players[1]
	var active_slot := PokemonSlot.new()
	var basic_cd := CardData.new()
	basic_cd.name = "Setup Basic"
	basic_cd.card_type = "Pokemon"
	basic_cd.stage = "Basic"
	basic_cd.hp = 70
	basic_cd.energy_type = "G"
	active_slot.pokemon_stack.append(CardInstance.create(basic_cd, 1))
	active_slot.turn_played = 0
	player.active_pokemon = active_slot

	var evo_cd := CardData.new()
	evo_cd.name = "Setup Evolution"
	evo_cd.card_type = "Pokemon"
	evo_cd.stage = "Stage 1"
	evo_cd.hp = 110
	evo_cd.energy_type = "G"
	evo_cd.evolves_from = "Setup Basic"
	var evolution := CardInstance.create(evo_cd, 1)
	player.hand.append(evolution)

	var evolved: bool = gsm.evolve_pokemon(1, evolution, active_slot)

	return run_checks([
		assert_false(evolved, "后攻玩家第一回合不能进化开场放置的宝可梦"),
		assert_eq(active_slot.get_pokemon_name(), "Setup Basic", "非法进化不应改变场上的宝可梦"),
		assert_true(evolution in player.hand, "非法进化时进化牌应保留在手牌"),
	])


func test_charizard_burning_darkness_does_not_discard_energy_and_only_counts_taken_prizes() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2

	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]

	var charizard_cd := CardData.new()
	charizard_cd.name = "鍠风伀榫檈x"
	charizard_cd.card_type = "Pokemon"
	charizard_cd.stage = "Stage 2"
	charizard_cd.hp = 330
	charizard_cd.energy_type = "D"
	charizard_cd.effect_id = "767b6233bf90b98b7af190ea3b40d7a2"
	charizard_cd.mechanic = "ex"
	charizard_cd.abilities = [{"name": "烈焰支配", "text": ""}]
	charizard_cd.attacks = [{
		"name": "鐕冪儳榛戞殫",
		"cost": "RR",
		"damage": "180+",
		"text": "This attack does 30 more damage for each Prize card your opponent has taken.",
		"is_vstar_power": false,
	}]
	gsm.effect_processor.register_pokemon_card(charizard_cd)

	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(charizard_cd, 0))
	player.active_pokemon = attacker_slot
	var fire_1 := CardInstance.create(_make_test_energy("R"), 0)
	var fire_2 := CardInstance.create(_make_test_energy("R"), 0)
	attacker_slot.attached_energy.append(fire_1)
	attacker_slot.attached_energy.append(fire_2)

	var defender_cd := CardData.new()
	defender_cd.name = "铁臂膀ex"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 230
	defender_cd.energy_type = "L"
	defender_cd.mechanic = "ex"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	opponent.active_pokemon = defender_slot

	for i: int in 6:
		var prize_cd := CardData.new()
		prize_cd.name = "濂栬祻%d" % i
		prize_cd.card_type = "Pokemon"
		prize_cd.stage = "Basic"
		prize_cd.hp = 60
		prize_cd.energy_type = "C"
		opponent.prizes.append(CardInstance.create(prize_cd, 1))

	var attacked: bool = gsm.use_attack(0, 0)
	return run_checks([
		assert_eq(attacked, true, "Charizard ex should attack successfully"),
		assert_eq(defender_slot.damage_counters, 180, "Burning Darkness should deal 180 when the opponent has taken no prizes"),
		assert_eq(attacker_slot.attached_energy.size(), 2, "Burning Darkness should not discard Energy"),
		assert_eq(player.discard_pile.size(), 0, "Burning Darkness should not move Energy to discard"),
		assert_false(defender_slot.is_knocked_out(), "A 230 HP target should survive the first 180 damage attack"),
	])


func _make_test_energy(energy_type: String) -> CardData:
	var e_cd := CardData.new()
	e_cd.card_type = "Basic Energy"
	e_cd.energy_provides = energy_type
	return e_cd


func test_action_log_records_actions() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.draw_card(0, 2)

	return run_checks([
		assert_eq(gsm.action_log.size() > 0, true, "Action log should record entries"),
	])


func test_attack_log_includes_damage_and_target_details() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	var attacker_cd := CardData.new()
	attacker_cd.name = "Attacker"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 110
	attacker_cd.energy_type = "C"
	attacker_cd.attacks = [{"name": "Quick Bolt", "cost": "C", "damage": "40", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy("C"), 0))
	player.active_pokemon = attacker_slot

	var defender_cd := CardData.new()
	defender_cd.name = "Defender"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 100
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var result: bool = gsm.use_attack(0, 0)
	var attack_action: GameAction = _get_last_action_of_type(gsm.action_log, GameAction.ActionType.ATTACK)

	return run_checks([
		assert_eq(result, true, "Attack should resolve successfully"),
		assert_not_null(attack_action, "Attack should be logged"),
		assert_eq(str(attack_action.data.get("attack_name", "")), "Quick Bolt", "Attack log should include the attack name"),
		assert_eq(int(attack_action.data.get("damage", -1)), 40, "Attack log should include the damage dealt"),
		assert_eq(str(attack_action.data.get("target_pokemon_name", "")), "Defender", "Attack log should include the target Pokemon name"),
	])


func test_attack_log_omits_active_target_when_prompt_targets_are_supplied() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	player.deck.clear()
	var chosen_top := CardInstance.create(_make_test_energy("M"), 0)
	player.deck.append(chosen_top)

	var attacker_cd := CardData.new()
	attacker_cd.name = "Beldum"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 70
	attacker_cd.energy_type = "M"
	attacker_cd.effect_id = "beldum_test_recording"
	attacker_cd.attacks = [{"name": "Magnetic Lift", "cost": "C", "damage": "", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy("M"), 0))
	player.active_pokemon = attacker_slot
	gsm.effect_processor.register_attack_effect("beldum_test_recording", AttackSearchDeckToTopEffect.new(1))

	var defender_cd := CardData.new()
	defender_cd.name = "Defender"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 100
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var result: bool = gsm.use_attack(0, 0, [{
		"search_cards": [chosen_top],
	}])
	var attack_action: GameAction = _get_last_action_of_type(gsm.action_log, GameAction.ActionType.ATTACK)
	var attack_data: Dictionary = attack_action.data if attack_action != null else {}

	return run_checks([
		assert_eq(result, true, "Prompt-targeted attack should resolve successfully"),
		assert_not_null(attack_action, "Attack should be logged"),
		assert_eq(int(attack_data.get("damage", -1)), 0, "Zero-damage attacks should record damage as 0"),
		assert_eq(attack_data.has("target_pokemon_name"), false, "Prompt-targeted attacks should not guess the opposing Active as the target"),
	])


func test_attack_log_keeps_active_target_for_non_target_prompt_with_damage() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	player.deck.clear()
	var chosen_top := CardInstance.create(_make_test_energy("M"), 0)
	player.deck.append(chosen_top)

	var attacker_cd := CardData.new()
	attacker_cd.name = "Attacker"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Basic"
	attacker_cd.hp = 110
	attacker_cd.energy_type = "M"
	attacker_cd.effect_id = "attacker_test_recording"
	attacker_cd.attacks = [{"name": "Magnetic Bolt", "cost": "C", "damage": "40", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	attacker_slot.attached_energy.append(CardInstance.create(_make_test_energy("M"), 0))
	player.active_pokemon = attacker_slot
	gsm.effect_processor.register_attack_effect("attacker_test_recording", AttackSearchDeckToTopEffect.new(1))

	var defender_cd := CardData.new()
	defender_cd.name = "Defender"
	defender_cd.card_type = "Pokemon"
	defender_cd.stage = "Basic"
	defender_cd.hp = 100
	defender_cd.energy_type = "W"
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var result: bool = gsm.use_attack(0, 0, [{
		"search_cards": [chosen_top],
	}])
	var attack_action: GameAction = _get_last_action_of_type(gsm.action_log, GameAction.ActionType.ATTACK)
	var attack_data: Dictionary = attack_action.data if attack_action != null else {}

	return run_checks([
		assert_eq(result, true, "Damage attack with auxiliary prompt should resolve successfully"),
		assert_not_null(attack_action, "Attack should be logged"),
		assert_eq(int(attack_data.get("damage", -1)), 40, "Damage attack should record the resolved damage"),
		assert_eq(str(attack_data.get("target_pokemon_name", "")), "Defender", "Auxiliary prompts should still keep the opposing Active as the target when the attack hits it"),
	])


func test_attack_log_omits_active_target_for_existing_explicit_target_step_ids() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	var attacker_cd := CardData.new()
	attacker_cd.name = "Greninja ex"
	attacker_cd.card_type = "Pokemon"
	attacker_cd.stage = "Stage 2"
	attacker_cd.hp = 310
	attacker_cd.energy_type = "W"
	attacker_cd.effect_id = "greninja_test_recording"
	attacker_cd.attacks = [{"name": "Mirage Barrage", "cost": "CC", "damage": "", "is_vstar_power": false}]
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	var energy_a := CardInstance.create(_make_test_energy("W"), 0)
	var energy_b := CardInstance.create(_make_test_energy("W"), 0)
	attacker_slot.attached_energy = [energy_a, energy_b]
	player.active_pokemon = attacker_slot
	gsm.effect_processor.register_attack_effect("greninja_test_recording", AttackGreninjaExMirageBarrageEffect.new(0, 120, 2))

	var active_defender_cd := CardData.new()
	active_defender_cd.name = "Active Defender"
	active_defender_cd.card_type = "Pokemon"
	active_defender_cd.stage = "Basic"
	active_defender_cd.hp = 120
	active_defender_cd.energy_type = "W"
	var active_defender := PokemonSlot.new()
	active_defender.pokemon_stack.append(CardInstance.create(active_defender_cd, 1))
	gsm.game_state.players[1].active_pokemon = active_defender

	var bench_defender_cd := CardData.new()
	bench_defender_cd.name = "Bench Defender"
	bench_defender_cd.card_type = "Pokemon"
	bench_defender_cd.stage = "Basic"
	bench_defender_cd.hp = 120
	bench_defender_cd.energy_type = "W"
	var bench_defender := PokemonSlot.new()
	bench_defender.pokemon_stack.append(CardInstance.create(bench_defender_cd, 1))
	gsm.game_state.players[1].bench = [bench_defender]

	var result: bool = gsm.use_attack(0, 0, [{
		"greninja_ex_discard_energy": [energy_a, energy_b],
		"greninja_ex_targets": [bench_defender],
	}])
	var attack_action: GameAction = _get_last_action_of_type(gsm.action_log, GameAction.ActionType.ATTACK)
	var attack_data: Dictionary = attack_action.data if attack_action != null else {}

	return run_checks([
		assert_eq(result, true, "Explicit-target attack should resolve successfully"),
		assert_not_null(attack_action, "Attack should be logged"),
		assert_eq(bench_defender.damage_counters, 120, "The explicit bench target should take the attack damage"),
		assert_eq(active_defender.damage_counters, 0, "The opposing Active should not be treated as the resolved target"),
		assert_eq(attack_data.has("target_pokemon_name"), false, "Explicit target-step attacks should not mislabel the opposing Active as the target"),
	])


func test_take_prize_log_includes_prize_count_and_card_identity() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	var player: PlayerState = gsm.game_state.players[0]
	var prize_cd := CardData.new()
	prize_cd.name = "Prize Target"
	prize_cd.card_type = "Pokemon"
	prize_cd.stage = "Basic"
	prize_cd.hp = 60
	prize_cd.energy_type = "W"
	player.prizes.append(CardInstance.create(prize_cd, 0))
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	gsm.set("_pending_prize_resume_mode", "")
	gsm.set("_pending_prize_resume_player_index", 0)

	var pending_prize_remaining: int = int(gsm.get("_pending_prize_remaining"))
	var took_prize: bool = gsm.resolve_take_prize(0, 0)
	var prize_action: GameAction = _get_last_action_of_type(gsm.action_log, GameAction.ActionType.TAKE_PRIZE)
	var prize_data: Dictionary = prize_action.data if prize_action != null else {}

	return run_checks([
		assert_eq(pending_prize_remaining, 1, "Prize fixture should queue exactly one prize"),
		assert_eq(took_prize, true, "Prize selection should resolve"),
		assert_not_null(prize_action, "Prize taking should be logged"),
		assert_eq(int(prize_data.get("prize_count", -1)), 1, "Prize log should include the prize count"),
		assert_eq(prize_data.get("card_names", []), ["Prize Target"], "Prize log should include the revealed prize list"),
		assert_eq(str(prize_data.get("card_name", "")), "Prize Target", "Prize log should include the revealed prize identity"),
	])


func test_knockout_without_available_prizes_keeps_knockout_log_intact() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.POKEMON_CHECK
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0

	gsm.game_state.players[0].prizes.clear()
	var knocked_out_cd := CardData.new()
	knocked_out_cd.name = "Prizeless Target"
	knocked_out_cd.card_type = "Pokemon"
	knocked_out_cd.stage = "Basic"
	knocked_out_cd.hp = 60
	knocked_out_cd.energy_type = "W"
	var knocked_out_slot := PokemonSlot.new()
	knocked_out_slot.pokemon_stack.append(CardInstance.create(knocked_out_cd, 1))
	gsm.game_state.players[1].bench.append(knocked_out_slot)

	var completed: bool = gsm._finalize_knockout(1, knocked_out_slot, false)
	var knockout_action: GameAction = _get_last_action_of_type(gsm.action_log, GameAction.ActionType.KNOCKOUT)
	var take_prize_action: GameAction = _get_last_action_of_type(gsm.action_log, GameAction.ActionType.TAKE_PRIZE)
	var knockout_data: Dictionary = knockout_action.data if knockout_action != null else {}

	return run_checks([
		assert_eq(completed, true, "Knockout should still complete when no prizes can be taken"),
		assert_not_null(knockout_action, "Knockout should be logged"),
		assert_eq(int(knockout_data.get("prize_count", -1)), 1, "Knockout log should keep the prize count from the defeated Pokemon"),
		assert_eq(knockout_data.has("card_names"), false, "Knockout log should not be overwritten with prize metadata when no prize was taken"),
		assert_null(take_prize_action, "No TAKE_PRIZE action should be logged when the attacker has no prizes remaining"),
	])


func test_send_out_log_includes_replacement_pokemon_name() -> String:
	var gsm := _make_gsm_with_decks()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.turn_number = 2
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0

	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = null
	var replacement_cd := CardData.new()
	replacement_cd.name = "Replacement"
	replacement_cd.card_type = "Pokemon"
	replacement_cd.stage = "Basic"
	replacement_cd.hp = 120
	replacement_cd.energy_type = "W"
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(replacement_cd, 1))
	player.bench.append(replacement)

	var sent_out: bool = gsm.send_out_pokemon(1, replacement)
	var send_out_action: GameAction = _get_last_action_of_type(gsm.action_log, GameAction.ActionType.SEND_OUT)

	return run_checks([
		assert_eq(sent_out, true, "Replacement Pokemon should be sent out"),
		assert_not_null(send_out_action, "Send-out should be logged"),
		assert_eq(str(send_out_action.data.get("replacement_pokemon_name", "")), "Replacement", "Send-out log should include the replacement Pokemon name"),
	])


func test_game_action_create() -> String:
	var action: GameAction = GameAction.create(
		GameAction.ActionType.DRAW_CARD, 0, {"count": 1}, 2, "抽1张牌"
	)
	return run_checks([
		assert_eq(action.action_type, GameAction.ActionType.DRAW_CARD, "Action type"),
		assert_eq(action.player_index, 0, "Player index"),
		assert_eq(action.turn_number, 2, "Turn number should be recorded"),
		assert_eq(action.description, "抽1张牌", "Description should be recorded"),
	])


func _get_last_action_of_type(action_log: Array[GameAction], action_type: GameAction.ActionType) -> GameAction:
	for i: int in range(action_log.size() - 1, -1, -1):
		var action: GameAction = action_log[i]
		if action != null and action.action_type == action_type:
			return action
	return null


func _get_actions_of_type(action_log: Array[GameAction], action_type: GameAction.ActionType) -> Array[GameAction]:
	var matches: Array[GameAction] = []
	for action: GameAction in action_log:
		if action != null and action.action_type == action_type:
			matches.append(action)
	return matches



