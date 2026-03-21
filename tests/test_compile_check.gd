## 编译健全性测试 - 确保所有类可以正确实例化和调用
class_name TestCompileCheck
extends TestBase


func test_card_data_instantiate() -> String:
	var card := CardData.new()
	card.name = "测试"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	card.energy_type = "R"
	card.set_code = "SV1"
	card.card_index = "001"
	card.mechanic = ""
	card.is_tags = PackedStringArray(["Basic"])
	# 验证所有方法可调用
	var _uid: String = card.get_uid()
	var _is_p: bool = card.is_pokemon()
	var _is_t: bool = card.is_trainer()
	var _is_e: bool = card.is_energy()
	var _is_bp: bool = card.is_basic_pokemon()
	var _is_ep: bool = card.is_evolution_pokemon()
	var _is_rb: bool = card.is_rule_box_pokemon()
	var _pc: int = card.get_prize_count()
	var _is_ace: bool = card.is_ace_spec()
	var _is_rad: bool = card.is_radiant()
	var _dict: Dictionary = card.to_dict()
	var _restored: CardData = CardData.from_dict(_dict)
	return ""


func test_deck_data_instantiate() -> String:
	var deck := DeckData.new()
	deck.id = 1
	deck.deck_name = "测试"
	deck.total_cards = 0
	deck.cards = []
	var _errors: PackedStringArray = deck.validate()
	var _keys: Array[Dictionary] = deck.get_card_keys()
	var _dict: Dictionary = deck.to_dict()
	var _restored: DeckData = DeckData.from_dict(_dict)
	return ""


func test_card_instance_instantiate() -> String:
	CardInstance.reset_id_counter()
	var card := CardData.new()
	card.name = "测试"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	var inst := CardInstance.create(card, 0)
	var _name: String = inst.get_name()
	var _type: String = inst.get_card_type()
	var _is_bp: bool = inst.is_basic_pokemon()
	var _is_e: bool = inst.is_energy()
	var _s: String = inst.to_string()
	return ""


func test_pokemon_slot_instantiate() -> String:
	CardInstance.reset_id_counter()
	var card := CardData.new()
	card.name = "测试"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	card.energy_type = "R"
	card.retreat_cost = 1
	card.attacks = [{"name": "招式", "text": "", "cost": "R", "damage": "20", "is_vstar_power": false}]
	card.abilities = []

	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))

	var _top: CardInstance = slot.get_top_card()
	var _data: CardData = slot.get_card_data()
	var _name: String = slot.get_pokemon_name()
	var _etype: String = slot.get_energy_type()
	var _mhp: int = slot.get_max_hp()
	var _rhp: int = slot.get_remaining_hp()
	var _ko: bool = slot.is_knocked_out()
	var _prize: int = slot.get_prize_count()
	var _retreat: int = slot.get_retreat_cost()
	var _attacks: Array[Dictionary] = slot.get_attacks()
	var _abilities: Array[Dictionary] = slot.get_abilities()
	var _has_status: bool = slot.has_any_status()
	slot.set_status("poisoned", true)
	slot.clear_all_status()
	var _count: int = slot.count_energy_of_type("R")
	var _total: int = slot.get_total_energy_count()
	var _all: Array[CardInstance] = slot.collect_all_cards()
	var _str: String = slot.to_string()
	return ""


func test_player_state_instantiate() -> String:
	CardInstance.reset_id_counter()
	var player := PlayerState.new()
	player.player_index = 0

	# 添加一些卡牌到牌库
	var card := CardData.new()
	card.name = "测试"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	for i in 10:
		player.deck.append(CardInstance.create(card, 0))

	var _drawn_card: CardInstance = player.draw_card()
	var _drawn_cards: Array[CardInstance] = player.draw_cards(2)
	var _has_bp: bool = player.has_basic_pokemon_in_hand()
	var _basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	var _bench_full: bool = player.is_bench_full()
	var _has_pokemon: bool = player.has_pokemon_in_play()
	var _all_pokemon: Array[PokemonSlot] = player.get_all_pokemon()
	var _prizes_done: bool = player.all_prizes_taken()
	player.shuffle_deck()
	return ""


func test_game_state_instantiate() -> String:
	var gs := GameState.new()
	var p0 := PlayerState.new()
	p0.player_index = 0
	var p1 := PlayerState.new()
	p1.player_index = 1
	gs.players = [p0, p1]
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.turn_number = 1

	var _cp: PlayerState = gs.get_current_player()
	var _op: PlayerState = gs.get_opponent_player()
	var _p0: PlayerState = gs.get_player(0)
	var _first: bool = gs.is_first_turn_of_first_player()
	var _over: bool = gs.is_game_over()
	gs.reset_turn_flags()
	gs.switch_player()
	gs.advance_turn()
	gs.set_game_over(0, "测试")
	return ""


