## PokemonSlot 单元测试
class_name TestPokemonSlot
extends TestBase


func _make_pokemon_data(pname: String = "小火龙", hp: int = 60, stage: String = "Basic") -> CardData:
	var card := CardData.new()
	card.name = pname
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = hp
	card.energy_type = "R"
	card.retreat_cost = 1
	card.attacks = [{"name": "火花", "text": "", "cost": "RC", "damage": "20", "is_vstar_power": false}]
	return card


func _make_energy_data(etype: String = "R") -> CardData:
	var card := CardData.new()
	card.name = "%s能量" % etype
	card.card_type = "Basic Energy"
	card.energy_provides = etype
	return card


func _make_slot(pname: String = "小火龙", hp: int = 60) -> PokemonSlot:
	CardInstance.reset_id_counter()
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_make_pokemon_data(pname, hp), 0))
	return slot


func test_get_top_card() -> String:
	var slot := _make_slot()
	return run_checks([
		assert_not_null(slot.get_top_card(), "非null"),
		assert_eq(slot.get_top_card().get_name(), "小火龙", "名称"),
	])


func test_get_top_card_empty() -> String:
	return assert_null(PokemonSlot.new().get_top_card(), "空栈返回null")


func test_hp_no_damage() -> String:
	var slot := _make_slot("小火龙", 60)
	return run_checks([
		assert_eq(slot.get_max_hp(), 60, "最大HP"),
		assert_eq(slot.get_remaining_hp(), 60, "剩余HP"),
		assert_false(slot.is_knocked_out(), "未昏厥"),
	])


func test_hp_with_damage() -> String:
	var slot := _make_slot("小火龙", 60)
	slot.damage_counters = 30
	return assert_eq(slot.get_remaining_hp(), 30, "剩余30")


func test_hp_overkill_clamped() -> String:
	var slot := _make_slot("小火龙", 60)
	slot.damage_counters = 100
	return assert_eq(slot.get_remaining_hp(), 0, "钳制为0")


func test_knocked_out() -> String:
	var slot := _make_slot("小火龙", 60)
	slot.damage_counters = 60
	return assert_true(slot.is_knocked_out(), "=HP应昏厥")


func test_not_knocked_out() -> String:
	var slot := _make_slot("小火龙", 60)
	slot.damage_counters = 50
	return assert_false(slot.is_knocked_out(), "<HP未昏厥")


func test_prize_count_normal() -> String:
	return assert_eq(_make_slot().get_prize_count(), 1, "普通1张")


func test_prize_count_ex() -> String:
	CardInstance.reset_id_counter()
	var data := _make_pokemon_data("喷火龙ex", 330)
	data.mechanic = "ex"
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, 0))
	return assert_eq(slot.get_prize_count(), 2, "ex 2张")


func test_retreat_cost() -> String:
	return assert_eq(_make_slot().get_retreat_cost(), 1, "撤退1")


func test_attacks() -> String:
	var attacks := _make_slot().get_attacks()
	return run_checks([
		assert_eq(attacks.size(), 1, "招式数"),
		assert_eq(attacks[0]["name"], "火花", "招式名"),
	])


func test_status_default() -> String:
	var slot := _make_slot()
	return assert_false(slot.has_any_status(), "默认无状态")


func test_set_status_poisoned() -> String:
	var slot := _make_slot()
	slot.set_status("poisoned", true)
	return run_checks([
		assert_true(slot.status_conditions["poisoned"], "中毒"),
		assert_true(slot.has_any_status(), "有状态"),
	])


func test_status_exclusive_sleep_clears_paralyzed() -> String:
	var slot := _make_slot()
	slot.set_status("paralyzed", true)
	slot.set_status("asleep", true)
	return run_checks([
		assert_true(slot.status_conditions["asleep"], "睡眠"),
		assert_false(slot.status_conditions["paralyzed"], "麻痹被清除"),
	])


func test_status_exclusive_paralyzed_clears_confused() -> String:
	var slot := _make_slot()
	slot.set_status("confused", true)
	slot.set_status("paralyzed", true)
	return run_checks([
		assert_true(slot.status_conditions["paralyzed"], "麻痹"),
		assert_false(slot.status_conditions["confused"], "混乱被清除"),
	])


func test_status_exclusive_confused_clears_asleep() -> String:
	var slot := _make_slot()
	slot.set_status("asleep", true)
	slot.set_status("confused", true)
	return run_checks([
		assert_true(slot.status_conditions["confused"], "混乱"),
		assert_false(slot.status_conditions["asleep"], "睡眠被清除"),
	])


func test_poison_burn_not_exclusive() -> String:
	var slot := _make_slot()
	slot.set_status("poisoned", true)
	slot.set_status("burned", true)
	slot.set_status("asleep", true)
	return run_checks([
		assert_true(slot.status_conditions["poisoned"], "中毒保留"),
		assert_true(slot.status_conditions["burned"], "灼伤保留"),
		assert_true(slot.status_conditions["asleep"], "睡眠保留"),
	])


func test_clear_all_status() -> String:
	var slot := _make_slot()
	slot.set_status("poisoned", true)
	slot.set_status("burned", true)
	slot.set_status("asleep", true)
	slot.clear_all_status()
	return assert_false(slot.has_any_status(), "清除后无状态")


func test_set_invalid_status() -> String:
	var slot := _make_slot()
	slot.set_status("nonexistent", true)
	return assert_false(slot.has_any_status(), "无效状态无效果")


func test_count_energy() -> String:
	CardInstance.reset_id_counter()
	var slot := _make_slot()
	slot.attached_energy.append(CardInstance.create(_make_energy_data("R"), 0))
	slot.attached_energy.append(CardInstance.create(_make_energy_data("R"), 0))
	slot.attached_energy.append(CardInstance.create(_make_energy_data("W"), 0))
	return run_checks([
		assert_eq(slot.count_energy_of_type("R"), 2, "火2"),
		assert_eq(slot.count_energy_of_type("W"), 1, "水1"),
		assert_eq(slot.count_energy_of_type("G"), 0, "草0"),
		assert_eq(slot.get_total_energy_count(), 3, "总3"),
	])


func test_collect_all_cards_with_tool() -> String:
	CardInstance.reset_id_counter()
	var slot := _make_slot()
	slot.attached_energy.append(CardInstance.create(_make_energy_data("R"), 0))
	var tool_data := CardData.new()
	tool_data.name = "活力围巾"
	tool_data.card_type = "Tool"
	slot.attached_tool = CardInstance.create(tool_data, 0)
	return assert_eq(slot.collect_all_cards().size(), 3, "宝可梦+能量+道具=3")


func test_collect_all_cards_no_tool() -> String:
	CardInstance.reset_id_counter()
	var slot := _make_slot()
	slot.attached_energy.append(CardInstance.create(_make_energy_data("R"), 0))
	return assert_eq(slot.collect_all_cards().size(), 2, "宝可梦+能量=2")


func test_evolution_stack() -> String:
	CardInstance.reset_id_counter()
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_make_pokemon_data("小火龙", 60, "Basic"), 0))
	slot.pokemon_stack.append(CardInstance.create(_make_pokemon_data("火恐龙", 90, "Stage 1"), 0))
	return run_checks([
		assert_eq(slot.get_pokemon_name(), "火恐龙", "顶层火恐龙"),
		assert_eq(slot.get_max_hp(), 90, "HP为火恐龙"),
		assert_eq(slot.pokemon_stack.size(), 2, "进化链2张"),
	])
