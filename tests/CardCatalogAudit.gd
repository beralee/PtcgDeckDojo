class_name CardCatalogAudit
extends RefCounted

const REPORT_PATH := "user://logs/card_audit_latest.txt"
const STATUS_MATRIX_PATH := "user://logs/card_status_matrix_latest.txt"

var _report_lines: Array[String] = []
var _status_lines: Array[String] = []
var _test_corpus: String = ""


func run() -> Dictionary:
	_report_lines.clear()
	_status_lines.clear()
	_test_corpus = _load_test_corpus()

	var cards: Array[CardData] = _load_cached_cards()
	cards.sort_custom(_sort_cards)

	var coverage_processor := EffectProcessor.new()
	var decks: Array[DeckData] = CardDatabase.get_all_decks()
	var deck_coverage: EffectCoverageReport = EffectCoverageReport.generate_multi(decks, coverage_processor)

	var registry_failures: Array[String] = []
	var smoke_failures: Array[String] = []
	var interaction_gaps: Array[String] = []
	var verification_gaps: Array[String] = []
	var exercised_cards := 0
	var skipped_cards := 0

	_report_lines.append("===== Card Catalog Audit =====")
	_report_lines.append("Cached cards: %d" % cards.size())
	_report_lines.append("Imported decks: %d" % decks.size())
	_report_lines.append("Deck effect coverage: %d/%d (%.1f%%)" % [
		deck_coverage.covered_cards,
		deck_coverage.total_unique_cards,
		deck_coverage.coverage_percent,
	])
	_report_lines.append("")

	_status_lines.append("===== Card Status Matrix =====")
	_status_lines.append("Legend: registry | implementation | interaction | verification")
	_status_lines.append("")

	for card_data in cards:
		var result: Dictionary = _audit_card(card_data)
		var status_entry: Dictionary = _build_status_entry(card_data, result)
		var status: String = str(result.get("status", "SKIP"))
		var detail: String = str(result.get("detail", ""))

		_report_lines.append("[%s] %s [%s] %s" % [
			status,
			card_data.get_uid(),
			card_data.card_type,
			card_data.name,
		])
		if detail != "":
			_report_lines.append("  %s" % detail)

		match status:
			"PASS":
				exercised_cards += 1
			"FAIL_REGISTRY":
				registry_failures.append("%s: %s" % [card_data.get_uid(), detail])
			"FAIL_SMOKE":
				smoke_failures.append("%s: %s" % [card_data.get_uid(), detail])
			_:
				skipped_cards += 1

		if status_entry["interaction"] == "missing":
			interaction_gaps.append("%s: %s" % [card_data.get_uid(), card_data.name])
		if status_entry["verification"] == "gap":
			verification_gaps.append("%s: %s" % [card_data.get_uid(), card_data.name])

		_status_lines.append("%s [%s] %s | %s | %s | %s | %s" % [
			card_data.get_uid(),
			card_data.card_type,
			card_data.name,
			status_entry["registry"],
			status_entry["implementation"],
			status_entry["interaction"],
			status_entry["verification"],
		])

	_report_lines.append("")
	_report_lines.append("Summary:")
	_report_lines.append("  Exercised: %d" % exercised_cards)
	_report_lines.append("  Skipped: %d" % skipped_cards)
	_report_lines.append("  Registry failures: %d" % registry_failures.size())
	_report_lines.append("  Smoke failures: %d" % smoke_failures.size())
	_report_lines.append("  Interaction gaps: %d" % interaction_gaps.size())
	_report_lines.append("  Verification gaps: %d" % verification_gaps.size())

	_status_lines.append("")
	_status_lines.append("Summary:")
	_status_lines.append("  Interaction gaps: %d" % interaction_gaps.size())
	_status_lines.append("  Verification gaps: %d" % verification_gaps.size())

	_write_report(_report_lines)
	_write_text_file(STATUS_MATRIX_PATH, _status_lines)

	return {
		"cached_cards": cards.size(),
		"deck_coverage": deck_coverage,
		"exercised_cards": exercised_cards,
		"skipped_cards": skipped_cards,
		"registry_failures": registry_failures,
		"smoke_failures": smoke_failures,
		"interaction_gaps": interaction_gaps,
		"verification_gaps": verification_gaps,
		"status_matrix_text": "\n".join(_status_lines),
		"report_text": "\n".join(_report_lines),
	}


