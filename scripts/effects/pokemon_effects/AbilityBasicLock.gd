## 恶作剧之锁 - 钥圈儿
## 只要钥圈儿在战斗场，双方场上基础宝可梦的特性全部消除（除恶作剧之锁外）。
## 被动特性，由 EffectProcessor 在检查特性时查询。
class_name AbilityBasicLock
extends BaseEffect

const ABILITY_NAME: String = "恶作剧之锁"


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


## 检查基础宝可梦特性是否被恶作剧之锁封锁
## 只需要场上有一个在战斗场的钥圈儿拥有此特性即可
static func is_basic_abilities_disabled(state: GameState, checking_slot: PokemonSlot = null) -> bool:
	# 检查双方战斗场
	for pi: int in 2:
		var active: PokemonSlot = state.players[pi].active_pokemon
		if active == null:
			continue
		if _has_basic_lock_ability(active):
			return true
	return false


static func _has_basic_lock_ability(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var cd: CardData = top.card_data
	if cd == null:
		return false
	var abilities: Variant = cd.abilities
	if abilities == null:
		return false
	for ability: Variant in abilities:
		if ability is Dictionary:
			var ab_name: Variant = ability.get("name", "")
			if ab_name is String and (ab_name as String) == ABILITY_NAME:
				return true
	return false


## 检查给定宝可梦是否受到恶作剧之锁影响
## 只有基础宝可梦才会被锁，且拥有恶作剧之锁的宝可梦自身不受影响
static func is_locked_by_basic_lock(slot: PokemonSlot, state: GameState) -> bool:
	if not is_basic_abilities_disabled(state):
		return false
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var cd: CardData = top.card_data
	if cd == null:
		return false
	# 只锁基础宝可梦
	if cd.stage != "Basic":
		return false
	# 自身拥有恶作剧之锁不被锁
	if _has_basic_lock_ability(slot):
		return false
	return true


func get_description() -> String:
	return "特性【恶作剧之锁】：只要此宝可梦在战斗场，双方基础宝可梦的特性全部消除。"
