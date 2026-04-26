extends Control

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")


func _ready() -> void:
	HudThemeScript.apply(self)
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnStartRound.pressed.connect(_on_start_round_pressed)
	_render()
	call_deferred("_render")


func _render() -> void:
	%TitleLabel.text = "比赛总览"
	%SubtitleLabel.text = "开赛前先确认参赛名单、卡组分布和本次瑞士轮轮数。"
	%MetaTitle.text = "本次比赛"
	%RosterTitle.text = "全部参赛选手"
	%RosterHint.text = "带 * 的是玩家本人。"
	if not GameManager.has_active_tournament():
		%MetaLabel.text = "当前没有待开始的比赛。"
		%DistributionText.text = "卡组分布"
		%RosterText.text = "参赛名单"
		%BtnStartRound.disabled = true
		return

	var tournament: RefCounted = GameManager.current_tournament
	var snapshot: Dictionary = tournament.get_overview_snapshot()
	var tournament_size: int = int(snapshot.get("tournament_size", 0))
	var total_rounds: int = int(snapshot.get("total_rounds", 0))
	var player_name: String = str(snapshot.get("player_name", "玩家"))
	var player_deck_name: String = str(snapshot.get("player_deck_name", "未选择"))

	%MetaLabel.text = "\n".join([
		"玩家：%s" % player_name,
		"参赛卡组：%s" % player_deck_name,
		"比赛人数：%d 人" % tournament_size,
		"瑞士轮数：%d 轮" % total_rounds,
		"对局规则：每轮自动配对，随机先后攻。",
	])
	%DistributionText.text = _build_distribution_text(snapshot.get("deck_distribution", []))
	%RosterText.text = _build_roster_text(snapshot.get("participants", []))
	%BtnStartRound.disabled = false


func _build_distribution_text(distribution_variant: Variant) -> String:
	var lines: Array[String] = ["卡组分布", "", "数量  占比    卡组"]
	if not (distribution_variant is Array):
		return "\n".join(lines)
	for entry_variant: Variant in distribution_variant:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var count: int = int(entry.get("count", 0))
		var share: float = float(entry.get("share", 0.0)) * 100.0
		var deck_name: String = str(entry.get("deck_name", ""))
		lines.append("%3d   %5.1f%%  %s" % [count, share, deck_name])
	return "\n".join(lines)


func _build_roster_text(participants_variant: Variant) -> String:
	var lines: Array[String] = ["参赛名单", "", "编号  强度   选手            卡组"]
	if not (participants_variant is Array):
		return "\n".join(lines)
	for entry_variant: Variant in participants_variant:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var marker := "*" if bool(entry.get("is_player", false)) else " "
		var index_label := "%s%02d" % [marker, int(entry.get("id", 0)) + 1]
		var ai_mode := str(entry.get("ai_mode", ""))
		var mode_label := "玩家" if bool(entry.get("is_player", false)) else _ai_mode_label(ai_mode)
		var name: String = str(entry.get("name", ""))
		var deck_name: String = str(entry.get("deck_name", ""))
		lines.append("%-4s  %-4s  %-14s  %s" % [index_label, mode_label, name, deck_name])
	return "\n".join(lines)


func _ai_mode_label(ai_mode: String) -> String:
	match ai_mode:
		"strong":
			return "强AI"
		"llm":
			return "LLM"
		_:
			return "弱AI"


func _on_back_pressed() -> void:
	GameManager.discard_tournament_keep_selected_deck()
	GameManager.goto_tournament_setup()


func _on_start_round_pressed() -> void:
	if not GameManager.prepare_current_tournament_battle():
		_render()
		return
	GameManager.goto_battle()
