extends Control

const TOURNAMENT_SIZES := [16, 32, 64, 128]
const SwissTournamentScript := preload("res://scripts/tournament/SwissTournament.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")

var _round_probe: RefCounted = SwissTournamentScript.new()


func _ready() -> void:
	HudThemeScript.apply(self)
	%BtnBack.text = "返回"
	%BtnStart.text = "查看比赛情况"
	%TitleLabel.text = "比赛设置"
	%NameLabel.text = "玩家名字"
	%SizeLabel.text = "比赛人数"
	%HintLabel.text = "下一步会进入赛前总览页面，先查看参赛名单、卡组分布和本次瑞士轮轮数，再正式开始第一轮。"
	%NameEdit.placeholder_text = "输入你的名字"
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnStart.pressed.connect(_on_start_pressed)
	%NameEdit.text_changed.connect(_on_name_changed)
	_setup_size_options()
	_refresh_selected_deck()
	_refresh_round_info()
	_clear_error()


func _setup_size_options() -> void:
	%SizeOption.clear()
	for size: int in TOURNAMENT_SIZES:
		%SizeOption.add_item("%d 人" % size)
	%SizeOption.select(0)
	if not %SizeOption.item_selected.is_connected(_on_size_changed):
		%SizeOption.item_selected.connect(_on_size_changed)


func _refresh_selected_deck() -> void:
	var deck: DeckData = CardDatabase.get_deck(GameManager.tournament_selected_player_deck_id)
	%DeckLabel.text = "参赛卡组：%s" % (deck.deck_name if deck != null else "未选择")


func _selected_tournament_size() -> int:
	var size_index: int = maxi(0, %SizeOption.selected)
	return TOURNAMENT_SIZES[min(size_index, TOURNAMENT_SIZES.size() - 1)]


func _refresh_round_info() -> void:
	var tournament_size: int = _selected_tournament_size()
	var total_rounds: int = int(_round_probe.call("rounds_for_size", tournament_size))
	%RoundInfoLabel.text = "预计轮数：%d 轮（%d 人瑞士轮）" % [total_rounds, tournament_size]


func _clear_error() -> void:
	%ErrorLabel.visible = false
	%ErrorLabel.text = ""


func _show_error(message: String) -> void:
	%ErrorLabel.visible = true
	%ErrorLabel.text = message


func _on_size_changed(_index: int) -> void:
	_refresh_round_info()


func _on_name_changed(_text: String) -> void:
	_clear_error()


func _on_back_pressed() -> void:
	GameManager.goto_tournament_deck_select()


func _on_start_pressed() -> void:
	var player_name: String = %NameEdit.text.strip_edges()
	if player_name == "":
		_show_error("请输入玩家名字后再继续。")
		if %NameEdit.is_inside_tree():
			%NameEdit.grab_focus()
		return
	if GameManager.tournament_selected_player_deck_id <= 0:
		_show_error("请先返回上一页选择参赛卡组。")
		return
	var tournament_size: int = _selected_tournament_size()
	GameManager.start_swiss_tournament(player_name, tournament_size)
	if not GameManager.has_active_tournament():
		_show_error("比赛初始化失败，请重新选择卡组后再试。")
		return
	if not is_inside_tree():
		return
	GameManager.goto_tournament_overview()
