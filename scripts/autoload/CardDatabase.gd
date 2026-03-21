## 全局卡牌数据库 - 管理卡牌缓存和卡组持久化
extends Node

## 卡牌缓存目录
const CARDS_DIR := "user://cards/"
const CARD_IMAGES_DIR := "user://cards/images/"
## 卡组存储目录
const DECKS_DIR := "user://decks/"

## 内存中的卡牌缓存 {uid -> CardData}
var _card_cache: Dictionary = {}
## 内存中的卡组缓存 {deck_id -> DeckData}
var _deck_cache: Dictionary = {}

## 卡组列表变更信号
signal decks_changed()


func _ready() -> void:
	_ensure_directories()
	_load_all_decks()


## 确保数据目录存在
func _ensure_directories() -> void:
	if not DirAccess.dir_exists_absolute(CARDS_DIR):
		DirAccess.make_dir_recursive_absolute(CARDS_DIR)
	if not DirAccess.dir_exists_absolute(CARD_IMAGES_DIR):
		DirAccess.make_dir_recursive_absolute(CARD_IMAGES_DIR)
	if not DirAccess.dir_exists_absolute(DECKS_DIR):
		DirAccess.make_dir_recursive_absolute(DECKS_DIR)


# === 卡牌操作 ===

## 是否已缓存指定卡牌
func has_card(set_code: String, card_index: String) -> bool:
	var uid := "%s_%s" % [set_code, card_index]
	if _card_cache.has(uid):
		return true
	# 检查文件系统
	return FileAccess.file_exists(CARDS_DIR + uid + ".json")


## 获取卡牌数据（先查内存，再查文件）
func get_card(set_code: String, card_index: String) -> CardData:
	var uid := "%s_%s" % [set_code, card_index]

	# 内存缓存
	if _card_cache.has(uid):
		return _card_cache[uid]

	# 文件缓存
	var path := CARDS_DIR + uid + ".json"
	if FileAccess.file_exists(path):
		var card := _load_card_from_file(path)
		if card:
			_card_cache[uid] = card
			return card

	return null


func get_all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	var seen := {}

	for uid: Variant in _card_cache.keys():
		var card: CardData = _card_cache[uid]
		if card == null:
			continue
		result.append(card)
		seen[uid] = true

	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var uid := file_name.trim_suffix(".json")
			if not seen.has(uid):
				var card := _load_card_from_file(CARDS_DIR + file_name)
				if card:
					_card_cache[uid] = card
					result.append(card)
		file_name = dir.get_next()
	dir.list_dir_end()

	result.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.get_uid() < b.get_uid()
	)
	return result


## 缓存卡牌数据（写入内存和文件）
func cache_card(card: CardData) -> void:
	card.ensure_image_metadata()
	var uid := card.get_uid()
	_card_cache[uid] = card
	_save_card_to_file(card)


func save_card_image(card: CardData, image_bytes: PackedByteArray) -> int:
	card.ensure_image_metadata()
	if card.image_local_path == "":
		return ERR_INVALID_PARAMETER
	if image_bytes.is_empty():
		return ERR_INVALID_DATA

	var image_dir := card.image_local_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(image_dir):
		var mkdir_err := DirAccess.make_dir_recursive_absolute(image_dir)
		if mkdir_err != OK:
			push_error("CardDatabase: 无法创建卡图目录 %s" % image_dir)
			return mkdir_err

	var file := FileAccess.open(card.image_local_path, FileAccess.WRITE)
	if file == null:
		var open_err := FileAccess.get_open_error()
		push_error("CardDatabase: 无法写入卡图文件 %s" % card.image_local_path)
		return open_err
	file.store_buffer(image_bytes)
	file.close()

	_card_cache[card.get_uid()] = card
	_save_card_to_file(card)
	return OK


## 从文件加载卡牌
func _load_card_from_file(path: String) -> CardData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) != OK:
		return null
	if json.data is not Dictionary:
		return null
	return CardData.from_dict(json.data)


## 保存卡牌到文件
func _save_card_to_file(card: CardData) -> void:
	var uid := card.get_uid()
	var path := CARDS_DIR + uid + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CardDatabase: 无法写入卡牌文件 %s" % path)
		return
	file.store_string(JSON.stringify(card.to_dict(), "\t"))
	file.close()


# === 卡组操作 ===

## 保存卡组
func save_deck(deck: DeckData) -> void:
	var path := DECKS_DIR + "%d.json" % deck.id
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CardDatabase: 无法写入卡组文件 %s" % path)
		return
	file.store_string(JSON.stringify(deck.to_dict(), "\t"))
	file.close()
	_deck_cache[deck.id] = deck
	decks_changed.emit()


## 删除卡组
func delete_deck(deck_id: int) -> void:
	var path := DECKS_DIR + "%d.json" % deck_id
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_deck_cache.erase(deck_id)
	decks_changed.emit()


## 获取卡组
func get_deck(deck_id: int) -> DeckData:
	return _deck_cache.get(deck_id)


## 获取所有卡组列表
func get_all_decks() -> Array[DeckData]:
	var result: Array[DeckData] = []
	for deck: Variant in _deck_cache.values():
		result.append(deck)
	# 按导入时间排序（新的在前）
	result.sort_custom(func(a: DeckData, b: DeckData) -> bool:
		return a.import_date > b.import_date
	)
	return result


## 是否存在指定卡组
func has_deck(deck_id: int) -> bool:
	return _deck_cache.has(deck_id)


## 从文件系统加载所有卡组
func _load_all_decks() -> void:
	_deck_cache.clear()
	var dir := DirAccess.open(DECKS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var deck := _load_deck_from_file(DECKS_DIR + file_name)
			if deck:
				_deck_cache[deck.id] = deck
		file_name = dir.get_next()
	dir.list_dir_end()


## 从文件加载卡组
func _load_deck_from_file(path: String) -> DeckData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) != OK:
		return null
	if json.data is not Dictionary:
		return null
	return DeckData.from_dict(json.data)


## 为指定卡组构建完整的 CardInstance 列表（用于开始对战）
## 返回60张卡牌实例数组
func build_deck_instances(deck: DeckData, owner_index: int) -> Array[CardInstance]:
	var instances: Array[CardInstance] = []
	for entry: Dictionary in deck.cards:
		var set_code: String = entry.get("set_code", "")
		var card_index: String = entry.get("card_index", "")
		var count: int = entry.get("count", 1)
		var card_data := get_card(set_code, card_index)
		if card_data == null:
			push_warning("CardDatabase: 卡牌 %s/%s 未找到" % [set_code, card_index])
			continue
		for i in count:
			instances.append(CardInstance.create(card_data, owner_index))
	return instances
