## 卡组导入器 - 从 tcg.mik.moe API 获取卡组和卡牌数据
class_name DeckImporter
extends Node

## API 基地址
const API_BASE := "https://tcg.mik.moe"
const DECK_DETAIL_URL := API_BASE + "/api/v3/deck/detail"
const CARD_DETAIL_URL := API_BASE + "/api/v3/card/card-detail"
const CARD_IMAGE_DOWNLOADER := preload("res://scripts/network/CardImageDownloader.gd")

## 导入进度信号
signal import_progress(current: int, total: int, message: String)
## 导入完成信号
signal import_completed(deck: DeckData, errors: PackedStringArray)
## 导入失败信号
signal import_failed(error_message: String)

## HTTP 请求节点
var _http_request: HTTPRequest = null
var _image_downloader = null
var _pending_deck: DeckData = null
var _pending_import_errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 15.0
	add_child(_http_request)

	_image_downloader = CARD_IMAGE_DOWNLOADER.new()
	add_child(_image_downloader)
	_image_downloader.progress.connect(_on_image_sync_progress)
	_image_downloader.completed.connect(_on_image_sync_completed)
	_image_downloader.failed.connect(_on_image_sync_failed)


## 从 tcg.mik.moe 链接中提取 deckId
static func parse_deck_id(url: String) -> int:
	# 格式: https://tcg.mik.moe/decks/list/<id> 或 https://tcg.mik.moe/decks/list/<id>?...
	var regex := RegEx.new()
	regex.compile("decks/list/(\\d+)")
	var result := regex.search(url)
	if result:
		return int(result.get_string(1))
	# 也允许直接输入数字
	if url.strip_edges().is_valid_int():
		return int(url.strip_edges())
	return -1


## 导入卡组完整流程
func import_deck(url_or_id: String) -> void:
	var deck_id := parse_deck_id(url_or_id)
	if deck_id <= 0:
		import_failed.emit("无法识别卡组ID，请输入有效的 tcg.mik.moe 卡组链接")
		return

	import_progress.emit(0, 1, "正在获取卡组数据...")
	_fetch_deck_detail(deck_id)


## 获取卡组详情
func _fetch_deck_detail(deck_id: int) -> void:
	var body := JSON.stringify({"deckId": deck_id})
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"User-Agent: PTCGTrain/1.0",
	])

	var callback := _on_deck_detail_response.bind(deck_id)
	_http_request.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var err := _http_request.request(DECK_DETAIL_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		if _http_request.request_completed.is_connected(callback):
			_http_request.request_completed.disconnect(callback)
		import_failed.emit("网络请求失败，错误码: %d" % err)


func _on_deck_detail_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, deck_id: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		import_failed.emit("网络连接失败 (result=%d)" % result)
		return

	if response_code != 200:
		import_failed.emit("服务器返回错误 (HTTP %d)" % response_code)
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		import_failed.emit("响应数据解析失败")
		return

	var resp: Dictionary = json.data
	if resp.get("code", 0) != 200:
		import_failed.emit("API 错误: %s" % resp.get("msg", "未知错误"))
		return

	var data_raw: Variant = resp.get("data")
	var data: Dictionary = data_raw if data_raw is Dictionary else {}
	var deck := DeckData.from_api_response(deck_id, data)

	# 验证基本合法性
	var errors := deck.validate()

	# 开始逐张获取卡牌详情
	var card_keys := deck.get_card_keys()
	_fetch_cards_sequentially(deck, card_keys, 0, errors)


## 顺序获取所有卡牌详情
func _fetch_cards_sequentially(deck: DeckData, keys: Array[Dictionary], index: int, errors: PackedStringArray) -> void:
	if index >= keys.size():
		_start_image_sync(deck, errors)
		return

	var key: Dictionary = keys[index]
	var set_code: String = key["set_code"]
	var card_index: String = key["card_index"]

	import_progress.emit(index, keys.size(), "正在获取卡牌 %d/%d..." % [index + 1, keys.size()])

	# 检查本地缓存
	if CardDatabase.has_card(set_code, card_index):
		call_deferred("_fetch_cards_sequentially", deck, keys, index + 1, errors)
		return

	# 从 API 获取
	var body := JSON.stringify({"setCode": set_code, "cardIndex": card_index})
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"User-Agent: PTCGTrain/1.0",
	])

	var callback := _on_card_detail_response.bind(deck, keys, index, errors, set_code, card_index)
	_http_request.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var err := _http_request.request(CARD_DETAIL_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		if _http_request.request_completed.is_connected(callback):
			_http_request.request_completed.disconnect(callback)
		errors.append("获取卡牌 %s/%s 失败: 网络错误" % [set_code, card_index])
		_fetch_cards_sequentially(deck, keys, index + 1, errors)


func _on_card_detail_response(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray,
	deck: DeckData, keys: Array[Dictionary], index: int, errors: PackedStringArray,
	set_code: String, card_index: String
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var resp: Dictionary = json.data
			if resp.get("code", 0) == 200:
				var data_raw: Variant = resp.get("data")
				var card_json: Dictionary = data_raw if data_raw is Dictionary else {}
				var card_data := CardData.from_api_json(card_json)
				CardDatabase.cache_card(card_data)
			else:
				errors.append("获取卡牌 %s/%s 失败: %s" % [set_code, card_index, resp.get("msg", "")])
		else:
			errors.append("解析卡牌 %s/%s 数据失败" % [set_code, card_index])
	else:
		errors.append("获取卡牌 %s/%s 网络错误" % [set_code, card_index])

	_fetch_cards_sequentially(deck, keys, index + 1, errors)


func _start_image_sync(deck: DeckData, errors: PackedStringArray) -> void:
	var cards_to_sync: Array[CardData] = []
	for key: Dictionary in deck.get_card_keys():
		var set_code: String = key.get("set_code", "")
		var card_index: String = key.get("card_index", "")
		var card := CardDatabase.get_card(set_code, card_index)
		if card == null:
			errors.append("卡牌 %s/%s 未缓存，跳过卡图同步" % [set_code, card_index])
			continue
		cards_to_sync.append(card)

	if cards_to_sync.is_empty():
		import_progress.emit(deck.cards.size(), deck.cards.size(), "导入完成!")
		import_completed.emit(deck, errors)
		return

	_pending_deck = deck
	_pending_import_errors = PackedStringArray()
	for err: String in errors:
		_pending_import_errors.append(err)

	import_progress.emit(0, cards_to_sync.size(), "正在同步卡图...")
	_image_downloader.sync_cards(cards_to_sync)


func _on_image_sync_progress(current: int, total: int, message: String) -> void:
	import_progress.emit(current, total, message)


func _on_image_sync_completed(stats: Dictionary, errors: PackedStringArray) -> void:
	if _pending_deck == null:
		return

	for err: String in errors:
		_pending_import_errors.append(err)

	var total := int(stats.get("total", 0))
	var deck := _pending_deck
	var combined_errors := _pending_import_errors

	_pending_deck = null
	_pending_import_errors = PackedStringArray()

	import_progress.emit(total, total, "导入完成!")
	import_completed.emit(deck, combined_errors)


func _on_image_sync_failed(error_message: String) -> void:
	if _pending_deck == null:
		return

	_pending_import_errors.append("卡图同步失败: %s" % error_message)
	var deck := _pending_deck
	var combined_errors := _pending_import_errors

	_pending_deck = null
	_pending_import_errors = PackedStringArray()

	import_completed.emit(deck, combined_errors)
