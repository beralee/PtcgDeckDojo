## 精神拥抱特性 - 沙奈朵ex
## 每回合可使用任意次。从弃牌区选择1张基本超能量，附着到己方超属性宝可梦身上，
## 然后在该宝可梦身上放置2个伤害指示物。
## 不能对放置指示物后会昏厥的宝可梦使用。
class_name AbilityPsychicEmbrace
extends BaseEffect


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var player: PlayerState = state.players[top.owner_index]
	if not _has_psychic_energy_in_discard(player):
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_valid_target(slot, state):
			return true
	return false


func can_use_embrace_on_target(target: PokemonSlot, state: GameState = null) -> bool:
	return _is_valid_target(target, state)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		if _is_basic_psychic_energy(discard_card):
			energy_items.append(discard_card)
			energy_labels.append(discard_card.card_data.name)
	if energy_items.is_empty():
		return []

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_valid_target(slot, state):
			target_items.append(slot)
			target_labels.append(slot.get_pokemon_name())
	if target_items.is_empty():
		return []

	return [
		{
			"id": "embrace_energy",
			"title": "选择弃牌区中1张基本超能量",
			"items": energy_items,
			"labels": energy_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "embrace_target",
			"title": "选择要附着能量的超属性宝可梦",
			"items": target_items,
			"labels": target_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var energy_raw: Array = ctx.get("embrace_energy", [])
	var energy_card: CardInstance = null
	if not energy_raw.is_empty() and energy_raw[0] is CardInstance:
		var chosen_energy: CardInstance = energy_raw[0]
		if chosen_energy in player.discard_pile and _is_basic_psychic_energy(chosen_energy):
			energy_card = chosen_energy
	if energy_card == null:
		for discard_card: CardInstance in player.discard_pile:
			if _is_basic_psychic_energy(discard_card):
				energy_card = discard_card
				break
	if energy_card == null:
		return

	var target_raw: Array = ctx.get("embrace_target", [])
	var target_slot: PokemonSlot = null
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var chosen_target: PokemonSlot = target_raw[0]
		if chosen_target in player.get_all_pokemon() and _is_valid_target(chosen_target, state):
			target_slot = chosen_target
	if target_slot == null:
		for slot: PokemonSlot in player.get_all_pokemon():
			if _is_valid_target(slot, state):
				target_slot = slot
				break
	if target_slot == null:
		return

	player.discard_pile.erase(energy_card)
	energy_card.face_up = true
	target_slot.attached_energy.append(energy_card)
	target_slot.damage_counters += 20


func _is_basic_psychic_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.card_type == "Basic Energy" and card.card_data.energy_provides == "P"


func _has_psychic_energy_in_discard(player: PlayerState) -> bool:
	for card: CardInstance in player.discard_pile:
		if _is_basic_psychic_energy(card):
			return true
	return false


func _is_valid_target(slot: PokemonSlot, state: GameState = null) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null or top.card_data == null:
		return false
	if top.card_data.energy_type != "P":
		return false
	return _get_effective_remaining_hp(slot, state) > 20


func _get_effective_remaining_hp(slot: PokemonSlot, state: GameState = null) -> int:
	if slot == null:
		return 0
	if state == null:
		return slot.get_remaining_hp()
	var processor := EffectProcessor.new()
	return processor.get_effective_remaining_hp(slot, state)


func get_description() -> String:
	return "特性【精神拥抱】：从弃牌区选1张基本超能量附着到己方超属性宝可梦上，放置2个伤害指示物。（每回合可任意次使用）"
