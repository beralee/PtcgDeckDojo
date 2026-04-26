class_name DeckDiscussionContextBuilder
extends RefCounted

const OPENING_HAND_SIZE := 7
const DECK_SIZE := 60

const DECK_NAME_OVERRIDES := {
	575716: "喷火龙 大比鸟",
	575720: "密勒顿",
	569061: "阿尔宙斯 骑拉帝纳",
	575657: "多龙巴鲁托 黑夜魔灵",
	578647: "沙奈朵",
	575718: "猛雷鼓",
	579502: "多龙巴鲁托 喷火龙",
	575723: "大比鸟 控制",
}

const GROUP_SEARCH_NAMES := {
	"Buddy-Buddy Poffin": true,
	"Nest Ball": true,
	"Ultra Ball": true,
	"Artazon": true,
	"Hisuian Heavy Ball": true,
	"Rare Candy": true,
}

const GROUP_DRAW_NAMES := {
	"Professor's Research": true,
	"Iono": true,
	"Arven": true,
	"PokeStop": true,
	"Radiant Greninja": true,
	"Rotom V": true,
	"Fezandipiti ex": true,
}

const CARD_NAME_ZH_OVERRIDES := {
	"Manaphy": "玛纳霏",
	"Thorton": "捩木",
	"Counter Catcher": "反击捕捉器",
	"Nest Ball": "巢穴球",
	"Fire Energy": "基本火能量",
	"Dusknoir": "黑夜魔灵",
	"Night Stretcher": "夜间担架",
	"Lumineon V": "霓虹鱼V",
	"Arven": "派帕",
	"Pidgey": "波波",
	"Professor Turo's Scenario": "弗图博士的剧本",
	"Charizard ex": "喷火龙ex",
	"Charmander": "小火龙",
	"Charmeleon": "火恐龙",
	"Pidgeot ex": "大比鸟ex",
	"Duskull": "夜巡灵",
	"Boss's Orders": "老大的指令",
	"Rotom V": "洛托姆V",
	"Radiant Charizard": "光辉喷火龙",
	"Lost Vacuum": "放逐吸尘器",
	"Double Turbo Energy": "双重涡轮能量",
	"Forest Seal Stone": "森林封印石",
	"Ultra Ball": "高级球",
	"Fezandipiti ex": "吉雉鸡ex",
	"Dusclops": "彷徨夜灵",
	"Iono": "奇树",
	"Super Rod": "厉害钓竿",
	"Unfair Stamp": "不公印章",
	"Rare Candy": "神奇糖果",
	"Defiance Band": "不服输头带",
	"Buddy-Buddy Poffin": "友好宝芬",
	"Collapsed Stadium": "崩塌的竞技场",
	"Lightning Energy": "基本雷能量",
	"Psychic Energy": "基本超能量",
	"Darkness Energy": "基本恶能量",
	"Grass Energy": "基本草能量",
	"Water Energy": "基本水能量",
	"Fighting Energy": "基本斗能量",
	"Metal Energy": "基本钢能量",
	"Miraidon ex": "密勒顿ex",
	"Electric Generator": "电气发生器",
	"Iron Hands ex": "铁臂膀ex",
	"Arceus V": "阿尔宙斯V",
	"Arceus VSTAR": "阿尔宙斯VSTAR",
	"Giratina V": "骑拉帝纳V",
	"Giratina VSTAR": "骑拉帝纳VSTAR",
	"Bidoof": "大牙狸",
	"Bibarel": "大尾狸",
	"Skwovet": "贪心栗鼠",
	"Gardevoir ex": "沙奈朵ex",
	"Ralts": "拉鲁拉丝",
	"Kirlia": "奇鲁莉安",
	"Radiant Greninja": "光辉甲贺忍蛙",
	"Flutter Mane": "振翼发",
	"Scream Tail": "吼叫尾",
	"Drifloon": "飘飘球",
	"Klefki": "钥圈儿",
	"Munkidori": "愿增猿",
	"Earthen Vessel": "大地容器",
	"Artazon": "深钵镇",
	"Bravery Charm": "勇气护符",
	"Secret Box": "神秘盒",
	"Technical Machine: Evolution": "招式学习器 进化",
	"Technical Machine: Devolution": "招式学习器 退化",
	"Technical Machine: Turbo Energize": "招式学习器 涡轮能量",
	"Raging Bolt ex": "猛雷鼓ex",
	"Iron Leaves ex": "铁斑叶ex",
	"Dragapult ex": "多龙巴鲁托ex",
	"Dreepy": "多龙梅西亚",
	"Drakloak": "多龙奇",
	"Radiant Alakazam": "光辉胡地",
	"Switch": "宝可梦交替",
	"Rescue Board": "紧急滑板",
	"Hyper Aroma": "高级香氛",
	"Banette ex": "诅咒娃娃ex",
	"Shuppet": "怨影娃娃",
	"Bloodmoon Ursaluna ex": "月月熊 赫月ex",
}


