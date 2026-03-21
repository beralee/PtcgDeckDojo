## PlayerState 单元测试
class_name TestPlayerState
extends TestBase


func _make_card_data(cname: String = "小火龙", ctype: String = "Pokemon") -> CardData:
	var card := CardData.new()
	card.name = cname
	card.card_type = ctype
	card.stage = "Basic" if ctype == "Pokemon" else ""
	return card


func _make_player_with_deck(count: int = 10) -> PlayerState:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.player_index = 0
	for i in count:
		player.deck.append(CardInstance.create(_make_card_data("卡牌%d" % i), 0))
	return player


func test_draw_card() -> String:
	var player := _make_player_with_deck(5)
	var card := player.draw_card()
	return run_checks([
		assert_not_null(card, "抽到卡"),
		assert_eq(player.hand.size(), 1, "手牌1张"),
		assert_eq(player.deck.size(), 4, "牌库4张"),
		assert_true(card.face_up, "抽到的卡面朝上"),
	])


func test_draw_card_empty_deck() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	return assert_null(player.draw_card(), "空牌库返回null")


func test_draw_cards_multiple() -> String:
	var player := _make_player_with_deck(10)
	var drawn := player.draw_cards(3)
	return run_checks([
		assert_eq(drawn.size(), 3, "抽3张"),
		assert_eq(player.hand.size(), 3, "手牌3"),
		assert_eq(player.deck.size(), 7, "牌库7"),
	])


func test_draw_cards_exceed_deck() -> String:
	var player := _make_player_with_deck(2)
	var drawn := player.draw_cards(5)
	return run_checks([
		assert_eq(drawn.size(), 2, "只能抽2张"),
		assert_eq(player.deck.size(), 0, "牌库空"),
		assert_eq(player.hand.size(), 2, "手牌2"),
	])


func test_draw_from_top() -> String:
	var player := _make_player_with_deck(5)
	# 牌库顶(index 0)的名字是"卡牌0"
	var card := player.draw_card()
	return assert_eq(card.get_name(), "卡牌0", "从顶部抽牌")


func test_remove_from_hand() -> String:
	var player := _make_player_with_deck(3)
	player.draw_cards(3)
	var target := player.hand[1]
	var ok := player.remove_from_hand(target)
	return run_checks([
		assert_true(ok, "移除成功"),
		assert_eq(player.hand.size(), 2, "手牌剩2"),
	])


func test_remove_from_hand_not_found() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	var card := CardInstance.create(_make_card_data(), 0)
	return assert_false(player.remove_from_hand(card), "不在手牌中应失败")


func test_discard_card() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	var card := CardInstance.create(_make_card_data(), 0)
	player.discard_card(card)
	return run_checks([
		assert_eq(player.discard_pile.size(), 1, "弃牌区1张"),
		assert_true(card.face_up, "弃牌面朝上"),
	])


func test_play_card_to_discard() -> String:
	var player := _make_player_with_deck(3)
	player.draw_cards(3)
	var target := player.hand[0]
	var ok := player.play_card_to_discard(target)
	return run_checks([
		assert_true(ok, "打出成功"),
		assert_eq(player.hand.size(), 2, "手牌2"),
		assert_eq(player.discard_pile.size(), 1, "弃牌区1"),
	])


func test_play_card_to_discard_not_in_hand() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	var card := CardInstance.create(_make_card_data(), 0)
	return assert_false(player.play_card_to_discard(card), "不在手牌中应失败")


func test_is_bench_full() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	for i in 5:
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(CardInstance.create(_make_card_data("宝可梦%d" % i), 0))
		player.bench.append(slot)
	return run_checks([
		assert_true(player.is_bench_full(), "5只应满"),
	])


func test_is_bench_not_full() -> String:
	var player := PlayerState.new()
	return assert_false(player.is_bench_full(), "空备战不满")