func _sort_cards(a: CardData, b: CardData) -> bool:
	return a.get_uid() < b.get_uid()


func _build_status_entry(card_data: CardData, result: Dictionary) -> Dictionary:
	var status: String = str(result.get("status", "SKIP"))
	var registry_status := "n/a"
	var implementation_status := "n/a"

	if card_data.is_pokemon() or card_data.effect_id != "":
		registry_status = "ok" if status != "FAIL_REGISTRY" else "missing"

	if status == "PASS":
		implementation_status = "ok"
	elif status == "FAIL_SMOKE":
		implementation_status = "broken"
	elif registry_status == "missing":
		implementation_status = "blocked"

	var interaction_status: String = _inspect_interaction_status(card_data)
	var verification_status := "n/a"
	if _needs_verification(card_data):
		verification_status = "covered" if _has_verification_coverage(card_data) else "gap"

	return {
		"registry": registry_status,
		"implementation": implementation_status,
		"interaction": interaction_status,
		"verification": verification_status,
	}


func _audit_card(card_data: CardData) -> Dictionary:
	if card_data.set_code == "UTEST":
		return {"status": "SKIP", "detail": "test fixture card"}

	if card_data.card_type == "Basic Energy":
		return {"status": "SKIP", "detail": "basic energy"}

	if card_data.is_pokemon():
		return _audit_pokemon(card_data)

	if card_data.effect_id == "":
		return {"status": "SKIP", "detail": "no effect_id"}

	var smoke_result: Dictionary = _smoke_non_pokemon(card_data)
	var status: String = str(smoke_result.get("status", "FAIL_SMOKE"))
	var detail: String = str(smoke_result.get("detail", ""))
	if status == "FAIL_REGISTRY" or status == "FAIL_SMOKE" or status == "SKIP":
		return {"status": status, "detail": detail}

	return {"status": "PASS", "detail": "executed"}


func _audit_pokemon(card_data: CardData) -> Dictionary:
	var needs_ability_mapping := not card_data.abilities.is_empty()
	var needs_attack_mapping := _has_scripted_attack(card_data)
	if not needs_ability_mapping and not needs_attack_mapping:
		return {"status": "SKIP", "detail": "numeric-only pokemon"}

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card_data)

	if card_data.effect_id == "":
		return {"status": "FAIL_REGISTRY", "detail": "pokemon effect_id is empty"}

	if needs_ability_mapping and not processor.has_effect(card_data.effect_id):
		return {"status": "FAIL_REGISTRY", "detail": "missing ability registry"}

	if needs_attack_mapping and not processor.has_attack_effect(card_data.effect_id):
		return {"status": "FAIL_REGISTRY", "detail": "missing scripted attack registry"}

	var smoke_error: String = _smoke_pokemon(card_data, processor)
	if smoke_error != "":
		return {"status": "FAIL_SMOKE", "detail": smoke_error}

	return {"status": "PASS", "detail": "registered and exercised"}


