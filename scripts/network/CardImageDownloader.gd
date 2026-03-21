class_name CardImageDownloader
extends Node

signal progress(current: int, total: int, message: String)
signal completed(stats: Dictionary, errors: PackedStringArray)
signal failed(error_message: String)

var _http_request: HTTPRequest = null
var _queue: Array[CardData] = []
var _errors: PackedStringArray = PackedStringArray()
var _current_index: int = 0
var _downloaded_count: int = 0
var _updated_count: int = 0
var _skipped_count: int = 0
var _is_running: bool = false


func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 20.0
	add_child(_http_request)


func sync_cached_cards() -> void:
	sync_cards(CardDatabase.get_all_cards())


func sync_cards(cards: Array[CardData]) -> void:
	if _is_running:
		failed.emit("已有卡图同步任务正在进行")
		return

	_queue = _dedupe_cards(cards)
	_errors = PackedStringArray()
	_current_index = 0
	_downloaded_count = 0
	_updated_count = 0
	_skipped_count = 0

	if _queue.is_empty():
		progress.emit(0, 0, "没有需要同步的卡牌")
		completed.emit(_build_stats(), _errors)
		return

	_is_running = true
	_process_next_card()


func _dedupe_cards(cards: Array[CardData]) -> Array[CardData]:
	var result: Array[CardData] = []
	var seen := {}
	for card: CardData in cards:
		if card == null:
			continue
		card.ensure_image_metadata()
		var uid := card.get_uid()
		if uid == "" or seen.has(uid):
			continue
		seen[uid] = true
		result.append(card)

	result.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.get_uid() < b.get_uid()
	)
	return result


func _process_next_card() -> void:
	if _current_index >= _queue.size():
		_finish()
		return

	var total := _queue.size()
	var card := _queue[_current_index]
	var metadata_changed := card.ensure_image_metadata()

	if card.has_local_image():
		if metadata_changed:
			CardDatabase.cache_card(card)
			_updated_count += 1
		else:
			_skipped_count += 1
		progress.emit(_current_index + 1, total, "已检查卡图 %d/%d" % [_current_index + 1, total])
		call_deferred("_advance_queue")
		return

	var callback := _on_image_response.bind(card, metadata_changed)
	_http_request.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var err := _http_request.request(
		card.image_url,
		PackedStringArray(["User-Agent: PTCGTrain/1.0"]),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		if _http_request.request_completed.is_connected(callback):
			_http_request.request_completed.disconnect(callback)
		if metadata_changed:
			CardDatabase.cache_card(card)
		_errors.append("下载卡图 %s 失败: 网络错误 %d" % [card.get_uid(), err])
		progress.emit(_current_index + 1, total, "下载卡图失败 %d/%d" % [_current_index + 1, total])
		call_deferred("_advance_queue")
		return

	progress.emit(_current_index, total, "正在下载卡图 %d/%d: %s" % [_current_index + 1, total, card.get_uid()])


func _on_image_response(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	card: CardData,
	metadata_changed: bool
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and not body.is_empty():
		var save_err := CardDatabase.save_card_image(card, body)
		if save_err == OK:
			_downloaded_count += 1
		else:
			_errors.append("保存卡图 %s 失败: 错误码 %d" % [card.get_uid(), save_err])
	elif result == HTTPRequest.RESULT_SUCCESS:
		if metadata_changed:
			CardDatabase.cache_card(card)
		_errors.append("下载卡图 %s 失败: HTTP %d" % [card.get_uid(), response_code])
	else:
		if metadata_changed:
			CardDatabase.cache_card(card)
		_errors.append("下载卡图 %s 失败: result=%d" % [card.get_uid(), result])

	progress.emit(_current_index + 1, _queue.size(), "已处理卡图 %d/%d" % [_current_index + 1, _queue.size()])
	_advance_queue()


func _advance_queue() -> void:
	_current_index += 1
	_process_next_card()


func _finish() -> void:
	_is_running = false
	completed.emit(_build_stats(), _errors)


func _build_stats() -> Dictionary:
	return {
		"total": _queue.size(),
		"downloaded": _downloaded_count,
		"updated": _updated_count,
		"skipped": _skipped_count,
	}