func test_deck_importer_parse() -> String:
	var _id1: int = DeckImporter.parse_deck_id("https://tcg.mik.moe/decks/list/574793")
	var _id2: int = DeckImporter.parse_deck_id("574793")
	var _id3: int = DeckImporter.parse_deck_id("invalid")
	var _id4: int = DeckImporter.parse_deck_id("")
	return ""


func test_card_data_api_json_full() -> String:
	# 模拟完整的 API 返回数据，包括 null 值
	var json := {
		"name": "玛纳霏",
		"cardType": "Pokemon",
		"mechanic": null,
		"label": null,
		"description": "特性描述",
		"yorenCode": "P490",
		"setCode": "CS5bC",
		"cardIndex": "052",
		"setCodeEn": "BRS",
		"cardIndexEn": "41",
		"nameEn": "Manaphy",
		"artist": "HYOGONOSUKE",
		"rarity": "U",
		"releaseDate": "2024-06-18",
		"regulationMark": "F",
		"effectId": "04653d",
		"is": ["Basic"],
		"regulationLegal": {"standard": true, "expanded": true},
		"pokemonAttr": {
			"energyType": "W",
			"stage": "Basic",
			"hp": 70,
			"retreatCost": 1,
			"evolvesFrom": "",
			"ancientTrait": "",
			"weakness": {"energy": "L", "value": "×2"},
			"resistance": null,
			"attack": [{"name": "泼水", "text": "", "cost": "W", "damage": "20", "isVStarPower": false}],
			"ability": [{"name": "浪花水帘", "text": "特性效果", "isVStarPower": false}],
		}
	}
	var card := CardData.from_api_json(json)
	return run_checks([
		assert_eq(card.name, "玛纳霏", "名称"),
		assert_eq(card.mechanic, "", "null mechanic 为空"),
		assert_eq(card.label, "", "null label 为空"),
		assert_eq(card.hp, 70, "HP"),
		assert_eq(card.energy_type, "W", "属性"),
		assert_eq(card.weakness_energy, "L", "弱点"),
		assert_eq(card.resistance_energy, "", "null resistance 弱点为空"),
		assert_eq(card.attacks.size(), 1, "招式数"),
		assert_eq(card.abilities.size(), 1, "特性数"),
		assert_eq(card.abilities[0]["name"], "浪花水帘", "特性名"),
		assert_eq(card.is_tags.size(), 1, "标签数"),
	])


func test_deck_data_api_response_full() -> String:
	# 模拟 deck detail API 数据
	var api_data := {
		"deckCode": "ABC123",
		"variant": {"variantName": "测试卡组"},
		"cards": [
			{
				"setCode": "CS5bC", "cardIndex": "052", "count": 1,
				"cardType": "Pokemon", "cardName": "玛纳霏",
				"effectId": "04653d", "nameEn": "Manaphy",
			},
			{
				"setCode": "CSVE1C", "cardIndex": "FIR", "count": 10,
				"cardType": "Basic Energy", "cardName": "基本火能量",
				"effectId": "22db54", "nameEn": "Fire Energy",
			},
		],
	}
	var deck := DeckData.from_api_response(574793, api_data)
	return run_checks([
		assert_eq(deck.id, 574793, "ID"),
		assert_eq(deck.deck_name, "测试卡组", "名称"),
		assert_eq(deck.total_cards, 11, "总数 1+10"),
		assert_eq(deck.cards.size(), 2, "条目数"),
		assert_eq(deck.cards[0]["set_code"], "CS5bC", "setCode 转 set_code"),
		assert_eq(deck.cards[0]["card_index"], "052", "cardIndex 转 card_index"),
		assert_eq(deck.cards[0]["name"], "玛纳霏", "cardName 转 name"),
		assert_str_contains(deck.source_url, "574793", "URL 含 ID"),
	])


func test_card_data_api_json_non_pokemon() -> String:
	# 模拟非宝可梦卡（物品卡），pokemonAttr 为 null
	var json := {
		"name": "反击捕捉器",
		"cardType": "Item",
		"mechanic": null,
		"label": null,
		"description": "效果描述",
		"yorenCode": "",
		"setCode": "CS6bC",
		"cardIndex": "070",
		"setCodeEn": "PAR",
		"cardIndexEn": "160",
		"nameEn": "Counter Catcher",
		"artist": "Artist",
		"rarity": "U",
		"releaseDate": "2024-01-01",
		"regulationMark": "G",
		"effectId": "abc123",
		"is": null,
		"regulationLegal": null,
		"pokemonAttr": null,
	}
	var card := CardData.from_api_json(json)
	return run_checks([
		assert_eq(card.name, "反击捕捉器", "名称"),
		assert_eq(card.card_type, "Item", "类型"),
		assert_eq(card.mechanic, "", "null mechanic 为空"),
		assert_eq(card.hp, 0, "非宝可梦 HP 为 0"),
		assert_eq(card.energy_type, "", "非宝可梦无属性"),
		assert_eq(card.attacks.size(), 0, "非宝可梦无招式"),
		assert_eq(card.abilities.size(), 0, "非宝可梦无特性"),
		assert_eq(card.is_tags.size(), 0, "null is 标签为空"),
		assert_eq(card.regulation_standard, true, "null regulationLegal 默认标准合法"),
	])