func _smoke_non_pokemon(card_data: CardData) -> Dictionary:
	var gsm := _make_fixture()
	var player: PlayerState = gsm.game_state.players[0]
	var card := CardInstance.create(card_data, 0)
	player.hand.append(card)

	match card_data.card_type:
		"Item", "Supporter":
			var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
			if effect == null:
				return {"status": "FAIL_REGISTRY", "detail": "missing registry"}
			if not effect.can_execute(card, gsm.game_state):
				return {"status": "SKIP", "detail": "fixture cannot satisfy can_execute"}
			var context: Dictionary = _auto_select_context(effect.get_interaction_steps(card, gsm.game_state))
			if not gsm.play_trainer(0, card, [context]):
				return {"status": "FAIL_SMOKE", "detail": "play_trainer returned false"}
		"Tool":
			if not gsm.effect_processor.has_effect(card_data.effect_id):
				return {"status": "FAIL_REGISTRY", "detail": "missing registry"}
			if not gsm.attach_tool(0, card, player.active_pokemon):
				return {"status": "FAIL_SMOKE", "detail": "attach_tool returned false"}
			gsm.effect_processor.get_attacker_modifier(player.active_pokemon, gsm.game_state)
			gsm.effect_processor.get_defender_modifier(player.active_pokemon, gsm.game_state)
			gsm.effect_processor.get_retreat_cost_modifier(player.active_pokemon, gsm.game_state)
			gsm.effect_processor.get_hp_modifier(player.active_pokemon)
		"Stadium":
			if not gsm.effect_processor.has_effect(card_data.effect_id):
				return {"status": "FAIL_REGISTRY", "detail": "missing registry"}
			if not gsm.play_stadium(0, card):
				return {"status": "FAIL_SMOKE", "detail": "play_stadium returned false"}
		"Special Energy":
			if not gsm.effect_processor.has_effect(card_data.effect_id):
				return {"status": "FAIL_REGISTRY", "detail": "missing registry"}
			var target_slot: PokemonSlot = player.active_pokemon
			if not player.bench.is_empty():
				target_slot = player.bench[0]
			if not gsm.attach_energy(0, card, target_slot):
				return {"status": "FAIL_SMOKE", "detail": "attach_energy returned false"}
			gsm.effect_processor.get_attacker_modifier(target_slot, gsm.game_state)
			gsm.effect_processor.get_retreat_cost_modifier(target_slot, gsm.game_state)
		_:
			return {"status": "SKIP", "detail": "unsupported card type"}

	return {"status": "PASS", "detail": ""}


func _smoke_pokemon(card_data: CardData, processor: EffectProcessor) -> String:
	var gsm := _make_fixture()
	gsm.effect_processor = processor

	var player: PlayerState = gsm.game_state.players[0]
	var attacker := PokemonSlot.new()
	var card := CardInstance.create(card_data, 0)
	attacker.pokemon_stack.append(card)
	attacker.turn_played = 0
	player.active_pokemon = attacker
	_fill_attack_energy(attacker, card_data.energy_type, 6, 0)

	if processor.has_effect(card_data.effect_id):
		var effect: BaseEffect = processor.get_effect(card_data.effect_id)
		var ability_context: Dictionary = _auto_select_context(effect.get_interaction_steps(card, gsm.game_state))
		if effect.has_method("can_use_ability"):
			if bool(effect.call("can_use_ability", attacker, gsm.game_state)):
				processor.execute_ability_effect(attacker, 0, [ability_context], gsm.game_state)
			else:
				var bench_slot := PokemonSlot.new()
				var bench_card := CardInstance.create(card_data, 0)
				bench_slot.pokemon_stack.append(bench_card)
				bench_slot.turn_played = 0
				player.bench.insert(0, bench_slot)
				var bench_context: Dictionary = _auto_select_context(effect.get_interaction_steps(bench_card, gsm.game_state))
				if bool(effect.call("can_use_ability", bench_slot, gsm.game_state)):
					processor.execute_ability_effect(bench_slot, 0, [bench_context], gsm.game_state)
				else:
					effect.execute_ability(attacker, 0, [ability_context], gsm.game_state)
		else:
			effect.execute_ability(attacker, 0, [ability_context], gsm.game_state)

	if processor.has_attack_effect(card_data.effect_id) and not card_data.attacks.is_empty():
		var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon
		processor.get_attack_damage_modifier(attacker, defender, card_data.attacks[0], gsm.game_state)
		processor.execute_attack_effect(attacker, 0, defender, gsm.game_state)

	return ""


func _inspect_interaction_status(card_data: CardData) -> String:
	if card_data.card_type == "Basic Energy":
		return "n/a"
	if not card_data.is_pokemon() and card_data.effect_id == "":
		return "n/a"

	var fixture := _make_fixture()
	var card := CardInstance.create(card_data, 0)

	if card_data.is_pokemon():
		fixture.effect_processor.register_pokemon_card(card_data)
		var pokemon_effect: BaseEffect = fixture.effect_processor.get_effect(card_data.effect_id)
		if pokemon_effect == null:
			return "n/a"
		return "present" if not pokemon_effect.get_interaction_steps(card, fixture.game_state).is_empty() else "none"

	var effect: BaseEffect = fixture.effect_processor.get_effect(card_data.effect_id)
	if effect == null:
		return "n/a"
	return "present" if not effect.get_interaction_steps(card, fixture.game_state).is_empty() else "none"


