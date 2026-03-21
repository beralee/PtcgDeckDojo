## 喷射能量 - 附着于备战宝可梦时，将该宝可梦与战斗宝可梦互换；提供1个无色能量
## 附着触发: 若附着目标为备战宝可梦，则立即将其换到战斗位
## 能量提供: 提供1个无色能量（C），持续存在于槽位上
## 附着效果通过 execute() 触发，与 EffectSpecialEnergyOnAttach 模式一致
class_name EffectJetEnergy
extends BaseEffect

## 此能量提供的能量类型
const ENERGY_TYPE: String = "C"
## 此能量提供的能量数量
const ENERGY_COUNT: int = 1


## 检查是否可以执行附着效果
## 仅当目标宝可梦位于备战区时触发换场；若已在战斗位则无换场效果但能量仍正常附着
func can_execute(_card: CardInstance, _state: GameState) -> bool:
	# 能量附着本身总可执行，无额外前置条件
	return true


## 执行附着效果：若附着的宝可梦在备战区，将其换到战斗位
## 由 EffectProcessor 在处理特殊能量附着时调用
## card: 此喷射能量的 CardInstance（owner_index 为附着者的玩家索引）
## targets: targets[0] 为附着目标 PokemonSlot（由调用方提供）
## state: 当前游戏状态
func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]

	# 获取附着目标槽位
	if targets.is_empty():
		return
	var target_slot: PokemonSlot = targets[0] as PokemonSlot
	if target_slot == null:
		return

	# 检查目标是否在备战区
	var bench_index: int = player.bench.find(target_slot)
	if bench_index == -1:
		# 目标不在备战区（可能已经在战斗位），不触发换场
		return

	# 执行换场：将备战宝可梦与战斗宝可梦互换
	if player.active_pokemon == null:
		# 若战斗位为空（理论上对战中不应出现），直接移过去
		player.bench.remove_at(bench_index)
		player.active_pokemon = target_slot
		return

	var old_active: PokemonSlot = player.active_pokemon
	player.bench.remove_at(bench_index)
	player.bench.append(old_active)
	player.active_pokemon = target_slot


## 获取此特殊能量提供的能量类型（供 EffectProcessor.get_energy_type 查询）
func get_energy_type_provides() -> String:
	return ENERGY_TYPE


## 获取此特殊能量提供的能量数量（供 EffectProcessor.get_energy_colorless_count 查询）
func get_energy_count() -> int:
	return ENERGY_COUNT


func get_description() -> String:
	return "附着于备战宝可梦时，将其换到战斗位；提供%d个%s能量" % [ENERGY_COUNT, ENERGY_TYPE]
