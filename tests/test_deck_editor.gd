class_name TestDeckEditor
extends TestBase

const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")
const DeckEditorScene := preload("res://scenes/deck_editor/DeckEditor.tscn")


func _set_navigation_suppressed(suppressed: bool) -> void:
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", suppressed)


func _make_deck() -> DeckData:
	var deck := DeckData.new()
	deck.id = 999999
	deck.deck_name = "测试卡组"
	deck.import_date = "2026-01-01"
	deck.cards = [
		{"set_code": "SV1", "card_index": "001", "count": 2, "card_type": "Pokemon", "name": "皮卡丘", "effect_id": "e001", "name_en": "Pikachu"},
		{"set_code": "SV1", "card_index": "050", "count": 1, "card_type": "Supporter", "name": "博士", "effect_id": "e050", "name_en": "Professor"},
		{"set_code": "SV1", "card_index": "060", "count": 1, "card_type": "Basic Energy", "name": "雷能量", "effect_id": "", "name_en": "Lightning Energy"},
	]
	deck.total_cards = 4
	return deck


func _make_card(set_code: String, card_index: String, card_name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.set_code = set_code
	card.card_index = card_index
	card.name = card_name
	card.card_type = card_type
	card.effect_id = ""
	card.name_en = card_name
	return card


func test_deck_editor_shows_strategy_button_and_hides_legacy_ai_button() -> String:
	var editor: Control = DeckEditorScene.instantiate()
	var strategy_button := editor.get_node_or_null("%BtnStrategy") as Button
	var ai_button := editor.get_node_or_null("%BtnAI") as Button
	var discuss_button := editor.get_node_or_null("%BtnDiscussAI") as Button
	editor.queue_free()

	return run_checks([
		assert_not_null(strategy_button, "旧打法思路按钮节点可保留以兼容旧代码"),
		assert_not_null(ai_button, "旧 AI 分析按钮节点可保留以兼容旧代码"),
		assert_not_null(discuss_button, "与 AI 探讨按钮应保留"),
		assert_true(strategy_button.visible, "打法思路按钮应在卡组编辑页面可见"),
		assert_false(ai_button.visible, "AI 分析按钮应从界面隐藏"),
		assert_true(discuss_button.visible, "与 AI 探讨按钮应保持可见"),
	])


# -- _flat_index_to_entry_index --

func test_flat_index_maps_to_correct_entry() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.set("_deck", _make_deck())

	var idx0: int = editor.call("_flat_index_to_entry_index", 0)
	var idx1: int = editor.call("_flat_index_to_entry_index", 1)
	var idx2: int = editor.call("_flat_index_to_entry_index", 2)
	var idx3: int = editor.call("_flat_index_to_entry_index", 3)
	var idx_bad: int = editor.call("_flat_index_to_entry_index", 99)

	return run_checks([
		assert_eq(idx0, 0, "flat 0 应映射到条目 0（皮卡丘第1张）"),
		assert_eq(idx1, 0, "flat 1 应映射到条目 0（皮卡丘第2张）"),
		assert_eq(idx2, 1, "flat 2 应映射到条目 1（博士）"),
		assert_eq(idx3, 2, "flat 3 应映射到条目 2（雷能量）"),
		assert_eq(idx_bad, -1, "超界索引应返回 -1"),
	])


func test_deck_editor_requeues_battle_setup_return_context_when_leaving() -> String:
	_set_navigation_suppressed(true)
	var editor: Control = DeckEditorScript.new()
	editor.set("_return_context", {
		"return_scene": "battle_setup",
		"deck1_id": 101,
		"deck2_id": 202,
	})

	editor.call("_go_back_to_return_scene")
	var context: Dictionary = GameManager.call("consume_deck_editor_return_context")

	_set_navigation_suppressed(false)
	return run_checks([
		assert_eq(str(context.get("return_scene", "")), "battle_setup", "Leaving DeckEditor toward battle_setup should restore the same return scene context"),
		assert_eq(int(context.get("deck1_id", 0)), 101, "Leaving DeckEditor toward battle_setup should preserve deck1 selection"),
		assert_eq(int(context.get("deck2_id", 0)), 202, "Leaving DeckEditor toward battle_setup should preserve deck2 selection"),
	])


# -- _do_replace --

func test_replace_decrements_old_card_count() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	var new_card := _make_card("SV2", "010", "喷火龙", "Pokemon")
	editor.call("_do_replace", 0, new_card)

	var pikachu_count: int = deck.cards[0].get("count", 0)
	var pikachu_name: String = deck.cards[0].get("name", "")

	return run_checks([
		assert_eq(pikachu_count, 1, "替换后皮卡丘数量应减为 1"),
		assert_eq(pikachu_name, "皮卡丘", "条目 0 仍应是皮卡丘"),
		assert_eq(deck.total_cards, 4, "总数应不变（一进一出）"),
	])


func test_replace_removes_entry_when_count_reaches_zero() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	var new_card := _make_card("SV2", "010", "喷火龙", "Pokemon")
	# 替换博士（count=1），应被移除
	editor.call("_do_replace", 1, new_card)

	var has_professor := false
	for entry: Dictionary in deck.cards:
		if entry.get("name", "") == "博士":
			has_professor = true
			break

	return run_checks([
		assert_false(has_professor, "博士 count=1 被替换后应从列表中移除"),
		assert_eq(deck.total_cards, 4, "总数应不变"),
	])


func test_replace_increments_existing_target() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	# 用已存在的皮卡丘替换博士
	var pikachu := _make_card("SV1", "001", "皮卡丘", "Pokemon")
	editor.call("_do_replace", 1, pikachu)

	var pikachu_count := 0
	for entry: Dictionary in deck.cards:
		if entry.get("name", "") == "皮卡丘":
			pikachu_count = entry.get("count", 0)
			break

	return run_checks([
		assert_eq(pikachu_count, 3, "皮卡丘替换入后应为 3 张"),
		assert_eq(deck.total_cards, 4, "总数应不变"),
	])


func test_replace_adds_new_entry_for_unknown_card() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	var charizard := _make_card("SV2", "010", "喷火龙ex", "Pokemon")
	editor.call("_do_replace", 0, charizard)

	var found_charizard := false
	for entry: Dictionary in deck.cards:
		if entry.get("name", "") == "喷火龙ex":
			found_charizard = true
			break

	return run_checks([
		assert_true(found_charizard, "新卡喷火龙ex 应出现在卡组中"),
		assert_eq(deck.total_cards, 4, "总数应不变"),
	])


func test_replace_sets_dirty_flag() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	var before: bool = editor.get("_dirty")
	var new_card := _make_card("SV2", "010", "喷火龙", "Pokemon")
	editor.call("_do_replace", 0, new_card)
	var after: bool = editor.get("_dirty")

	return run_checks([
		assert_false(before, "初始 dirty 应为 false"),
		assert_true(after, "替换后 dirty 应为 true"),
	])


# -- _category_for_type --

func test_category_for_type_maps_correctly() -> String:
	var editor: Control = DeckEditorScript.new()

	var pokemon: int = editor.call("_category_for_type", "Pokemon")
	var supporter: int = editor.call("_category_for_type", "Supporter")
	var item: int = editor.call("_category_for_type", "Item")
	var tool_cat: int = editor.call("_category_for_type", "Tool")
	var stadium: int = editor.call("_category_for_type", "Stadium")
	var basic_energy: int = editor.call("_category_for_type", "Basic Energy")
	var special_energy: int = editor.call("_category_for_type", "Special Energy")

	return run_checks([
		assert_eq(pokemon, 0, "Pokemon 应对应分类 0"),
		assert_eq(supporter, 1, "Supporter 应对应分类 1"),
		assert_eq(item, 2, "Item 应对应分类 2"),
		assert_eq(tool_cat, 3, "Tool 应对应分类 3"),
		assert_eq(stadium, 4, "Stadium 应对应分类 4"),
		assert_eq(basic_energy, 5, "Basic Energy 应对应分类 5"),
		assert_eq(special_energy, 5, "Special Energy 应对应分类 5"),
	])


# -- _build_deck_categories --

func test_build_deck_categories_groups_by_type() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)
	editor.call("_build_deck_categories")

	var deck_by_cat: Array[Array] = editor.get("_deck_by_category")
	var pokemon_count := deck_by_cat[0].size()  # 宝可梦：皮卡丘 ×2 = 2 个 flat 条目
	var supporter_count := deck_by_cat[1].size()  # 支援者：博士 ×1 = 1
	var energy_count := deck_by_cat[5].size()  # 能量：雷能量 ×1 = 1
	var item_count := deck_by_cat[2].size()  # 物品：0

	return run_checks([
		assert_eq(pokemon_count, 2, "宝可梦分类应有 2 个 flat 条目（皮卡丘 ×2）"),
		assert_eq(supporter_count, 1, "支援者分类应有 1 个 flat 条目（博士 ×1）"),
		assert_eq(energy_count, 1, "能量分类应有 1 个 flat 条目（雷能量 ×1）"),
		assert_eq(item_count, 0, "物品分类应为空"),
	])