func _has_verification_coverage(card_data: CardData) -> bool:
	if _test_corpus == "":
		return false
	if card_data.get_uid() != "" and _test_corpus.contains(card_data.get_uid()):
		return true
	if card_data.name != "" and _test_corpus.contains(card_data.name):
		return true
	if card_data.effect_id != "" and _test_corpus.contains(card_data.effect_id):
		return true
	return false


func _needs_verification(card_data: CardData) -> bool:
	if card_data.set_code == "UTEST":
		return false
	if card_data.card_type == "Basic Energy":
		return false
	if card_data.is_pokemon():
		return not card_data.abilities.is_empty() or _has_scripted_attack(card_data)
	return card_data.effect_id != ""


func _load_test_corpus() -> String:
	var corpus_parts: Array[String] = []
	var dir := DirAccess.open("res://tests")
	if dir == null:
		return ""

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd") and file_name != "CardCatalogAudit.gd":
			corpus_parts.append(_read_text_file("res://tests/%s" % file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

	return "\n".join(corpus_parts)


func _read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content: String = file.get_as_text()
	file.close()
	return content


func _make_fixture() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players.clear()

	CardInstance.reset_id_counter()
	for pi in range(2):
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
		_populate_player_fixture(gsm.game_state, player, pi)

	return gsm


func _populate_player_fixture(state: GameState, player: PlayerState, owner_index: int) -> void:
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_data("Active%d" % owner_index, "R", 130), owner_index))
	active.turn_played = 0
	active.damage_counters = 20
	active.status_conditions["asleep"] = true
	active.status_conditions["paralyzed"] = true
	player.active_pokemon = active
	_fill_attack_energy(active, "R", 3, owner_index)

	player.bench.clear()
	for energy_type in ["L", "W", "G", "M"]:
		var bench := PokemonSlot.new()
		var bench_card := CardInstance.create(_make_pokemon_data("Bench%s%d" % [energy_type, owner_index], energy_type, 110), owner_index)
		bench.pokemon_stack.append(bench_card)
		bench.turn_played = 0
		player.bench.append(bench)

	if owner_index == 1:
		var tool_card := CardInstance.create(_make_trainer_data("Fixture Tool In Play", "Tool"), owner_index)
		player.active_pokemon.attached_tool = tool_card

	player.hand.clear()
	player.hand.append(CardInstance.create(_make_pokemon_data("HandBasic%d" % owner_index, "C", 60), owner_index))
	player.hand.append(CardInstance.create(_make_pokemon_data("HandStage2%d" % owner_index, "G", 150, "Stage 2", "", "Stage 1"), owner_index))
	player.hand.append(CardInstance.create(_make_trainer_data("HandItem%d" % owner_index, "Item"), owner_index))
	player.hand.append(CardInstance.create(_make_trainer_data("HandTool%d" % owner_index, "Tool"), owner_index))

	player.deck.clear()
	for cd in _make_deck_fixture_cards():
		player.deck.append(CardInstance.create(cd, owner_index))

	player.discard_pile.clear()
	player.discard_pile.append(CardInstance.create(_make_pokemon_data("DiscardBasic%d" % owner_index, "W", 70), owner_index))
	player.discard_pile.append(CardInstance.create(_make_energy_data("DiscardLightning%d" % owner_index, "L"), owner_index))
	player.discard_pile.append(CardInstance.create(_make_energy_data("DiscardWaterA%d" % owner_index, "W"), owner_index))
	player.discard_pile.append(CardInstance.create(_make_energy_data("DiscardWaterB%d" % owner_index, "W"), owner_index))
	player.discard_pile.append(CardInstance.create(_make_energy_data("DiscardMetal%d" % owner_index, "M"), owner_index))
	player.discard_pile.append(CardInstance.create(_make_trainer_data("DiscardSupporter%d" % owner_index, "Supporter"), owner_index))

	player.prizes.clear()
	var prize_count := 6 if owner_index == 0 else 5
	for i in range(prize_count):
		player.prizes.append(CardInstance.create(_make_pokemon_data("Prize%d_%d" % [owner_index, i], "C", 50), owner_index))

	if owner_index == 1:
		state.stadium_card = CardInstance.create(_make_trainer_data("Fixture Stadium", "Stadium"), owner_index)
		state.stadium_owner_index = owner_index