func build_context(deck: DeckData) -> Dictionary:
	return build_detailed_context(deck)


func build_light_context(deck: DeckData) -> Dictionary:
	var detailed := _build_base_context(deck, false)
	return {
		"context_level": "light",
		"deck_id": detailed.get("deck_id", 0),
		"deck_name": detailed.get("deck_name", ""),
		"total_cards": detailed.get("total_cards", 0),
		"cards": detailed.get("cards", []),
		"counts_by_type": detailed.get("counts_by_type", {}),
		"opening_reference": _compact_opening_reference(detailed.get("opening_reference", {})),
		"key_cards": detailed.get("key_cards", []),
		"available_tools": [{
			"name": "get_deck_detail",
			"description": "Fetch full deck context including card ids, stages, HP, mechanics, evolution data, energy breakdown, per-card opening probabilities, and readable strategy if available.",
		}],
	}


func build_detailed_context(deck: DeckData) -> Dictionary:
	var context := _build_base_context(deck, true)
	context["context_level"] = "detailed"
	return context


func build_card_detail_context(card: CardData, count: int = 0) -> Dictionary:
	if card == null:
		return {}
	var entry := {
		"set_code": card.set_code,
		"card_index": card.card_index,
		"count": count,
		"card_type": card.card_type,
		"name": card.name,
		"name_en": card.name_en,
	}
	return _build_card_row(entry, card, true)


func build_play_guide_context(deck: DeckData) -> Dictionary:
	var context := _build_base_context(deck, false)
	context["context_level"] = "play_guide"
	context["core_cards"] = _top_cards_by_type(context.get("cards", []), "Pokemon", 16)
	context["engine_cards"] = _top_non_pokemon_cards(context.get("cards", []), 18)
	context["plan_hints"] = _build_plan_hints(context)
	context["available_tools"] = [{
		"name": "get_deck_detail",
		"description": "Fetch compact deck detail only if specific card text, evolution data, or exact per-card odds are required.",
	}]
	return context


func build_quick_summary(context: Dictionary) -> String:
	var opening: Dictionary = context.get("opening_reference", {})
	return "60张，基础宝可梦%d，能量%d，起手有基础 %.1f%%，重抽 %.1f%%" % [
		int(opening.get("basic_pokemon_count", 0)),
		int(opening.get("energy_count", 0)),
		float(opening.get("p_open_at_least_one_basic", 0.0)) * 100.0,
		float(opening.get("p_mulligan", 0.0)) * 100.0,
	]


