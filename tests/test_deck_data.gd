## DeckData 单元测试
class_name TestDeckData
extends TestBase


func _make_valid_deck() -> DeckData:
	var deck := DeckData.new()
	deck.id = 12345
	deck.deck_name = "测试卡组"
	deck.source_url = "https://tcg.mik.moe/decks/list/12345"
	deck.import_date = "2025-01-01T00:00:00"
	deck.variant_name = "测试变体"
	deck.deck_code = "ABCDEF"
	deck.total_cards = 60
	# 4种宝可梦各4张=16 + 11种物品各4张=44 = 60
	for i in 4:
		deck.cards.append({"set_code": "SV1", "card_index": "%03d" % (i+1), "count": 4, "card_type": "Pokemon", "name": "宝可梦%d" % (i+1)})
	for i in 11:
		deck.cards.append({"set_code": "SV1", "card_index": "%03d" % (i+10), "count": 4, "card_type": "Item", "name": "物品%d" % (i+1)})
	return deck


func test_from_api_response() -> String:
	var api_data := {
		"deckCode": "XYZABC", "variant": {"variantName": "测试变体"},
		"cards": [
			{"setCode": "SV1", "cardIndex": "001", "count": 4, "cardType": "Pokemon", "cardName": "小火龙", "effectId": "e1", "nameEn": "Charmander"},
			{"setCode": "SV1", "cardIndex": "010", "count": 4, "cardType": "Item", "cardName": "精灵球", "effectId": "e2", "nameEn": "Poke Ball"},
		],
	}
	var deck := DeckData.from_api_response(99999, api_data)
	return run_checks([
		assert_eq(deck.id, 99999, "ID"),
		assert_eq(deck.deck_name, "测试变体", "名称"),
		assert_eq(deck.deck_code, "XYZABC", "代码"),
		assert_eq(deck.cards.size(), 2, "条目数"),
		assert_eq(deck.total_cards, 8, "总数"),
		assert_str_contains(deck.source_url, "99999", "URL含ID"),
	])


func test_from_api_no_variant_name() -> String:
	var api_data := {"deckCode": "ABC", "variant": {"variantName": ""}, "cards": []}
	var deck := DeckData.from_api_response(42, api_data)
	return assert_eq(deck.deck_name, "卡组 42", "无变体名时默认名")


func test_validate_correct_deck() -> String:
	var deck := _make_valid_deck()
	return assert_eq(deck.validate().size(), 0, "合法卡组无错误")


func test_validate_wrong_total() -> String:
	var deck := _make_valid_deck()
	deck.total_cards = 59
	var errors := deck.validate()
	return run_checks([
		assert_gt(errors.size(), 0, "非60张应报错"),
		assert_str_contains(errors[0], "59", "错误含数量"),
	])


func test_validate_over_4_copies() -> String:
	var deck := DeckData.new()
	deck.total_cards = 60
	deck.cards = [{"set_code": "SV1", "card_index": "001", "count": 5, "card_type": "Pokemon", "name": "小火龙"}]
	var errors := deck.validate()
	return run_checks([
		assert_gt(errors.size(), 0, "5张同名应报错"),
		assert_str_contains(errors[0], "小火龙", "错误含卡名"),
	])


func test_validate_basic_energy_unlimited() -> String:
	var deck := DeckData.new()
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "SVE", "card_index": "001", "count": 30, "card_type": "Basic Energy", "name": "火能量"},
		{"set_code": "SVE", "card_index": "002", "count": 30, "card_type": "Basic Energy", "name": "水能量"},
	]
	return assert_eq(deck.validate().size(), 0, "基本能量不受4张限制")


func test_get_card_keys() -> String:
	var deck := DeckData.new()
	deck.cards = [{"set_code": "SV1", "card_index": "001"}, {"set_code": "SV2", "card_index": "010"}]
	var keys := deck.get_card_keys()
	return run_checks([
		assert_eq(keys.size(), 2, "键数"),
		assert_eq(keys[0]["set_code"], "SV1", "第一张"),
		assert_eq(keys[1]["card_index"], "010", "第二张"),
	])


func test_to_dict_from_dict_roundtrip() -> String:
	var original := _make_valid_deck()
	var restored := DeckData.from_dict(original.to_dict())
	return run_checks([
		assert_eq(restored.id, original.id, "ID"),
		assert_eq(restored.deck_name, original.deck_name, "名称"),
		assert_eq(restored.total_cards, original.total_cards, "总数"),
		assert_eq(restored.cards.size(), original.cards.size(), "条目数"),
		assert_eq(restored.deck_code, original.deck_code, "代码"),
	])