func test_get_all_pokemon() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_card_data("活跃"), 0))
	player.active_pokemon = active
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_card_data("备战"), 0))
	player.bench.append(bench_slot)
	var all := player.get_all_pokemon()
	return assert_eq(all.size(), 2, "战斗+备战=2")


func test_get_all_pokemon_no_active() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_card_data("备战"), 0))
	player.bench.append(bench_slot)
	return assert_eq(player.get_all_pokemon().size(), 1, "仅备战=1")


func test_has_pokemon_in_play() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	return run_checks([
		assert_false(player.has_pokemon_in_play(), "空场无宝可梦"),
	])


func test_has_pokemon_active() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(_make_card_data(), 0))
	return assert_true(player.has_pokemon_in_play(), "有活跃宝可梦")


func test_get_basic_pokemon_in_hand() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.hand.append(CardInstance.create(_make_card_data("小火龙", "Pokemon"), 0))
	player.hand.append(CardInstance.create(_make_card_data("精灵球", "Item"), 0))
	player.hand.append(CardInstance.create(_make_card_data("皮卡丘", "Pokemon"), 0))
	var basics := player.get_basic_pokemon_in_hand()
	return run_checks([
		assert_eq(basics.size(), 2, "2只基础宝可梦"),
		assert_true(player.has_basic_pokemon_in_hand(), "有基础宝可梦"),
	])


func test_no_basic_pokemon_in_hand() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.hand.append(CardInstance.create(_make_card_data("精灵球", "Item"), 0))
	return run_checks([
		assert_eq(player.get_basic_pokemon_in_hand().size(), 0, "无基础宝可梦"),
		assert_false(player.has_basic_pokemon_in_hand(), "无基础宝可梦"),
	])


func test_take_prize() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	for i in 6:
		var card := CardInstance.create(_make_card_data("奖赏%d" % i), 0)
		card.face_up = false
		player.prizes.append(card)
	var prize := player.take_prize(0)
	return run_checks([
		assert_not_null(prize, "拿到奖赏"),
		assert_true(prize.face_up, "奖赏面朝上"),
		assert_eq(player.prizes.size(), 5, "剩5张奖赏"),
		assert_eq(player.hand.size(), 1, "手牌1张"),
	])


func test_take_prize_invalid_index() -> String:
	var player := PlayerState.new()
	return assert_null(player.take_prize(0), "空奖赏区返回null")


func test_all_prizes_taken() -> String:
	var player := PlayerState.new()
	return assert_true(player.all_prizes_taken(), "空奖赏区已拿完")


func test_prizes_not_taken() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.prizes.append(CardInstance.create(_make_card_data(), 0))
	return assert_false(player.all_prizes_taken(), "有奖赏未拿完")


func test_shuffle_deck() -> String:
	# 洗牌应不改变元素数量（概率性测试，仅验证大小不变）
	var player := _make_player_with_deck(60)
	player.shuffle_deck()
	return assert_eq(player.deck.size(), 60, "洗牌后仍60张")


func test_return_to_deck() -> String:
	var player := _make_player_with_deck(5)
	var card := player.draw_card()
	player.discard_card(card)
	player.remove_from_hand(card)  # draw_card 已加入手牌，先从手牌移除再弃牌... 实际card已在discard
	# card 现在在 discard_pile 和 hand 中都有... 重新测试
	# 正确流程：play_card_to_discard 或手动操作
	CardInstance.reset_id_counter()
	var p2 := PlayerState.new()
	var c2 := CardInstance.create(_make_card_data(), 0)
	c2.face_up = true
	p2.discard_pile.append(c2)
	var ok := p2.return_to_deck(c2)
	return run_checks([
		assert_true(ok, "回收成功"),
		assert_eq(p2.discard_pile.size(), 0, "弃牌区空"),
		assert_eq(p2.deck.size(), 1, "牌库1张"),
		assert_false(c2.face_up, "回收后面朝下"),
	])


func test_return_to_deck_not_in_discard() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	var card := CardInstance.create(_make_card_data(), 0)
	return assert_false(player.return_to_deck(card), "不在弃牌区应失败")
