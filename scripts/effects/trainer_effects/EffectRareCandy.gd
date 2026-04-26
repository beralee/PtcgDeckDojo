## 神奇糖果 - 跳过1阶段进化，将2阶段进化宝可梦放在基础宝可梦上
## 不能在最初回合使用，也不能对当回合刚出场的宝可梦使用
class_name EffectRareCandy
extends BaseEffect

const STAGE_ONE_BASIC_NAME_OVERRIDES := {
	"比比鸟": ["波波", "Pidgey"],
	"呱头蛙": ["呱呱泡蛙", "Froakie"],
	"冻脊龙": ["凉脊龙", "Frigibax"],
	"Pidgeotto": ["Pidgey", "波波"],
	"Frogadier": ["Froakie", "呱呱泡蛙"],
	"Arctibax": ["Frigibax", "凉脊龙"],
}


func _get_card_database() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("CardDatabase")
	return null


func _can_rare_candy_evolve(stage2_card: CardInstance, target_slot: PokemonSlot, state: GameState) -> bool:
	if stage2_card == null or target_slot == null or state == null:
		return false
	if state.is_first_turn_for_player(stage2_card.owner_index):
		return false
	if not stage2_card.card_data.is_pokemon() or stage2_card.card_data.stage != "Stage 2":
		return false
	if target_slot.pokemon_stack.size() != 1:
		return false
	if target_slot.turn_played == state.turn_number:
		return false

	var target_top: CardInstance = target_slot.get_top_card()
	if target_top == null or not target_top.card_data.is_basic_pokemon():
		return false

	var evolves_from: String = stage2_card.card_data.evolves_from
	if evolves_from == "":
		return false
	if evolves_from == target_slot.get_pokemon_name():
		return true

	var player: PlayerState = state.players[stage2_card.owner_index]
	if player != null:
		for card: CardInstance in player.hand:
			if _matches_stage_one_reference(card, evolves_from, target_slot.get_pokemon_name()):
				return true
		for card: CardInstance in player.deck:
			if _matches_stage_one_reference(card, evolves_from, target_slot.get_pokemon_name()):
				return true
		for card: CardInstance in player.discard_pile:
			if _matches_stage_one_reference(card, evolves_from, target_slot.get_pokemon_name()):
				return true
		for card: CardInstance in player.prizes:
			if _matches_stage_one_reference(card, evolves_from, target_slot.get_pokemon_name()):
				return true
		for slot: PokemonSlot in player.get_all_pokemon():
			for ref_card: CardInstance in slot.pokemon_stack:
				if _matches_stage_one_reference(ref_card, evolves_from, target_slot.get_pokemon_name()):
					return true

	var card_database := _get_card_database()
	if card_database != null:
		for card_data: CardData in card_database.get_all_cards():
			if card_data == null or not card_data.is_pokemon():
				continue
			if card_data.stage != "Stage 1":
				continue
			if card_data.name != evolves_from:
				continue
			if card_data.evolves_from == target_slot.get_pokemon_name():
				return true
	return _matches_stage_one_basic_override(evolves_from, target_slot.get_pokemon_name())


func _matches_stage_one_basic_override(stage_one_name: String, basic_name: String) -> bool:
	var aliases: Variant = STAGE_ONE_BASIC_NAME_OVERRIDES.get(stage_one_name, [])
	if aliases is String:
		return str(aliases) == basic_name
	if aliases is Array:
		for alias: Variant in aliases:
			if str(alias) == basic_name:
				return true
	return false


func _matches_stage_one_reference(card: CardInstance, stage_one_name: String, basic_name: String) -> bool:
	if card == null or card.card_data == null:
		return false
	var card_data: CardData = card.card_data
	return (
		card_data.is_pokemon()
		and card_data.stage == "Stage 1"
		and card_data.name == stage_one_name
		and card_data.evolves_from == basic_name
	)


func _get_valid_stage2_targets(player: PlayerState, stage2_card: CardInstance, state: GameState) -> Array[PokemonSlot]:
	var targets: Array[PokemonSlot] = []
	if player == null:
		return targets
	for slot: PokemonSlot in player.get_all_pokemon():
		if _can_rare_candy_evolve(stage2_card, slot, state):
			targets.append(slot)
	return targets


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var stage2_items: Array = []
	var stage2_labels: Array[String] = []
	var valid_target_map: Dictionary = {}

	for c: CardInstance in player.hand:
		if not c.card_data.is_pokemon() or c.card_data.stage != "Stage 2":
			continue
		var valid_targets: Array[PokemonSlot] = _get_valid_stage2_targets(player, c, state)
		if valid_targets.is_empty():
			continue
		stage2_items.append(c)
		stage2_labels.append(c.card_data.name)
		for slot: PokemonSlot in valid_targets:
			valid_target_map[slot] = true

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if not valid_target_map.has(slot):
			continue
		target_items.append(slot)
		target_labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])

	return [
		{
			"id": "stage2_card",
			"title": "选择要跳阶进化的2阶段宝可梦",
			"items": stage2_items,
			"labels": stage2_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "target_pokemon",
			"title": "选择要进化的基础宝可梦",
			"items": target_items,
			"labels": target_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	if state.is_first_turn_for_player(pi):
		return false

	for c: CardInstance in player.hand:
		if not c.card_data.is_pokemon() or c.card_data.stage != "Stage 2":
			continue
		if not _get_valid_stage2_targets(player, c, state).is_empty():
			return true
	return false


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	var stage2_card: CardInstance = null
	var target_slot: PokemonSlot = null
	var has_explicit_stage2 := false
	var has_explicit_target := false

	var stage2_raw: Array = ctx.get("stage2_card", [])
	if not stage2_raw.is_empty() and stage2_raw[0] is CardInstance:
		has_explicit_stage2 = true
		var selected_stage2: CardInstance = stage2_raw[0]
		if selected_stage2 in player.hand:
			stage2_card = selected_stage2

	var target_raw: Array = ctx.get("target_pokemon", [])
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		has_explicit_target = true
		var selected_target: PokemonSlot = target_raw[0]
		if selected_target in player.get_all_pokemon():
			target_slot = selected_target

	if not _can_rare_candy_evolve(stage2_card, target_slot, state):
		if has_explicit_stage2 or has_explicit_target:
			return
		stage2_card = null
		target_slot = null

	if stage2_card == null or target_slot == null:
		for c: CardInstance in player.hand:
			var valid_targets: Array[PokemonSlot] = _get_valid_stage2_targets(player, c, state)
			if valid_targets.is_empty():
				continue
			stage2_card = c
			target_slot = valid_targets[0]
			break

	if stage2_card == null or target_slot == null:
		return

	player.hand.erase(stage2_card)
	target_slot.pokemon_stack.append(stage2_card)
	target_slot.turn_evolved = state.turn_number
	target_slot.clear_all_status()


func get_description() -> String:
	return "选择手牌中的2阶段进化宝可梦，跳过1阶段直接进化场上的基础宝可梦。"