func _build_base_context(deck: DeckData, detailed: bool) -> Dictionary:
	var cards: Array[Dictionary] = []
	var counts_by_type := {
		"Pokemon": 0,
		"Supporter": 0,
		"Item": 0,
		"Tool": 0,
		"Stadium": 0,
		"Basic Energy": 0,
		"Special Energy": 0,
	}
	var basics_count := 0
	var energy_count := 0
	var search_count := 0
	var draw_count := 0
	var card_probabilities: Array[Dictionary] = []
	var key_cards: Array[Dictionary] = []
	var energy_breakdown: Dictionary = {}

	for entry: Dictionary in deck.cards:
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		var count := int(entry.get("count", 0))
		var card_type := str(entry.get("card_type", ""))
		var card: CardData = CardDatabase.get_card(set_code, card_index)
		var display_name := _display_card_name(entry, card)
		var name_en := _card_name_en(entry, card)

		if counts_by_type.has(card_type):
			counts_by_type[card_type] += count
		if card_type in ["Basic Energy", "Special Energy"]:
			energy_count += count

		if (card != null and card.is_basic_pokemon()) or (card == null and card_type == "Pokemon"):
			basics_count += count
		if GROUP_SEARCH_NAMES.has(display_name) or GROUP_SEARCH_NAMES.has(name_en):
			search_count += count
		if GROUP_DRAW_NAMES.has(display_name) or GROUP_DRAW_NAMES.has(name_en):
			draw_count += count

		var row := _build_card_row(entry, card, detailed)
		if detailed and card != null and card.is_energy():
			var bucket := card.energy_provides if card.energy_provides != "" else display_name
			energy_breakdown[bucket] = int(energy_breakdown.get(bucket, 0)) + count
		cards.append(row)

		card_probabilities.append({
			"name": display_name,
			"count": count,
			"p_at_least_one_in_7": _round_probability(_probability_at_least_one(count, OPENING_HAND_SIZE, DECK_SIZE)),
		})
		if _is_key_card(display_name, name_en, card_type):
			key_cards.append({
				"name": display_name,
				"count": count,
				"card_type": card_type,
				"p_at_least_one_in_7": _round_probability(_probability_at_least_one(count, OPENING_HAND_SIZE, DECK_SIZE)),
			})

	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	card_probabilities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	key_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)

	var opening_reference := {
		"deck_size": DECK_SIZE,
		"opening_hand_size": OPENING_HAND_SIZE,
		"basic_pokemon_count": basics_count,
		"energy_count": energy_count,
		"search_card_count": search_count,
		"draw_card_count": draw_count,
		"p_open_at_least_one_basic": _round_probability(_probability_at_least_one(basics_count, OPENING_HAND_SIZE, DECK_SIZE)),
		"p_mulligan": _round_probability(_probability_zero(basics_count, OPENING_HAND_SIZE, DECK_SIZE)),
		"p_open_at_least_one_energy": _round_probability(_probability_at_least_one(energy_count, OPENING_HAND_SIZE, DECK_SIZE)),
		"p_open_at_least_one_search": _round_probability(_probability_at_least_one(search_count, OPENING_HAND_SIZE, DECK_SIZE)),
		"p_open_at_least_one_draw": _round_probability(_probability_at_least_one(draw_count, OPENING_HAND_SIZE, DECK_SIZE)),
	}
	if detailed:
		opening_reference["per_card_at_least_one"] = card_probabilities

	var result := {
		"deck_name": _display_deck_name(deck),
		"deck_id": deck.id,
		"total_cards": deck.total_cards,
		"cards": cards,
		"counts_by_type": counts_by_type,
		"opening_reference": opening_reference,
		"key_cards": key_cards,
	}
	if detailed:
		result["energy_breakdown"] = energy_breakdown
		result["available_tools"] = [
			{
				"name": "get_other_deck_detail",
				"description": "当用户询问当前卡组之外的另一套卡组时，按卡组名或 deck_id 加载同格式完整去重卡表。",
			},
			{
				"name": "get_card_detail",
				"description": "当用户询问当前卡组中没有的单卡时，按中文名、英文名或关键词加载该卡完整信息。",
			},
		]
		var strategy := _readable_or_empty(deck.strategy)
		if strategy != "":
			result["strategy_summary"] = strategy.left(900)
	return result


