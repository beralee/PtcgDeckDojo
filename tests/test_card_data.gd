## CardData 单元测试
class_name TestCardData
extends TestBase


## 辅助：创建基础宝可梦 CardData
func _make_basic_pokemon(pname: String = "小火龙", hp: int = 60) -> CardData:
	var card := CardData.new()
	card.name = pname
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.energy_type = "R"
	card.set_code = "SV1"
	card.card_index = "001"
	card.weakness_energy = "W"
	card.weakness_value = "×2"
	card.retreat_cost = 1
	card.attacks = [{"name": "火花", "text": "", "cost": "RC", "damage": "20", "is_vstar_power": false}]
	return card


func test_is_pokemon() -> String:
	var card := _make_basic_pokemon()
	return assert_true(card.is_pokemon(), "基础宝可梦应返回 is_pokemon=true")


func test_is_trainer_types() -> String:
	var types: Array[String] = ["Item", "Supporter", "Tool", "Stadium"]
	for t: String in types:
		var card := CardData.new()
		card.card_type = t
		var r := assert_true(card.is_trainer(), "%s 应为 trainer" % t)
		if r != "":
			return r
		r = assert_false(card.is_pokemon(), "%s 不应为 pokemon" % t)
		if r != "":
			return r
	return ""


func test_is_energy() -> String:
	for t: String in ["Basic Energy", "Special Energy"]:
		var card := CardData.new()
		card.card_type = t
		var r := assert_true(card.is_energy(), "%s 应为能量卡" % t)
		if r != "":
			return r
	return ""


func test_is_basic_pokemon() -> String:
	var card := _make_basic_pokemon()
	return run_checks([
		assert_true(card.is_basic_pokemon(), "stage=Basic 应为基础宝可梦"),
		assert_false(card.is_evolution_pokemon(), "基础宝可梦不应为进化宝可梦"),
	])


func test_is_evolution_pokemon() -> String:
	for s: String in ["Stage 1", "Stage 2"]:
		var card := CardData.new()
		card.card_type = "Pokemon"
		card.stage = s
		var r := assert_true(card.is_evolution_pokemon(), "%s 应为进化宝可梦" % s)
		if r != "":
			return r
	return ""


func test_is_rule_box_pokemon() -> String:
	for m: String in ["ex", "V", "VSTAR", "VMAX"]:
		var card := CardData.new()
		card.mechanic = m
		var r := assert_true(card.is_rule_box_pokemon(), "%s 应为特殊规则宝可梦" % m)
		if r != "":
			return r
	var normal := _make_basic_pokemon()
	return assert_false(normal.is_rule_box_pokemon(), "普通宝可梦不应为特殊规则宝可梦")


func test_prize_count() -> String:
	return run_checks([
		assert_eq(_make_basic_pokemon().get_prize_count(), 1, "普通奖赏1"),
		assert_eq(CardData.new().get_prize_count(), 1, "默认奖赏1"),
	])


func test_prize_count_ex() -> String:
	var card := CardData.new()
	card.mechanic = "ex"
	return assert_eq(card.get_prize_count(), 2, "ex 奖赏2")


func test_prize_count_vmax() -> String:
	var card := CardData.new()
	card.mechanic = "VMAX"
	return assert_eq(card.get_prize_count(), 3, "VMAX 奖赏3")


func test_is_ace_spec() -> String:
	var card := CardData.new()
	card.is_tags = PackedStringArray(["ACE SPEC", "Item"])
	return run_checks([
		assert_true(card.is_ace_spec(), "有 ACE SPEC 标签"),
	])


func test_not_ace_spec() -> String:
	var card := CardData.new()
	card.is_tags = PackedStringArray(["Item"])
	return assert_false(card.is_ace_spec(), "无 ACE SPEC 标签")


func test_is_radiant() -> String:
	var c1 := CardData.new()
	c1.mechanic = "Radiant"
	var c2 := CardData.new()
	c2.is_tags = PackedStringArray(["Radiant", "Basic"])
	return run_checks([
		assert_true(c1.is_radiant(), "mechanic=Radiant"),
		assert_true(c2.is_radiant(), "tag含Radiant"),
	])


func test_get_uid() -> String:
	var card := _make_basic_pokemon()
	return assert_eq(card.get_uid(), "SV1_001", "UID 格式")


