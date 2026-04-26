## 全局卡牌数据库 - 管理卡牌缓存和卡组持久化
extends Node

## 卡牌缓存目录
const CARDS_DIR := "user://cards/"
const CARD_IMAGES_DIR := "user://cards/images/"
## 卡组存储目录
const DECKS_DIR := "user://decks/"
const AI_DECKS_DIR := "user://ai_decks/"
const BUNDLED_USER_DIR := "res://data/bundled_user/"
const BUNDLED_CARDS_DIR := BUNDLED_USER_DIR + "cards/"
const BUNDLED_DECKS_DIR := BUNDLED_USER_DIR + "decks/"
const BUNDLED_MANIFEST := BUNDLED_USER_DIR + "_manifest.txt"
const SUPPORTED_AI_DECK_IDS: Array[int] = [569061, 575657, 575716, 575718, 575720, 575723, 578647, 579502]

## 内存中的卡牌缓存 {uid -> CardData}
var _card_cache: Dictionary = {}
## 内存中的卡组缓存 {deck_id -> DeckData}
var _deck_cache: Dictionary = {}
var _ai_deck_cache: Dictionary = {}

## 卡组列表变更信号
signal decks_changed()


func _ready() -> void:
	_ensure_directories()
	_seed_bundled_user_data()
	_load_all_decks()
	_load_all_ai_decks()


## 确保数据目录存在
func _ensure_directories() -> void:
	if not DirAccess.dir_exists_absolute(CARDS_DIR):
		DirAccess.make_dir_recursive_absolute(CARDS_DIR)
	if not DirAccess.dir_exists_absolute(CARD_IMAGES_DIR):
		DirAccess.make_dir_recursive_absolute(CARD_IMAGES_DIR)
	if not DirAccess.dir_exists_absolute(DECKS_DIR):
		DirAccess.make_dir_recursive_absolute(DECKS_DIR)
	if not DirAccess.dir_exists_absolute(AI_DECKS_DIR):
		DirAccess.make_dir_recursive_absolute(AI_DECKS_DIR)


func _seed_bundled_user_data() -> void:
	var manifest := _load_bundled_manifest()
	for bundled_path: String in manifest:
		if bundled_path.ends_with(".import"):
			continue
		var relative := bundled_path.trim_prefix(BUNDLED_USER_DIR)
		if relative.begins_with("cards/"):
			var entry_name := relative.get_file()
			var sub_dir := relative.trim_prefix("cards/").get_base_dir()
			var target_dir := CARDS_DIR
			if sub_dir != "":
				target_dir = CARDS_DIR.path_join(sub_dir)
			var target_path := _resolve_bundled_target_path(target_dir, entry_name)
			_copy_file_if_missing(bundled_path, target_path)
		elif relative.begins_with("decks/"):
			var entry_name := relative.get_file()
			var target_path := DECKS_DIR.path_join(entry_name)
			_copy_file_if_missing(bundled_path, target_path)
	_backfill_deck_strategy_from_bundled(manifest)


## 读取清单文件（导出后 DirAccess 无法遍历 pck，需要预生成清单）
func _load_bundled_manifest() -> Array[String]:
	var results: Array[String] = []
	if not FileAccess.file_exists(BUNDLED_MANIFEST):
		# 回退：编辑器中直接遍历目录生成清单
		return _scan_bundled_dir_recursive(BUNDLED_USER_DIR)
	var file := FileAccess.open(BUNDLED_MANIFEST, FileAccess.READ)
	if file == null:
		return results
	var text := file.get_as_text()
	file.close()
	for line: String in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed != "":
			results.append(trimmed)
	return results


