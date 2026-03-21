## 招式学习器 进化 - 道具赋予的招式
## [C] 进化：选择最多2只备战宝可梦，从牌库搜索其进化卡各1张放上进化。洗牌。
## 道具在回合结束时弃置。
class_name AttackTMEvolution
extends BaseEffect

const GRANTED_ATTACK_ID := "tm_evolution"

var max_targets: int = 2


func _init(max_count: int = 2) -> void:
	max_targets = max_count


## 向 EffectProcessor 提供道具赋予的招式列表
func get_granted_attacks(_pokemon: PokemonSlot, _state: GameState) -> Array[Dictionary]:
	return [{
		"id": GRANTED_ATTACK_ID,
		"name": "进化",
		"cost": "C",
		"damage": "",
		"text": "选择自己最多%d只备战宝可梦，从牌库中选择进化卡各1张放上进化。并重洗牌库。" % max_targets,
	}]


## 返回交互步骤（玩家选择要进化的备战宝可梦）
func get_granted_attack_interaction_steps(
	pokemon: PokemonSlot,
	_attack_data: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return []
	var player: PlayerState = state.players[top.owner_index]
	var bench_items: Array = []
	var bench_labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		var slot_top: CardInstance = slot.get_top_card()
		if slot_top == null or slot_top.card_data == null:
			continue
		if _has_evolution_in_deck(player, slot_top.card_data.name):
			bench_items.append(slot)
			bench_labels.append(slot.get_pokemon_name())
	if bench_items.is_empty():
		return []
	return [{
		"id": "evolution_bench",
		"title": "选择最多%d只要进化的备战宝可梦" % max_targets,
		"items": bench_items,
		"labels": bench_labels,
		"min_select": 1,
		"max_select": mini(max_targets, bench_items.size()),
		"allow_cancel": true,
	}]


## 执行道具赋予的招式
func execute_granted_attack(
	attacker: PokemonSlot,
	attack_data: Dictionary,
	state: GameState,
	targets: Array = []
) -> void:
	if str(attack_data.get("id", "")) != GRANTED_ATTACK_ID:
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]

	var ctx: Dictionary = get_interaction_context(targets)

	# 从交互上下文获取选中的备战宝可梦
	var bench_raw: Array = ctx.get("evolution_bench", [])
	if bench_raw.is_empty():
		return

	var evolved_count: int = 0
	for entry: Variant in bench_raw:
		if evolved_count >= max_targets:
			break
		if not (entry is PokemonSlot):
			continue
		var slot: PokemonSlot = entry as PokemonSlot
		if slot not in player.bench:
			continue
		var slot_top: CardInstance = slot.get_top_card()
		if slot_top == null or slot_top.card_data == null:
			continue
		var evo_card: CardInstance = _find_evolution_in_deck(player, slot_top.card_data.name)
		if evo_card == null:
			continue
		player.deck.erase(evo_card)
		evo_card.face_up = true
		slot.pokemon_stack.append(evo_card)
		evolved_count += 1

	if evolved_count > 0:
		player.shuffle_deck()


## 标记此道具在回合结束时弃置
func discard_at_end_of_turn(_slot: PokemonSlot, _state: GameState) -> bool:
	return true


func _has_evolution_in_deck(player: PlayerState, pokemon_name: String) -> bool:
	return _find_evolution_in_deck(player, pokemon_name) != null


func _find_evolution_in_deck(player: PlayerState, pokemon_name: String) -> CardInstance:
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data == null:
			continue
		if not deck_card.card_data.is_pokemon():
			continue
		if deck_card.card_data.evolves_from == pokemon_name:
			return deck_card
	return null


func get_description() -> String:
	return "招式【进化】：选择最多%d只备战宝可梦，从牌库搜索进化卡各1张放上进化。回合结束时弃置。" % max_targets
