## 伤害计算器测试
class_name TestDamageCalculator
extends TestBase


## 创建宝可梦槽位辅助函数
func _make_slot(energy_type: String, hp: int, weakness_e: String = "", weakness_v: String = "", resistance_e: String = "", resistance_v: String = "") -> PokemonSlot:
	var cd := CardData.new()
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = hp
	cd.energy_type = energy_type
	cd.weakness_energy = weakness_e
	cd.weakness_value = weakness_v
	cd.resistance_energy = resistance_e
	cd.resistance_value = resistance_v
	CardInstance.reset_id_counter()
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, 0))
	return slot


func test_parse_damage_normal() -> String:
	var calc := DamageCalculator.new()
	return run_checks([
		assert_eq(calc.parse_damage("30"), 30, "解析'30'"),
		assert_eq(calc.parse_damage("120"), 120, "解析'120'"),
		assert_eq(calc.parse_damage("30+"), 30, "解析'30+'"),
		assert_eq(calc.parse_damage("10×"), 10, "解析'10×'"),
		assert_eq(calc.parse_damage(""), 0, "空字符串返回0"),
		assert_eq(calc.parse_damage("0"), 0, "解析'0'"),
	])


func test_apply_weakness_multiply() -> String:
	var calc := DamageCalculator.new()
	return run_checks([
		assert_eq(calc.apply_weakness(60, "×2"), 120, "×2弱点"),
		assert_eq(calc.apply_weakness(30, "×2"), 60, "×2弱点"),
	])


func test_apply_resistance() -> String:
	var calc := DamageCalculator.new()
	return run_checks([
		assert_eq(calc.apply_resistance(60, "-30"), 30, "-30抗性"),
		assert_eq(calc.apply_resistance(20, "-30"), -10, "抗性后可为负"),
	])


func test_calculate_damage_no_modifier() -> String:
	var calc := DamageCalculator.new()
	var state := GameState.new()
	var attacker := _make_slot("R", 100)
	var defender := _make_slot("W", 100)

	var attack := {"name": "吐火", "cost": "R", "damage": "30", "is_vstar_power": false}
	var damage: int = calc.calculate_damage(attacker, defender, attack, state)
	return run_checks([
		assert_eq(damage, 30, "无修正基础伤害30"),
	])


func test_calculate_damage_with_weakness() -> String:
	var calc := DamageCalculator.new()
	var state := GameState.new()
	var attacker := _make_slot("R", 100)
	# 防守方对火属性弱点×2
	var defender := _make_slot("W", 100, "R", "×2")

	var attack := {"name": "吐火", "cost": "R", "damage": "60", "is_vstar_power": false}
	var damage: int = calc.calculate_damage(attacker, defender, attack, state)
	return run_checks([
		assert_eq(damage, 120, "火属性弱点×2，60→120"),
	])


func test_calculate_damage_with_resistance() -> String:
	var calc := DamageCalculator.new()
	var state := GameState.new()
	var attacker := _make_slot("G", 100)
	# 防守方对草属性抗性-30
	var defender := _make_slot("W", 100, "", "", "G", "-30")

	var attack := {"name": "招式", "cost": "G", "damage": "60", "is_vstar_power": false}
	var damage: int = calc.calculate_damage(attacker, defender, attack, state)
	return run_checks([
		assert_eq(damage, 30, "草属性抗性-30，60→30"),
	])


func test_calculate_damage_no_type_match() -> String:
	var calc := DamageCalculator.new()
	var state := GameState.new()
	var attacker := _make_slot("W", 100)
	# 火弱点对水属性攻击无效
	var defender := _make_slot("G", 100, "R", "×2")

	var attack := {"name": "水攻", "cost": "W", "damage": "50", "is_vstar_power": false}
	var damage: int = calc.calculate_damage(attacker, defender, attack, state)
	return run_checks([
		assert_eq(damage, 50, "属性不匹配，弱点无效"),
	])


func test_calculate_damage_empty_damage() -> String:
	var calc := DamageCalculator.new()
	var state := GameState.new()
	var attacker := _make_slot("R", 100)
	var defender := _make_slot("W", 100)

	var attack := {"name": "无伤害招式", "cost": "R", "damage": "", "is_vstar_power": false}
	var damage: int = calc.calculate_damage(attacker, defender, attack, state)
	return run_checks([
		assert_eq(damage, 0, "空伤害招式返回0"),
	])


func test_calculate_damage_minimum_zero() -> String:
	var calc := DamageCalculator.new()
	var state := GameState.new()
	var attacker := _make_slot("G", 100)
	# 草属性抗性-60，基础伤害30→负数→归零
	var defender := _make_slot("W", 100, "", "", "G", "-60")

	var attack := {"name": "招式", "cost": "G", "damage": "30", "is_vstar_power": false}
	var damage: int = calc.calculate_damage(attacker, defender, attack, state)
	return run_checks([
		assert_eq(damage, 0, "最终伤害不低于0"),
	])


func test_apply_damage_to_slot() -> String:
	var calc := DamageCalculator.new()
	var slot := _make_slot("R", 100)

	calc.apply_damage_to_slot(slot, 30)
	return run_checks([
		assert_eq(slot.damage_counters, 30, "放置30伤害"),
		assert_eq(slot.get_remaining_hp(), 70, "剩余HP=70"),
	])


func test_apply_damage_rounds_down() -> String:
	var calc := DamageCalculator.new()
	var slot := _make_slot("R", 100)

	# 伤害应向下取整到10的倍数
	calc.apply_damage_to_slot(slot, 35)
	return run_checks([
		assert_eq(slot.damage_counters, 30, "35伤害取整为30"),
	])


func test_check_knockout() -> String:
	var calc := DamageCalculator.new()
	var slot := _make_slot("R", 30)
	slot.damage_counters = 30

	return run_checks([
		assert_eq(calc.check_knockout(slot), true, "HP归零时昏厥"),
	])
