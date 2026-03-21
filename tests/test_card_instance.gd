## CardInstance 单元测试
class_name TestCardInstance
extends TestBase


func _make_card(cname: String = "小火龙", ctype: String = "Pokemon") -> CardData:
	var card := CardData.new()
	card.name = cname
	card.card_type = ctype
	card.stage = "Basic" if ctype == "Pokemon" else ""
	card.set_code = "SV1"
	card.card_index = "001"
	return card


func test_create_instance() -> String:
	CardInstance.reset_id_counter()
	var inst := CardInstance.create(_make_card(), 0)
	return run_checks([
		assert_not_null(inst, "不为null"),
		assert_eq(inst.instance_id, 0, "首ID为0"),
		assert_eq(inst.owner_index, 0, "owner"),
		assert_false(inst.face_up, "初始面朝下"),
	])


func test_auto_increment_id() -> String:
	CardInstance.reset_id_counter()
	var data := _make_card()
	var i1 := CardInstance.create(data, 0)
	var i2 := CardInstance.create(data, 1)
	var i3 := CardInstance.create(data, 0)
	return run_checks([
		assert_eq(i1.instance_id, 0, "ID0"),
		assert_eq(i2.instance_id, 1, "ID1"),
		assert_eq(i3.instance_id, 2, "ID2"),
	])


func test_reset_id_counter() -> String:
	CardInstance.reset_id_counter()
	CardInstance.create(_make_card(), 0)
	CardInstance.reset_id_counter()
	var inst := CardInstance.create(_make_card(), 0)
	return assert_eq(inst.instance_id, 0, "重置后从0开始")


func test_get_name() -> String:
	CardInstance.reset_id_counter()
	return assert_eq(CardInstance.create(_make_card("喷火龙"), 0).get_name(), "喷火龙", "名称")


func test_get_card_type() -> String:
	CardInstance.reset_id_counter()
	return assert_eq(CardInstance.create(_make_card("精灵球", "Item"), 0).get_card_type(), "Item", "类型")


func test_is_basic_pokemon() -> String:
	CardInstance.reset_id_counter()
	var pokemon := CardInstance.create(_make_card("小火龙", "Pokemon"), 0)
	var item := CardInstance.create(_make_card("精灵球", "Item"), 0)
	return run_checks([
		assert_true(pokemon.is_basic_pokemon(), "宝可梦"),
		assert_false(item.is_basic_pokemon(), "物品非宝可梦"),
	])


func test_is_energy() -> String:
	CardInstance.reset_id_counter()
	var energy := CardInstance.create(_make_card("火能量", "Basic Energy"), 0)
	return run_checks([
		assert_true(energy.is_energy(), "能量卡"),
		assert_false(energy.is_basic_pokemon(), "能量非宝可梦"),
	])


func test_null_card_data_safety() -> String:
	var inst := CardInstance.new()
	inst.card_data = null
	return run_checks([
		assert_eq(inst.get_name(), "", "null名称为空"),
		assert_eq(inst.get_card_type(), "", "null类型为空"),
		assert_false(inst.is_basic_pokemon(), "null非宝可梦"),
		assert_false(inst.is_energy(), "null非能量"),
	])


func test_to_string() -> String:
	CardInstance.reset_id_counter()
	var s := CardInstance.create(_make_card("皮卡丘"), 0).to_string()
	return run_checks([
		assert_str_contains(s, "皮卡丘", "含名称"),
		assert_str_contains(s, "0", "含ID"),
	])
