## 备战区保护特性效果 - 浪花水帘（玛纳霏）
## 只要此宝可梦在场上，己方备战宝可梦不受对手招式伤害
## 被动特性，由 EffectProcessor 查询 has_bench_protect()
## 特性激活时在游戏状态的效果列表中存储标记（或直接由引擎轮询）
class_name AbilityBenchProtect
extends BaseEffect


## 被动特性，无需执行任何动作
## 引擎应在每次对备战区宝可梦施加招式伤害前调用此类的 is_active() 检查
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需主动执行
	pass


## 返回此特性是否阻止对备战区宝可梦的招式伤害
## EffectProcessor 应调用此方法判断备战区保护是否有效
func blocks_bench_damage() -> bool:
	return true


func get_description() -> String:
	return "特性【浪花水帘】：只要此宝可梦在场上，己方备战宝可梦不受对手招式伤害。"