# -- _is_excluded_card --

func test_utest_cards_are_excluded() -> String:
	var editor: Control = DeckEditorScript.new()
	var utest := _make_card("UTEST", "001", "Dynamic Registration", "Pokemon")
	var real := _make_card("CSV1C", "050", "皮卡丘", "Pokemon")

	var excluded_utest: bool = editor.call("_is_excluded_card", utest)
	var excluded_real: bool = editor.call("_is_excluded_card", real)

	return run_checks([
		assert_true(excluded_utest, "UTEST 系列卡牌应被排除"),
		assert_false(excluded_real, "正常卡牌不应被排除"),
	])


# -- _ordered_pokemon_cards --

func test_ordered_pokemon_cards_groups_by_energy() -> String:
	var editor: Control = DeckEditorScript.new()

	var fire1 := _make_card("SV1", "001", "小火龙", "Pokemon")
	fire1.energy_type = "R"
	var water1 := _make_card("SV1", "002", "杰尼龟", "Pokemon")
	water1.energy_type = "W"
	var fire2 := _make_card("SV1", "003", "火恐龙", "Pokemon")
	fire2.energy_type = "R"

	var cards: Array = [fire1, water1, fire2]
	var ordered: Array = editor.call("_ordered_pokemon_cards", cards)

	# 火(R) 排在 水(W) 前面
	return run_checks([
		assert_eq((ordered[0] as CardData).name, "小火龙", "第一个应是火属性卡"),
		assert_eq((ordered[1] as CardData).name, "火恐龙", "第二个应是火属性卡"),
		assert_eq((ordered[2] as CardData).name, "杰尼龟", "第三个应是水属性卡"),
	])


