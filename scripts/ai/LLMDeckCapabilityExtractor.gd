class_name LLMDeckCapabilityExtractor
extends RefCounted

const EFFECT_TO_INTERACTIONS := {
	# Core search and setup items/supporters.
	"5bdbc985f9aa2e6f248b53f6f35d1d37": ["search_item", "search_tool"], # Arven
	"f866dfee26cd6b0dbbb52b74438d0a59": ["search_pokemon"], # Buddy-Buddy Poffin
	"a337ed34a45e63c6d21d98c3d8e0cb6e": ["discard_cards", "search_cards"], # Ultra Ball
	"1af63a7e2cb7a79215474ad8db8fd8fd": ["search_pokemon"], # Nest Ball
	"d3891abcfe3277c8811cde06741d3236": ["stage2_card", "target_pokemon"], # Rare Candy
	"e366f56ecd3f805a28294109a1a37453": ["discard_cards", "search_energy"], # Earthen Vessel
	"8538726d6cdfad2fa3ca5f4b462c12c5": ["recover_energy"], # Energy Retrieval
	"c9c948169525fbb3dce70c477ec7a90a": ["shuffle_back_cards"], # Super Rod
	"3e6f1daf545dfed48d0588dd50792a2e": ["recover_card"], # Night Stretcher
	"9fa9943ccda36f417ac3cb675177c216": ["search_cards"], # Forest Seal Stone
	"2234845fbc2e11ab95587e1b393bb318": ["energy_assignments"], # Electric Generator
	"8b0d4f541f256d67f0757efe4fc8b407": ["discard_cards", "search_cards"], # Techno Radar
	"768b545a38fccd5e265093b5adce10af": ["search_supporter"], # Pokegear 3.0
	"70d14b4a5a9c15581b8a0c8dfd325717": ["keep_or_discard_top_card"], # Trekking Shoes
	"06bc00d5dcec33898dc6db2e4c4d10ec": ["gust_target"], # Counter Catcher
	"8e1fa2c9018db938084c94c7c970d419": ["gust_target"], # Boss's Orders
	"4ec261453212280d0eb03ed8254ca97f": ["gust_target", "switch_target"], # Prime Catcher
	"3a6d419769778b40091e69fbd76737ec": ["gust_target"], # Pokemon Catcher
	"8342fe3eeec6f897f3271be1aa26a412": ["switch_target"], # Switch Cart
	"73d5f46ecf3a6d71b23ce7bc1a28d4f4": ["target_pokemon"], # Professor Turo's Scenario
	"af514f82d182aeae5327b2c360df703d": [], # Iono
	"d324e01179ab048ed023bf4a20bf658d": [], # Unfair Stamp
	"651276c51911345aa091c1c7b87f3f4f": ["sada_assignments"], # Professor Sada's Vitality
	"43386015be5c073ba2e5b9d3692ece3f": ["search_to_bench"], # TM Evolution
	"e92a86246f44351d023bd4fa271089aa": ["discard_cards", "search_item", "search_tool", "search_cards"], # Secret Box
}

const ABILITY_TO_INTERACTIONS := {
	"音速搜索": ["search_cards"],
	"烈炎支配": ["energy_assignments"],
	"咒怨炸弹": ["self_ko_target"],
	"诅咒炸弹": ["self_ko_target"],
	"隐藏牌": ["discard_energy"],
	"精神拥抱": ["psychic_embrace_assignments", "embrace_energy", "embrace_target"],
	"精炼": ["discard_cards"],
	"亢奋脑力": ["source_pokemon", "target_pokemon", "counter_count"],
	"夜光信号": ["search_supporter"],
	"快速充电": [],
	"串联装置": ["search_to_bench"],
	"电气象征": [],
	"瞬步": ["energy_assignments"],
	"化危为吉": [],
	"星耀诞生": ["search_cards"],
}

const EFFECT_ROLE_HINTS := {
	"d3891abcfe3277c8811cde06741d3236": "stage2_acceleration",
	"5bdbc985f9aa2e6f248b53f6f35d1d37": "item_tool_search",
	"e366f56ecd3f805a28294109a1a37453": "energy_search_and_discard_fuel",
	"2234845fbc2e11ab95587e1b393bb318": "lightning_energy_acceleration",
	"651276c51911345aa091c1c7b87f3f4f": "ancient_energy_acceleration",
}


func extract_for_player(player: PlayerState) -> Dictionary:
	if player == null:
		return {}
	var card_datas: Array[CardData] = _collect_unique_card_data(player)
	var cards: Array[Dictionary] = []
	var action_types: Dictionary = {}
	var interaction_ids: Dictionary = {}
	var strategic_roles: Dictionary = {}
	for cd: CardData in card_datas:
		var cap: Dictionary = _describe_card(cd)
		cards.append(cap)
		for action_type: String in cap.get("actions", []):
			action_types[action_type] = true
		for interaction_id: String in cap.get("interactions", []):
			interaction_ids[interaction_id] = true
		for role: String in cap.get("roles", []):
			strategic_roles[role] = true
	return {
		"schema": "deck_capabilities_v1",
		"cards": cards,
		"action_types": _sorted_keys(action_types),
		"interaction_ids": _sorted_keys(interaction_ids),
		"strategic_roles": _sorted_keys(strategic_roles),
		"tree_requirements": [
			"Use card names only from card.name or card.name_en.",
			"If a selected card has interaction_ids, include matching action.interactions.",
			"Prefer target_policy over hard-coded target names when the exact target depends on current board.",
		],
	}


