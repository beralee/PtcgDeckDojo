class_name LLMDecisionAuditLogger
extends RefCounted

const LOG_DIR := "user://logs"
const LOG_PREFIX := "llm_decisions"

var enabled: bool = true
var log_path: String = ""


func _init() -> void:
	log_path = _default_log_path()


func log_event(event_type: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("logs"):
		dir.make_dir("logs")
	var entry := {
		"ts_unix": Time.get_unix_time_from_system(),
		"ts": Time.get_datetime_string_from_system(false, true),
		"event": event_type,
	}
	for key: String in data.keys():
		entry[key] = _json_safe(data.get(key))
	var line := JSON.stringify(entry)
	var file := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(log_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)


func compact_action(action: Dictionary) -> Dictionary:
	var result := {
		"kind": str(action.get("kind", action.get("type", ""))),
	}
	for key: String in [
		"id", "action_id", "card", "pokemon", "target", "position",
		"attack_name", "ability", "bench_target", "bench_position",
	]:
		if action.has(key):
			result[key] = _json_safe(action.get(key))
	if action.has("card") and action.get("card") is CardInstance:
		var card: CardInstance = action.get("card")
		result["card"] = _card_label(card)
	if action.has("target_slot") and action.get("target_slot") is PokemonSlot:
		result["target"] = _slot_label(action.get("target_slot"))
	if action.has("source_slot") and action.get("source_slot") is PokemonSlot:
		result["pokemon"] = _slot_label(action.get("source_slot"))
	if action.has("bench_target") and action.get("bench_target") is PokemonSlot:
		result["bench_target"] = _slot_label(action.get("bench_target"))
	if action.has("attack_index"):
		result["attack_index"] = int(action.get("attack_index", -1))
	if action.has("ability_index"):
		result["ability_index"] = int(action.get("ability_index", -1))
	if action.has("requires_interaction"):
		result["requires_interaction"] = bool(action.get("requires_interaction", false))
	if action.has("interactions"):
		result["interactions"] = _json_safe(action.get("interactions", {}))
	if action.has("selection_policy"):
		result["selection_policy"] = _json_safe(action.get("selection_policy", {}))
	if action.has("capability"):
		result["capability"] = str(action.get("capability", ""))
	if action.has("interaction_schema"):
		result["interaction_schema"] = _json_safe(action.get("interaction_schema", {}))
	return result


func compact_actions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in actions:
		if raw is Dictionary:
			result.append(compact_action(raw))
	return result


func compact_action_catalog(catalog: Dictionary, limit: int = 80) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_key: Variant in catalog.keys():
		if result.size() >= limit:
			break
		var action_id := str(raw_key)
		var ref: Dictionary = catalog.get(raw_key, {}) if catalog.get(raw_key, {}) is Dictionary else {}
		var row := {
			"id": action_id,
			"type": str(ref.get("type", "")),
			"summary": str(ref.get("summary", "")),
		}
		for key: String in [
			"card", "pokemon", "target", "position", "attack_name", "ability",
			"requires_interaction", "capability", "interaction_schema", "selection_policy",
			"attack_quality", "resource_conflicts",
		]:
			if ref.has(key):
				row[key] = _json_safe(ref.get(key))
		result.append(row)
	return result


func compact_items(items: Array, limit: int = 12) -> Array:
	var result: Array = []
	for i: int in mini(items.size(), limit):
		result.append(_json_safe(items[i]))
	return result


func safe_value(value: Variant) -> Variant:
	return _json_safe(value)


func _default_log_path() -> String:
	var d := Time.get_date_dict_from_system()
	return "%s/%s_%04d%02d%02d.jsonl" % [
		LOG_DIR,
		LOG_PREFIX,
		int(d.get("year", 0)),
		int(d.get("month", 0)),
		int(d.get("day", 0)),
	]


func _json_safe(value: Variant) -> Variant:
	if value == null:
		return null
	if value is String or value is bool or value is int or value is float:
		return value
	if value is CardInstance:
		return _card_label(value)
	if value is PokemonSlot:
		return _slot_label(value)
	if value is Dictionary:
		var result := {}
		for key: Variant in (value as Dictionary).keys():
			result[str(key)] = _json_safe((value as Dictionary).get(key))
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json_safe(item))
		return result
	return str(value)


func _card_label(card: CardInstance) -> Dictionary:
	if card == null or card.card_data == null:
		return {}
	return {
		"instance_id": int(card.instance_id),
		"name": str(card.card_data.name),
		"name_en": str(card.card_data.name_en),
		"type": str(card.card_data.card_type),
		"energy": str(card.card_data.energy_provides),
	}


func _slot_label(slot: PokemonSlot) -> Dictionary:
	if slot == null:
		return {}
	var cd := slot.get_card_data()
	return {
		"name": str(slot.get_pokemon_name()),
		"name_en": str(cd.name_en) if cd != null else "",
		"hp_remaining": int(slot.get_remaining_hp()),
		"damage_counters": int(slot.damage_counters),
		"energy_count": slot.attached_energy.size(),
		"tool": _card_label(slot.attached_tool) if slot.attached_tool != null else {},
	}
