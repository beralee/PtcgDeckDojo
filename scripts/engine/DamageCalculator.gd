class_name DamageCalculator
extends RefCounted


func calculate_damage(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack: Dictionary,
	_state: GameState,
	attack_modifier: int = 0,
	attacker_modifier: int = 0,
	defender_modifier: int = 0,
	ignore_weakness_and_resistance: bool = false
) -> int:
	var damage_str: String = str(attack.get("damage", ""))
	var base_damage: int = parse_damage(damage_str) if damage_str != "" else 0

	# 如果基础伤害为0且没有修正值，视为无伤害招式直接返回
	if base_damage == 0 and damage_str != "0" and attack_modifier == 0 and attacker_modifier == 0:
		return 0

	base_damage += attack_modifier
	base_damage += attacker_modifier

	var attacker_type: String = attacker.get_energy_type()
	if not ignore_weakness_and_resistance:
		var weakness_energy: String = defender.get_card_data().weakness_energy
		var weakness_value: String = defender.get_card_data().weakness_value
		if weakness_energy != "" and weakness_energy == attacker_type:
			base_damage = apply_weakness(base_damage, weakness_value)

	if not ignore_weakness_and_resistance:
		var resistance_energy: String = defender.get_card_data().resistance_energy
		var resistance_value: String = defender.get_card_data().resistance_value
		if resistance_energy != "" and resistance_energy == attacker_type:
			base_damage = apply_resistance(base_damage, resistance_value)

	base_damage += defender_modifier
	return max(0, base_damage)


func parse_damage(damage_str: String) -> int:
	var cleaned: String = damage_str.strip_edges()
	if cleaned == "":
		return 0
	return _extract_first_int(cleaned)


func apply_weakness(damage: int, value: String) -> int:
	var cleaned: String = value.strip_edges()
	var amount: int = _extract_first_int(cleaned)
	if amount <= 0:
		return damage
	if "+" in cleaned:
		return damage + amount
	return damage * amount


func apply_resistance(damage: int, value: String) -> int:
	var reduction: int = _extract_first_int(value)
	if reduction > 0:
		return damage - reduction
	return damage


func apply_damage_to_slot(slot: PokemonSlot, damage: int) -> void:
	var counters: int = (damage / 10) * 10
	slot.damage_counters += counters


func check_knockout(slot: PokemonSlot) -> bool:
	return slot.is_knocked_out()


func _extract_first_int(text: String) -> int:
	var digits := ""
	var started := false
	for i: int in text.length():
		var ch: String = text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
			started = true
		elif started:
			break
	return int(digits) if digits != "" else 0
