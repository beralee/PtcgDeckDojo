## 金属制造者特性效果 - 金属怪（金属制造者）
## 查看牌库顶 look_count 张牌，从中选出基本钢能量附着于己方任意宝可梦，
## 剩余卡牌按任意顺序放回牌库底部
## 参数: look_count (int), energy_type (String)
class_name AbilityMetalMaker
extends BaseEffect

## 查看牌库顶的卡牌数量
var look_count: int = 4
## 筛选的能量类型（默认 "M" = 钢能量）
var energy_type: String = "M"

## 每回合已使用标记 key
const USED_KEY: String = "ability_metal_maker_used"


func _init(look: int = 4, e_type: String = "M") -> void:
	look_count = look
	energy_type = e_type


## 检查特性是否可以使用
func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index

	# 每回合限用1次
	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == USED_KEY and eff.get("turn") == state.turn_number:
			return false

	# 牌库必须有牌
	var player: PlayerState = state.players[pi]
	return not player.deck.is_empty()


## 执行特性
## targets: 每个元素为要附着能量的 PokemonSlot（可为空，此时自动选己方战斗宝可梦）
## 简化逻辑：
##   1. 查看牌库顶 look_count 张（最多，不足时取全部）
##   2. 将其中符合条件的钢能量依次附着到 targets 指定宝可梦（或自动选择）
##   3. 剩余卡牌放回牌库底部（简化：直接 append 到 deck 末尾）
func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]

	if player.deck.is_empty():
		return

	# 取牌库顶 look_count 张（不足则全取）
	var take: int = mini(look_count, player.deck.size())
	var viewed: Array[CardInstance] = []
	for _i: int in take:
		viewed.append(player.deck.pop_front())

	# 分离：符合能量条件的卡 vs 其他卡
	var energies: Array[CardInstance] = []
	var others: Array[CardInstance] = []
	for card: CardInstance in viewed:
		if _matches_energy(card):
			energies.append(card)
		else:
			others.append(card)

	# 将符合条件的能量附着到目标宝可梦
	# targets 中每个元素为 PokemonSlot；若未指定目标则依次附着到己方所有宝可梦
	var attach_targets: Array[PokemonSlot] = []
	if not targets.is_empty():
		for t: Variant in targets:
			if t is PokemonSlot:
				attach_targets.append(t as PokemonSlot)
	else:
		attach_targets.append_array(player.get_all_pokemon())

	var energy_idx: int = 0
	if attach_targets.size() == 1 and not energies.is_empty():
		var single_target: PokemonSlot = attach_targets[0]
		for energy_card: CardInstance in energies:
			energy_card.face_up = true
			single_target.attached_energy.append(energy_card)
			energy_idx += 1
	else:
		for target_slot: PokemonSlot in attach_targets:
			if energy_idx >= energies.size():
				break
			var energy_card: CardInstance = energies[energy_idx]
			energy_card.face_up = true
			target_slot.attached_energy.append(energy_card)
			energy_idx += 1

	# 未能附着的能量也放回牌库底
	while energy_idx < energies.size():
		var leftover: CardInstance = energies[energy_idx]
		leftover.face_up = false
		player.deck.append(leftover)
		energy_idx += 1

	# 其他卡牌放回牌库底
	for card: CardInstance in others:
		card.face_up = false
		player.deck.append(card)

	# 不再额外洗牌（规则中剩余卡回到牌库底，非顶，通常不洗牌）

	# 标记本回合已使用
	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


## 判断卡牌是否为目标能量类型（基本钢能量）
func _matches_energy(card: CardInstance) -> bool:
	var cd: CardData = card.card_data
	if cd == null:
		return false
	if cd.card_type != "Basic Energy":
		return false
	return cd.energy_provides == energy_type


func get_description() -> String:
	return "特性【金属制造者】：查看牌库顶%d张牌，从中将基本%s能量附着于己方宝可梦，其余放回牌库底。（每回合1次）" % [
		look_count, energy_type
	]
