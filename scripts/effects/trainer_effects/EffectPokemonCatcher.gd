class_name EffectPokemonCatcher
extends BaseEffect

var coin_flipper: CoinFlipper
var _pending_heads: bool = false
var _has_pending_flip: bool = false


func _init(flipper: CoinFlipper = null) -> void:
	coin_flipper = flipper if flipper != null else CoinFlipper.new()


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[1 - card.owner_index].bench.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	_pending_heads = coin_flipper.flip()
	_has_pending_flip = true
	if not _pending_heads:
		return []

	var opponent: PlayerState = state.players[1 - card.owner_index]
	var items: Array = opponent.bench.duplicate()
	var labels: Array[String] = []
	for slot: PokemonSlot in opponent.bench:
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [{
		"id": "opponent_bench_target",
		"title": "Choose 1 opponent Benched Pokemon",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if not _has_pending_flip:
		_pending_heads = coin_flipper.flip()
		_has_pending_flip = true
	if not _pending_heads:
		_has_pending_flip = false
		return

	var opponent: PlayerState = state.players[1 - card.owner_index]
	if opponent.active_pokemon == null or opponent.bench.is_empty():
		_has_pending_flip = false
		return
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("opponent_bench_target", [])
	var chosen: PokemonSlot = opponent.bench[0]
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot and selected_raw[0] in opponent.bench:
		chosen = selected_raw[0]

	var old_active: PokemonSlot = opponent.active_pokemon
	opponent.bench.erase(chosen)
	opponent.bench.append(old_active)
	opponent.active_pokemon = chosen
	_has_pending_flip = false


func get_description() -> String:
	return "Flip a coin. If heads, switch in 1 of your opponent's Benched Pokemon."
