## 卡牌静态数据 - 从 API 获取后缓存于本地
class_name CardData
extends Resource

const IMAGE_BASE_URL := "https://tcg.mik.moe/static/img"
const LOCAL_IMAGE_ROOT := "user://cards/images"
const BUNDLED_IMAGE_ROOT := "res://data/bundled_user/cards/images"
const FUTURE_TAG := "Future"
const ANCIENT_TAG := "Ancient"
const TAG_OVERRIDE_PATH := "res://scripts/data/card_tag_overrides.json"
static var _tag_overrides_loaded: bool = false
static var _tag_override_cache: Dictionary = {}

## 卡牌名称
@export var name: String = ""
## 卡牌类型: Pokemon/Item/Supporter/Tool/Stadium/Basic Energy/Special Energy
@export var card_type: String = ""
## 特殊机制: ex/V/VSTAR/VMAX/Radiant 或空
@export var mechanic: String = ""
## 标签
@export var label: String = ""
## 效果描述文本
@export var description: String = ""
## 游人代码
@export var yoren_code: String = ""

## 系列代码(中文)
@export var set_code: String = ""
## 卡牌序号
@export var card_index: String = ""
## 系列代码(英文)
@export var set_code_en: String = ""
## 卡牌序号(英文)
@export var card_index_en: String = ""
## 英文名
@export var name_en: String = ""

## 画师
@export var artist: String = ""
## 稀有度
@export var rarity: String = ""
## 发行日期
@export var release_date: String = ""
## 赛制标记
@export var regulation_mark: String = ""
## 效果唯一ID（同效果卡牌共享）
@export var effect_id: String = ""
@export var image_url: String = ""
@export var image_local_path: String = ""
## 标签数组: Basic/Stage 1/Stage 2/ex/V/VSTAR/VMAX/Radiant/ACE SPEC 等
@export var is_tags: PackedStringArray = []

## 赛制合法性
@export var regulation_standard: bool = true
@export var regulation_expanded: bool = true

# === 宝可梦专属属性（仅 card_type == "Pokemon" 时有效）===
## 属性类型: R/W/G/L/P/F/D/M/N/C
@export var energy_type: String = ""
## 进化状态: Basic/Stage 1/Stage 2
@export var stage: String = ""
## 生命值
@export var hp: int = 0
## 弱点属性
@export var weakness_energy: String = ""
## 弱点倍率（如 "×2"）
@export var weakness_value: String = ""
## 抗性属性
@export var resistance_energy: String = ""
## 抗性数值（如 "-30"）
@export var resistance_value: String = ""
## 撤退所需能量数
@export var retreat_cost: int = 0
## 进化来源（空字符串表示基础宝可梦）
@export var evolves_from: String = ""
## 远古特性
@export var ancient_trait: String = ""

## 招式列表 - 存储为 Array[Dictionary]
## 每个 Dictionary: {name, text, cost, damage, is_vstar_power}
@export var attacks: Array[Dictionary] = []

## 特性列表 - 存储为 Array[Dictionary]
## 每个 Dictionary: {name, text}
@export var abilities: Array[Dictionary] = []

# === 能量卡专属 ===
## 基本能量提供的能量类型
@export var energy_provides: String = ""


## 获取唯一标识符
func get_uid() -> String:
	return "%s_%s" % [set_code, card_index]


static func build_image_url(card_set_code: String, card_idx: String) -> String:
	if card_set_code == "" or card_idx == "":
		return ""
	return "%s/%s/%s.png" % [IMAGE_BASE_URL, card_set_code, card_idx]


static func build_local_image_path(card_set_code: String, card_idx: String) -> String:
	if card_set_code == "" or card_idx == "":
		return ""
	return "%s/%s/%s.png" % [LOCAL_IMAGE_ROOT, card_set_code, card_idx]


static func build_bundled_image_path(card_set_code: String, card_idx: String) -> String:
	if card_set_code == "" or card_idx == "":
		return ""
	return "%s/%s/%s.png.bin" % [BUNDLED_IMAGE_ROOT, card_set_code, card_idx]


static func get_image_candidate_paths(card_set_code: String, card_idx: String, preferred_local_path: String = "") -> PackedStringArray:
	var candidates := PackedStringArray()
	var local_path := preferred_local_path if preferred_local_path != "" else build_local_image_path(card_set_code, card_idx)
	if local_path != "":
		candidates.append(local_path)
	var bundled_path := build_bundled_image_path(card_set_code, card_idx)
	if bundled_path != "" and bundled_path not in candidates:
		candidates.append(bundled_path)
	return candidates


