class_name AttackDrawCards
extends BaseEffect

var draw_count: int = 1
var attack_index_to_match: int = -1


func _init(count: int = 1, match_attack_index: int = -1) -> void:
	draw_count = count
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	_draw_cards_with_log(state, top.owner_index, draw_count, top, "attack")


func get_description() -> String:
	return "抽取%d张卡牌。" % draw_count
