## 交替推车 - 将战斗场上的基础宝可梦与备战宝可梦互换，治疗换入备战区的30HP
class_name EffectSwitchCart
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	if player.active_pokemon == null or player.bench.is_empty():
		return false
	# 战斗宝可梦必须是基础宝可梦
	var cd: CardData = player.active_pokemon.get_card_data()
	return cd != null and cd.stage == "Basic"


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		items.append(slot)
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [{
		"id": "switch_target",
		"title": "选择要换上战斗场的备战宝可梦",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]

	if player.active_pokemon == null or player.bench.is_empty():
		return

	var old_active: PokemonSlot = player.active_pokemon
	var ctx: Dictionary = get_interaction_context(targets)
	var new_active: PokemonSlot = null
	var target_raw: Array = ctx.get("switch_target", [])
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = target_raw[0]
		if candidate in player.bench:
			new_active = candidate
	if new_active == null:
		return

	player.bench.erase(new_active)
	player.bench.append(old_active)
	player.active_pokemon = new_active

	# 治疗换入备战区的宝可梦（即原战斗宝可梦）30HP
	old_active.damage_counters = maxi(0, old_active.damage_counters - 30)


func get_description() -> String:
	return "将战斗场基础宝可梦与备战宝可梦互换，治疗换入备战区的30HP"
