class_name AttackAttachBasicEnergyFromDiscard
extends BaseEffect

var energy_type: String = ""
var max_count: int = 2


func _init(required_type: String = "", count: int = 2) -> void:
	energy_type = required_type
	max_count = count


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var attached := 0
	var discard_copy: Array[CardInstance] = player.discard_pile.duplicate()
	for discard_card: CardInstance in discard_copy:
		if attached >= max_count:
			break
		if discard_card.card_data.card_type != "Basic Energy":
			continue
		if energy_type != "" and discard_card.card_data.energy_provides != energy_type:
			continue
		player.discard_pile.erase(discard_card)
		attacker.attached_energy.append(discard_card)
		attached += 1


func get_description() -> String:
	return "Attach Basic Energy from your discard pile to this Pokemon."
