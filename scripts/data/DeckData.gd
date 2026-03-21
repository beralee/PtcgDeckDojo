## 卡组数据 - 从 API 导入后本地持久化
class_name DeckData
extends Resource

## 卡组ID（来自 tcg.mik.moe）
@export var id: int = 0
## 卡组名称（取自变体名或由用户设定）
@export var deck_name: String = ""
## 来源URL
@export var source_url: String = ""
## 导入时间
@export var import_date: String = ""
## 卡组变体名
@export var variant_name: String = ""
## 卡组代码
@export var deck_code: String = ""

## 卡牌条目列表
## 每个 Dictionary: {set_code, card_index, count, card_type, name, effect_id, name_en}
@export var cards: Array[Dictionary] = []

## 总卡牌数
@export var total_cards: int = 0


## 从 API deck/detail 响应创建
static func from_api_response(deck_id: int, data: Dictionary) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.source_url = "https://tcg.mik.moe/decks/list/%d" % deck_id
	deck.import_date = Time.get_datetime_string_from_system()
	deck.deck_code = data.get("deckCode", "")

	var variant_raw: Variant = data.get("variant")
	var variant: Dictionary = variant_raw if variant_raw is Dictionary else {}
	deck.variant_name = variant.get("variantName", "")
	deck.deck_name = deck.variant_name if deck.variant_name != "" else "卡组 %d" % deck_id

	var cards_raw: Variant = data.get("cards")
	var api_cards: Array = cards_raw if cards_raw is Array else []
	var total := 0
	for c: Variant in api_cards:
		var count: int = int(c.get("count", 1))
		deck.cards.append({
			"set_code": c.get("setCode", ""),
			"card_index": c.get("cardIndex", ""),
			"count": count,
			"card_type": c.get("cardType", ""),
			"name": c.get("cardName", ""),
			"effect_id": c.get("effectId", ""),
			"name_en": c.get("nameEn", ""),
		})
		total += count
	deck.total_cards = total
	return deck


## 验证卡组合法性，返回错误信息列表（空列表表示合法）
func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	# 总数必须为60张
	if total_cards != 60:
		errors.append("卡组总数为 %d 张，应为 60 张" % total_cards)

	# 同名卡牌最多4张（基本能量除外）
	var name_counts: Dictionary = {}
	var _ace_spec_count := 0
	var _radiant_count := 0
	for entry: Dictionary in cards:
		var cname: String = entry.get("name", "")
		var ctype: String = entry.get("card_type", "")
		var count: int = entry.get("count", 0)

		if ctype != "Basic Energy":
			name_counts[cname] = name_counts.get(cname, 0) + count
			if name_counts[cname] > 4:
				errors.append("「%s」数量为 %d 张，超过上限 4 张" % [cname, name_counts[cname]])

	# ACE SPEC 和光辉检查需要完整卡牌数据，此处跳过
	# 将在 CardDatabase 层做更完整的校验

	return errors


## 获取所有唯一卡牌的 (set_code, card_index) 对
func get_card_keys() -> Array[Dictionary]:
	var keys: Array[Dictionary] = []
	for entry: Dictionary in cards:
		keys.append({
			"set_code": entry.get("set_code", ""),
			"card_index": entry.get("card_index", ""),
		})
	return keys


## 序列化为 JSON Dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"deck_name": deck_name,
		"source_url": source_url,
		"import_date": import_date,
		"variant_name": variant_name,
		"deck_code": deck_code,
		"cards": cards,
		"total_cards": total_cards,
	}


## 从本地 JSON Dictionary 创建
static func from_dict(d: Dictionary) -> DeckData:
	var deck := DeckData.new()
	deck.id = int(d.get("id", 0))
	deck.deck_name = d.get("deck_name", "")
	deck.source_url = d.get("source_url", "")
	deck.import_date = d.get("import_date", "")
	deck.variant_name = d.get("variant_name", "")
	deck.deck_code = d.get("deck_code", "")
	var cards_raw: Variant = d.get("cards")
	var cards_array: Array = cards_raw if cards_raw is Array else []
	deck.cards.clear()
	for entry: Variant in cards_array:
		if entry is Dictionary:
			deck.cards.append(entry)
	deck.total_cards = int(d.get("total_cards", 0))
	return deck