# -- AI prompt/payload --

func test_build_ai_system_prompt_contains_key_instructions() -> String:
	var editor: Control = DeckEditorScript.new()
	var prompt: String = editor.call("_build_ai_system_prompt")

	return run_checks([
		assert_true(prompt.contains("PTCG"), "系统提示应包含 PTCG"),
		assert_true(prompt.contains("max_changes"), "系统提示应提及 max_changes 约束"),
		assert_true(prompt.contains("available_pool"), "系统提示应提及可选卡池"),
		assert_true(prompt.contains("ACE SPEC"), "系统提示应提及 ACE SPEC 规则"),
		assert_true(prompt.contains("replacements"), "系统提示应要求 JSON replacements 格式"),
	])


func test_build_ai_user_data_structure() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)
	# 需要初始化 _pool_by_category 以便构建 available_pool
	editor.set("_pool_by_category", [[], [], [], [], [], []] as Array[Array])

	var target := DeckData.new()
	target.deck_name = "对手"
	target.cards = [{"name": "X", "card_type": "Pokemon", "count": 1}]
	var targets: Array[DeckData] = [target]
	var goals: Array[String] = ["damage"]

	var data: Dictionary = editor.call("_build_ai_user_data", targets, goals)

	var current: Dictionary = data.get("current_deck", {})
	var target_arr: Array = data.get("target_decks", [])
	var goal_arr: Array = data.get("optimization_goals", [])

	return run_checks([
		assert_eq(str(current.get("deck_name", "")), "测试卡组", "应包含当前卡组名"),
		assert_eq(int(current.get("total_cards", 0)), 4, "应包含正确总数"),
		assert_eq(target_arr.size(), 1, "应有 1 个针对卡组"),
		assert_eq(str(target_arr[0].get("deck_name", "")), "对手", "针对卡组名正确"),
		assert_eq(goal_arr.size(), 1, "应有 1 个优化方向"),
		assert_eq(int(data.get("max_changes", 0)), 8, "应包含 max_changes"),
		assert_true(data.has("available_pool"), "应包含可选卡池"),
	])


# -- GameManager deck editor navigation --

func test_deck_editor_id_is_one_shot() -> String:
	var gm_script: GDScript = load("res://scripts/autoload/GameManager.gd")
	var manager: Node = gm_script.new()

	manager.set("_deck_editor_deck_id", 42)
	var first: int = manager.call("consume_deck_editor_id")
	var second: int = manager.call("consume_deck_editor_id")

	return run_checks([
		assert_eq(first, 42, "首次 consume 应返回设置的 ID"),
		assert_eq(second, -1, "二次 consume 应返回 -1（已消费）"),
	])