func test_card_data_api_json_energy() -> String:
	# 模拟基本能量卡
	var json := {
		"name": "基本火能量",
		"cardType": "Basic Energy",
		"mechanic": null,
		"label": null,
		"description": "",
		"yorenCode": "",
		"setCode": "CSVE1C",
		"cardIndex": "FIR",
		"setCodeEn": "SVE",
		"cardIndexEn": "2",
		"nameEn": "Fire Energy",
		"artist": "",
		"rarity": "",
		"releaseDate": "",
		"regulationMark": "",
		"effectId": "22db54",
		"is": [],
		"regulationLegal": {"standard": true, "expanded": true},
		"pokemonAttr": null,
	}
	var card := CardData.from_api_json(json)
	return run_checks([
		assert_eq(card.name, "基本火能量", "名称"),
		assert_eq(card.card_type, "Basic Energy", "类型"),
		assert_eq(card.energy_provides, "R", "火能量推断"),
		assert_eq(card.hp, 0, "能量无 HP"),
		assert_eq(card.attacks.size(), 0, "能量无招式"),
	])


func test_serialization_roundtrip_card() -> String:
	# 完整序列化往返测试
	var original := CardData.new()
	original.name = "测试宝可梦"
	original.card_type = "Pokemon"
	original.mechanic = "ex"
	original.stage = "Stage 2"
	original.hp = 330
	original.energy_type = "R"
	original.set_code = "SV1"
	original.card_index = "100"
	original.weakness_energy = "W"
	original.weakness_value = "×2"
	original.resistance_energy = "G"
	original.resistance_value = "-30"
	original.retreat_cost = 3
	original.evolves_from = "中间形态"
	original.effect_id = "abc123"
	original.is_tags = PackedStringArray(["Stage 2", "ex"])
	original.attacks = [
		{"name": "招式1", "text": "效果1", "cost": "RRC", "damage": "200", "is_vstar_power": false},
		{"name": "招式2", "text": "效果2", "cost": "RRRC", "damage": "330", "is_vstar_power": false},
	]
	original.abilities = [{"name": "特性", "text": "特性效果"}]

	var json_str := JSON.stringify(original.to_dict())
	var json := JSON.new()
	var _err := json.parse(json_str)
	var restored := CardData.from_dict(json.data)

	return run_checks([
		assert_eq(restored.name, original.name, "名称"),
		assert_eq(restored.card_type, original.card_type, "类型"),
		assert_eq(restored.mechanic, original.mechanic, "机制"),
		assert_eq(restored.stage, original.stage, "阶段"),
		assert_eq(restored.hp, original.hp, "HP"),
		assert_eq(restored.energy_type, original.energy_type, "属性"),
		assert_eq(restored.weakness_energy, original.weakness_energy, "弱点属性"),
		assert_eq(restored.weakness_value, original.weakness_value, "弱点值"),
		assert_eq(restored.resistance_energy, original.resistance_energy, "抗性属性"),
		assert_eq(restored.resistance_value, original.resistance_value, "抗性值"),
		assert_eq(restored.retreat_cost, original.retreat_cost, "撤退"),
		assert_eq(restored.evolves_from, original.evolves_from, "进化来源"),
		assert_eq(restored.effect_id, original.effect_id, "效果ID"),
		assert_eq(restored.attacks.size(), 2, "招式数"),
		assert_eq(restored.abilities.size(), 1, "特性数"),
		assert_eq(restored.is_tags.size(), 2, "标签数"),
	])


func test_serialization_roundtrip_deck() -> String:
	var original := DeckData.new()
	original.id = 99999
	original.deck_name = "序列化测试"
	original.source_url = "https://tcg.mik.moe/decks/list/99999"
	original.import_date = "2025-06-01T12:00:00"
	original.variant_name = "变体"
	original.deck_code = "XYZABC"
	original.total_cards = 60
	original.cards = [
		{"set_code": "SV1", "card_index": "001", "count": 4, "card_type": "Pokemon", "name": "小火龙"},
	]

	var json_str := JSON.stringify(original.to_dict())
	var json := JSON.new()
	var _err := json.parse(json_str)
	var restored := DeckData.from_dict(json.data)

	return run_checks([
		assert_eq(restored.id, original.id, "ID"),
		assert_eq(restored.deck_name, original.deck_name, "名称"),
		assert_eq(restored.source_url, original.source_url, "URL"),
		assert_eq(restored.import_date, original.import_date, "日期"),
		assert_eq(restored.variant_name, original.variant_name, "变体名"),
		assert_eq(restored.deck_code, original.deck_code, "代码"),
		assert_eq(restored.total_cards, original.total_cards, "总数"),
		assert_eq(restored.cards.size(), 1, "条目数"),
	])
