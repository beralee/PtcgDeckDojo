class_name AIFixedDeckOrderRegistry
extends RefCounted

const FIXED_ORDER_DIR := "res://data/bundled_user/ai_fixed_deck_orders"


func get_fixed_order_path(deck_id: int) -> String:
	if deck_id <= 0:
		return ""
	var path := "%s/%d.json" % [FIXED_ORDER_DIR, deck_id]
	return path if FileAccess.file_exists(path) else ""


func has_fixed_order(deck_id: int) -> bool:
	return get_fixed_order_path(deck_id) != ""


func load_fixed_order(deck_id: int) -> Array[Dictionary]:
	return load_fixed_order_from_path(get_fixed_order_path(deck_id))


func load_fixed_order_from_path(path: String) -> Array[Dictionary]:
	if path == "" or not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return _normalize_fixed_order(parsed)


func _normalize_fixed_order(raw: Variant) -> Array[Dictionary]:
	var entries: Array = []
	if raw is Dictionary:
		var top_to_bottom: Variant = raw.get("top_to_bottom", [])
		entries = top_to_bottom if top_to_bottom is Array else []
	elif raw is Array:
		entries = raw

	var normalized: Array[Dictionary] = []
	for entry_variant: Variant in entries:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		if set_code == "" or card_index == "":
			continue
		normalized.append({
			"set_code": set_code,
			"card_index": card_index,
		})
	return normalized
