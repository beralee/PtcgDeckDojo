## 双倍无色能量效果 - 一张能量提供2个无色能量
## 适用: 双倍无色能量
## 注意: 通过 EffectProcessor.get_energy_value() 查询实际提供量
class_name EffectDoubleColorless
extends BaseEffect

## 提供的无色能量数量
var provides_count: int = 2


func _init(count: int = 2) -> void:
	provides_count = count


func get_description() -> String:
	return "提供%d个无色能量" % provides_count
