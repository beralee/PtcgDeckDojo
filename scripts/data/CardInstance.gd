## 卡牌实例 - 游戏中每张具体的卡牌
class_name CardInstance
extends RefCounted

## 全局自增实例ID
static var _next_id: int = 0

## 唯一实例ID
var instance_id: int = 0
## 引用卡牌静态数据
var card_data: CardData = null
## 所属玩家索引 (0 或 1)
var owner_index: int = 0
## 是否正面朝上
var face_up: bool = false


## 创建卡牌实例
static func create(data: CardData, owner: int) -> CardInstance:
	var inst := CardInstance.new()
	inst.instance_id = _next_id
	_next_id += 1
	inst.card_data = data
	inst.owner_index = owner
	inst.face_up = false
	return inst


## 重置全局ID计数器（新游戏时调用）
static func reset_id_counter() -> void:
	_next_id = 0


## 快捷方法：获取卡牌名称
func get_name() -> String:
	return card_data.name if card_data else ""


## 快捷方法：获取卡牌类型
func get_card_type() -> String:
	return card_data.card_type if card_data else ""


## 快捷方法：是否为基础宝可梦
func is_basic_pokemon() -> bool:
	return card_data.is_basic_pokemon() if card_data else false


## 快捷方法：是否为能量卡
func is_energy() -> bool:
	return card_data.is_energy() if card_data else false


func _to_string() -> String:
	return "[CardInstance#%d: %s]" % [instance_id, get_name()]
