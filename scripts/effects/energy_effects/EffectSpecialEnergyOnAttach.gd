## 特殊能量附着时效果 - 附着时触发一次性效果
## 适用: 某些特殊能量附着时治疗/抽牌等
## 参数: heal_amount, draw_count
class_name EffectSpecialEnergyOnAttach
extends BaseEffect

## 附着时治疗量（0=不治疗）
var heal_amount: int = 0
## 附着时抽卡数（0=不抽卡）
var draw_count: int = 0


func _init(heal: int = 0, draw: int = 0) -> void:
	heal_amount = heal
	draw_count = draw


## 通过 execute 触发（附着能量时由 EffectProcessor 调用）
func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]

	if heal_amount > 0 and player.active_pokemon != null:
		var slot: PokemonSlot = player.active_pokemon
		slot.damage_counters = maxi(0, slot.damage_counters - heal_amount)

	if draw_count > 0:
		player.draw_cards(draw_count)


func get_description() -> String:
	var parts: Array[String] = []
	if heal_amount > 0:
		parts.append("治疗%d点伤害" % heal_amount)
	if draw_count > 0:
		parts.append("抽%d张牌" % draw_count)
	return "附着时" + "，".join(parts)