func test_image_metadata_helpers() -> String:
	var card := _make_basic_pokemon()
	card.image_url = ""
	card.image_local_path = ""
	var changed := card.ensure_image_metadata()

	return run_checks([
		assert_true(changed, "应补齐卡图元数据"),
		assert_eq(card.image_url, "https://tcg.mik.moe/static/img/SV1/001.png", "卡图URL"),
		assert_eq(card.image_local_path, "user://cards/images/SV1/001.png", "本地卡图路径"),
	])


func test_to_dict_from_dict_roundtrip() -> String:
	var original := _make_basic_pokemon()
	original.mechanic = "ex"
	original.abilities = [{"name": "炎之体", "text": "特性效果文本"}]
	original.is_tags = PackedStringArray(["Basic", "ex"])
	original.ensure_image_metadata()

	var dict := original.to_dict()
	var restored := CardData.from_dict(dict)

	return run_checks([
		assert_eq(restored.name, original.name, "名称"),
		assert_eq(restored.card_type, original.card_type, "类型"),
		assert_eq(restored.mechanic, original.mechanic, "机制"),
		assert_eq(restored.image_url, original.image_url, "卡图URL"),
		assert_eq(restored.image_local_path, original.image_local_path, "卡图本地路径"),
		assert_eq(restored.hp, original.hp, "HP"),
		assert_eq(restored.energy_type, original.energy_type, "属性"),
		assert_eq(restored.weakness_energy, original.weakness_energy, "弱点"),
		assert_eq(restored.retreat_cost, original.retreat_cost, "撤退"),
		assert_eq(restored.attacks.size(), original.attacks.size(), "招式数"),
		assert_eq(restored.abilities.size(), original.abilities.size(), "特性数"),
		assert_eq(restored.get_uid(), original.get_uid(), "UID"),
		assert_eq(restored.is_tags.size(), original.is_tags.size(), "标签数"),
	])


func test_from_dict_normalizes_zero_cost_attack() -> String:
	var restored := CardData.from_dict({
		"name": "Cleffa",
		"card_type": "Pokemon",
		"stage": "Basic",
		"attacks": [{
			"name": "Eeeek",
			"text": "",
			"cost": "0",
			"damage": "",
			"is_vstar_power": false,
		}],
	})

	return run_checks([
		assert_eq(restored.attacks.size(), 1, "应保留招式"),
		assert_eq(restored.attacks[0].get("cost", "__missing__"), "", "0费招式应归一化为空费用"),
	])


func test_from_api_json_pokemon() -> String:
	var json := {
		"name": "小火龙", "cardType": "Pokemon", "mechanic": null,
		"setCode": "151C", "cardIndex": "004", "setCodeEn": "MEW", "cardIndexEn": "004",
		"nameEn": "Charmander", "effectId": "eff_001", "is": ["Basic"],
		"regulationLegal": {"standard": true, "expanded": true},
		"pokemonAttr": {
			"energyType": "R", "stage": "Basic", "hp": 60, "retreatCost": 1,
			"evolvesFrom": "", "weakness": {"energy": "W", "value": "×2"},
			"resistance": {},
			"attack": [{"name": "火花", "text": "对方受到20伤害", "cost": "RC", "damage": "20", "isVStarPower": false}],
			"ability": [],
		}
	}
	var card := CardData.from_api_json(json)
	return run_checks([
		assert_eq(card.name, "小火龙", "名称"),
		assert_eq(card.card_type, "Pokemon", "类型"),
		assert_eq(card.mechanic, "", "null mechanic 应为空"),
		assert_eq(card.image_url, "https://tcg.mik.moe/static/img/151C/004.png", "API卡图URL"),
		assert_eq(card.image_local_path, "user://cards/images/151C/004.png", "API卡图路径"),
		assert_eq(card.hp, 60, "HP"),
		assert_eq(card.energy_type, "R", "属性"),
		assert_eq(card.weakness_energy, "W", "弱点"),
		assert_eq(card.attacks.size(), 1, "招式数"),
		assert_true(card.is_basic_pokemon(), "基础宝可梦"),
	])


func test_from_api_json_energy_infer() -> String:
	var mapping := {"火能量": "R", "水能量": "W", "草能量": "G", "雷能量": "L", "超能量": "P", "斗能量": "F", "恶能量": "D", "钢能量": "M"}
	for ename: String in mapping:
		var json := {"name": ename, "cardType": "Basic Energy", "setCode": "SVE", "cardIndex": "001"}
		var card := CardData.from_api_json(json)
		var r := assert_eq(card.energy_provides, mapping[ename], "%s 推断" % ename)
		if r != "":
			return r
	return ""