func _build_card_row(entry: Dictionary, card: CardData, detailed: bool) -> Dictionary:
	var set_code := str(entry.get("set_code", ""))
	var card_index := str(entry.get("card_index", ""))
	var count := int(entry.get("count", 0))
	var card_type := str(entry.get("card_type", ""))
	var display_name := _display_card_name(entry, card)
	var name_en := _card_name_en(entry, card)
	var row := {
		"name": display_name,
		"count": count,
		"card_type": card_type,
	}
	if not detailed:
		return row
	row["set_code"] = set_code
	row["card_index"] = card_index
	if name_en != "":
		row["name_en"] = name_en
	if card == null:
		return row
	if card.energy_type != "":
		row["energy_type"] = card.energy_type
	if card.stage != "":
		row["stage"] = card.stage
	if card.hp > 0:
		row["hp"] = card.hp
	if card.mechanic != "":
		row["mechanic"] = card.mechanic
	var evolves_from := _readable_or_empty(card.evolves_from)
	if evolves_from != "":
		row["evolves_from"] = evolves_from
	var weakness := _compact_type_value(card.weakness_energy, card.weakness_value)
	if not weakness.is_empty():
		row["weakness"] = weakness
	var resistance := _compact_type_value(card.resistance_energy, card.resistance_value)
	if not resistance.is_empty():
		row["resistance"] = resistance
	if card.retreat_cost > 0:
		row["retreat_cost"] = card.retreat_cost
	var abilities := _compact_abilities(card.abilities)
	if not abilities.is_empty():
		row["abilities"] = abilities
	var attacks := _compact_attacks(card.attacks)
	if not attacks.is_empty():
		row["attacks"] = attacks
	var description := _compact_text(card.description, 700)
	if description != "":
		row["description"] = description
	if card.effect_id != "":
		row["effect_id"] = card.effect_id
	var tags := Array(card.is_tags)
	if not tags.is_empty():
		row["tags"] = tags
	return row


