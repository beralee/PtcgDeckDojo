extends Control

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")

var _decks: Array[DeckData] = []


func _ready() -> void:
	HudThemeScript.apply(self)
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnNext.pressed.connect(_on_next_pressed)
	_load_decks()


func _load_decks() -> void:
	%TitleLabel.text = "比赛模式：选择玩家卡组"
	%HintLabel.text = "先选择你要参加瑞士轮比赛的卡组。"
	%BtnBack.text = "返回"
	%BtnNext.text = "下一步"
	_decks = CardDatabase.get_all_decks()
	%DeckOption.clear()
	for deck: DeckData in _decks:
		%DeckOption.add_item(deck.deck_name)
	if %DeckOption.item_count > 0:
		%DeckOption.select(0)
	_update_selected_deck_label()
	if not %DeckOption.item_selected.is_connected(_on_deck_selected):
		%DeckOption.item_selected.connect(_on_deck_selected)


func _on_deck_selected(_index: int) -> void:
	_update_selected_deck_label()


func _update_selected_deck_label() -> void:
	var deck: DeckData = _selected_deck()
	if deck == null:
		%SelectedDeckLabel.text = "当前没有可用卡组。"
		return
	%SelectedDeckLabel.text = "已选择：%s" % deck.deck_name


func _selected_deck() -> DeckData:
	var index: int = %DeckOption.selected
	if index < 0 or index >= _decks.size():
		return null
	return _decks[index]


func _on_back_pressed() -> void:
	GameManager.goto_main_menu()


func _on_next_pressed() -> void:
	var deck: DeckData = _selected_deck()
	if deck == null:
		return
	GameManager.set_tournament_selected_player_deck_id(deck.id)
	GameManager.goto_tournament_setup()
