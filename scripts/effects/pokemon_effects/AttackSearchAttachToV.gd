## 检索能量附着于V效果 - 从牌库中检索基本能量并附着到己方V宝可梦
## 适用: 阿尔宙斯VSTAR"三重新星"(检索最多3张基本能量附着到己方V宝可梦)
## 参数: max_energy_count
class_name AttackSearchAttachToV
extends BaseEffect

## 最多检索并附着的基本能量数量
var max_energy_count: int = 3


func _init(max_count: int = 3) -> void:
	max_energy_count = max_count


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var player: PlayerState = state.players[pi]

	# 收集牌库中所有基本能量
	var basic_energies: Array = []
	for card: CardInstance in player.deck:
		if card.card_data != null and card.card_data.card_type == "Basic Energy":
			basic_energies.append(card)

	if basic_energies.is_empty():
		return

	# TODO: 需要UI交互 — 自动选取前 max_energy_count 张基本能量
	var to_attach: Array = []
	var attach_count: int = min(max_energy_count, basic_energies.size())
	for i: int in attach_count:
		to_attach.append(basic_energies[i])

	# 收集己方所有 V 宝可梦槽位（出战 + 备战）
	var v_slots: Array = []
	if player.active_pokemon != null and _is_v_pokemon(player.active_pokemon):
		v_slots.append(player.active_pokemon)
	for bench_slot: PokemonSlot in player.bench:
		if _is_v_pokemon(bench_slot):
			v_slots.append(bench_slot)

	if v_slots.is_empty():
		# 没有V宝可梦在场，能量无法附着
		return

	# TODO: 需要UI交互 — 为每张能量选择目标V宝可梦，简化附着到第一只V宝可梦
	var target_slot: PokemonSlot = v_slots[0]
	for energy: CardInstance in to_attach:
		# 从牌库移除
		player.deck.erase(energy)
		# 附着到目标V宝可梦
		target_slot.attached_energy.append(energy)

	# 洗牌（检索后需要洗牌）
	player.shuffle_deck()


## 判断宝可梦槽位的顶层卡牌是否为V宝可梦
func _is_v_pokemon(slot: PokemonSlot) -> bool:
	var card: CardInstance = slot.get_top_card()
	if card == null or card.card_data == null:
		return false
	# V宝可梦在 mechanic 字段或 is_tags 中标记
	var mechanic: String = card.card_data.mechanic
	return mechanic == "V" or mechanic == "VSTAR" or mechanic == "VMAX"


func get_description() -> String:
	return "从牌库检索最多%d张基本能量，附着到己方V宝可梦，然后洗牌" % max_energy_count