func _make_deck_fixture_cards() -> Array[CardData]:
	var future_basic := _make_pokemon_data("Future Pokemon", "L", 120)
	future_basic.is_tags = PackedStringArray(["Future"])

	return [
		_make_energy_data("Top Lightning Energy A", "L"),
		_make_energy_data("Top Lightning Energy B", "L"),
		_make_pokemon_data("Lightning Basic", "L", 60),
		_make_pokemon_data("Water Basic", "W", 90),
		_make_trainer_data("Top Supporter", "Supporter"),
		_make_pokemon_data("Grass Basic", "G", 70),
		_make_pokemon_data("Metal Basic", "M", 80),
		_make_pokemon_data("Tiny Basic", "C", 60),
		_make_pokemon_data("Evolution Stage1", "W", 110, "Stage 1", "", "Water Basic"),
		_make_pokemon_data("Evolution Stage2", "G", 150, "Stage 2", "", "Evolution Stage1"),
		_make_pokemon_data("Pokemon ex", "L", 220, "Basic", "ex"),
		_make_pokemon_data("Pokemon V", "L", 210, "Basic", "V"),
		future_basic,
		_make_trainer_data("Fixture Item", "Item"),
		_make_trainer_data("Fixture Supporter", "Supporter"),
		_make_trainer_data("Fixture Tool", "Tool"),
		_make_energy_data("Water Energy", "W"),
		_make_energy_data("Metal Energy", "M"),
	]


func _make_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	evolves_from: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.evolves_from = evolves_from
	cd.retreat_cost = 1
	cd.attacks = [{
		"name": "Audit Attack",
		"cost": "C",
		"damage": "10",
		"text": "",
		"is_vstar_power": false,
	}]
	return cd


func _make_trainer_data(name: String, card_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	return cd


func _make_energy_data(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return cd


func _fill_attack_energy(slot: PokemonSlot, energy_type: String, count: int, owner_index: int) -> void:
	var final_type := energy_type if energy_type != "" else "C"
	for _i in range(count):
		slot.attached_energy.append(CardInstance.create(_make_energy_data("%s Energy" % final_type, final_type), owner_index))


func _has_scripted_attack(card_data: CardData) -> bool:
	for attack in card_data.attacks:
		if str(attack.get("text", "")).strip_edges() != "":
			return true
	return false


func _auto_select_context(steps: Array[Dictionary]) -> Dictionary:
	var context: Dictionary = {}
	for step in steps:
		var step_id: String = str(step.get("id", ""))
		if step_id == "":
			continue

		var items: Array = step.get("items", [])
		var max_select: int = int(step.get("max_select", 0))
		var min_select: int = int(step.get("min_select", 0))
		var desired_count := maxi(min_select, max_select)
		desired_count = mini(desired_count, items.size())

		var selected: Array = []
		for i in range(desired_count):
			selected.append(items[i])
		context[step_id] = selected

	return context


func _load_cached_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	var dir := DirAccess.open(CardDatabase.CARDS_DIR)
	if dir == null:
		return cards

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var card: CardData = _load_card_file("%s%s" % [CardDatabase.CARDS_DIR, file_name])
			if card != null:
				cards.append(card)
		file_name = dir.get_next()
	dir.list_dir_end()
	return cards


func _load_card_file(path: String) -> CardData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) != OK:
		return null
	if json.data is not Dictionary:
		return null
	return CardData.from_dict(json.data)


func _write_report(lines: Array[String]) -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("logs")
	_write_text_file(REPORT_PATH, lines)


func _write_text_file(path: String, lines: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()
