class_name AttackLostMine
extends BaseEffect

var required_lost_zone_count: int = 10
var total_damage: int = 120
var attack_index_to_match: int = -1


func _init(required_count: int = 10, total: int = 120, match_attack_index: int = -1) -> void:
	required_lost_zone_count = required_count
	total_damage = total
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.lost_zone.size() < required_lost_zone_count:
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var target_items: Array = []
	var target_labels: Array[String] = []
	if opponent.active_pokemon != null:
		target_items.append(opponent.active_pokemon)
		target_labels.append(opponent.active_pokemon.get_pokemon_name())
	for slot: PokemonSlot in opponent.bench:
		target_items.append(slot)
		target_labels.append(slot.get_pokemon_name())
	if target_items.is_empty():
		return []
	var counter_count: int = total_damage / 10
	return [{
		"id": "lost_mine_counters",
		"title": "将 %d 个伤害指示物以任意方式放置到对手的宝可梦身上" % counter_count,
		"ui_mode": "counter_distribution",
		"total_counters": counter_count,
		"target_items": target_items,
		"target_labels": target_labels,
		"min_select": counter_count,
		"max_select": counter_count,
		"allow_cancel": false,
	}]


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	if player.lost_zone.size() < required_lost_zone_count:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var legal_targets: Array[PokemonSlot] = []
	if opponent.active_pokemon != null:
		legal_targets.append(opponent.active_pokemon)
	for slot: PokemonSlot in opponent.bench:
		legal_targets.append(slot)
	if legal_targets.is_empty():
		return
	var ctx: Dictionary = get_attack_interaction_context()
	var assignments_raw: Array = ctx.get("lost_mine_counters", [])
	if not assignments_raw.is_empty():
		for entry: Variant in assignments_raw:
			if not (entry is Dictionary):
				continue
			var assignment: Dictionary = entry
			var target: Variant = assignment.get("target", null)
			var amount: int = int(assignment.get("amount", 10))
			if target is PokemonSlot and target in legal_targets:
				(target as PokemonSlot).damage_counters += max(0, amount)
		return

	var remaining: int = total_damage
	var idx: int = 0
	while remaining > 0 and not legal_targets.is_empty():
		var chunk: int = min(10, remaining)
		legal_targets[idx % legal_targets.size()].damage_counters += chunk
		remaining -= chunk
		idx += 1


func get_description() -> String:
	return "当自己的放逐区有 %d 张以上卡牌时，将 %d 个伤害指示物以任意方式放置到对手的宝可梦身上。" % [
		required_lost_zone_count,
		total_damage / 10,
	]


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if card == null or card.card_data == null:
		return int(attack.get("_override_attack_index", -1))
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return int(attack.get("_override_attack_index", -1))