static func resolve_existing_image_path(paths: PackedStringArray) -> String:
	for candidate: String in paths:
		if candidate == "":
			continue
		if candidate.begins_with("res://"):
			if FileAccess.file_exists(candidate):
				return candidate
			continue
		var absolute_path := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(absolute_path):
			return absolute_path
	return ""


func ensure_image_metadata() -> bool:
	var changed := false
	var expected_url := build_image_url(set_code, card_index)
	if expected_url != "" and image_url != expected_url:
		image_url = expected_url
		changed = true

	var expected_local_path := build_local_image_path(set_code, card_index)
	if expected_local_path != "" and image_local_path != expected_local_path:
		image_local_path = expected_local_path
		changed = true

	return changed


func has_local_image() -> bool:
	var local_path := image_local_path if image_local_path != "" else build_local_image_path(set_code, card_index)
	return local_path != "" and FileAccess.file_exists(local_path)


## 是否为宝可梦卡
func is_pokemon() -> bool:
	return card_type == "Pokemon"


## 是否为训练家卡
func is_trainer() -> bool:
	return card_type in ["Item", "Supporter", "Tool", "Stadium"]


## 是否为能量卡
func is_energy() -> bool:
	return card_type in ["Basic Energy", "Special Energy"]


## 是否为基础宝可梦
func is_basic_pokemon() -> bool:
	return is_pokemon() and stage == "Basic"


## 是否为进化宝可梦（包括 VSTAR、VMAX 等从其他宝可梦进化而来的形态）
func is_evolution_pokemon() -> bool:
	return is_pokemon() and stage in ["Stage 1", "Stage 2", "VSTAR", "VMAX"]


## 是否为特殊规则宝可梦（昏厥给对手额外奖赏卡）
func is_rule_box_pokemon() -> bool:
	return mechanic in ["ex", "V", "VSTAR", "VMAX"]


## 昏厥时对手获取的奖赏卡数量
func get_prize_count() -> int:
	match mechanic:
		"VMAX":
			return 3
		"ex", "V", "VSTAR":
			return 2
		_:
			return 1


## 是否为 ACE SPEC 卡
func is_ace_spec() -> bool:
	return "ACE SPEC" in is_tags


## 是否为光辉宝可梦
func is_radiant() -> bool:
	return mechanic == "Radiant" or "Radiant" in is_tags


func has_tag(tag: String) -> bool:
	return tag in is_tags


func is_future_pokemon() -> bool:
	return is_pokemon() and has_tag(FUTURE_TAG)


func is_ancient_pokemon() -> bool:
	return is_pokemon() and has_tag(ANCIENT_TAG)


