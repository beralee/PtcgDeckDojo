## 粉碎之锤 - 投币正面→弃掉对手场上宝可梦身上附着的1个能量
class_name EffectCrushingHammer
extends BaseEffect

var _coin_flipper: CoinFlipper = null
var _pending_heads: bool = false
var _has_pending_flip: bool = false


func _init(flipper: CoinFlipper = null) -> void:
	_coin_flipper = flipper


func can_execute(_card: CardInstance, state: GameState) -> bool:
	var opp: PlayerState = state.players[1 - state.current_player_index]
	for slot: PokemonSlot in opp.get_all_pokemon():
		if not slot.attached_energy.is_empty():
			return true
	return false


func get_preview_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return [{
		"id": "coin_flip_preview",
		"title": "Flip a coin",
		"wait_for_coin_animation": true,
		"preview_only": true,
	}]


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var flipper: CoinFlipper = _coin_flipper if _coin_flipper != null else CoinFlipper.new()
	_pending_heads = flipper.flip()
	_has_pending_flip = true
	if not _pending_heads:
		return []
	var opp: PlayerState = state.players[1 - card.owner_index]
	var slot_items: Array = []
	var slot_labels: Array[String] = []
	for slot: PokemonSlot in opp.get_all_pokemon():
		if not slot.attached_energy.is_empty():
			slot_items.append(slot)
			slot_labels.append("%s (%d能量)" % [slot.get_pokemon_name(), slot.attached_energy.size()])
	if slot_items.is_empty():
		return []
	return [{
		"id": "target_pokemon",
		"title": "选择对手要弃掉能量的宝可梦",
		"items": slot_items,
		"labels": slot_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"wait_for_coin_animation": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if not _has_pending_flip:
		var flipper: CoinFlipper = _coin_flipper if _coin_flipper != null else CoinFlipper.new()
		_pending_heads = flipper.flip()
		_has_pending_flip = true
	if not _pending_heads:
		_has_pending_flip = false
		return

	var opp: PlayerState = state.players[1 - card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var target_slot: PokemonSlot = null

	var raw: Array = ctx.get("target_pokemon", [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var selected: PokemonSlot = raw[0]
		if selected in opp.get_all_pokemon() and not selected.attached_energy.is_empty():
			target_slot = selected

	if target_slot == null:
		for slot: PokemonSlot in opp.get_all_pokemon():
			if not slot.attached_energy.is_empty():
				target_slot = slot
				break

	if target_slot == null or target_slot.attached_energy.is_empty():
		_has_pending_flip = false
		return

	var energy: CardInstance = target_slot.attached_energy.pop_back()
	opp.discard_card(energy)
	_has_pending_flip = false


func get_description() -> String:
	return "投币正面：弃掉对手场上宝可梦身上附着的1个能量"
