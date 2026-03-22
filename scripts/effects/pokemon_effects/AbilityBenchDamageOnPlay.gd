class_name AbilityBenchDamageOnPlay
extends BaseEffect

const USED_FLAG_TYPE := "ability_bench_damage_on_play_used"

var damage_per_target: int = 10
var target_count: int = 2


func _init(damage_each: int = 10, max_targets: int = 2) -> void:
	damage_per_target = damage_each
	target_count = max_targets


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	if pokemon.turn_played != state.turn_number:
		return false
	if not state.players[top.owner_index].bench.has(pokemon):
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false
	return not state.players[1 - top.owner_index].bench.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var items: Array = opponent.bench.duplicate()
	var labels: Array[String] = []
	for slot: PokemonSlot in opponent.bench:
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	var select_count: int = mini(target_count, items.size())
	return [{
		"id": "opponent_bench_targets",
		"title": "选择对手的 %d 只备战宝可梦放置伤害指示物" % select_count,
		"items": items,
		"labels": labels,
		"min_select": select_count,
		"max_select": select_count,
		"allow_cancel": true,
	}]


func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("opponent_bench_targets", [])
	var applied := 0
	for entry: Variant in selected_raw:
		if entry is PokemonSlot and entry in opponent.bench:
			entry.damage_counters += damage_per_target
			applied += 1
			if applied >= target_count:
				break
	pokemon.effects.append({"type": USED_FLAG_TYPE, "turn": state.turn_number})


func get_description() -> String:
	return "将这张卡牌从手牌放于备战区时，给对手的 %d 只备战宝可梦各放置1个伤害指示物。" % target_count