## 从 API JSON 数据创建 CardData
static func from_api_json(json: Dictionary) -> CardData:
	var card := CardData.new()
	# 对所有 String 字段做类型检查，防止 API 返回 null/Array 等意外类型
	card.name = _to_str(json.get("name"))
	card.card_type = _to_str(json.get("cardType"))
	card.mechanic = _to_str(json.get("mechanic"))
	card.label = _to_str(json.get("label"))
	card.description = _to_str(json.get("description"))
	card.yoren_code = _to_str(json.get("yorenCode"))
	card.set_code = _to_str(json.get("setCode"))
	card.card_index = _to_str(json.get("cardIndex"))
	card.set_code_en = _to_str(json.get("setCodeEn"))
	card.card_index_en = _to_str(json.get("cardIndexEn"))
	card.name_en = _to_str(json.get("nameEn"))
	card.artist = _to_str(json.get("artist"))
	card.rarity = _to_str(json.get("rarity"))
	card.release_date = _to_str(json.get("releaseDate"))
	card.regulation_mark = _to_str(json.get("regulationMark"))
	card.effect_id = _to_str(json.get("effectId"))

	var tags_raw: Variant = json.get("is")
	var tags_array: Array = tags_raw if tags_raw is Array else []
	var packed := PackedStringArray()
	for tag: Variant in tags_array:
		packed.append(str(tag))
	card.is_tags = packed

	var reg_raw: Variant = json.get("regulationLegal")
	var reg_legal: Dictionary = reg_raw if reg_raw is Dictionary else {}
	card.regulation_standard = reg_legal.get("standard", true)
	card.regulation_expanded = reg_legal.get("expanded", true)

	# 宝可梦属性（非宝可梦卡此字段为 null）
	var pattr_raw: Variant = json.get("pokemonAttr")
	var pattr: Dictionary = pattr_raw if pattr_raw is Dictionary else {}
	if not pattr.is_empty():
		card.energy_type = _to_str(pattr.get("energyType"))
		card.stage = _to_str(pattr.get("stage"))
		card.hp = int(pattr.get("hp", 0))
		card.retreat_cost = int(pattr.get("retreatCost", 0))
		card.evolves_from = _to_str(pattr.get("evolvesFrom"))
		card.ancient_trait = _to_str(pattr.get("ancientTrait"))

		# 弱点
		var weakness: Variant = pattr.get("weakness")
		if weakness is Dictionary:
			card.weakness_energy = _to_str(weakness.get("energy"))
			card.weakness_value = _to_str(weakness.get("value"))

		# 抗性
		var resistance: Variant = pattr.get("resistance")
		if resistance is Dictionary:
			card.resistance_energy = _to_str(resistance.get("energy"))
			card.resistance_value = _to_str(resistance.get("value"))

		# 招式
		var atk_raw: Variant = pattr.get("attack")
		var atk_array: Array = atk_raw if atk_raw is Array else []
		for atk: Variant in atk_array:
			if not atk is Dictionary:
				continue
			card.attacks.append({
				"name": _to_str(atk.get("name")),
				"text": _to_str(atk.get("text")),
				"cost": normalize_attack_cost(atk.get("cost")),
				"damage": _to_str(atk.get("damage")),
				"is_vstar_power": atk.get("isVStarPower") == true,
			})

		# 特性
		var ab_raw: Variant = pattr.get("ability")
		var ability_array: Array = ab_raw if ab_raw is Array else []
		for ab: Variant in ability_array:
			if not ab is Dictionary:
				continue
			card.abilities.append({
				"name": _to_str(ab.get("name")),
				"text": _to_str(ab.get("text")),
			})

	# 能量卡: 根据卡牌类型和名称推断提供的能量
	if card.card_type == "Basic Energy":
		card.energy_provides = _infer_energy_type(card.name, card.yoren_code)

	card._apply_supplemental_tags()
	card.ensure_image_metadata()
	return card


## 安全地将 Variant 转为 String，非 String 类型（含 null/Array）返回空字符串
static func _to_str(value: Variant) -> String:
	return value if value is String else ""


static func normalize_attack_cost(value: Variant) -> String:
	var cost := _to_str(value).strip_edges()
	if cost == "0":
		return ""
	return cost


## 根据基本能量名称推断能量类型
static func _infer_energy_type(card_name: String, _yoren_code: String) -> String:
	var mapping := {
		"火": "R", "水": "W", "草": "G", "雷": "L",
		"超": "P", "斗": "F", "恶": "D", "钢": "M", "龙": "N",
		"Fire": "R", "Water": "W", "Grass": "G", "Lightning": "L",
		"Psychic": "P", "Fighting": "F", "Dark": "D", "Metal": "M", "Dragon": "N",
	}
	for keyword: String in mapping:
		if keyword in card_name:
			return mapping[keyword]
	return "C"


## 序列化为 JSON Dictionary（用于本地缓存）
func to_dict() -> Dictionary:
	return {
		"name": name,
		"card_type": card_type,
		"mechanic": mechanic,
		"label": label,
		"description": description,
		"yoren_code": yoren_code,
		"set_code": set_code,
		"card_index": card_index,
		"set_code_en": set_code_en,
		"card_index_en": card_index_en,
		"name_en": name_en,
		"artist": artist,
		"rarity": rarity,
		"release_date": release_date,
		"regulation_mark": regulation_mark,
		"effect_id": effect_id,
		"image_url": image_url,
		"image_local_path": image_local_path,
		"is_tags": Array(is_tags),
		"regulation_standard": regulation_standard,
		"regulation_expanded": regulation_expanded,
		"energy_type": energy_type,
		"stage": stage,
		"hp": hp,
		"weakness_energy": weakness_energy,
		"weakness_value": weakness_value,
		"resistance_energy": resistance_energy,
		"resistance_value": resistance_value,
		"retreat_cost": retreat_cost,
		"evolves_from": evolves_from,
		"ancient_trait": ancient_trait,
		"attacks": attacks,
		"abilities": abilities,
		"energy_provides": energy_provides,
	}