## 编辑器回退：递归遍历目录
func _scan_bundled_dir_recursive(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with(".") and not entry.ends_with(".import"):
			var full_path := dir_path.path_join(entry)
			if dir.current_is_dir():
				results.append_array(_scan_bundled_dir_recursive(full_path))
			else:
				results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return results


func _backfill_deck_strategy_from_bundled(manifest: Array[String]) -> void:
	for bundled_path: String in manifest:
		if not bundled_path.begins_with(BUNDLED_DECKS_DIR):
			continue
		if not bundled_path.ends_with(".json"):
			continue
		var entry_name := bundled_path.get_file()
		var user_path := DECKS_DIR.path_join(entry_name)
		if FileAccess.file_exists(user_path):
			_merge_strategy_field(bundled_path, user_path)


func _seed_ai_decks_from_bundled(manifest: Array[String]) -> void:
	for deck_id: int in SUPPORTED_AI_DECK_IDS:
		var entry_name := "%d.json" % deck_id
		var bundled_path := BUNDLED_DECKS_DIR.path_join(entry_name)
		var ai_target_path := AI_DECKS_DIR.path_join(entry_name)
		if bundled_path in manifest and FileAccess.file_exists(bundled_path):
			_copy_file_if_missing(bundled_path, ai_target_path)
			_merge_strategy_field(bundled_path, ai_target_path)
			continue
		var user_path := DECKS_DIR.path_join(entry_name)
		if FileAccess.file_exists(user_path):
			_copy_file_if_missing(user_path, ai_target_path)


func _merge_strategy_field(bundled_path: String, user_path: String) -> void:
	var bf := FileAccess.open(bundled_path, FileAccess.READ)
	if bf == null:
		return
	var bundled_data: Variant = JSON.parse_string(bf.get_as_text())
	bf.close()
	if not bundled_data is Dictionary:
		return
	var bundled_strategy: String = (bundled_data as Dictionary).get("strategy", "")
	if bundled_strategy == "":
		return

	var uf := FileAccess.open(user_path, FileAccess.READ)
	if uf == null:
		return
	var user_data: Variant = JSON.parse_string(uf.get_as_text())
	uf.close()
	if not user_data is Dictionary:
		return

	var user_dict := user_data as Dictionary
	var existing: String = user_dict.get("strategy", "")
	if existing.strip_edges() != "" and not _is_legacy_raging_bolt_strategy_text(user_dict, existing):
		return

	user_dict["strategy"] = bundled_strategy
	var wf := FileAccess.open(user_path, FileAccess.WRITE)
	if wf == null:
		return
	wf.store_string(JSON.stringify(user_dict, "\t"))
	wf.close()


func _is_legacy_raging_bolt_strategy_text(deck_data: Dictionary, strategy_text: String) -> bool:
	if int(deck_data.get("id", -1)) != 575718:
		return false
	return strategy_text.contains("从弃牌区") and strategy_text.contains("猛雷鼓") and strategy_text.contains("厄诡椪")


func _resolve_bundled_target_path(target_dir_path: String, entry_name: String) -> String:
	if entry_name.ends_with(".bin"):
		return target_dir_path.path_join(entry_name.trim_suffix(".bin"))
	return target_dir_path.path_join(entry_name)


func _copy_missing_files_recursive(source_dir_path: String, target_dir_path: String) -> void:
	var dir := DirAccess.open(source_dir_path)
	if dir == null:
		return
	if not DirAccess.dir_exists_absolute(target_dir_path):
		DirAccess.make_dir_recursive_absolute(target_dir_path)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var source_path := source_dir_path.path_join(entry)
		if dir.current_is_dir():
			_copy_missing_files_recursive(source_path, target_dir_path.path_join(entry))
		elif not entry.ends_with(".import"):
			var target_path := _resolve_bundled_target_path(target_dir_path, entry)
			_copy_file_if_missing(source_path, target_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _copy_file_if_missing(source_path: String, target_path: String) -> void:
	if FileAccess.file_exists(target_path):
		return
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		push_warning("CardDatabase: 无法读取内置文件 %s" % source_path)
		return
	var target_dir := target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	var target_file := FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		push_warning("CardDatabase: 无法写入预置文件 %s" % target_path)
		source_file.close()
		return
	target_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	target_file.close()
	source_file.close()


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


func save_ai_deck(deck: DeckData) -> void:
	if deck != null and SUPPORTED_AI_DECK_IDS.has(deck.id):
		var bundled_ai_deck := _load_bundled_ai_deck(deck.id)
		if bundled_ai_deck != null:
			_ai_deck_cache[deck.id] = bundled_ai_deck
		return
	var path := AI_DECKS_DIR + "%d.json" % deck.id
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CardDatabase: 无法写入 AI 卡组文件 %s" % path)
		return
	file.store_string(JSON.stringify(deck.to_dict(), "\t"))
	file.close()
	_ai_deck_cache[deck.id] = deck


func delete_ai_deck(deck_id: int) -> void:
	if SUPPORTED_AI_DECK_IDS.has(deck_id):
		var bundled_ai_deck := _load_bundled_ai_deck(deck_id)
		if bundled_ai_deck != null:
			_ai_deck_cache[deck_id] = bundled_ai_deck
		return
	var path := AI_DECKS_DIR + "%d.json" % deck_id
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_ai_deck_cache.erase(deck_id)


## 删除卡组
func delete_deck(deck_id: int) -> void:
	var path := DECKS_DIR + "%d.json" % deck_id
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_deck_cache.erase(deck_id)
	decks_changed.emit()


## 获取卡组
func get_deck(deck_id: int) -> DeckData:
	_ensure_deck_cache_ready()
	return _deck_cache.get(deck_id)


func get_ai_deck(deck_id: int) -> DeckData:
	_ensure_ai_deck_cache_ready()
	return _ai_deck_cache.get(deck_id)


## 获取所有卡组列表
func get_all_decks() -> Array[DeckData]:
	_ensure_deck_cache_ready()
	return _sorted_deck_values(_deck_cache)


func get_all_ai_decks() -> Array[DeckData]:
	_ensure_ai_deck_cache_ready()
	var result: Array[DeckData] = []
	for deck_id: int in SUPPORTED_AI_DECK_IDS:
		var deck: DeckData = _ai_deck_cache.get(deck_id)
		if deck != null:
			result.append(deck)
	return result


## 是否存在指定卡组
func has_deck(deck_id: int) -> bool:
	_ensure_deck_cache_ready()
	return _deck_cache.has(deck_id)


func has_ai_deck(deck_id: int) -> bool:
	_ensure_ai_deck_cache_ready()
	return _ai_deck_cache.has(deck_id)


func get_supported_ai_deck_ids() -> Array[int]:
	return SUPPORTED_AI_DECK_IDS.duplicate()


## 从文件系统加载所有卡组
func _load_all_decks() -> void:
	_deck_cache = _load_deck_cache_from_dir(DECKS_DIR)


func _load_all_ai_decks() -> void:
	_ai_deck_cache = _load_deck_cache_from_dir(AI_DECKS_DIR)
	for deck_id: int in SUPPORTED_AI_DECK_IDS:
		var bundled_ai_deck := _load_bundled_ai_deck(deck_id)
		if bundled_ai_deck != null:
			_ai_deck_cache[deck_id] = bundled_ai_deck


func _ensure_deck_cache_ready() -> void:
	if not _deck_cache.is_empty():
		return
	_ensure_directories()
	_seed_bundled_user_data()
	_load_all_decks()


func _ensure_ai_deck_cache_ready() -> void:
	if not _ai_deck_cache.is_empty():
		return
	_ensure_deck_cache_ready()
	_load_all_ai_decks()


func _load_bundled_ai_deck(deck_id: int) -> DeckData:
	var bundled_path := BUNDLED_DECKS_DIR.path_join("%d.json" % deck_id)
	if not FileAccess.file_exists(bundled_path):
		return null
	return _load_deck_from_file(bundled_path)


func _load_deck_cache_from_dir(dir_path: String) -> Dictionary:
	var cache := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return cache
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var deck := _load_deck_from_file(dir_path.path_join(file_name))
			if deck:
				cache[deck.id] = deck
		file_name = dir.get_next()
	dir.list_dir_end()
	return cache


func _sorted_deck_values(cache: Dictionary) -> Array[DeckData]:
	var result: Array[DeckData] = []
	for deck: Variant in cache.values():
		result.append(deck)
	result.sort_custom(func(a: DeckData, b: DeckData) -> bool:
		return a.import_date > b.import_date
	)
	return result


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