func _top_cards_by_type(cards: Array, card_type: String, limit: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in cards:
		if not item is Dictionary:
			continue
		var row := item as Dictionary
		if str(row.get("card_type", "")) != card_type:
			continue
		result.append(row.duplicate(true))
		if result.size() >= limit:
			break
	return result


func _top_non_pokemon_cards(cards: Array, limit: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in cards:
		if not item is Dictionary:
			continue
		var row := item as Dictionary
		if str(row.get("card_type", "")) == "Pokemon":
			continue
		result.append(row.duplicate(true))
		if result.size() >= limit:
			break
	return result


func _compact_type_value(energy: String, value: String) -> Dictionary:
	if energy.strip_edges() == "" and value.strip_edges() == "":
		return {}
	return {
		"energy": energy,
		"value": value,
	}


func _compact_abilities(abilities: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ability_variant: Variant in abilities:
		if not ability_variant is Dictionary:
			continue
		var ability := ability_variant as Dictionary
		result.append({
			"name": _compact_text(str(ability.get("name", "")), 80),
			"text": _compact_text(str(ability.get("text", "")), 700),
		})
	return result


func _compact_attacks(attacks: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for attack_variant: Variant in attacks:
		if not attack_variant is Dictionary:
			continue
		var attack := attack_variant as Dictionary
		result.append({
			"name": _compact_text(str(attack.get("name", "")), 80),
			"cost": _compact_text(str(attack.get("cost", "")), 40),
			"damage": _compact_text(str(attack.get("damage", "")), 40),
			"text": _compact_text(str(attack.get("text", "")), 700),
			"is_vstar_power": bool(attack.get("is_vstar_power", false)),
		})
	return result


func _compact_text(text: String, max_length: int) -> String:
	var normalized := text.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	while normalized.contains("\n\n\n"):
		normalized = normalized.replace("\n\n\n", "\n\n")
	if max_length <= 0 or normalized.length() <= max_length:
		return normalized
	return normalized.left(max_length - 3) + "..."


func _build_plan_hints(context: Dictionary) -> Array[String]:
	var hints: Array[String] = []
	var cards: Array = context.get("cards", [])
	var names := {}
	for item: Variant in cards:
		if item is Dictionary:
			names[str((item as Dictionary).get("name", ""))] = int((item as Dictionary).get("count", 0))
	if _has_any_name(names, ["卡比兽", "Snorlax"]):
		hints.append("卡比兽通常偏控制/卡位型思路：拖慢对手、限制撤退或攻击窗口，用资源循环赢长盘。")
	if _has_any_name(names, ["喷火龙ex", "Charizard ex"]):
		hints.append("喷火龙体系通常围绕小火龙铺场、神奇糖果跳进化、喷火龙ex成型输出。")
	if _has_any_name(names, ["大比鸟ex", "Pidgeot ex"]):
		hints.append("大比鸟ex提供每回合稳定检索，优先评估能否尽快做出。")
	if _has_any_name(names, ["沙奈朵ex", "Gardevoir ex"]):
		hints.append("沙奈朵体系通常需要拉鲁拉丝/奇鲁莉安过牌、弃超能、沙奈朵ex加速。")
	return hints


func _has_any_name(names: Dictionary, candidates: Array[String]) -> bool:
	for candidate: String in candidates:
		if names.has(candidate):
			return true
	return false


func _compact_opening_reference(opening: Dictionary) -> Dictionary:
	var result := opening.duplicate(true)
	result.erase("per_card_at_least_one")
	return result


func _display_deck_name(deck: DeckData) -> String:
	if DECK_NAME_OVERRIDES.has(deck.id):
		return str(DECK_NAME_OVERRIDES[deck.id])
	var name := _readable_or_empty(deck.deck_name)
	if name != "":
		return name
	var variant := _readable_or_empty(deck.variant_name)
	if variant != "":
		return variant
	return "Deck %d" % deck.id


func _display_card_name(entry: Dictionary, card: CardData) -> String:
	var english := _card_name_en(entry, card)
	var zh := str(CARD_NAME_ZH_OVERRIDES.get(english, "")).strip_edges()
	if zh != "":
		return zh
	var raw := _readable_or_empty(str(entry.get("name", "")))
	if raw != "":
		return raw
	if card != null:
		raw = _readable_or_empty(card.name)
		if raw != "":
			return raw
	if english != "":
		return english
	return "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]


func _card_name_en(entry: Dictionary, card: CardData) -> String:
	var from_entry := str(entry.get("name_en", "")).strip_edges()
	if from_entry != "":
		return from_entry
	if card != null:
		return str(card.name_en).strip_edges()
	return ""


func _readable_named_text_array(items: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in items:
		if not item is Dictionary:
			continue
		var item_dict := item as Dictionary
		var name := _readable_or_empty(str(item_dict.get("name", "")))
		var text := _readable_or_empty(str(item_dict.get("text", "")))
		if name == "" and text == "":
			continue
		var out := {}
		if name != "":
			out["name"] = name
		if text != "":
			out["text"] = text
		var cost: Variant = item_dict.get("cost", [])
		if cost is Array and not (cost as Array).is_empty():
			out["cost"] = cost
		var damage := str(item_dict.get("damage", "")).strip_edges()
		if damage != "":
			out["damage"] = damage
		result.append(out)
	return result


func _readable_or_empty(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed == "" or _looks_mojibake(trimmed):
		return ""
	return trimmed


func _looks_mojibake(value: String) -> bool:
	var bad_markers := ["锛", "鍗", "瀹", "绋", "鐗", "姊", char(0x20AC), char(0xFFFD), "涓", "榫", "熀"]
	for marker: String in bad_markers:
		if value.find(marker) >= 0:
			return true
	return false


func _is_key_card(card_name: String, name_en: String, card_type: String) -> bool:
	if GROUP_SEARCH_NAMES.has(card_name) or GROUP_SEARCH_NAMES.has(name_en):
		return true
	if GROUP_DRAW_NAMES.has(card_name) or GROUP_DRAW_NAMES.has(name_en):
		return true
	return card_type in ["Supporter", "Special Energy"]


func _probability_at_least_one(successes: int, draws: int, deck_size: int) -> float:
	return 1.0 - _probability_zero(successes, draws, deck_size)


func _probability_zero(successes: int, draws: int, deck_size: int) -> float:
	if draws <= 0:
		return 1.0
	if successes <= 0:
		return 1.0
	if successes >= deck_size:
		return 0.0
	var misses := deck_size - successes
	if draws > misses:
		return 0.0
	return _n_choose_k(misses, draws) / _n_choose_k(deck_size, draws)


func _n_choose_k(n: int, k: int) -> float:
	if k < 0 or k > n:
		return 0.0
	if k == 0 or k == n:
		return 1.0
	var effective_k := mini(k, n - k)
	var result := 1.0
	for i: int in range(1, effective_k + 1):
		result *= float(n - effective_k + i) / float(i)
	return result


func _round_probability(value: float) -> float:
	return roundf(value * 10000.0) / 10000.0
