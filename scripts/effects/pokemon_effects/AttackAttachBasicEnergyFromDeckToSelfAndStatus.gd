class_name AttackAttachBasicEnergyFromDeckToSelfAndStatus
extends BaseEffect

const ASSIGNMENT_ID := "energy_assignments"

var energy_type: String = ""
var attach_count: int = 2
var status_name: String = "poisoned"
var attack_index_to_match: int = -1


func _init(e_type: String = "", count: int = 2, status: String = "poisoned", match_attack_index: int = -1) -> void:
	energy_type = e_type
	attach_count = count
	status_name = status
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if not applies_to_attack_index(int(attack.get("_override_attack_index", _get_attack_index(card, attack)))):
		return []
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var source_items: Array = _get_matching_basic_energy(player)
	if source_items.is_empty():
		return []
	var source_labels: Array[String] = []
	for energy: CardInstance in source_items:
		source_labels.append(energy.card_data.name)
	var self_slot := _find_owner_slot(card, player)
	if self_slot == null:
		return []
	return [build_card_assignment_step(
		ASSIGNMENT_ID,
		"Choose up to %d Basic %s Energy cards to attach to this Pokemon" % [attach_count, energy_type],
		source_items,
		source_labels,
		[self_slot],
		["%s (self)" % self_slot.get_pokemon_name()],
		0,
		mini(attach_count, source_items.size()),
		true
	)]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var candidates: Array = _get_matching_basic_energy(player)
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(ASSIGNMENT_ID, [])
	var has_explicit_selection: bool = ctx.has(ASSIGNMENT_ID)
	var chosen: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source", null)
		var target: Variant = assignment.get("target", null)
		if not (source is CardInstance) or target != attacker:
			continue
		var source_card := source as CardInstance
		if source_card not in candidates or source_card in chosen:
			continue
		chosen.append(source_card)
		if chosen.size() >= attach_count:
			break

	if chosen.is_empty() and not has_explicit_selection:
		for i: int in mini(attach_count, candidates.size()):
			chosen.append(candidates[i])

	var attached_count_local := 0
	for energy: CardInstance in chosen:
		if energy not in player.deck:
			continue
		player.deck.erase(energy)
		energy.face_up = true
		attacker.attached_energy.append(energy)
		attached_count_local += 1

	player.shuffle_deck()
	if attached_count_local > 0:
		attacker.set_status(status_name, true)


func _get_matching_basic_energy(player: PlayerState) -> Array:
	var result: Array = []
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type != "Basic Energy":
			continue
		if energy_type != "" and card.card_data.energy_provides != energy_type and card.card_data.energy_type != energy_type:
			continue
		result.append(card)
	return result


func _find_owner_slot(card: CardInstance, player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_top_card() == card:
			return slot
	return null


func _get_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "Attach up to %d Basic %s Energy card(s) from your deck to this Pokemon. If you do, it is now %s." % [attach_count, energy_type, status_name]
