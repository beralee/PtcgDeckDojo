## DeckImporter 单元测试（仅测试纯函数部分，不测试网络）
class_name TestDeckImporter
extends TestBase


func test_parse_deck_id_full_url() -> String:
	var id := DeckImporter.parse_deck_id("https://tcg.mik.moe/decks/list/574793")
	return assert_eq(id, 574793, "完整URL解析")


func test_parse_deck_id_with_query() -> String:
	var id := DeckImporter.parse_deck_id("https://tcg.mik.moe/decks/list/574793?tab=cards")
	return assert_eq(id, 574793, "带查询参数URL解析")


func test_parse_deck_id_number_only() -> String:
	var id := DeckImporter.parse_deck_id("574793")
	return assert_eq(id, 574793, "纯数字解析")


func test_parse_deck_id_number_with_spaces() -> String:
	var id := DeckImporter.parse_deck_id("  574793  ")
	return assert_eq(id, 574793, "带空格数字解析")


func test_parse_deck_id_invalid() -> String:
	var id := DeckImporter.parse_deck_id("not_a_valid_url")
	return assert_eq(id, -1, "无效输入返回-1")


func test_parse_deck_id_empty() -> String:
	var id := DeckImporter.parse_deck_id("")
	return assert_eq(id, -1, "空字符串返回-1")


func test_parse_deck_id_partial_url() -> String:
	var id := DeckImporter.parse_deck_id("decks/list/12345")
	return assert_eq(id, 12345, "部分URL解析")


func test_parse_deck_id_different_numbers() -> String:
	return run_checks([
		assert_eq(DeckImporter.parse_deck_id("1"), 1, "ID=1"),
		assert_eq(DeckImporter.parse_deck_id("999999"), 999999, "ID=999999"),
		assert_eq(DeckImporter.parse_deck_id("https://tcg.mik.moe/decks/list/1"), 1, "URL ID=1"),
	])


func test_imported_card_uses_image_metadata_defaults() -> String:
	var json := {
		"name": "妙蛙种子",
		"cardType": "Pokemon",
		"setCode": "151C",
		"cardIndex": "001",
	}
	var card := CardData.from_api_json(json)
	return run_checks([
		assert_eq(card.image_url, "https://tcg.mik.moe/static/img/151C/001.png", "卡图URL默认值"),
		assert_eq(card.image_local_path, "user://cards/images/151C/001.png", "卡图本地路径默认值"),
	])
