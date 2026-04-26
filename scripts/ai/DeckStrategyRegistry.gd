class_name DeckStrategyRegistry
extends RefCounted


const DeckStrategyMiraidonScript = preload("res://scripts/ai/DeckStrategyMiraidon.gd")
const DeckStrategyCharizardExScript = preload("res://scripts/ai/DeckStrategyCharizardEx.gd")
const DeckStrategyCharizardExBaselineScript = preload("res://scripts/ai/DeckStrategyCharizardExBaseline.gd")
const DeckStrategyDragapultDusknoirScript = preload("res://scripts/ai/DeckStrategyDragapultDusknoir.gd")
const DeckStrategyDragapultBanetteScript = preload("res://scripts/ai/DeckStrategyDragapultBanette.gd")
const DeckStrategyDragapultCharizardScript = preload("res://scripts/ai/DeckStrategyDragapultCharizard.gd")
const DeckStrategyRegidragoScript = preload("res://scripts/ai/DeckStrategyRegidrago.gd")
const DeckStrategyLugiaArcheopsScript = preload("res://scripts/ai/DeckStrategyLugiaArcheops.gd")
const DeckStrategyDialgaMetangScript = preload("res://scripts/ai/DeckStrategyDialgaMetang.gd")
const DeckStrategyArceusGiratinaScript = preload("res://scripts/ai/DeckStrategyArceusGiratina.gd")
const DeckStrategyPalkiaGholdengoScript = preload("res://scripts/ai/DeckStrategyPalkiaGholdengo.gd")
const DeckStrategyPalkiaDusknoirScript = preload("res://scripts/ai/DeckStrategyPalkiaDusknoir.gd")
const DeckStrategyLostBoxScript = preload("res://scripts/ai/DeckStrategyLostBox.gd")
const DeckStrategyFutureBoxScript = preload("res://scripts/ai/DeckStrategyFutureBox.gd")
const DeckStrategyIronThornsScript = preload("res://scripts/ai/DeckStrategyIronThorns.gd")
const DeckStrategyRagingBoltOgerponScript = preload("res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd")
const DeckStrategyRagingBoltLLMScript = preload("res://scripts/ai/DeckStrategyRagingBoltLLM.gd")
const DeckStrategyBlisseyTankScript = preload("res://scripts/ai/DeckStrategyBlisseyTank.gd")
const DeckStrategyGougingFireAncientScript = preload("res://scripts/ai/DeckStrategyGougingFireAncient.gd")
const _GARDEVOIR_SCRIPT_PATH := "res://scripts/ai/DeckStrategyGardevoir.gd"
const _GARDEVOIR_SIGNATURES: Array[String] = ["沙奈朵ex", "奇鲁莉安", "拉鲁拉丝", "Gardevoir ex", "Kirlia", "Ralts"]

const _STRATEGY_SCRIPTS := {
	"charizard_ex": DeckStrategyCharizardExScript,
	"charizard_ex_baseline": DeckStrategyCharizardExBaselineScript,
	"dragapult_dusknoir": DeckStrategyDragapultDusknoirScript,
	"dragapult_banette": DeckStrategyDragapultBanetteScript,
	"dragapult_charizard": DeckStrategyDragapultCharizardScript,
	"regidrago": DeckStrategyRegidragoScript,
	"lugia_archeops": DeckStrategyLugiaArcheopsScript,
	"dialga_metang": DeckStrategyDialgaMetangScript,
	"arceus_giratina": DeckStrategyArceusGiratinaScript,
	"palkia_gholdengo": DeckStrategyPalkiaGholdengoScript,
	"palkia_dusknoir": DeckStrategyPalkiaDusknoirScript,
	"lost_box": DeckStrategyLostBoxScript,
	"future_box": DeckStrategyFutureBoxScript,
	"iron_thorns": DeckStrategyIronThornsScript,
	"raging_bolt_ogerpon": DeckStrategyRagingBoltOgerponScript,
	"raging_bolt_ogerpon_llm": DeckStrategyRagingBoltLLMScript,
	"blissey_tank": DeckStrategyBlisseyTankScript,
	"gouging_fire_ancient": DeckStrategyGougingFireAncientScript,
	"miraidon": DeckStrategyMiraidonScript,
}

const _STRATEGY_ORDER: Array[String] = [
	"dragapult_charizard",
	"dragapult_dusknoir",
	"dragapult_banette",
	"charizard_ex",
	"palkia_dusknoir",
	"palkia_gholdengo",
	"regidrago",
	"lugia_archeops",
	"dialga_metang",
	"arceus_giratina",
	"future_box",
	"iron_thorns",
	"raging_bolt_ogerpon",
	"gouging_fire_ancient",
	"blissey_tank",
	"lost_box",
	"gardevoir",
	"miraidon",
]


