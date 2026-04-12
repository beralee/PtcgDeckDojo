class_name EffectMela
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	if state.last_knockout_turn_against[pi] != state.turn_number - 1:
		return false
	var player: PlayerState = state.players[pi]
	return _get_fire_energy(player).size() >= 1 and not player.get_all_pokemon().is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var pokemon_items: Array = player.get_all_pokemon()
	var pokemon_labels: Array[String] = []
	for slot: PokemonSlot in pokemon_items:
		pokemon_labels.append(slot.get_pokemon_name())
	var energy_items: Array = _get_fire_energy(player)
	var energy_labels: Array[String] = []
	for energy: CardInstance in energy_items:
		energy_labels.append(energy.card_data.name)
	return [
		{
			"id": "mela_target",
			"title": "选择要附着能量的宝可梦",
			"items": pokemon_items,
			"labels": pokemon_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "mela_energy",
			"title": "选择弃牌区中的1张基本火能量",
			"items": energy_items,
			"labels": energy_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var target_raw: Array = ctx.get("mela_target", [])
	if target_raw.is_empty() or not (target_raw[0] is PokemonSlot):
		return
	var target: PokemonSlot = target_raw[0]
	var energy_raw: Array = ctx.get("mela_energy", [])
	var attached_count := 0
	for entry: Variant in energy_raw:
		if attached_count >= 1:
			break
		if not (entry is CardInstance):
			continue
		var energy: CardInstance = entry
		if energy not in player.discard_pile:
			continue
		if energy.card_data.card_type != "Basic Energy" or energy.card_data.energy_provides != "R":
			continue
		player.discard_pile.erase(energy)
		target.attached_energy.append(energy)
		attached_count += 1
	var draw_count := maxi(0, 6 - player.hand.size())
	_draw_cards_with_log(state, card.owner_index, draw_count, card, "trainer")


func _get_fire_energy(player: PlayerState) -> Array:
	var items: Array = []
	for card: CardInstance in player.discard_pile:
		if card.card_data.card_type == "Basic Energy" and card.card_data.energy_provides == "R":
			items.append(card)
	return items


func get_description() -> String:
	return "上一个对手回合己方宝可梦昏厥时可使用。从弃牌区选1张基本火能量附着于宝可梦，然后抽卡到手牌6张。"
