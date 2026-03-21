## 竞技场撤退费用修正 - 场上时修正宝可梦撤退费用
## 适用: "所有宝可梦撤退费用-1" 等竞技场
## 参数: retreat_modifier, pokemon_filter
class_name EffectStadiumRetreatModifier
extends BaseEffect

## 撤退费用修正量（负数=减少）
var retreat_modifier: int = 0
## 宝可梦过滤: "" = 全部
var pokemon_filter: String = ""


func _init(modifier: int = -1, filter: String = "") -> void:
	retreat_modifier = modifier
	pokemon_filter = filter


## 检查宝可梦是否受此竞技场影响
func matches_pokemon(slot: PokemonSlot) -> bool:
	if pokemon_filter == "":
		return true
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	match pokemon_filter:
		"Basic":
			return cd.stage == "Basic"
		"evolved":
			return cd.stage in ["Stage 1", "Stage 2"]
		_:
			return true


func get_description() -> String:
	var filter_str: String = ""
	if pokemon_filter != "":
		var filter_map := {"Basic": "基础宝可梦", "evolved": "进化宝可梦"}
		filter_str = filter_map.get(pokemon_filter, pokemon_filter) + "的"
	return "场上%s撤退费用%d" % [filter_str, retreat_modifier]
