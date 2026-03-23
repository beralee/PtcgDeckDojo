class_name AISetupPlanner
extends RefCounted


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var active_index := -1
	var bench_indices: Array[int] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card.card_data.card_type != "Pokemon":
			continue
		if str(card.card_data.stage) != "Basic":
			continue
		if active_index == -1:
			active_index = i
		elif bench_indices.size() < 5:
			bench_indices.append(i)
	return {
		"active_hand_index": active_index,
		"bench_hand_indices": bench_indices,
	}


func choose_mulligan_bonus_draw() -> bool:
	return true
