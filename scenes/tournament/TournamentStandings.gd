extends Control

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const CHAMPION_GOLD := Color(1.0, 0.72, 0.24, 1.0)
const CHAMPION_TEXT := Color(1.0, 0.96, 0.82, 1.0)
const CHAMPION_DEEP := Color(0.12, 0.055, 0.018, 0.92)


func _ready() -> void:
	HudThemeScript.apply(self)
	_apply_champion_banner_style()
	%BtnPrimary.pressed.connect(_on_primary_pressed)
	%BtnSecondary.pressed.connect(_on_secondary_pressed)
	_render()
	call_deferred("_render")


func _render() -> void:
	if not GameManager.has_active_tournament():
		%TitleLabel.text = "比赛模式"
		%SummaryText.text = "当前没有进行中的比赛。"
		%StandingsLabel.text = "积分榜"
		%StandingsText.text = ""
		%BtnPrimary.text = "返回首页"
		%BtnSecondary.visible = false
		_set_champion_banner_visible(false)
		return

	var tournament: RefCounted = GameManager.current_tournament
	var summary: Dictionary = tournament.last_round_summary
	var round_number: int = int(summary.get("round", tournament.current_round))
	var player: Dictionary = summary.get("player", {})
	var opponent: Dictionary = summary.get("opponent", {})
	var result_label := "胜利" if str(summary.get("result", "")) == "win" else "失利"
	var standings: Array = _normalize_standings(summary.get("standings", tournament.get_standings()))
	var final_round := bool(summary.get("is_final_round", false))
	var player_rank := _rank_for_player(standings, int(tournament.player_participant_id))
	var player_is_champion := final_round and player_rank == 1

	if player_is_champion:
		%TitleLabel.text = "冠军诞生"
	elif final_round:
		%TitleLabel.text = "比赛结束"
	else:
		%TitleLabel.text = "第 %d 轮结束" % round_number
	_set_champion_banner_visible(player_is_champion)
	if player_is_champion:
		_render_champion_banner(tournament, player)

	var summary_lines: Array[String] = []
	if not player.is_empty():
		if player_is_champion:
			summary_lines.append("恭喜你，%s！你以第 1 名完成本次比赛，正式获得冠军。" % str(player.get("name", "玩家")))
			summary_lines.append("这不是单局胜利，而是整场瑞士轮稳定表现的结果。")
			summary_lines.append("最终积分：%d" % int(player.get("points", 0)))
		else:
			summary_lines.append("本轮结果：%s" % result_label)
			summary_lines.append("你的积分：%d" % int(player.get("points", 0)))
			if final_round and player_rank > 0:
				summary_lines.append("最终排名：第 %d 名" % player_rank)
		summary_lines.append("你的战绩：%d-%d-%d" % [
			int(player.get("wins", 0)),
			int(player.get("losses", 0)),
			int(player.get("draws", 0)),
		])
	if not opponent.is_empty():
		summary_lines.append("本轮对手：%s" % str(opponent.get("name", "")))
		summary_lines.append("对手卡组：%s" % tournament.participant_deck_name(int(opponent.get("id", -1))))
	if str(summary.get("reason", "")).strip_edges() != "":
		summary_lines.append("结束原因：%s" % str(summary.get("reason", "")))
	%SummaryText.text = "\n".join(summary_lines)
	%StandingsLabel.text = "最终积分榜" if final_round else "积分榜"
	%StandingsText.text = _build_standings_text(standings)
	%BtnPrimary.text = "返回首页" if final_round else "下一轮"
	%BtnSecondary.visible = true
	%BtnSecondary.text = "结束比赛"


func _apply_champion_banner_style() -> void:
	var banner := get_node_or_null("%ChampionBanner") as PanelContainer
	if banner == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = CHAMPION_DEEP
	style.border_color = CHAMPION_GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(1.0, 0.58, 0.12, 0.34)
	style.shadow_size = 18
	banner.add_theme_stylebox_override("panel", style)
	%ChampionKicker.add_theme_font_size_override("font_size", 13)
	%ChampionKicker.add_theme_color_override("font_color", Color(1.0, 0.80, 0.36, 1.0))
	%ChampionTitle.add_theme_color_override("font_color", CHAMPION_TEXT)
	%ChampionTitle.add_theme_color_override("font_shadow_color", Color(1.0, 0.58, 0.12, 0.72))
	%ChampionTitle.add_theme_constant_override("shadow_offset_y", 2)
	%ChampionSubtitle.add_theme_font_size_override("font_size", 16)
	%ChampionSubtitle.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56, 1.0))


func _set_champion_banner_visible(visible: bool) -> void:
	var banner := get_node_or_null("%ChampionBanner") as Control
	if banner != null:
		banner.visible = visible


func _render_champion_banner(tournament: RefCounted, player: Dictionary) -> void:
	var player_name := str(player.get("name", tournament.player_name if tournament != null else "玩家"))
	var record := "%d-%d-%d" % [
		int(player.get("wins", 0)),
		int(player.get("losses", 0)),
		int(player.get("draws", 0)),
	]
	%ChampionKicker.text = "TOURNAMENT CHAMPION"
	%ChampionTitle.text = "恭喜，%s 获得冠军！" % player_name
	%ChampionSubtitle.text = "最终战绩 %s，积分 %d。你的卡组赢下了整场比赛。" % [record, int(player.get("points", 0))]


func _normalize_standings(standings_variant: Variant) -> Array:
	var standings: Array = []
	if not (standings_variant is Array):
		return standings
	for entry_variant: Variant in standings_variant:
		if entry_variant is Dictionary:
			standings.append((entry_variant as Dictionary).duplicate(true))
	return standings


func _rank_for_player(standings: Array, player_id: int) -> int:
	for entry_variant: Variant in standings:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if int(entry.get("id", -1)) == player_id:
			return int(entry.get("rank", 0))
	return 0


func _build_standings_text(standings_variant: Variant) -> String:
	var lines: Array[String] = ["排名  积分  战绩      选手          卡组"]
	if not (standings_variant is Array):
		return "\n".join(lines)
	for entry_variant: Variant in standings_variant:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var rank: int = int(entry.get("rank", 0))
		var points: int = int(entry.get("points", 0))
		var record := "%d-%d-%d" % [
			int(entry.get("wins", 0)),
			int(entry.get("losses", 0)),
			int(entry.get("draws", 0)),
		]
		var name: String = str(entry.get("name", ""))
		var deck_name := ""
		if GameManager.has_active_tournament():
			deck_name = GameManager.current_tournament.participant_deck_name(int(entry.get("id", -1)))
		lines.append("%2d    %2d    %-7s  %-12s  %s" % [rank, points, record, name, deck_name])
	return "\n".join(lines)


func _on_primary_pressed() -> void:
	if not GameManager.has_active_tournament():
		GameManager.goto_main_menu()
		return
	if GameManager.current_tournament.finished:
		GameManager.clear_tournament()
		GameManager.goto_main_menu()
		return
	if not GameManager.prepare_current_tournament_battle():
		GameManager.clear_tournament()
		GameManager.goto_main_menu()
		return
	GameManager.goto_battle()


func _on_secondary_pressed() -> void:
	GameManager.clear_tournament()
	GameManager.goto_main_menu()