## 从本地缓存 Dictionary 创建 CardData
static func from_dict(d: Dictionary) -> CardData:
	var card := CardData.new()
	card.name = d.get("name", "")
	card.card_type = d.get("card_type", "")
	card.mechanic = d.get("mechanic", "")
	card.label = d.get("label", "")
	card.description = d.get("description", "")
	card.yoren_code = d.get("yoren_code", "")
	card.set_code = d.get("set_code", "")
	card.card_index = d.get("card_index", "")
	card.set_code_en = d.get("set_code_en", "")
	card.card_index_en = d.get("card_index_en", "")
	card.name_en = d.get("name_en", "")
	card.artist = d.get("artist", "")
	card.rarity = d.get("rarity", "")
	card.release_date = d.get("release_date", "")
	card.regulation_mark = d.get("regulation_mark", "")
	card.effect_id = d.get("effect_id", "")
	card.image_url = d.get("image_url", "")
	card.image_local_path = d.get("image_local_path", "")
	card.regulation_standard = d.get("regulation_standard", true)
	card.regulation_expanded = d.get("regulation_expanded", true)
	card.energy_type = d.get("energy_type", "")
	card.stage = d.get("stage", "")
	card.hp = int(d.get("hp", 0))
	card.weakness_energy = d.get("weakness_energy", "")
	card.weakness_value = d.get("weakness_value", "")
	card.resistance_energy = d.get("resistance_energy", "")
	card.resistance_value = d.get("resistance_value", "")
	card.retreat_cost = int(d.get("retreat_cost", 0))
	card.evolves_from = d.get("evolves_from", "")
	card.ancient_trait = d.get("ancient_trait", "")
	var attacks_raw: Variant = d.get("attacks")
	var attacks_array: Array = attacks_raw if attacks_raw is Array else []
	card.attacks.clear()
	for atk: Variant in attacks_array:
		if atk is Dictionary:
			var normalized_attack: Dictionary = atk.duplicate(true)
			normalized_attack["cost"] = normalize_attack_cost(atk.get("cost"))
			card.attacks.append(normalized_attack)
	var abilities_raw: Variant = d.get("abilities")
	var abilities_array: Array = abilities_raw if abilities_raw is Array else []
	card.abilities.clear()
	for ab: Variant in abilities_array:
		if ab is Dictionary:
			card.abilities.append(ab)
	card.energy_provides = d.get("energy_provides", "")

	var tags: Array = d.get("is_tags", [])
	var packed := PackedStringArray()
	for tag: Variant in tags:
		packed.append(str(tag))
	card.is_tags = packed

	card._apply_supplemental_tags()
	card.ensure_image_metadata()
	return card


func _apply_supplemental_tags() -> void:
	var unique_tags: Dictionary = {}
	for raw_tag: String in is_tags:
		var tag := _normalize_special_tag(raw_tag)
		if tag != "":
			unique_tags[tag] = true

	var label_tag := _normalize_special_tag(label)
	if label_tag != "":
		unique_tags[label_tag] = true

	for tag: String in _get_uid_override_tags():
		unique_tags[tag] = true

	var normalized := PackedStringArray()
	for tag: Variant in unique_tags.keys():
		normalized.append(String(tag))
	is_tags = normalized


func _get_uid_override_tags() -> PackedStringArray:
	_ensure_tag_overrides_loaded()
	var override_tags: Variant = _tag_override_cache.get(get_uid(), [])
	var normalized := PackedStringArray()
	if override_tags is Array:
		for raw_tag: Variant in override_tags:
			var tag := _normalize_special_tag(str(raw_tag))
			if tag != "":
				normalized.append(tag)
	return normalized


static func _normalize_special_tag(raw_tag: String) -> String:
	var tag := raw_tag.strip_edges()
	match tag.to_lower():
		"future", "未来":
			return FUTURE_TAG
		"ancient", "古代":
			return ANCIENT_TAG
		_:
			return tag


static func _ensure_tag_overrides_loaded() -> void:
	if _tag_overrides_loaded:
		return
	_tag_overrides_loaded = true
	_tag_override_cache.clear()

	if not FileAccess.file_exists(TAG_OVERRIDE_PATH):
		return

	var file := FileAccess.open(TAG_OVERRIDE_PATH, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) != OK:
		return
	if json.data is not Dictionary:
		return

	for uid: Variant in json.data.keys():
		var tags_raw: Variant = json.data.get(uid, [])
		if tags_raw is Array:
			var normalized_tags: Array[String] = []
			for raw_tag: Variant in tags_raw:
				var tag := _normalize_special_tag(str(raw_tag))
				if tag != "":
					normalized_tags.append(tag)
			_tag_override_cache[str(uid)] = normalized_tags
