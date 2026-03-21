## Electric Generator - reveal the top 5 cards, then attach found Lightning Energy.
class_name EffectElectricGenerator
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return false
	for slot: PokemonSlot in player.bench:
		if slot.get_energy_type() == "L":
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var reveal_cards: Array[CardInstance] = []
	var reveal_labels: Array[String] = []
	for idx: int in mini(5, player.deck.size()):
		var reveal_card: CardInstance = player.deck[idx]
		reveal_cards.append(reveal_card)
		reveal_labels.append(reveal_card.card_data.name)

	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for reveal_card: CardInstance in reveal_cards:
		if _is_basic_lightning_energy(reveal_card):
			energy_items.append(reveal_card)
			energy_labels.append(reveal_card.card_data.name)

	var bench_items: Array = []
	var bench_labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		if slot.get_energy_type() == "L":
			bench_items.append(slot)
			bench_labels.append("%s (%d/%d)" % [
				slot.get_pokemon_name(),
				slot.get_remaining_hp(),
				slot.get_max_hp(),
			])

	var reveal_title: String = "查看牌库顶端 5 张：%s" % ", ".join(reveal_labels)
	if energy_items.is_empty():
		return [{
			"id": "reveal_only",
			"title": "%s\n未找到可附着的基础雷能量" % reveal_title,
			"items": ["继续"],
			"labels": ["继续"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	return [
		{
			"id": "selected_energy",
			"title": "%s\n选择最多 2 张要附着的基础雷能量" % reveal_title,
			"items": energy_items,
			"labels": energy_labels,
			"presentation": "cards",
			"card_items": energy_items,
			"choice_labels": energy_labels,
			"min_select": 1,
			"max_select": mini(2, energy_items.size()),
			"allow_cancel": true,
		},
		{
			"id": "attach_target",
			"title": "选择要附着能量的备战区雷属性宝可梦",
			"items": bench_items,
			"labels": bench_labels,
			"presentation": "cards",
			"card_items": bench_items,
			"choice_labels": bench_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var reveal_cards: Array[CardInstance] = []
	for idx: int in mini(5, player.deck.size()):
		reveal_cards.append(player.deck[idx])

	var selected_energy_raw: Array = ctx.get("selected_energy", [])
	var selected_energies: Array[CardInstance] = []
	for entry: Variant in selected_energy_raw:
		if entry is CardInstance and entry in reveal_cards and _is_basic_lightning_energy(entry):
			selected_energies.append(entry)

	if selected_energies.is_empty():
		player.shuffle_deck()
		return

	var target_slot: PokemonSlot = null
	var target_raw: Array = ctx.get("attach_target", [])
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = target_raw[0]
		if candidate in player.bench and candidate.get_energy_type() == "L":
			target_slot = candidate

	if target_slot == null:
		player.shuffle_deck()
		return

	for energy: CardInstance in selected_energies:
		player.deck.erase(energy)
		energy.face_up = true
		target_slot.attached_energy.append(energy)

	player.shuffle_deck()


func get_description() -> String:
	return "查看牌库顶端 5 张，选择最多 2 张基础雷能量附着到备战区雷属性宝可梦。"


func _is_basic_lightning_energy(card: CardInstance) -> bool:
	return (
		card.card_data.card_type == "Basic Energy"
		and card.card_data.energy_provides == "L"
	)
