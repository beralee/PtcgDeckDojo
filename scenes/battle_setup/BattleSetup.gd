## 对战设置场景
extends Control

## 卡组列表（与 OptionButton index 对应）
var _deck_list: Array[DeckData] = []


func _ready() -> void:
	%ModeOption.add_item("双人操控", 0)
	%ModeOption.add_item("AI 对战", 1)

	%BtnStart.pressed.connect(_on_start)
	%BtnBack.pressed.connect(_on_back)

	_refresh_deck_options()


func _refresh_deck_options() -> void:
	_deck_list = CardDatabase.get_all_decks()
	%Deck1Option.clear()
	%Deck2Option.clear()

	if _deck_list.size() < 2:
		%NoDeckWarning.visible = true
		%BtnStart.disabled = true
		return

	%NoDeckWarning.visible = false
	%BtnStart.disabled = false

	for deck: DeckData in _deck_list:
		var label := "%s (%d张)" % [deck.deck_name, deck.total_cards]
		%Deck1Option.add_item(label)
		%Deck2Option.add_item(label)

	# 默认选不同的卡组
	if _deck_list.size() >= 2:
		%Deck2Option.select(1)


func _on_start() -> void:
	var mode_idx: int = %ModeOption.selected
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER if mode_idx == 0 else GameManager.GameMode.VS_AI

	var deck1_idx: int = %Deck1Option.selected
	var deck2_idx: int = %Deck2Option.selected
	if deck1_idx < 0 or deck2_idx < 0:
		return

	GameManager.selected_deck_ids = [_deck_list[deck1_idx].id, _deck_list[deck2_idx].id]
	GameManager.goto_battle()


func _on_back() -> void:
	GameManager.goto_main_menu()