func detect_strategy_id_for_player(player: PlayerState) -> String:
	if player == null:
		return ""
	var visible_names: Dictionary = {}
	for name: String in _collect_visible_names(player):
		visible_names[name] = true
	return _best_strategy_id_for_visible_names(visible_names)


func create_strategy_by_id(strategy_id: String) -> RefCounted:
	if strategy_id == "gardevoir":
		return _instantiate_strategy_from_path(_GARDEVOIR_SCRIPT_PATH)
	var script: Variant = _STRATEGY_SCRIPTS.get(strategy_id, null)
	if script is GDScript:
		return (script as GDScript).new()
	return null


func create_strategy_for_player(player: PlayerState) -> RefCounted:
	var strategy_id: String = detect_strategy_id_for_player(player)
	if strategy_id == "":
		return null
	return create_strategy_by_id(strategy_id)


func resolve_strategy_id_for_deck(deck: DeckData) -> String:
	if deck == null:
		return ""
	var visible_names: Dictionary = {}
	for name: String in _collect_deck_names(deck):
		visible_names[name] = true
	return _best_strategy_id_for_visible_names(visible_names)


func resolve_strategy_for_deck(deck: DeckData) -> RefCounted:
	var strategy_id: String = resolve_strategy_id_for_deck(deck)
	if strategy_id == "":
		return null
	var strategy := create_strategy_by_id(strategy_id)
	_configure_strategy_from_deck(strategy, deck)
	return strategy


func apply_strategy_for_deck(ai: RefCounted, deck: DeckData) -> RefCounted:
	if ai == null or not ai.has_method("set_deck_strategy"):
		return null
	var strategy := resolve_strategy_for_deck(deck)
	if strategy != null:
		ai.call("set_deck_strategy", strategy)
	return strategy


func _best_strategy_id_for_visible_names(visible_names: Dictionary) -> String:
	var best_strategy_id := ""
	var best_match_count := 0
	for strategy_id: String in _STRATEGY_ORDER:
		if strategy_id == "gardevoir":
			var gardevoir_match_count := 0
			for signature_name: String in _GARDEVOIR_SIGNATURES:
				if visible_names.has(signature_name):
					gardevoir_match_count += 1
			if gardevoir_match_count > best_match_count:
				best_match_count = gardevoir_match_count
				best_strategy_id = strategy_id
			continue
		var strategy = create_strategy_by_id(strategy_id)
		if strategy == null or not strategy.has_method("get_signature_names"):
			continue
		var match_count := 0
		for signature_name: String in strategy.get_signature_names():
			if visible_names.has(signature_name):
				match_count += 1
		if match_count > best_match_count:
			best_match_count = match_count
			best_strategy_id = strategy_id
	if best_match_count > 0:
		return best_strategy_id
	return ""


func _configure_strategy_from_deck(strategy: RefCounted, deck: DeckData) -> void:
	if strategy == null or deck == null:
		return
	if strategy.has_method("set_deck_strategy_text"):
		strategy.call("set_deck_strategy_text", str(deck.strategy))


func _instantiate_strategy_from_path(script_path: String) -> RefCounted:
	var script: Variant = load(script_path)
	if script is GDScript:
		return (script as GDScript).new()
	return null


func _collect_visible_names(player: PlayerState) -> Array[String]:
	var names: Array[String] = []
	for card: CardInstance in player.hand:
		_append_card_names(card, names)
	if player.active_pokemon != null and player.active_pokemon.get_top_card() != null:
		_append_card_names(player.active_pokemon.get_top_card(), names)
	for slot: PokemonSlot in player.bench:
		if slot != null and slot.get_top_card() != null:
			_append_card_names(slot.get_top_card(), names)
	return names


func _append_card_names(card: CardInstance, names: Array[String]) -> void:
	if card == null or card.card_data == null:
		return
	var localized_name := str(card.card_data.name)
	var english_name := str(card.card_data.name_en)
	if localized_name != "":
		names.append(localized_name)
	if english_name != "" and english_name != localized_name:
		names.append(english_name)


func _collect_deck_names(deck: DeckData) -> Array[String]:
	var names: Array[String] = []
	if deck == null:
		return names
	for card_entry_variant: Variant in deck.cards:
		if not card_entry_variant is Dictionary:
			continue
		var card_entry: Dictionary = card_entry_variant
		var localized_name := str(card_entry.get("name", ""))
		var english_name := str(card_entry.get("name_en", ""))
		if localized_name != "":
			names.append(localized_name)
		if english_name != "" and english_name != localized_name:
			names.append(english_name)
	return names