func _collect_unique_card_data(player: PlayerState) -> Array[CardData]:
	var by_key: Dictionary = {}
	var result: Array[CardData] = []
	var add_card := func(card: CardInstance) -> void:
		if card == null or card.card_data == null:
			return
		var key: String = "%s_%s_%s" % [card.card_data.set_code, card.card_data.card_index, card.card_data.name]
		if by_key.has(key):
			return
		by_key[key] = true
		result.append(card.card_data)
	for card: CardInstance in player.hand:
		add_card.call(card)
	for card: CardInstance in player.deck:
		add_card.call(card)
	for card: CardInstance in player.discard_pile:
		add_card.call(card)
	for card: CardInstance in player.prizes:
		add_card.call(card)
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		for card: CardInstance in slot.pokemon_stack:
			add_card.call(card)
		for card: CardInstance in slot.attached_energy:
			add_card.call(card)
		add_card.call(slot.attached_tool)
	return result


func _describe_card(cd: CardData) -> Dictionary:
	var actions: Array[String] = []
	var interactions: Array[String] = []
	var roles: Array[String] = []
	if cd.is_pokemon():
		if cd.stage == "Basic":
			actions.append("play_basic_to_bench")
		else:
			actions.append("evolve")
		if not cd.abilities.is_empty():
			actions.append("use_ability")
		if not cd.attacks.is_empty():
			actions.append("attack")
		roles.append_array(_pokemon_roles(cd))
	elif cd.card_type in ["Item", "Supporter"]:
		actions.append("play_trainer")
	elif cd.card_type == "Stadium":
		actions.append("play_stadium")
	elif cd.card_type == "Tool":
		actions.append("attach_tool")
	elif cd.is_energy():
		actions.append("attach_energy")

	interactions.append_array(_interactions_for_card(cd))
	roles.append_array(_roles_for_card(cd))
	return {
		"name": str(cd.name),
		"name_en": str(cd.name_en),
		"card_type": str(cd.card_type),
		"stage": str(cd.stage),
		"evolves_from": str(cd.evolves_from),
		"effect_id": str(cd.effect_id),
		"actions": _dedupe_strings(actions),
		"interactions": _dedupe_strings(interactions),
		"roles": _dedupe_strings(roles),
		"abilities": _ability_summaries(cd),
		"attacks": _attack_summaries(cd),
	}


func _interactions_for_card(cd: CardData) -> Array[String]:
	var result: Array[String] = []
	result.append_array(EFFECT_TO_INTERACTIONS.get(str(cd.effect_id), []))
	for ability: Dictionary in cd.abilities:
		var ability_name: String = str(ability.get("name", ""))
		result.append_array(ABILITY_TO_INTERACTIONS.get(ability_name, []))
	for attack: Dictionary in cd.attacks:
		var text: String = str(attack.get("text", ""))
		if text.find("伤害指示物") >= 0 or text.to_lower().find("damage counter") >= 0:
			result.append("counter_distribution")
		if text.find("弃") >= 0 or text.to_lower().find("discard") >= 0:
			result.append("attack_energy_discard")
		if text.find("备战") >= 0 or text.to_lower().find("bench") >= 0:
			result.append("attack_target")
	return _dedupe_strings(result)


func _roles_for_card(cd: CardData) -> Array[String]:
	var roles: Array[String] = []
	var effect_role: String = str(EFFECT_ROLE_HINTS.get(str(cd.effect_id), ""))
	if effect_role != "":
		roles.append(effect_role)
	if cd.card_type == "Tool":
		roles.append("tool_modifier")
	if cd.card_type == "Stadium":
		roles.append("stadium_modifier")
	if cd.is_energy():
		roles.append("energy_resource")
	return roles


func _pokemon_roles(cd: CardData) -> Array[String]:
	var roles: Array[String] = []
	if cd.mechanic in ["ex", "V", "VSTAR"]:
		roles.append("multi_prize_pokemon")
	if cd.stage == "Stage 2":
		roles.append("stage2_line")
	if not cd.attacks.is_empty():
		roles.append("attacker_candidate")
	for ability: Dictionary in cd.abilities:
		var name: String = str(ability.get("name", ""))
		match name:
			"音速搜索", "星耀诞生":
				roles.append("universal_search_engine")
			"烈炎支配", "精神拥抱", "瞬步":
				roles.append("energy_acceleration")
			"隐藏牌", "精炼", "快速充电", "化危为吉":
				roles.append("draw_engine")
			"咒怨炸弹", "诅咒炸弹", "亢奋脑力":
				roles.append("damage_counter_control")
			"串联装置":
				roles.append("bench_setup_engine")
			"电气象征":
				roles.append("damage_boost_engine")
	return _dedupe_strings(roles)


func _ability_summaries(cd: CardData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ability: Dictionary in cd.abilities:
		result.append({
			"name": str(ability.get("name", "")),
			"interactions": ABILITY_TO_INTERACTIONS.get(str(ability.get("name", "")), []),
		})
	return result


func _attack_summaries(cd: CardData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for attack: Dictionary in cd.attacks:
		result.append({
			"name": str(attack.get("name", "")),
			"cost": str(attack.get("cost", "")),
			"damage": str(attack.get("damage", "")),
		})
	return result


func _dedupe_strings(values: Array) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for value: Variant in values:
		var text: String = str(value).strip_edges()
		if text == "" or seen.has(text):
			continue
		seen[text] = true
		result.append(text)
	result.sort()
	return result


func _sorted_keys(dict: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in dict.keys():
		keys.append(str(key))
	keys.sort()
	return keys
