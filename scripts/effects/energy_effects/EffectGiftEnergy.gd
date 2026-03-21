## 馈赠能量 - 提供1个无色能量，附着宝可梦昏厥时抽卡到手牌7张
## 昏厥触发由 GameStateMachine 在 _handle_knockout 中处理
class_name EffectGiftEnergy
extends BaseEffect

## 抽到的目标手牌数
var target_hand_size: int = 7


## 能量类型
func get_energy_type_provides() -> String:
	return "C"


func get_energy_count() -> int:
	return 1


## 检查昏厥的宝可梦是否附有馈赠能量
static func check_gift_energy_on_knockout(slot: PokemonSlot) -> bool:
	for energy: CardInstance in slot.attached_energy:
		if energy.card_data.effect_id == "dbb3f3d2ef2f3372bc8b21336e6c9bc6":
			return true
	return false


## 执行昏厥时的抽卡效果
static func trigger_on_knockout(player: PlayerState) -> void:
	var draw_count: int = maxi(0, 7 - player.hand.size())
	if draw_count > 0:
		player.draw_cards(draw_count)


func get_description() -> String:
	return "提供1个无色能量，附着宝可梦昏厥时抽到手牌7张"
