## BattleScene
extends Control

# ===================== Constants =====================
const BENCH_SIZE := 5
const BATTLE_CARD_VIEW := preload("res://scenes/battle/BattleCardView.gd")
const CARD_ASPECT := 0.716
const BATTLE_RUNTIME_LOG_PATH := "user://logs/battle_runtime.log"
const BATTLE_BACKDROP_RESOURCE := "res://assets/ui/background.png"
const PLAYER_CARD_BACK_RESOURCE := "res://assets/ui/card_back_player.svg"
const OPPONENT_CARD_BACK_RESOURCE := "res://assets/ui/card_back_opponent.svg"
const USED_ABILITY_TILT_DEGREES := 15.0
const CoinFlipAnimatorScript := preload("res://scenes/battle/CoinFlipAnimator.gd")

# ===================== State =====================
var _gsm: GameStateMachine
var _view_player: int = 0        # Two-player local mode currently visible player
var _selected_hand_card: CardInstance = null
var _pending_choice: String = ""
var _pending_effect_card: CardInstance = null
var _pending_effect_steps: Array[Dictionary] = []
var _pending_effect_step_index: int = -1
var _pending_effect_context: Dictionary = {}
var _pending_effect_kind: String = ""
var _pending_effect_player_index: int = -1
var _pending_effect_slot: PokemonSlot = null
var _pending_effect_ability_index: int = -1
var _pending_effect_attack_data: Dictionary = {}
var _pending_effect_attack_effects: Array[BaseEffect] = []
var _dialog_multi_selected_indices: Array[int] = []
var _slot_card_views: Dictionary = {}
var _detail_card_view = null

var _setup_done: Array[bool] = [false, false]
var _play_card_size: Vector2 = Vector2(130, 182)
var _dialog_card_size: Vector2 = Vector2(148, 208)
var _detail_card_size: Vector2 = Vector2(300, 420)
var _last_ui_state_signature: String = ""
var _pending_handover_action: Callable = Callable()
var _opp_prize_slots: Array[BattleCardView] = []
var _my_prize_slots: Array[BattleCardView] = []
var _opp_deck_preview: BattleCardView = null
var _my_deck_preview: BattleCardView = null
var _opp_discard_preview: BattleCardView = null
var _my_discard_preview: BattleCardView = null
var _pending_prize_player_index: int = -1
var _pending_prize_remaining: int = 0
var _pending_prize_animating: bool = false

var _field_interaction_overlay: Control = null
var _field_interaction_layout: VBoxContainer = null
var _field_interaction_top_spacer: Control = null
var _field_interaction_bottom_spacer: Control = null
var _field_interaction_panel: PanelContainer = null
var _field_interaction_title_lbl: Label = null
var _field_interaction_status_lbl: Label = null
var _field_interaction_scroll: ScrollContainer = null
var _field_interaction_row: HBoxContainer = null
var _field_interaction_buttons: HBoxContainer = null
var _field_interaction_clear_btn: Button = null
var _field_interaction_cancel_btn: Button = null
var _field_interaction_confirm_btn: Button = null
var _field_interaction_mode: String = ""
var _field_interaction_data: Dictionary = {}
var _field_interaction_slot_index_by_id: Dictionary = {}
var _field_interaction_selected_indices: Array[int] = []
var _field_interaction_assignment_selected_source_index: int = -1
var _field_interaction_assignment_entries: Array[Dictionary] = []
var _field_interaction_position: String = "center"

var _player_card_back_texture: Texture2D = null
var _opponent_card_back_texture: Texture2D = null

# ===================== UI References =====================
@onready var _log_list: ItemList = %LogList
@onready var _log_title: Label = $MainArea/LogPanel/LogTitle

# Top status
@onready var _lbl_phase: Label = %LblPhase
@onready var _lbl_turn: Label = %LblTurn
@onready var _top_bar: PanelContainer = $TopBar

# Top actions
@onready var _btn_end_turn: Button = %BtnEndTurn
@onready var _btn_back: Button = %BtnBack
@onready var _btn_zeus_help: Button = %BtnZeusHelp
@onready var _hud_end_turn_btn: Button = %HudEndTurnBtn
@onready var _opp_hand_bar: PanelContainer = $MainArea/CenterField/OppHandBar
@onready var _left_panel: VBoxContainer = $MainArea/LeftPanel
@onready var _right_panel: VBoxContainer = $MainArea/RightPanel

# --- Opponent field ---
@onready var _opp_prizes: Label = %OppPrizesCount
@onready var _opp_deck: Label = %OppDeck
@onready var _opp_discard: Label = %OppDiscard
@onready var _opp_hand_lbl: Label = %OppHandLbl
@onready var _opp_prizes_box: VBoxContainer = $MainArea/LeftPanel/OppPrizesBox
@onready var _opp_deck_box: VBoxContainer = $MainArea/RightPanel/OppDeckBox
@onready var _opp_active: PanelContainer = %OppActive
@onready var _opp_bench: HBoxContainer = %OppBench
@onready var _opp_active_lbl: RichTextLabel = %OppActiveLbl
@onready var _opp_field_shell: HBoxContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldShell
@onready var _opp_hud_left: PanelContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft
@onready var _opp_hud_right: PanelContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight
@onready var _opp_prize_hud_count: Label = %OppHudLeftValue
@onready var _opp_prize_hud_host: VBoxContainer = %OppPrizeHudHost
@onready var _opp_deck_hud_box: VBoxContainer = %OppDeckHudBox
@onready var _opp_deck_hud_value: Label = %OppDeckHudValue
@onready var _opp_discard_hud_box: VBoxContainer = %OppDiscardHudBox
@onready var _opp_discard_hud_value: Label = %OppDiscardHudValue

# --- Stadium ---
@onready var _stadium_lbl: Label = %StadiumLbl
@onready var _btn_stadium_action: Button = %BtnStadiumAction
@onready var _lost_zone_section: PanelContainer = %LostZoneSection
@onready var _stadium_center_section: PanelContainer = %StadiumCenterSection
@onready var _vstar_section: PanelContainer = %VstarSection
@onready var _enemy_vstar_value: Label = %EnemyVstarValue
@onready var _my_vstar_value: Label = %MyVstarValue
@onready var _enemy_lost_value: Label = %EnemyLostValue
@onready var _my_lost_value: Label = %MyLostValue

# --- Player field ---
@onready var _my_prizes: Label = %MyPrizesCount
@onready var _my_deck: Label = %MyDeck
@onready var _my_discard: Label = %MyDiscard
@onready var _my_prizes_box: VBoxContainer = $MainArea/LeftPanel/MyPrizesBox
@onready var _my_deck_box: VBoxContainer = $MainArea/RightPanel/MyDeckBox
@onready var _my_active: PanelContainer = %MyActive
@onready var _my_bench: HBoxContainer = %MyBench
@onready var _my_active_lbl: RichTextLabel = %MyActiveLbl
@onready var _my_field_shell: HBoxContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldShell
@onready var _my_hud_left: PanelContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft
@onready var _my_hud_right: PanelContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight
@onready var _my_prize_hud_count: Label = %MyHudLeftValue
@onready var _my_prize_hud_host: VBoxContainer = %MyPrizeHudHost
@onready var _my_deck_hud_box: VBoxContainer = %MyDeckHudBox
@onready var _my_deck_hud_value: Label = %MyDeckHudValue
@onready var _my_discard_hud_box: VBoxContainer = %MyDiscardHudBox
@onready var _my_discard_hud_value: Label = %MyDiscardHudValue

# Hand area
@onready var _hand_title: Label = $MainArea/CenterField/HandArea/HandVBox/HandTitle
@onready var _hand_container: HBoxContainer = %HandContainer
@onready var _hand_scroll: ScrollContainer = %HandScroll

# Dialog UI
@onready var _dialog_overlay: Panel = %DialogOverlay
@onready var _dialog_title: Label = %DialogTitle
@onready var _dialog_list: ItemList = %DialogList
@onready var _dialog_confirm: Button = %DialogConfirm
@onready var _dialog_cancel: Button = %DialogCancel
@onready var _dialog_box: PanelContainer = $DialogOverlay/DialogCenter/DialogBox
@onready var _dialog_vbox: VBoxContainer = $DialogOverlay/DialogCenter/DialogBox/DialogVBox

# Handover overlay
@onready var _handover_panel: Panel = %HandoverPanel
@onready var _handover_lbl: Label = %HandoverLbl
@onready var _handover_btn: Button = %HandoverBtn

# Coin flip overlay (旧文本弹窗，保留作为后备)
@onready var _coin_overlay: Panel = %CoinFlipOverlay
@onready var _coin_result_lbl: Label = %CoinResultLbl
@onready var _coin_ok_btn: Button = %CoinOkBtn

# 投币动画
var _coin_animator: Node = null
var _coin_flip_queue: Array[bool] = []
var _coin_animating: bool = false

# Card detail overlay
@onready var _detail_overlay: Panel = %DetailOverlay
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_content: RichTextLabel = %DetailContent
@onready var _detail_close_btn: Button = %DetailCloseBtn

# Discard viewer overlay
@onready var _discard_overlay: Panel = %DiscardOverlay
@onready var _discard_title: Label = %DiscardTitle
@onready var _discard_list: ItemList = %DiscardList
@onready var _discard_close_btn: Button = %DiscardCloseBtn


# ===================== Lifecycle =====================

func _ready() -> void:
	_init_battle_runtime_log()
	_btn_end_turn.pressed.connect(_on_end_turn)
	_hud_end_turn_btn.pressed.connect(_on_end_turn)
	_btn_stadium_action.pressed.connect(_on_stadium_action_pressed)
	_btn_zeus_help.pressed.connect(_on_zeus_help_pressed)
	_btn_back.pressed.connect(_on_back_pressed)
	_dialog_confirm.pressed.connect(_on_dialog_confirm)
	_dialog_cancel.pressed.connect(_on_dialog_cancel)
	_handover_btn.pressed.connect(_on_handover_confirmed)
	_handover_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_handover_panel.z_index = 100

	_dialog_overlay.visible = false
	_set_handover_panel_visible(false, "ready_init")
	_coin_overlay.visible = false
	_detail_overlay.visible = false
	_discard_overlay.visible = false
	_hand_title.visible = false
	_left_panel.visible = false
	_right_panel.visible = false
	_opp_prize_hud_count.visible = false
	_my_prize_hud_count.visible = false
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyVstar/EnemyVstarMargin/EnemyVstarVBox/EnemyVstarCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyVstar/MyVstarMargin/MyVstarVBox/MyVstarCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyLost/EnemyLostMargin/EnemyLostVBox/EnemyLostCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyLost/MyLostMargin/MyLostVBox/MyLostCaption"
	]:
		var caption := get_node_or_null(caption_path) as Label
		if caption != null:
			caption.visible = false
	_opp_hand_bar.visible = false
	($MainArea/CenterField/HandArea/HandVBox as VBoxContainer).add_theme_constant_override("separation", 0)
	_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_setup_side_previews()
	_install_field_card_views()
	_setup_detail_preview()
	_setup_dialog_gallery()
	_setup_discard_gallery()
	_setup_prize_viewer()
	_setup_field_interaction_panel()
	_setup_battle_layout()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	# 投币动画
	_coin_animator = CoinFlipAnimatorScript.new()
	_coin_animator.set_anchors_preset(PRESET_FULL_RECT)
	_coin_animator.z_index = 150
	_coin_animator.visible = false
	add_child(_coin_animator)
	_coin_animator.animation_finished.connect(_on_coin_animation_finished)

	# Popups
	_coin_ok_btn.pressed.connect(func() -> void:
		_coin_overlay.visible = false
	)
	_detail_close_btn.pressed.connect(func() -> void:
		_detail_overlay.visible = false
	)
	_discard_close_btn.pressed.connect(func() -> void:
		_discard_overlay.visible = false
	)
	var stadium_sections := $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections as HBoxContainer
	if stadium_sections != null:
		stadium_sections.move_child(_stadium_center_section, 0)
		stadium_sections.move_child(_lost_zone_section, 1)

	# Discard pile interactions
	_opp_discard.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mbe := e as InputEventMouseButton
			if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
				_show_discard_pile(1 - _view_player, "对方弃牌区")
	)
	_my_discard.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mbe := e as InputEventMouseButton
			if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
				_show_discard_pile(_view_player, "己方弃牌区")
	)
	if _opp_discard_preview != null:
		_opp_discard_preview.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			_show_discard_pile(1 - _view_player, "对方弃牌区")
		)
		_opp_discard_preview.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
			if cd != null:
				_show_card_detail(cd)
		)
	if _my_discard_preview != null:
		_my_discard_preview.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			_show_discard_pile(_view_player, "己方弃牌区")
		)
		_my_discard_preview.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
			if cd != null:
				_show_card_detail(cd)
		)
	_my_deck.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mbe := e as InputEventMouseButton
			if mbe.pressed and mbe.button_index == MOUSE_BUTTON_RIGHT:
				_show_deck_cards(_view_player, "己方牌库")
	)
	if _my_deck_preview != null:
		_my_deck_preview.right_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			_show_deck_cards(_view_player, "己方牌库")
		)
	_stadium_center_section.gui_input.connect(_on_stadium_area_input)
	_btn_stadium_action.gui_input.connect(_on_stadium_area_input)

	# Pokemon slot interactions
	_opp_active.gui_input.connect(func(e: InputEvent) -> void:
		_on_slot_input(e, "opp_active")
	)
	_my_active.gui_input.connect(func(e: InputEvent) -> void:
		_on_slot_input(e, "my_active")
	)
	for i: int in BENCH_SIZE:
		var opp_slot: PanelContainer = _opp_bench.get_child(i) as PanelContainer
		var my_slot: PanelContainer = _my_bench.get_child(i) as PanelContainer
		var idx := i
		if opp_slot:
			opp_slot.gui_input.connect(func(e: InputEvent) -> void:
				_on_slot_input(e, "opp_bench_%d" % idx)
			)
		if my_slot:
			my_slot.gui_input.connect(func(e: InputEvent) -> void:
				_on_slot_input(e, "my_bench_%d" % idx)
			)

	_start_battle()


func _start_battle() -> void:
	var deck1_data: DeckData = CardDatabase.get_deck(GameManager.selected_deck_ids[0])
	var deck2_data: DeckData = CardDatabase.get_deck(GameManager.selected_deck_ids[1])
	if deck1_data == null or deck2_data == null:
		_log("未找到已选择的卡组数据。")
		return
	_runtime_log(
		"start_battle",
		"deck1=%s deck2=%s first=%d" % [
			deck1_data.deck_name,
			deck2_data.deck_name,
			GameManager.first_player_choice
		]
	)

	_gsm = GameStateMachine.new()
	_gsm.state_changed.connect(_on_state_changed)
	_gsm.action_logged.connect(_on_action_logged)
	_gsm.player_choice_required.connect(_on_player_choice_required)
	_gsm.game_over.connect(_on_game_over)
	_gsm.coin_flipper.coin_flipped.connect(_on_coin_flipped)

	_setup_done = [false, false]
	# Reset visible player before starting a new match.
	_view_player = 0
	_gsm.start_game(deck1_data, deck2_data, GameManager.first_player_choice)
	# Setup flow continues through state change callbacks and mulligan prompts.
	# The visible player may be switched later by setup and handover logic.

func _setup_battle_layout() -> void:
	_install_battle_backdrop()
	_apply_battle_surface_styles()
	_apply_responsive_layout()


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var left_panel: VBoxContainer = $MainArea/LeftPanel
	var right_panel: VBoxContainer = $MainArea/RightPanel
	var log_panel: VBoxContainer = $MainArea/LogPanel
	var main_area: HBoxContainer = $MainArea
	var hand_area: PanelContainer = $MainArea/CenterField/HandArea
	var opp_hand_bar: PanelContainer = $MainArea/CenterField/OppHandBar
	var field_area: VBoxContainer = $MainArea/CenterField/FieldArea
	var stadium_bar: PanelContainer = $MainArea/CenterField/FieldArea/StadiumBar
	var stadium_sections: HBoxContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections
	var stadium_action_row: HBoxContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/StadiumCenterSection/StadiumCenterMargin/StadiumCenterVBox/StadiumActionRow
	var stadium_center_margin: MarginContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/StadiumCenterSection/StadiumCenterMargin
	var vstar_margin: MarginContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin
	var vstar_vbox: VBoxContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox
	var enemy_info_column: VBoxContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn
	var my_info_column: VBoxContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn
	var enemy_vstar_margin: MarginContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyVstar/EnemyVstarMargin
	var enemy_lost_margin: MarginContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyLost/EnemyLostMargin
	var my_vstar_margin: MarginContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyVstar/MyVstarMargin
	var my_lost_margin: MarginContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyLost/MyLostMargin
	var turn_action_column: VBoxContainer = $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/TurnActionColumn
	var opp_field_inner: VBoxContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner
	var my_field_inner: VBoxContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner
	var opp_active_row: HBoxContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner/OppActiveRow
	var my_active_row: HBoxContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner/MyActiveRow
	var top_bar: PanelContainer = $TopBar

	var side_width: float = 0.0 if not left_panel.visible else clampf(viewport_size.x * 0.05, 72.0, 108.0)
	var right_width: float = 0.0 if not right_panel.visible else side_width + 6.0
	var log_width: float = clampf(viewport_size.x * 0.125, 124.0, 204.0)
	left_panel.custom_minimum_size = Vector2(side_width, 0)
	right_panel.custom_minimum_size = Vector2(right_width, 0)
	log_panel.custom_minimum_size = Vector2(log_width, 0)

	var top_bar_height: float = roundf(clampf(viewport_size.y * 0.042, 26.0, 38.0) * (2.0 / 3.0))
	top_bar.offset_bottom = top_bar.offset_top + top_bar_height
	main_area.offset_top = top_bar.offset_bottom + 4.0
	_btn_back.custom_minimum_size = Vector2(clampf(viewport_size.x * 0.11, 126.0, 172.0), maxf(top_bar_height - 6.0, 18.0))
	opp_hand_bar.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.032, 24.0, 34.0))
	field_area.add_theme_constant_override("separation", clampi(int(viewport_size.y * 0.004), 2, 6))
	stadium_sections.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.006), 6, 14))
	stadium_action_row.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.004), 6, 12))
	_opp_field_shell.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.006), 8, 16))
	_my_field_shell.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.006), 8, 16))
	opp_field_inner.add_theme_constant_override("separation", clampi(int(viewport_size.y * 0.003), 1, 4))
	my_field_inner.add_theme_constant_override("separation", clampi(int(viewport_size.y * 0.003), 1, 4))
	opp_active_row.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.002), 2, 4))
	my_active_row.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.002), 2, 4))
	_my_bench.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.003), 3, 8))
	_opp_bench.add_theme_constant_override("separation", clampi(int(viewport_size.x * 0.003), 3, 8))
	_my_bench.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_opp_bench.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var center_width := maxf(0.0, viewport_size.x - side_width - right_width - log_width)
	var bench_spacing: float = float(clampi(int(viewport_size.x * 0.004), 4, 10))
	var play_h: float = _compute_play_card_height(viewport_size, center_width, bench_spacing)
	var dialog_h: float = clampf(viewport_size.y * 0.24, 148.0, 220.0)
	var detail_h: float = clampf(viewport_size.y * 0.5, 260.0, 460.0)
	_play_card_size = Vector2(round(play_h * CARD_ASPECT), round(play_h))
	_dialog_card_size = Vector2(round(dialog_h * CARD_ASPECT), round(dialog_h))
	_detail_card_size = Vector2(round(detail_h * CARD_ASPECT), round(detail_h))
	var preview_card_size := Vector2(roundf(_play_card_size.x * 0.9), roundf(_play_card_size.y * 0.9))
	var prize_slot_size: Vector2 = preview_card_size

	hand_area.custom_minimum_size = Vector2(0, _play_card_size.y + 10.0)
	var stadium_height: float = roundf(clampf(viewport_size.y * 0.082, 54.0, 72.0) * (4.0 / 9.0))
	var stadium_inner_vpad: int = clampi(int(stadium_height * 0.08), 1, 3)
	var vstar_stack_gap: int = clampi(int(stadium_height * 0.08), 1, 2)
	var vstar_panel_vpad: int = clampi(int(stadium_height * 0.06), 1, 2)
	var prize_panel_height: float = roundf((preview_card_size.y * 2.0 + 24.0) * 0.95)
	stadium_bar.custom_minimum_size = Vector2(0, stadium_height)
	stadium_sections.offset_top = float(stadium_inner_vpad)
	stadium_sections.offset_bottom = -float(stadium_inner_vpad)
	stadium_center_margin.offset_top = float(stadium_inner_vpad)
	stadium_center_margin.offset_bottom = -float(stadium_inner_vpad)
	vstar_margin.offset_top = float(stadium_inner_vpad)
	vstar_margin.offset_bottom = -float(stadium_inner_vpad)
	vstar_vbox.add_theme_constant_override("separation", vstar_stack_gap)
	enemy_info_column.add_theme_constant_override("separation", vstar_stack_gap * 2)
	my_info_column.add_theme_constant_override("separation", vstar_stack_gap * 2)
	for margin: MarginContainer in [enemy_vstar_margin, enemy_lost_margin, my_vstar_margin, my_lost_margin]:
		margin.offset_top = float(vstar_panel_vpad)
		margin.offset_bottom = -float(vstar_panel_vpad)
	turn_action_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hud_end_turn_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hud_end_turn_btn.custom_minimum_size = Vector2(0, maxf(stadium_height - float(stadium_inner_vpad * 2), 18.0))
	_opp_hud_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_my_hud_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_opp_hud_left.custom_minimum_size = Vector2(0, prize_panel_height)
	_my_hud_left.custom_minimum_size = Vector2(0, prize_panel_height)
	var backdrop := get_node_or_null("BattleBackdrop") as TextureRect
	if backdrop != null:
		backdrop.anchor_left = 0.0
		backdrop.anchor_top = 0.0
		backdrop.anchor_right = 0.0
		backdrop.anchor_bottom = 0.0
		backdrop.offset_left = 0.0
		backdrop.offset_top = 0.0
		backdrop.offset_right = viewport_size.x - log_width
		backdrop.offset_bottom = viewport_size.y
	_hand_container.add_theme_constant_override("separation", clampi(int(_play_card_size.x * 0.08), 4, 10))
	_my_active.custom_minimum_size = _play_card_size
	_opp_active.custom_minimum_size = _play_card_size
	_my_active.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_opp_active.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_my_active.clip_contents = false
	_opp_active.clip_contents = false
	_my_bench.custom_minimum_size = Vector2(0, _play_card_size.y)
	_opp_bench.custom_minimum_size = Vector2(0, _play_card_size.y)
	for panel: PanelContainer in _my_bench.get_children():
		panel.custom_minimum_size = _play_card_size
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.clip_contents = false
	for panel: PanelContainer in _opp_bench.get_children():
		panel.custom_minimum_size = _play_card_size
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.clip_contents = false
	for prize_view: BattleCardView in _opp_prize_slots:
		if prize_view == null:
			continue
		prize_view.custom_minimum_size = prize_slot_size
		prize_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		prize_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for prize_view: BattleCardView in _my_prize_slots:
		if prize_view == null:
			continue
		prize_view.custom_minimum_size = prize_slot_size
		prize_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		prize_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for preview: BattleCardView in [_opp_deck_preview, _my_deck_preview, _opp_discard_preview, _my_discard_preview]:
		if preview != null:
			preview.custom_minimum_size = preview_card_size

	_dialog_box.custom_minimum_size = Vector2(
		clampf(viewport_size.x * 0.62, 640.0, 1120.0),
		clampf(viewport_size.y * 0.52, 360.0, 620.0)
	)
	if _dialog_card_scroll != null:
		_dialog_card_scroll.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.29, 180.0, 300.0))
	if _dialog_assignment_source_scroll != null:
		_dialog_assignment_source_scroll.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.22, 148.0, 230.0))
	if _dialog_assignment_target_scroll != null:
		_dialog_assignment_target_scroll.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.22, 148.0, 230.0))

	var detail_box: PanelContainer = $DetailOverlay/DetailCenter/DetailBox
	detail_box.custom_minimum_size = Vector2(
		clampf(viewport_size.x * 0.42, 420.0, 760.0),
		clampf(viewport_size.y * 0.78, 440.0, 880.0)
	)
	if _detail_card_view != null:
		_detail_card_view.custom_minimum_size = _detail_card_size

	if _dialog_card_row != null:
		for child: Node in _dialog_card_row.get_children():
			if child is BattleCardView:
				(child as BattleCardView).custom_minimum_size = _dialog_card_size
	if _dialog_assignment_source_row != null:
		for child: Node in _dialog_assignment_source_row.get_children():
			if child is BattleCardView:
				(child as BattleCardView).custom_minimum_size = _dialog_card_size
	if _dialog_assignment_target_row != null:
		for child: Node in _dialog_assignment_target_row.get_children():
			if child is BattleCardView:
				(child as BattleCardView).custom_minimum_size = _dialog_card_size
	if _discard_card_scroll != null:
		_discard_card_scroll.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.34, 220.0, 340.0))
		var discard_box: PanelContainer = $DiscardOverlay/DiscardCenter/DiscardBox
		discard_box.custom_minimum_size = Vector2(
			clampf(viewport_size.x * 0.76, 820.0, 1280.0),
			clampf(viewport_size.y * 0.5, 360.0, 560.0)
		)
		for child: Node in _discard_card_row.get_children():
			if child is BattleCardView:
				(child as BattleCardView).custom_minimum_size = _dialog_card_size

	_update_field_interaction_panel_metrics(viewport_size)

	if _gsm != null:
		_refresh_hand()


func _compute_play_card_height(viewport_size: Vector2, center_width: float, bench_spacing: float) -> float:
	var reserved_vertical := \
		clampf(viewport_size.y * 0.042, 26.0, 38.0) + \
		clampf(viewport_size.y * 0.032, 24.0, 34.0) + \
		92.0
	var height_limited := (viewport_size.y - reserved_vertical) / 5.0

	var bench_row_padding := 40.0
	var usable_center_width := maxf(center_width - bench_row_padding, 0.0)
	var width_limited := (usable_center_width - float(BENCH_SIZE - 1) * bench_spacing) / maxf(float(BENCH_SIZE) * CARD_ASPECT, 1.0)

	return clampf(minf(height_limited, width_limited), 112.0, 192.0)


func _install_battle_backdrop() -> void:
	if has_node("BattleBackdrop"):
		return

	var backdrop := TextureRect.new()
	backdrop.name = "BattleBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.texture = _load_battle_backdrop_texture()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(backdrop)
	move_child(backdrop, 0)


func _load_battle_backdrop_texture() -> Texture2D:
	var backdrop_path := _resolve_battle_backdrop_path()
	if ResourceLoader.exists(backdrop_path):
		var backdrop_res := load(backdrop_path)
		if backdrop_res is Texture2D:
			return backdrop_res as Texture2D
	if FileAccess.file_exists(backdrop_path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(backdrop_path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color("07131d"),
		Color("102634"),
		Color("16394a"),
		Color("0b1825"),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 640
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture


func _resolve_battle_backdrop_path() -> String:
	var backdrop_path := GameManager.selected_battle_background
	if backdrop_path != "" and (ResourceLoader.exists(backdrop_path) or FileAccess.file_exists(backdrop_path)):
		return backdrop_path
	return BATTLE_BACKDROP_RESOURCE


func _load_card_back_texture(resource_path: String, is_player_side: bool) -> Texture2D:
	var texture_res := load(resource_path)
	if texture_res is Texture2D:
		return texture_res as Texture2D

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color("0a1d30") if is_player_side else Color("1b0714"),
		Color("174d7a") if is_player_side else Color("4d1540"),
		Color("f3d86b") if is_player_side else Color("ff93c9"),
		Color("07111d") if is_player_side else Color("10060f"),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.78, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 356
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.35)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture

func _apply_battle_surface_styles() -> void:
	_style_panel(_opp_prizes_box, Color(0.05, 0.09, 0.13, 0.82), Color(0.37, 0.47, 0.64), 16)
	_style_panel(_my_prizes_box, Color(0.05, 0.09, 0.13, 0.82), Color(0.35, 0.6, 0.5), 16)
	_style_panel(_opp_deck_box, Color(0.05, 0.09, 0.13, 0.82), Color(0.37, 0.47, 0.64), 16)
	_style_panel(_my_deck_box, Color(0.05, 0.09, 0.13, 0.82), Color(0.35, 0.6, 0.5), 16)
	_style_panel($MainArea/CenterField/FieldArea/OppField, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0))
	_style_panel($MainArea/CenterField/FieldArea/MyField, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0))
	_style_panel(_opp_hud_left, Color(0.02, 0.1, 0.16, 0.7), Color(0.22, 0.68, 0.84, 0.92), 16)
	_style_panel(_my_hud_left, Color(0.03, 0.11, 0.15, 0.7), Color(0.27, 0.86, 0.7, 0.92), 16)
	_style_panel(_opp_hud_right, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 16)
	_style_panel(_my_hud_right, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 16)
	_style_panel(_opp_hand_bar, Color(0.01, 0.11, 0.18, 0.72), Color(0.16, 0.62, 0.76, 0.9), 10)
	for panel_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppDeckHudPanel",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppDiscardHudPanel"
	]:
		var panel := get_node_or_null(panel_path) as PanelContainer
		_style_panel(panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 12)
	for panel_path: String in [
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyDeckHudPanel",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyDiscardHudPanel"
	]:
		var panel := get_node_or_null(panel_path) as PanelContainer
		_style_panel(panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 12)
	_style_panel($MainArea/CenterField/HandArea, Color(0.05, 0.09, 0.13, 0.88), Color(0.42, 0.58, 0.74))
	_style_panel(_top_bar, Color(0.01, 0.08, 0.13, 0.78), Color(0.19, 0.66, 0.8, 0.9), 14)
	_style_panel($MainArea/CenterField/FieldArea/StadiumBar, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 14)
	_style_panel(_lost_zone_section, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 12)
	_style_panel(_stadium_center_section, Color(0.11, 0.16, 0.12, 0.82), Color(0.73, 0.87, 0.62), 12)
	_style_panel(_vstar_section, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 12)
	for panel_path: String in [
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyVstar",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyVstar",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyLost",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyLost"
	]:
		var panel := get_node_or_null(panel_path) as PanelContainer
		_style_panel(panel, Color(0.01, 0.11, 0.18, 0.72), Color(0.16, 0.62, 0.76, 0.9), 10)
	_lost_zone_section.self_modulate = Color(1, 1, 1, 0)
	_stadium_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stadium_lbl.add_theme_font_size_override("font_size", 12)
	_btn_stadium_action.add_theme_color_override("font_color", Color(0.93, 0.96, 0.88))
	_btn_stadium_action.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.94))
	_btn_stadium_action.add_theme_color_override("font_disabled_color", Color(0.5, 0.53, 0.49))
	_btn_stadium_action.add_theme_font_size_override("font_size", 12)
	_style_hud_button(_hud_end_turn_btn)
	_style_hud_button(_btn_zeus_help)
	_style_hud_button(_btn_back)
	for label: Label in [_lbl_phase, _lbl_turn]:
		if label != null:
			label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
			label.add_theme_color_override("font_outline_color", Color(0.02, 0.07, 0.12, 0.9))
			label.add_theme_constant_override("outline_size", 1)
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftTitle",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightTitle",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox/OppDeckHudHeader/OppDeckHudCaption",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox/OppDiscardHudHeader/OppDiscardHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox/MyDeckHudHeader/MyDeckHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox/MyDiscardHudHeader/MyDiscardHudCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyVstar/EnemyVstarMargin/EnemyVstarVBox/EnemyVstarCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyVstar/MyVstarMargin/MyVstarVBox/MyVstarCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyLost/EnemyLostMargin/EnemyLostVBox/EnemyLostCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyLost/MyLostMargin/MyLostVBox/MyLostCaption"
	]:
		var caption := get_node_or_null(caption_path) as Label
		if caption != null:
			caption.add_theme_color_override("font_color", Color(0.54, 0.9, 0.94, 0.9))
	for value_label: Label in [_enemy_vstar_value, _my_vstar_value, _enemy_lost_value, _my_lost_value]:
		if value_label != null:
			value_label.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0))
	for value_label: Label in [
		_opp_prize_hud_count,
		_opp_deck_hud_value,
		_opp_discard_hud_value,
		_my_prize_hud_count,
		_my_deck_hud_value,
		_my_discard_hud_value
	]:
		if value_label != null:
			value_label.add_theme_color_override("font_color", Color(0.96, 1.0, 1.0))
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftTitle",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightTitle"
	]:
		var caption := get_node_or_null(caption_path) as Label
		if caption != null:
			caption.add_theme_color_override("font_color", Color(0.55, 0.89, 0.96, 0.9))
	for value_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftValue",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightValue"
	]:
		var value_label := get_node_or_null(value_path) as Label
		if value_label != null:
			value_label.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0))
	for label_text: Dictionary in [
		{"path": "MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftTitle", "text": "对方奖赏"},
		{"path": "MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightTitle", "text": ""},
		{"path": "MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightValue", "text": ""},
		{"path": "MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftTitle", "text": "己方奖赏"},
		{"path": "MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightTitle", "text": ""},
		{"path": "MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightValue", "text": ""}
	]:
		var label := get_node_or_null(str(label_text["path"])) as Label
		if label != null:
			label.text = str(label_text["text"])
	for label: Label in [_opp_prize_hud_count, _my_prize_hud_count]:
		if label != null:
			label.add_theme_font_size_override("font_size", 18)
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDeckHudPanel/OppDeckHudMargin/OppDeckHudBox/OppDeckHudHeader/OppDeckHudCaption",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow/OppDiscardHudPanel/OppDiscardHudMargin/OppDiscardHudBox/OppDiscardHudHeader/OppDiscardHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDeckHudPanel/MyDeckHudMargin/MyDeckHudBox/MyDeckHudHeader/MyDeckHudCaption",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow/MyDiscardHudPanel/MyDiscardHudMargin/MyDiscardHudBox/MyDiscardHudHeader/MyDiscardHudCaption"
	]:
		var caption := get_node_or_null(caption_path) as Label
		if caption != null:
			caption.add_theme_font_size_override("font_size", 14)
	for label: Label in [_opp_hand_lbl]:
		if label != null:
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0))
			label.add_theme_color_override("font_outline_color", Color(0.02, 0.07, 0.12, 0.9))
			label.add_theme_constant_override("outline_size", 1)
	if _log_title != null:
		_log_title.add_theme_font_size_override("font_size", 17)
	if _log_list != null:
		_log_list.add_theme_font_size_override("font_size", 15)
	for label_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightTitle",
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudRightValue",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightTitle",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudRightValue"
	]:
		var label := get_node_or_null(label_path) as Label
		if label != null:
			label.visible = false
	_style_panel(_dialog_box, Color(0.05, 0.08, 0.11, 0.98), Color(0.38, 0.55, 0.72), 20)
	_style_panel($DetailOverlay/DetailCenter/DetailBox, Color(0.05, 0.08, 0.11, 0.98), Color(0.65, 0.5, 0.27), 20)
	_style_panel($DiscardOverlay/DiscardCenter/DiscardBox, Color(0.05, 0.08, 0.11, 0.98), Color(0.5, 0.57, 0.72), 20)
	_style_panel($CoinFlipOverlay/CoinCenter/CoinBox, Color(0.05, 0.08, 0.11, 0.98), Color(0.89, 0.78, 0.34), 18)
	_style_panel($HandoverPanel/HandoverCenter/HandoverBox, Color(0.05, 0.08, 0.11, 0.98), Color(0.72, 0.72, 0.76), 18)
	_style_panel(_my_active, Color(0.04, 0.07, 0.1, 0.88), Color(0.52, 0.72, 0.58), 18)
	_style_panel(_opp_active, Color(0.04, 0.07, 0.1, 0.88), Color(0.63, 0.68, 0.79), 18)

	for bench_panel: PanelContainer in _my_bench.get_children():
		_style_panel(bench_panel, Color(0.04, 0.07, 0.1, 0.76), Color(0.32, 0.5, 0.44), 16)
	for bench_panel: PanelContainer in _opp_bench.get_children():
		_style_panel(bench_panel, Color(0.04, 0.07, 0.1, 0.76), Color(0.33, 0.39, 0.5), 16)
	_hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _style_panel(panel: Control, bg_color: Color, border_color: Color, radius: int = 18) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	if panel is PanelContainer:
		(panel as PanelContainer).add_theme_stylebox_override("panel", style)
	elif panel is Panel:
		(panel as Panel).add_theme_stylebox_override("panel", style)


func _style_hud_button(button: Button) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.01, 0.11, 0.18, 0.72)
	normal.border_color = Color(0.16, 0.62, 0.76, 0.9)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.04, 0.18, 0.28, 0.82)
	hover.border_color = Color(0.37, 0.91, 0.98, 0.96)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.03, 0.14, 0.22, 0.9)
	pressed.border_color = Color(0.56, 0.94, 1.0, 1.0)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.04, 0.08, 0.12, 0.45)
	disabled.border_color = Color(0.22, 0.31, 0.38, 0.6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.58, 0.63))





func _install_field_card_views() -> void:
	_slot_card_views.clear()
	_install_slot_card_view("my_active", _my_active, BATTLE_CARD_VIEW.MODE_SLOT_ACTIVE)
	_install_slot_card_view("opp_active", _opp_active, BATTLE_CARD_VIEW.MODE_SLOT_ACTIVE)

	for i: int in BENCH_SIZE:
		var my_panel: PanelContainer = _my_bench.get_child(i) as PanelContainer
		var opp_panel: PanelContainer = _opp_bench.get_child(i) as PanelContainer
		_install_slot_card_view("my_bench_%d" % i, my_panel, BATTLE_CARD_VIEW.MODE_SLOT_BENCH)
		_install_slot_card_view("opp_bench_%d" % i, opp_panel, BATTLE_CARD_VIEW.MODE_SLOT_BENCH)


func _install_slot_card_view(slot_id: String, panel: PanelContainer, mode: String) -> void:
	if panel == null:
		return

	for child: Node in panel.get_children():
		if child is RichTextLabel:
			child.visible = false

	var card_view = BATTLE_CARD_VIEW.new()
	card_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_view.set_clickable(false)
	card_view.setup_from_instance(null, mode)
	panel.add_child(card_view)
	_slot_card_views[slot_id] = card_view


func _setup_detail_preview() -> void:
	var detail_box: PanelContainer = $DetailOverlay/DetailCenter/DetailBox
	detail_box.custom_minimum_size = Vector2(520, 620)

	var detail_vbox: VBoxContainer = $DetailOverlay/DetailCenter/DetailBox/DetailVBox
	_detail_card_view = BATTLE_CARD_VIEW.new()
	_detail_card_view.custom_minimum_size = _detail_card_size
	_detail_card_view.set_clickable(false)
	_detail_card_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
	detail_vbox.add_child(_detail_card_view)
	detail_vbox.move_child(_detail_card_view, 1)



func _setup_side_previews() -> void:
	_opponent_card_back_texture = _load_card_back_texture(OPPONENT_CARD_BACK_RESOURCE, false)
	_player_card_back_texture = _load_card_back_texture(PLAYER_CARD_BACK_RESOURCE, true)
	_opp_prize_hud_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_my_prize_hud_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_opp_prize_hud_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_my_prize_hud_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_opp_prize_hud_host.add_theme_constant_override("separation", 0)
	_my_prize_hud_host.add_theme_constant_override("separation", 0)
	var opp_prize_panel_vbox := get_node_or_null("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox") as VBoxContainer
	var my_prize_panel_vbox := get_node_or_null("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox") as VBoxContainer
	if opp_prize_panel_vbox != null:
		opp_prize_panel_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		opp_prize_panel_vbox.add_theme_constant_override("separation", 0)
	if my_prize_panel_vbox != null:
		my_prize_panel_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		my_prize_panel_vbox.add_theme_constant_override("separation", 0)
	_opp_prize_slots = _build_prize_slots(_opp_prize_hud_host, _opponent_card_back_texture)
	_my_prize_slots = _build_prize_slots(_my_prize_hud_host, _player_card_back_texture)
	_opp_deck_preview = _insert_pile_preview(_opp_deck_hud_box, 1, false, _opponent_card_back_texture)
	_opp_discard_preview = _insert_pile_preview(_opp_discard_hud_box, 1, true)
	_my_deck_preview = _insert_pile_preview(_my_deck_hud_box, 1, false, _player_card_back_texture)
	_my_discard_preview = _insert_pile_preview(_my_discard_hud_box, 1, true)


func _build_prize_slots(box: VBoxContainer, back_texture: Texture2D) -> Array[BattleCardView]:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(center)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	center.add_child(grid)

	var slots: Array[BattleCardView] = []
	for _i: int in 6:
		var card_view := BATTLE_CARD_VIEW.new()
		card_view.name = "PrizeCardView"
		card_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_view.set_clickable(false)
		card_view.set_compact_preview(true)
		card_view.set_back_texture(back_texture)
		card_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
		card_view.set_face_down(true)
		grid.add_child(card_view)
		slots.append(card_view)
	return slots


func _insert_pile_preview(box: VBoxContainer, child_index: int, clickable: bool, back_texture: Texture2D = null) -> BattleCardView:
	var preview := BATTLE_CARD_VIEW.new()
	preview.set_clickable(clickable)
	preview.set_back_texture(back_texture)
	preview.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
	preview.set_info("", "")
	box.add_child(preview)
	box.move_child(preview, child_index)
	return preview

# ===================== Scene Callbacks =====================

func _on_state_changed(_new_phase: GameState.GamePhase) -> void:
	_refresh_ui()
	_check_two_player_handover()
	_runtime_log("state_changed", _state_snapshot())


func _on_action_logged(action: GameAction) -> void:
	if action.description != "":
		_log(action.description)


func _on_player_choice_required(choice_type: String, data: Dictionary) -> void:
	_runtime_log("player_choice_required", "%s data=%s" % [choice_type, JSON.stringify(data)])
	match choice_type:
		"mulligan_extra_draw":
			var beneficiary: int = data.get("beneficiary", 0)
			var count: int = data.get("mulligan_count", 1)
			_pending_choice = "mulligan_extra_draw"
			_show_dialog(
				"对手第 %d 次重抽" % count,
				["玩家 %d 额外抽 1 张牌" % (beneficiary + 1), "不额外抽牌"],
				{"beneficiary": beneficiary}
			)
		"setup_ready":
			_begin_setup_flow()
		"take_prize":
			_start_prize_selection(
				int(data.get("player", _view_player)),
				int(data.get("count", 1))
			)
		"send_out_pokemon":
			_clear_prize_selection()
			var pi: int = data.get("player", 0)
			_prompt_send_out_dialog(pi)
		"heavy_baton_target":
			var pi_hb: int = data.get("player", 0)
			var bench_raw: Array = data.get("bench", [])
			var bench_targets: Array[PokemonSlot] = []
			for slot: Variant in bench_raw:
				if slot is PokemonSlot:
					bench_targets.append(slot)
			_prompt_heavy_baton_dialog(
				pi_hb,
				bench_targets,
				int(data.get("count", 0)),
				str(data.get("source_name", "沉重接力棒"))
			)


func _start_prize_selection(player_index: int, count: int) -> void:
	_pending_choice = "take_prize"
	_pending_prize_player_index = player_index
	_pending_prize_remaining = count
	_pending_prize_animating = false
	_refresh_ui()
	_focus_prize_panel(player_index)
	_log("请选择 1 张奖赏卡（剩余 %d 张）" % count)


func _clear_prize_selection() -> void:
	if _pending_choice == "take_prize":
		_pending_choice = ""
	_pending_prize_player_index = -1
	_pending_prize_remaining = 0
	_pending_prize_animating = false


func _focus_prize_panel(player_index: int) -> void:
	var target_panel: Control = _my_hud_left if player_index == _view_player else _opp_hud_left
	if target_panel == null or not is_inside_tree():
		return
	target_panel.pivot_offset = target_panel.size * 0.5
	target_panel.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(target_panel, "scale", Vector2(1.05, 1.05), 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _on_game_over(winner_index: int, reason: String) -> void:
	_runtime_log("game_over", "winner=%d reason=%s" % [winner_index, reason])
	_clear_prize_selection()
	_refresh_ui()
	_show_dialog(
		"游戏结束",
		["玩家 %d 获胜\n原因：%s" % [winner_index + 1, reason], "返回对战准备"],
		{"winner": winner_index, "action": "game_over"}
	)


# ===================== Setup Flow (UI-driven) =====================

func _begin_setup_flow() -> void:
	_setup_done = [false, false]
	_refresh_ui()
	_setup_player_active(0)


func _setup_player_active(pi: int) -> void:
	_view_player = pi
	_refresh_ui()
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER and pi != 0:
		_show_handover_prompt(pi, func() -> void:
			_set_handover_panel_visible(false, "setup_active_follow_up")
			_view_player = pi
			_refresh_ui()
			_show_setup_active_dialog(pi)
		)
	else:
		_show_setup_active_dialog(pi)


func _show_setup_active_dialog(pi: int) -> void:
	var player: PlayerState = _gsm.game_state.players[pi]
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	var items: Array[String] = []
	for c: CardInstance in basics:
		items.append("%s (HP %d)" % [c.card_data.name, c.card_data.hp])
	_pending_choice = "setup_active_%d" % pi
	_show_dialog("玩家 %d：选择战斗宝可梦" % (pi + 1), items, {
		"basics": basics,
		"player": pi,
		"presentation": "cards",
		"card_items": basics,
		"choice_labels": items,
	})
	_dialog_cancel.visible = false


func _after_setup_active(pi: int) -> void:
	_refresh_ui()
	_show_setup_bench_dialog(pi)


func _show_setup_bench_dialog(pi: int) -> void:
	var player: PlayerState = _gsm.game_state.players[pi]
	if player.is_bench_full():
		_after_setup_bench(pi)
		return
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	if basics.is_empty():
		_after_setup_bench(pi)
		return
	var items: Array[String] = ["完成"]
	for c: CardInstance in basics:
		items.append("%s (HP %d)" % [c.card_data.name, c.card_data.hp])
	var choice_indices: Array[int] = []
	for card_idx: int in basics.size():
		choice_indices.append(card_idx + 1)
	_pending_choice = "setup_bench_%d" % pi
	_show_dialog("玩家 %d：选择备战宝可梦（可选，最多 5 只）" % (pi + 1), items, {
		"cards": basics,
		"player": pi,
		"presentation": "cards",
		"card_items": basics,
		"card_indices": choice_indices,
		"choice_labels": items.slice(1),
		"utility_actions": [{"label": "完成", "index": 0}],
	})
	_dialog_cancel.visible = false


func _after_setup_bench(pi: int) -> void:
	_setup_done[pi] = true
	_refresh_ui()
	if pi == 0 and not _setup_done[1]:
		_setup_player_active(1)
	else:
		if _gsm.setup_complete(0):
			_view_player = _gsm.game_state.current_player_index
			_refresh_ui()
			_check_two_player_handover()


# ===================== Field Interactions =====================

func _on_end_turn() -> void:
	if _gsm == null or _is_field_interaction_active():
		return
	_selected_hand_card = null
	_refresh_hand()
	_gsm.end_turn(_gsm.game_state.current_player_index)
	_check_two_player_handover()


func _on_stadium_action_pressed() -> void:
	if _gsm == null or _is_field_interaction_active():
		return
	_try_use_stadium_with_interaction(_gsm.game_state.current_player_index)


func _on_stadium_area_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed or mbe.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _gsm == null or _gsm.game_state.stadium_card == null:
		return
	_show_card_detail(_gsm.game_state.stadium_card.card_data)


func _on_back_pressed() -> void:
	if _is_field_interaction_active():
		return
	_pending_choice = "confirm_exit"
	_show_dialog("确认退出对战？当前进度不会保存。", ["确认退出", "取消"], {})
	_dialog_cancel.visible = false


func _on_zeus_help_pressed() -> void:
	if _gsm == null or _gsm.game_state == null or _is_field_interaction_active():
		return
	if _view_player < 0 or _view_player >= _gsm.game_state.players.size():
		return
	var player: PlayerState = _gsm.game_state.players[_view_player]
	var deck_cards: Array = player.deck.duplicate()
	if deck_cards.is_empty():
		_log("当前牌库为空。")
		return
	var labels: Array[String] = []
	for card: CardInstance in deck_cards:
		labels.append(card.card_data.name if card != null and card.card_data != null else "未知卡牌")
	_pending_choice = "zeus_help"
	_show_dialog("宙斯帮我：从牌库中选择任意张牌加入手牌", labels, {
		"player": _view_player,
		"min_select": 0,
		"max_select": deck_cards.size(),
		"allow_cancel": true,
		"presentation": "cards",
		"card_items": deck_cards,
		"deck_cards": deck_cards,
		"choice_labels": labels,
	})


func _on_slot_input(event: InputEvent, slot_id: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return
	if _handover_panel.visible:
		_runtime_log("slot_input_blocked", "slot=%s reason=handover %s" % [slot_id, _state_snapshot()])
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return

	if mbe.button_index == MOUSE_BUTTON_RIGHT:
		_runtime_log("slot_right_click", "slot=%s %s" % [slot_id, _state_snapshot()])
		var detail_state: GameState = _gsm.game_state if _gsm != null else null
		if detail_state != null:
			var detail_slot: PokemonSlot = _slot_from_id(slot_id, detail_state)
			if detail_slot != null and not detail_slot.pokemon_stack.is_empty():
				_show_card_detail(detail_slot.get_card_data())
		return

	if mbe.button_index != MOUSE_BUTTON_LEFT:
		return
	_runtime_log(
		"slot_left_click",
		"slot=%s selected=%s %s" % [slot_id, _card_instance_label(_selected_hand_card), _state_snapshot()]
	)

	var cp: int = _gsm.game_state.current_player_index if _gsm != null else 0
	var gs: GameState = _gsm.game_state if _gsm != null else null
	if gs == null:
		return

	var target_slot: PokemonSlot = _slot_from_id(slot_id, gs)
	if _is_field_interaction_active():
		_try_handle_field_interaction_slot_click(slot_id, target_slot)
		return
	if target_slot == null and not slot_id.begins_with("opp"):
		if _selected_hand_card != null and _selected_hand_card.card_data.is_basic_pokemon():
			_try_play_to_bench(cp, _selected_hand_card, slot_id)
		return

	if target_slot == null:
		return

	if _selected_hand_card != null:
		var card := _selected_hand_card
		var cd := card.card_data
		if cd.is_pokemon() and cd.stage != "Basic":
			if _gsm.evolve_pokemon(cp, card, target_slot):
				_selected_hand_card = null
				_refresh_ui()
				_try_start_evolve_trigger_ability_interaction(cp, target_slot)
			else:
				_log("无法让这只宝可梦进化")
		elif cd.card_type == "Basic Energy" or cd.card_type == "Special Energy":
			if _gsm.attach_energy(cp, card, target_slot):
				_selected_hand_card = null
				_refresh_ui()
			else:
				_log("无法附着能量")
		elif cd.card_type == "Tool":
			if _gsm.attach_tool(cp, card, target_slot):
				_selected_hand_card = null
				_refresh_ui()
			else:
				_log("无法将该道具附着到这里")
		return

	if slot_id.begins_with("my_"):
		_show_pokemon_action_dialog(cp, target_slot, slot_id == "my_active")


func _try_play_to_bench(player_index: int, card: CardInstance, _slot_id: String) -> void:
	var gs: GameState = _gsm.game_state
	if gs.current_player_index != player_index:
		_log("当前不是你的回合")
		return
	if gs.phase != GameState.GamePhase.MAIN:
		_log("基础宝可梦只能在主要阶段放置（当前阶段：%d）" % gs.phase)
		return
	var bench_effect: BaseEffect = _gsm.effect_processor.get_effect(card.card_data.effect_id)
	var bench_steps: Array[Dictionary] = []
	if bench_effect is AbilityOnBenchEnter or bench_effect is AbilityBenchDamageOnPlay:
		bench_steps = bench_effect.get_interaction_steps(card, gs)
	var auto_trigger_bench_ability: bool = bench_steps.is_empty()
	if _gsm.play_basic_to_bench(player_index, card, auto_trigger_bench_ability):
		if not auto_trigger_bench_ability:
			var player: PlayerState = _gsm.game_state.players[player_index]
			var bench_slot: PokemonSlot = player.bench.back() if not player.bench.is_empty() else null
			if bench_slot != null:
				_start_effect_interaction("ability", player_index, bench_steps, bench_slot.get_top_card(), bench_slot, 0)
		_selected_hand_card = null
		_refresh_ui()
	else:
		_log("无法将该宝可梦放入备战区")


# ===================== Dialog State =====================

var _dialog_data: Dictionary = {}
var _dialog_items_data: Array = []
var _dialog_card_scroll: ScrollContainer = null
var _dialog_card_row: HBoxContainer = null
var _dialog_utility_row: HBoxContainer = null
var _dialog_status_lbl: Label = null
var _dialog_card_selected_indices: Array[int] = []
var _dialog_card_mode: bool = false
var _dialog_assignment_mode: bool = false
var _dialog_assignment_panel: VBoxContainer = null
var _dialog_assignment_source_scroll: ScrollContainer = null
var _dialog_assignment_source_row: HBoxContainer = null
var _dialog_assignment_target_scroll: ScrollContainer = null
var _dialog_assignment_target_row: HBoxContainer = null
var _dialog_assignment_summary_lbl: Label = null
var _dialog_assignment_selected_source_index: int = -1
var _dialog_assignment_assignments: Array[Dictionary] = []
var _discard_card_scroll: ScrollContainer = null
var _discard_card_row: HBoxContainer = null


func _setup_dialog_gallery() -> void:
	_dialog_box.custom_minimum_size = Vector2(860, 420)
	var buttons_row: Control = _dialog_confirm.get_parent()

	_dialog_card_scroll = ScrollContainer.new()
	_dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog_card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_card_scroll.custom_minimum_size = Vector2(0, 252)
	_dialog_card_scroll.visible = false
	_dialog_vbox.add_child(_dialog_card_scroll)
	_dialog_vbox.move_child(_dialog_card_scroll, buttons_row.get_index())

	_dialog_card_row = HBoxContainer.new()
	_dialog_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dialog_card_row.add_theme_constant_override("separation", 14)
	_dialog_card_scroll.add_child(_dialog_card_row)

	_dialog_status_lbl = Label.new()
	_dialog_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_status_lbl.visible = false
	_dialog_vbox.add_child(_dialog_status_lbl)
	_dialog_vbox.move_child(_dialog_status_lbl, buttons_row.get_index())

	_dialog_utility_row = HBoxContainer.new()
	_dialog_utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dialog_utility_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_utility_row.add_theme_constant_override("separation", 12)
	_dialog_utility_row.visible = false
	_dialog_vbox.add_child(_dialog_utility_row)
	_dialog_vbox.move_child(_dialog_utility_row, buttons_row.get_index())

	_dialog_assignment_panel = VBoxContainer.new()
	_dialog_assignment_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_assignment_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_assignment_panel.add_theme_constant_override("separation", 8)
	_dialog_assignment_panel.visible = false
	_dialog_vbox.add_child(_dialog_assignment_panel)
	_dialog_vbox.move_child(_dialog_assignment_panel, buttons_row.get_index())

	var source_title := Label.new()
	source_title.text = "待分配卡牌"
	source_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_assignment_panel.add_child(source_title)

	_dialog_assignment_source_scroll = ScrollContainer.new()
	_dialog_assignment_source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dialog_assignment_source_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog_assignment_source_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_assignment_source_scroll.custom_minimum_size = Vector2(0, 186)
	_dialog_assignment_panel.add_child(_dialog_assignment_source_scroll)

	_dialog_assignment_source_row = HBoxContainer.new()
	_dialog_assignment_source_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_assignment_source_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dialog_assignment_source_row.add_theme_constant_override("separation", 14)
	_dialog_assignment_source_scroll.add_child(_dialog_assignment_source_row)

	var target_title := Label.new()
	target_title.text = "附着目标"
	target_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_assignment_panel.add_child(target_title)

	_dialog_assignment_target_scroll = ScrollContainer.new()
	_dialog_assignment_target_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dialog_assignment_target_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog_assignment_target_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_assignment_target_scroll.custom_minimum_size = Vector2(0, 186)
	_dialog_assignment_panel.add_child(_dialog_assignment_target_scroll)

	_dialog_assignment_target_row = HBoxContainer.new()
	_dialog_assignment_target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_assignment_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dialog_assignment_target_row.add_theme_constant_override("separation", 14)
	_dialog_assignment_target_scroll.add_child(_dialog_assignment_target_row)

	_dialog_assignment_summary_lbl = Label.new()
	_dialog_assignment_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_assignment_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_assignment_panel.add_child(_dialog_assignment_summary_lbl)


func _setup_discard_gallery() -> void:
	var discard_box: PanelContainer = $DiscardOverlay/DiscardCenter/DiscardBox
	discard_box.custom_minimum_size = Vector2(900, 360)

	var discard_vbox: VBoxContainer = $DiscardOverlay/DiscardCenter/DiscardBox/DiscardVBox
	var close_btn: Button = %DiscardCloseBtn
	_discard_list.visible = false

	_discard_card_scroll = ScrollContainer.new()
	_discard_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_discard_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_discard_card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discard_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	discard_vbox.add_child(_discard_card_scroll)
	discard_vbox.move_child(_discard_card_scroll, close_btn.get_index())

	_discard_card_row = HBoxContainer.new()
	_discard_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discard_card_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_discard_card_row.add_theme_constant_override("separation", 14)
	_discard_card_scroll.add_child(_discard_card_row)


func _setup_field_interaction_panel() -> void:
	_ensure_field_interaction_panel()
	_update_field_interaction_panel_metrics()
	_hide_field_interaction()


func _ensure_field_interaction_panel() -> void:
	if _field_interaction_overlay != null:
		return

	_field_interaction_overlay = Control.new()
	_field_interaction_overlay.name = "FieldInteractionOverlay"
	_field_interaction_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_field_interaction_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_interaction_overlay.z_index = 80
	add_child(_field_interaction_overlay)

	_field_interaction_layout = VBoxContainer.new()
	_field_interaction_layout.set_anchors_preset(PRESET_FULL_RECT)
	_field_interaction_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_interaction_overlay.add_child(_field_interaction_layout)

	_field_interaction_top_spacer = Control.new()
	_field_interaction_top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_interaction_top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_interaction_layout.add_child(_field_interaction_top_spacer)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_interaction_layout.add_child(row)

	_field_interaction_panel = PanelContainer.new()
	_field_interaction_panel.name = "FieldInteractionPanel"
	_field_interaction_panel.custom_minimum_size = Vector2(760, 136)
	_field_interaction_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_field_interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_field_interaction_panel)

	_field_interaction_bottom_spacer = Control.new()
	_field_interaction_bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_interaction_bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_interaction_layout.add_child(_field_interaction_bottom_spacer)
	_apply_field_interaction_position("center")

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.06, 0.1, 0.92)
	panel_style.border_color = Color(0.28, 0.82, 0.92, 0.88)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.02, 0.04, 0.08, 0.42)
	panel_style.shadow_size = 10
	_field_interaction_panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	_field_interaction_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_field_interaction_title_lbl = Label.new()
	_field_interaction_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field_interaction_title_lbl.add_theme_font_size_override("font_size", 16)
	_field_interaction_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	vbox.add_child(_field_interaction_title_lbl)

	_field_interaction_status_lbl = Label.new()
	_field_interaction_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field_interaction_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_field_interaction_status_lbl.add_theme_font_size_override("font_size", 12)
	_field_interaction_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.9, 0.96))
	vbox.add_child(_field_interaction_status_lbl)

	_field_interaction_scroll = ScrollContainer.new()
	_field_interaction_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_field_interaction_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_field_interaction_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_interaction_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_field_interaction_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_field_interaction_scroll)

	_field_interaction_row = HBoxContainer.new()
	_field_interaction_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_field_interaction_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_interaction_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_field_interaction_row.add_theme_constant_override("separation", 14)
	_field_interaction_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_interaction_scroll.add_child(_field_interaction_row)

	_field_interaction_buttons = HBoxContainer.new()
	_field_interaction_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_field_interaction_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_interaction_buttons.add_theme_constant_override("separation", 10)
	_field_interaction_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_field_interaction_buttons)

	_field_interaction_clear_btn = Button.new()
	_field_interaction_clear_btn.text = "清空"
	_field_interaction_clear_btn.custom_minimum_size = Vector2(110, 34)
	_field_interaction_clear_btn.pressed.connect(_on_field_interaction_clear_pressed)
	_field_interaction_buttons.add_child(_field_interaction_clear_btn)

	_field_interaction_cancel_btn = Button.new()
	_field_interaction_cancel_btn.text = "取消"
	_field_interaction_cancel_btn.custom_minimum_size = Vector2(110, 34)
	_field_interaction_cancel_btn.pressed.connect(_on_field_interaction_cancel_pressed)
	_field_interaction_buttons.add_child(_field_interaction_cancel_btn)

	_field_interaction_confirm_btn = Button.new()
	_field_interaction_confirm_btn.text = "确认"
	_field_interaction_confirm_btn.custom_minimum_size = Vector2(140, 34)
	_field_interaction_confirm_btn.pressed.connect(_on_field_interaction_confirm_pressed)
	_field_interaction_buttons.add_child(_field_interaction_confirm_btn)


func _hide_field_interaction() -> void:
	_field_interaction_mode = ""
	_field_interaction_data.clear()
	_field_interaction_slot_index_by_id.clear()
	_field_interaction_selected_indices.clear()
	_field_interaction_assignment_selected_source_index = -1
	_field_interaction_assignment_entries.clear()
	_apply_field_interaction_position("center")
	if _field_interaction_title_lbl != null:
		_field_interaction_title_lbl.text = ""
	if _field_interaction_status_lbl != null:
		_field_interaction_status_lbl.text = ""
	if _field_interaction_row != null:
		_clear_container_children(_field_interaction_row)
	if _field_interaction_overlay != null:
		_field_interaction_overlay.visible = false


func _update_field_interaction_panel_metrics(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if _field_interaction_panel == null or _field_interaction_scroll == null or _field_interaction_row == null:
		return
	var effective_viewport: Vector2 = viewport_size
	if effective_viewport == Vector2.ZERO and is_inside_tree():
		effective_viewport = get_viewport().get_visible_rect().size
	if effective_viewport == Vector2.ZERO:
		effective_viewport = Vector2(1366, 768)
	var card_height: float = _play_card_size.y if _play_card_size.y > 0.0 else 152.0
	var strip_height: float = card_height + 8.0
	var panel_width: float = clampf(effective_viewport.x * 0.54, 680.0, 980.0)
	_field_interaction_panel.custom_minimum_size = Vector2(
		panel_width,
		maxf(strip_height + 86.0, 136.0)
	)
	_field_interaction_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_field_interaction_scroll.custom_minimum_size = Vector2(0.0, strip_height)
	_field_interaction_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_field_interaction_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_field_interaction_position(_field_interaction_position)


func _is_field_interaction_active() -> bool:
	return _field_interaction_mode != ""


func _field_interaction_target_owner(slot: PokemonSlot) -> int:
	if slot == null:
		return -1
	var top_card: CardInstance = slot.get_top_card()
	return top_card.owner_index if top_card != null else -1


func _resolve_field_interaction_position(slots: Array) -> String:
	var own_targets: int = 0
	var opponent_targets: int = 0
	for item: Variant in slots:
		if not (item is PokemonSlot):
			continue
		var owner_index: int = _field_interaction_target_owner(item as PokemonSlot)
		if owner_index == _view_player:
			own_targets += 1
		elif owner_index >= 0:
			opponent_targets += 1
	if own_targets > 0 and opponent_targets == 0:
		return "top"
	if opponent_targets > 0 and own_targets == 0:
		return "bottom"
	return "center"


func _apply_field_interaction_position(position: String) -> void:
	_field_interaction_position = position
	if _field_interaction_top_spacer == null or _field_interaction_bottom_spacer == null:
		return
	match position:
		"top":
			_field_interaction_top_spacer.size_flags_stretch_ratio = 0.22
			_field_interaction_bottom_spacer.size_flags_stretch_ratio = 6.45
		"bottom":
			_field_interaction_top_spacer.size_flags_stretch_ratio = 6.45
			_field_interaction_bottom_spacer.size_flags_stretch_ratio = 0.22
		_:
			_field_interaction_top_spacer.size_flags_stretch_ratio = 1.0
			_field_interaction_bottom_spacer.size_flags_stretch_ratio = 1.0


func _show_field_slot_choice(title: String, items: Array, data: Dictionary = {}) -> void:
	_ensure_field_interaction_panel()
	_update_field_interaction_panel_metrics()
	_hide_field_interaction()
	_field_interaction_mode = "slot_select"
	_field_interaction_data = data.duplicate(true)
	_field_interaction_data["title"] = title
	_field_interaction_data["items"] = items.duplicate()
	_apply_field_interaction_position(_resolve_field_interaction_position(items))
	_rebuild_field_slot_index_map(items)
	_field_interaction_overlay.visible = true
	_refresh_field_interaction_status()


func _show_field_assignment_interaction(step: Dictionary) -> void:
	_ensure_field_interaction_panel()
	_update_field_interaction_panel_metrics()
	_hide_field_interaction()
	_field_interaction_mode = "assignment"
	_field_interaction_data = step.duplicate(true)
	_apply_field_interaction_position(_resolve_field_interaction_position(step.get("target_items", [])))
	_rebuild_field_slot_index_map(step.get("target_items", []))
	_build_field_assignment_source_cards()
	_field_interaction_overlay.visible = true
	_refresh_field_interaction_status()


func _rebuild_field_slot_index_map(items: Array) -> void:
	_field_interaction_slot_index_by_id.clear()
	for i: int in items.size():
		var slot_variant: Variant = items[i]
		if not (slot_variant is PokemonSlot):
			continue
		var slot_id := _slot_id_from_slot(slot_variant as PokemonSlot)
		if slot_id != "":
			_field_interaction_slot_index_by_id[slot_id] = i


func _build_field_assignment_source_cards() -> void:
	if _field_interaction_row == null:
		return
	_clear_container_children(_field_interaction_row)

	var source_items: Array = _field_interaction_data.get("source_items", [])
	var source_labels: Array = _field_interaction_data.get("source_labels", [])
	var source_groups: Array = _field_interaction_data.get("source_groups", [])
	if source_groups.is_empty():
		for i: int in source_items.size():
			_add_field_assignment_source_card(source_items, source_labels, i)
		return

	for group_index: int in source_groups.size():
		var group: Dictionary = source_groups[group_index]
		var slot_variant: Variant = group.get("slot")
		var energy_indices: Array = group.get("energy_indices", [])
		if group_index > 0:
			var separator := VSeparator.new()
			separator.custom_minimum_size = Vector2(2, 0)
			separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_field_interaction_row.add_child(separator)
		if slot_variant is PokemonSlot:
			var header_view := BATTLE_CARD_VIEW.new()
			header_view.custom_minimum_size = _play_card_size
			header_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			header_view.set_clickable(false)
			var slot: PokemonSlot = slot_variant as PokemonSlot
			header_view.setup_from_card_data(slot.get_card_data(), _battle_card_mode_for_slot(slot))
			header_view.set_badges()
			header_view.set_battle_status(_build_battle_status(slot))
			_field_interaction_row.add_child(header_view)
		for energy_index_variant: Variant in energy_indices:
			_add_field_assignment_source_card(source_items, source_labels, int(energy_index_variant))


func _add_field_assignment_source_card(source_items: Array, source_labels: Array, source_index: int) -> void:
	if source_index < 0 or source_index >= source_items.size():
		return
	var source_view := BATTLE_CARD_VIEW.new()
	source_view.custom_minimum_size = _play_card_size
	source_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	source_view.set_clickable(true)
	_setup_dialog_card_view(
		source_view,
		source_items[source_index],
		str(source_labels[source_index]) if source_index < source_labels.size() else ""
	)
	source_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		_on_field_assignment_source_chosen(source_index)
	)
	source_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
		if cd != null:
			_show_card_detail(cd)
	)
	source_view.set_meta("field_assignment_source_index", source_index)
	_field_interaction_row.add_child(source_view)


func _on_field_assignment_source_chosen(source_index: int) -> void:
	var source_items: Array = _field_interaction_data.get("source_items", [])
	if source_index < 0 or source_index >= source_items.size():
		return
	var assigned_index := _find_field_assignment_index_for_source(source_index)
	if assigned_index >= 0:
		_field_interaction_assignment_entries.remove_at(assigned_index)
		if _field_interaction_assignment_selected_source_index == source_index:
			_field_interaction_assignment_selected_source_index = -1
		_refresh_field_interaction_status()
		_refresh_ui()
		return

	var max_assignments: int = int(_field_interaction_data.get("max_select", source_items.size()))
	if max_assignments > 0 and _field_interaction_assignment_entries.size() >= max_assignments:
		_log("已达到最多可分配数量。")
		return

	if _field_interaction_assignment_selected_source_index == source_index:
		_field_interaction_assignment_selected_source_index = -1
	else:
		_field_interaction_assignment_selected_source_index = source_index
	_refresh_field_interaction_status()
	_refresh_ui()


func _find_field_assignment_index_for_source(source_index: int) -> int:
	for i: int in _field_interaction_assignment_entries.size():
		if int(_field_interaction_assignment_entries[i].get("source_index", -1)) == source_index:
			return i
	return -1


func _field_interaction_selected_slot_ids() -> Array[String]:
	var result: Array[String] = []
	if _field_interaction_mode == "slot_select":
		var items: Array = _field_interaction_data.get("items", [])
		for selected_index: int in _field_interaction_selected_indices:
			if selected_index < 0 or selected_index >= items.size():
				continue
			var slot_variant: Variant = items[selected_index]
			if slot_variant is PokemonSlot:
				var slot_id := _slot_id_from_slot(slot_variant as PokemonSlot)
				if slot_id != "":
					result.append(slot_id)
	elif _field_interaction_mode == "assignment":
		for entry: Dictionary in _field_interaction_assignment_entries:
			var target_variant: Variant = entry.get("target")
			if target_variant is PokemonSlot:
				var target_slot_id := _slot_id_from_slot(target_variant as PokemonSlot)
				if target_slot_id != "":
					result.append(target_slot_id)
	return result


func _refresh_field_interaction_status() -> void:
	_ensure_field_interaction_panel()
	if not _is_field_interaction_active():
		_hide_field_interaction()
		return
	_field_interaction_overlay.visible = true
	_field_interaction_title_lbl.text = str(_field_interaction_data.get("title", "请选择"))
	var show_cards: bool = _field_interaction_mode == "assignment"
	_field_interaction_scroll.visible = show_cards
	if _field_interaction_buttons != null:
		_field_interaction_buttons.visible = true

	if _field_interaction_mode == "slot_select":
		var min_select: int = int(_field_interaction_data.get("min_select", 1))
		var max_select: int = int(_field_interaction_data.get("max_select", 1))
		var selected_count := _field_interaction_selected_indices.size()
		var status := "请直接点击战场上的高亮宝可梦。"
		if max_select > 1 or min_select > 1:
			status = "已选择 %d / %d" % [selected_count, min_select]
			if max_select > 1:
				status += "（最多 %d）" % max_select
		_field_interaction_status_lbl.text = status
		_field_interaction_clear_btn.visible = selected_count > 0 and max_select > 1
		_field_interaction_cancel_btn.visible = bool(_field_interaction_data.get("allow_cancel", true))
		_field_interaction_confirm_btn.visible = max_select > 1 or min_select > 1
		_field_interaction_confirm_btn.disabled = selected_count < min_select
	else:
		_refresh_field_assignment_source_views()
		var min_assignments: int = int(_field_interaction_data.get("min_select", 0))
		var max_assignments: int = int(_field_interaction_data.get("max_select", 0))
		var summary := "先选择中间卡牌，再点击战场上的目标宝可梦。"
		if _field_interaction_assignment_selected_source_index >= 0:
			var source_items: Array = _field_interaction_data.get("source_items", [])
			if _field_interaction_assignment_selected_source_index < source_items.size():
				var selected_source: Variant = source_items[_field_interaction_assignment_selected_source_index]
				if selected_source is CardInstance:
					summary = "当前选择：%s。请点击场上目标。" % (selected_source as CardInstance).card_data.name
		if not _field_interaction_assignment_entries.is_empty():
			summary += " 已完成 %d" % _field_interaction_assignment_entries.size()
			if max_assignments > 0:
				summary += " / %d" % max_assignments
		_field_interaction_status_lbl.text = summary
		_field_interaction_clear_btn.visible = not _field_interaction_assignment_entries.is_empty()
		_field_interaction_cancel_btn.visible = bool(_field_interaction_data.get("allow_cancel", true))
		_field_interaction_confirm_btn.visible = true
		_field_interaction_confirm_btn.disabled = _field_interaction_assignment_entries.size() < min_assignments


func _refresh_field_assignment_source_views() -> void:
	if _field_interaction_row == null:
		return
	for child: Node in _field_interaction_row.get_children():
		if not (child is BattleCardView):
			continue
		var card_view := child as BattleCardView
		var idx: int = int(card_view.get_meta("field_assignment_source_index", -1))
		card_view.set_selected(idx == _field_interaction_assignment_selected_source_index)
		card_view.set_disabled(_find_field_assignment_index_for_source(idx) >= 0)


func _on_field_interaction_clear_pressed() -> void:
	if _field_interaction_mode == "slot_select":
		_field_interaction_selected_indices.clear()
	else:
		_field_interaction_assignment_selected_source_index = -1
		_field_interaction_assignment_entries.clear()
	_refresh_field_interaction_status()
	_refresh_ui()


func _on_field_interaction_cancel_pressed() -> void:
	_cancel_field_interaction()


func _on_field_interaction_confirm_pressed() -> void:
	if _field_interaction_mode == "slot_select":
		_finalize_field_slot_selection()
	else:
		_finalize_field_assignment_selection()


func _cancel_field_interaction() -> void:
	var handled_choice := _pending_choice
	_hide_field_interaction()
	if handled_choice == "effect_interaction":
		_reset_effect_interaction()
		return
	_pending_choice = ""
	_dialog_data.clear()
	_dialog_items_data.clear()


func _slot_id_from_slot(slot: PokemonSlot) -> String:
	if slot == null or _gsm == null or _gsm.game_state == null:
		return ""
	var gs: GameState = _gsm.game_state
	if gs.players.size() < 2:
		return ""
	var vp: int = _view_player
	var op: int = 1 - vp
	if gs.players[vp].active_pokemon == slot:
		return "my_active"
	if gs.players[op].active_pokemon == slot:
		return "opp_active"
	for i: int in BENCH_SIZE:
		if i < gs.players[vp].bench.size() and gs.players[vp].bench[i] == slot:
			return "my_bench_%d" % i
		if i < gs.players[op].bench.size() and gs.players[op].bench[i] == slot:
			return "opp_bench_%d" % i
	return ""

func _setup_prize_viewer() -> void:
	for i: int in _opp_prize_slots.size():
		var prize_slot: BattleCardView = _opp_prize_slots[i]
		if prize_slot == null:
			continue
		prize_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_index := i
		prize_slot.gui_input.connect(func(event: InputEvent) -> void:
			_on_prize_slot_input(event, 1 - _view_player, "对方奖赏卡", slot_index)
		)
	for i: int in _my_prize_slots.size():
		var prize_slot: BattleCardView = _my_prize_slots[i]
		if prize_slot == null:
			continue
		prize_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_index := i
		prize_slot.gui_input.connect(func(event: InputEvent) -> void:
			_on_prize_slot_input(event, _view_player, "己方奖赏卡", slot_index)
		)


func _on_prize_slot_input(event: InputEvent, player_index: int, title: String, slot_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return
	if mbe.button_index == MOUSE_BUTTON_LEFT:
		_try_take_prize_from_slot(player_index, slot_index)
		return
	if mbe.button_index != MOUSE_BUTTON_RIGHT:
		return
	_show_prize_cards(player_index, title)


func _try_take_prize_from_slot(player_index: int, slot_index: int) -> void:
	if _gsm == null:
		return
	if _pending_choice != "take_prize" or _pending_prize_player_index != player_index:
		return
	if _pending_prize_animating:
		return
	var player: PlayerState = _gsm.game_state.players[player_index]
	var prize_card: CardInstance = player.get_prize_at_slot(slot_index)
	if prize_card == null:
		return
	var prize_view: BattleCardView = _get_prize_slot_view(player_index, slot_index)
	if prize_view == null:
		return
	_pending_prize_animating = true
	_animate_prize_flip(prize_view, prize_card, func() -> void:
		_pending_choice = ""
		_pending_prize_player_index = -1
		_pending_prize_remaining = 0
		var resolved: bool = _gsm.resolve_take_prize(player_index, slot_index)
		_pending_prize_animating = false
		if resolved and _pending_choice == "take_prize":
			_focus_prize_panel(player_index)
		elif resolved:
			_clear_prize_selection()
		_refresh_ui()
		_check_two_player_handover()
	)


func _get_prize_slot_view(player_index: int, slot_index: int) -> BattleCardView:
	var slots: Array[BattleCardView] = _my_prize_slots if player_index == _view_player else _opp_prize_slots
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return slots[slot_index]


func _animate_prize_flip(prize_view: BattleCardView, prize_card: CardInstance, on_complete: Callable) -> void:
	if prize_view == null:
		if on_complete.is_valid():
			on_complete.call()
		return
	if not is_inside_tree():
		prize_view.setup_from_instance(prize_card, BATTLE_CARD_VIEW.MODE_PREVIEW)
		prize_view.set_face_down(false)
		if on_complete.is_valid():
			on_complete.call()
		return
	prize_view.pivot_offset = prize_view.size * 0.5
	var tween := create_tween()
	tween.tween_property(prize_view, "scale:x", 0.05, 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		prize_view.setup_from_instance(prize_card, BATTLE_CARD_VIEW.MODE_PREVIEW)
		prize_view.set_face_down(false)
		prize_view.set_selected(true)
	)
	tween.tween_property(prize_view, "scale:x", 1.0, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.08)
	tween.finished.connect(func() -> void:
		prize_view.scale = Vector2.ONE
		if on_complete.is_valid():
			on_complete.call()
	)


func _show_dialog(title: String, items: Array, extra_data: Dictionary = {}) -> void:
	_dialog_title.text = title
	_dialog_list.clear()
	_dialog_items_data = items
	_dialog_data = extra_data
	_dialog_multi_selected_indices.clear()
	_dialog_card_selected_indices.clear()
	_reset_dialog_assignment_state()
	_dialog_assignment_mode = str(extra_data.get("ui_mode", "")) == "card_assignment"
	_dialog_card_mode = false if _dialog_assignment_mode else _dialog_should_use_card_mode(items, extra_data)

	if _dialog_assignment_mode:
		_show_assignment_dialog(extra_data)
	elif _dialog_card_mode:
		_show_card_dialog(items, extra_data)
	else:
		_show_text_dialog(items, extra_data)

	_dialog_overlay.visible = true
	_dialog_cancel.visible = extra_data.get("allow_cancel", true)
	_update_dialog_confirm_state()
	_runtime_log(
		"show_dialog",
		"title=%s mode=%s items=%d %s" % [
			title,
			"assignment" if _dialog_assignment_mode else ("cards" if _dialog_card_mode else "list"),
			items.size(),
			_dialog_state_snapshot()
		]
	)
	if not _dialog_assignment_mode and int(extra_data.get("max_select", 1)) > 1:
		_log("已启用多选：先选择卡牌，再点击确认。")
	return

func _dialog_should_use_card_mode(items: Array, extra_data: Dictionary) -> bool:
	var presentation := str(extra_data.get("presentation", "auto"))
	if presentation == "cards":
		return true
	if presentation == "list":
		return false

	var card_items: Array = extra_data.get("card_items", items)
	for item: Variant in card_items:
		if not _dialog_item_has_card_visual(item):
			return false
	return not card_items.is_empty()


func _show_text_dialog(items: Array, extra_data: Dictionary) -> void:
	_dialog_card_scroll.visible = false
	_dialog_assignment_panel.visible = false
	_dialog_status_lbl.visible = false
	_dialog_utility_row.visible = false
	_dialog_confirm.visible = true
	_dialog_list.visible = true
	_clear_container_children(_dialog_utility_row)

	for item: Variant in items:
		_dialog_list.add_item(str(item))

	_dialog_list.select_mode = ItemList.SELECT_TOGGLE if int(extra_data.get("max_select", 1)) > 1 else ItemList.SELECT_SINGLE
	if _dialog_list.item_selected.is_connected(_on_dialog_item_selected):
		_dialog_list.item_selected.disconnect(_on_dialog_item_selected)
	if _dialog_list.multi_selected.is_connected(_on_dialog_item_multi_selected):
		_dialog_list.multi_selected.disconnect(_on_dialog_item_multi_selected)
	if _dialog_list.select_mode != ItemList.SELECT_SINGLE:
		_dialog_list.multi_selected.connect(_on_dialog_item_multi_selected)
	else:
		_dialog_list.item_selected.connect(_on_dialog_item_selected)


func _show_card_dialog(items: Array, extra_data: Dictionary) -> void:
	_dialog_list.visible = false
	_dialog_card_scroll.visible = true
	_dialog_assignment_panel.visible = false
	_dialog_card_scroll.scroll_horizontal = 0
	if _dialog_list.item_selected.is_connected(_on_dialog_item_selected):
		_dialog_list.item_selected.disconnect(_on_dialog_item_selected)
	if _dialog_list.multi_selected.is_connected(_on_dialog_item_multi_selected):
		_dialog_list.multi_selected.disconnect(_on_dialog_item_multi_selected)

	_clear_container_children(_dialog_card_row)
	_clear_container_children(_dialog_utility_row)

	var card_items: Array = extra_data.get("card_items", items)
	var card_indices: Array = extra_data.get("card_indices", [])
	var labels: Array = extra_data.get("choice_labels", items)
	for i: int in card_items.size():
		var real_index: int = i
		if i < card_indices.size():
			real_index = int(card_indices[i])
		var card_view := BATTLE_CARD_VIEW.new()
		card_view.custom_minimum_size = _dialog_card_size
		card_view.set_clickable(true)
		_setup_dialog_card_view(card_view, card_items[i], labels[i] if i < labels.size() else "")
		card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			_on_dialog_card_chosen(real_index)
		)
		card_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
			if cd != null:
				_show_card_detail(cd)
		)
		card_view.set_meta("dialog_choice_index", real_index)
		_dialog_card_row.add_child(card_view)

	var utility_actions: Array = extra_data.get("utility_actions", [])
	_dialog_utility_row.visible = not utility_actions.is_empty()
	for action_variant: Variant in utility_actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 40)
		button.text = str(action.get("label", "鎿嶄綔"))
		var action_index: int = int(action.get("index", -1))
		button.pressed.connect(func() -> void:
			_confirm_dialog_selection(PackedInt32Array([action_index]))
		)
		_dialog_utility_row.add_child(button)

	var min_select: int = int(extra_data.get("min_select", 1))
	var max_select: int = int(extra_data.get("max_select", 1))
	var show_confirm := max_select > 1 or min_select > 1
	_dialog_confirm.visible = show_confirm
	_dialog_status_lbl.visible = show_confirm
	if show_confirm:
		_update_dialog_status_text()


func _show_assignment_dialog(extra_data: Dictionary) -> void:
	_dialog_list.visible = false
	_dialog_card_scroll.visible = false
	_dialog_assignment_panel.visible = true
	_dialog_assignment_source_scroll.scroll_horizontal = 0
	_dialog_assignment_target_scroll.scroll_horizontal = 0
	_clear_container_children(_dialog_card_row)
	_clear_container_children(_dialog_utility_row)
	_clear_container_children(_dialog_assignment_source_row)
	_clear_container_children(_dialog_assignment_target_row)
	_reset_dialog_assignment_state()
	_dialog_assignment_mode = true
	_dialog_assignment_panel.visible = true

	var source_items: Array = extra_data.get("source_items", [])
	var source_labels: Array = extra_data.get("source_labels", [])
	var source_groups: Array = extra_data.get("source_groups", [])

	if not source_groups.is_empty():
		# 分组模式：按宝可梦分组展示能量
		_populate_grouped_source_items(source_items, source_labels, source_groups)
	else:
		# 默认平铺模式
		for i: int in source_items.size():
			_add_assignment_source_card(source_items, source_labels, i)

	var target_items: Array = extra_data.get("target_items", [])
	var target_labels: Array = extra_data.get("target_labels", [])
	for i: int in target_items.size():
		var target_view := BATTLE_CARD_VIEW.new()
		target_view.custom_minimum_size = _dialog_card_size
		target_view.set_clickable(true)
		_setup_dialog_card_view(target_view, target_items[i], target_labels[i] if i < target_labels.size() else "")
		target_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			_on_assignment_target_chosen(i)
		)
		target_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
			if cd != null:
				_show_card_detail(cd)
		)
		target_view.set_meta("assignment_target_index", i)
		_dialog_assignment_target_row.add_child(target_view)

	_dialog_utility_row.visible = true
	var clear_button := Button.new()
	clear_button.custom_minimum_size = Vector2(140, 40)
	clear_button.text = "清空分配"
	clear_button.pressed.connect(func() -> void:
		_dialog_assignment_assignments.clear()
		_dialog_assignment_selected_source_index = -1
		_refresh_assignment_dialog_views()
	)
	_dialog_utility_row.add_child(clear_button)

	_dialog_confirm.visible = true
	_dialog_status_lbl.visible = false
	_refresh_assignment_dialog_views()


func _populate_grouped_source_items(
	source_items: Array,
	source_labels: Array,
	source_groups: Array
) -> void:
	for gi: int in source_groups.size():
		var group: Dictionary = source_groups[gi]
		var slot: Variant = group.get("slot")
		var indices: Array = group.get("energy_indices", [])
		if not slot is PokemonSlot or indices.is_empty():
			continue
		# 组间分隔符
		if gi > 0:
			var sep := VSeparator.new()
			sep.custom_minimum_size = Vector2(2, 0)
			sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_dialog_assignment_source_row.add_child(sep)
		# 宝可梦组头（不可点击）
		var header_view := BATTLE_CARD_VIEW.new()
		header_view.custom_minimum_size = _dialog_card_size
		header_view.set_clickable(false)
		var pokemon_slot: PokemonSlot = slot as PokemonSlot
		header_view.setup_from_card_data(pokemon_slot.get_card_data(), _battle_card_mode_for_slot(pokemon_slot))
		header_view.set_badges()
		header_view.set_battle_status(_build_battle_status(pokemon_slot))
		_dialog_assignment_source_row.add_child(header_view)
		# 该宝可梦身上的能量卡（可点击）
		for energy_idx: Variant in indices:
			var i: int = int(energy_idx)
			_add_assignment_source_card(source_items, source_labels, i)


func _add_assignment_source_card(source_items: Array, source_labels: Array, i: int) -> void:
	var source_view := BATTLE_CARD_VIEW.new()
	source_view.custom_minimum_size = _dialog_card_size
	source_view.set_clickable(true)
	var source_label: String = source_labels[i] if i < source_labels.size() else ""
	_setup_dialog_card_view(source_view, source_items[i], source_label)
	source_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		_on_assignment_source_chosen(i)
	)
	source_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
		if cd != null:
			_show_card_detail(cd)
	)
	source_view.set_meta("assignment_source_index", i)
	_dialog_assignment_source_row.add_child(source_view)


func _on_assignment_source_chosen(source_index: int) -> void:
	var source_items: Array = _dialog_data.get("source_items", [])
	if source_index < 0 or source_index >= source_items.size():
		return

	var assigned_index := _find_assignment_index_for_source(source_index)
	if assigned_index >= 0:
		_dialog_assignment_assignments.remove_at(assigned_index)
		if _dialog_assignment_selected_source_index == source_index:
			_dialog_assignment_selected_source_index = -1
		_refresh_assignment_dialog_views()
		return

	var max_assignments: int = int(_dialog_data.get("max_select", source_items.size()))
	if max_assignments > 0 and _dialog_assignment_assignments.size() >= max_assignments:
		_log("已达到最多可分配数量。")
		return

	if _dialog_assignment_selected_source_index == source_index:
		_dialog_assignment_selected_source_index = -1
	else:
		_dialog_assignment_selected_source_index = source_index
	_refresh_assignment_dialog_views()


func _on_assignment_target_chosen(target_index: int) -> void:
	if _dialog_assignment_selected_source_index < 0:
		_log("请先选择1张要分配的卡。")
		return
	var source_items: Array = _dialog_data.get("source_items", [])
	var target_items: Array = _dialog_data.get("target_items", [])
	if _dialog_assignment_selected_source_index >= source_items.size():
		return
	if target_index < 0 or target_index >= target_items.size():
		return
	var exclude_map: Dictionary = _dialog_data.get("source_exclude_targets", {})
	var excluded: Array = exclude_map.get(_dialog_assignment_selected_source_index, [])
	if target_index in excluded:
		_log("不能转移给能量来源的同一只宝可梦。")
		return
	_dialog_assignment_assignments.append({
		"source_index": _dialog_assignment_selected_source_index,
		"source": source_items[_dialog_assignment_selected_source_index],
		"target_index": target_index,
		"target": target_items[target_index],
	})
	_dialog_assignment_selected_source_index = -1
	_refresh_assignment_dialog_views()


func _refresh_assignment_dialog_views() -> void:
	for child: Node in _dialog_assignment_source_row.get_children():
		if not (child is BattleCardView):
			continue
		var card_view := child as BattleCardView
		var idx: int = int(card_view.get_meta("assignment_source_index", -1))
		card_view.set_selected(idx == _dialog_assignment_selected_source_index)
		card_view.set_disabled(_find_assignment_index_for_source(idx) >= 0)

	for child: Node in _dialog_assignment_target_row.get_children():
		if not (child is BattleCardView):
			continue
		var target_view := child as BattleCardView
		var idx: int = int(target_view.get_meta("assignment_target_index", -1))
		target_view.set_selected(idx == _dialog_assignment_last_target_index())
		target_view.set_disabled(false)

	_update_assignment_dialog_state()


func _update_assignment_dialog_state() -> void:
	var min_assignments: int = int(_dialog_data.get("min_select", 0))
	var max_assignments: int = int(_dialog_data.get("max_select", 0))
	_dialog_confirm.disabled = _dialog_assignment_assignments.size() < min_assignments
	var target_counts: Dictionary = {}
	for assignment: Dictionary in _dialog_assignment_assignments:
		var target: Variant = assignment.get("target")
		if target == null:
			continue
		target_counts[target] = int(target_counts.get(target, 0)) + 1

	var summary_parts: Array[String] = []
	for target: Variant in target_counts.keys():
		if target is PokemonSlot:
			var slot: PokemonSlot = target as PokemonSlot
			summary_parts.append("%s×%d" % [slot.get_pokemon_name(), int(target_counts[target])])

	var summary: String = "已分配 %d" % _dialog_assignment_assignments.size()
	if max_assignments > 0:
		summary += " / %d" % max_assignments
	summary += "。先选择左侧卡牌，再点击右侧目标。"
	if _dialog_assignment_selected_source_index >= 0:
		var source_items: Array = _dialog_data.get("source_items", [])
		if _dialog_assignment_selected_source_index < source_items.size():
			var selected_source: Variant = source_items[_dialog_assignment_selected_source_index]
			if selected_source is CardInstance:
				summary += " 当前选择：%s。" % (selected_source as CardInstance).card_data.name
	if not summary_parts.is_empty():
		summary += " 已分配到：" + ", ".join(summary_parts)
	_dialog_assignment_summary_lbl.text = summary


func _find_assignment_index_for_source(source_index: int) -> int:
	for i: int in _dialog_assignment_assignments.size():
		if int(_dialog_assignment_assignments[i].get("source_index", -1)) == source_index:
			return i
	return -1


func _dialog_assignment_last_target_index() -> int:
	if _dialog_assignment_assignments.is_empty():
		return -1
	return int(_dialog_assignment_assignments.back().get("target_index", -1))


func _reset_dialog_assignment_state() -> void:
	_dialog_assignment_mode = false
	_dialog_assignment_selected_source_index = -1
	_dialog_assignment_assignments.clear()
	if _dialog_assignment_panel != null:
		_dialog_assignment_panel.visible = false
	if _dialog_assignment_summary_lbl != null:
		_dialog_assignment_summary_lbl.text = ""


func _setup_dialog_card_view(card_view: BattleCardView, item: Variant, label: String) -> void:
	if item is CardInstance:
		card_view.setup_from_instance(item, BATTLE_CARD_VIEW.MODE_CHOICE)
		card_view.set_info(item.card_data.name, _dialog_choice_subtitle(item, label))
	elif item is CardData:
		card_view.setup_from_card_data(item, BATTLE_CARD_VIEW.MODE_CHOICE)
		card_view.set_info(item.name, _dialog_choice_subtitle(item, label))
	elif item is PokemonSlot:
		var slot: PokemonSlot = item
		card_view.setup_from_card_data(slot.get_card_data(), _battle_card_mode_for_slot(slot))
		card_view.set_badges()
		card_view.set_battle_status(_build_battle_status(slot))
	else:
		card_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_CHOICE)
		card_view.set_info(str(label), "")


func _dialog_choice_subtitle(item: Variant, label: String) -> String:
	if item is PokemonSlot:
		var slot: PokemonSlot = item
		return "HP %d/%d" % [_get_display_remaining_hp(slot), _get_display_max_hp(slot)]
	if item is CardInstance:
		var card: CardInstance = item
		if label != "" and label != card.card_data.name:
			return label
		return _hand_card_subtext(card.card_data)
	if item is CardData:
		var data: CardData = item
		if label != "" and label != data.name:
			return label
		return _hand_card_subtext(data)
	return label


func _dialog_item_has_card_visual(item: Variant) -> bool:
	return item is CardInstance or item is CardData or item is PokemonSlot


func _on_dialog_card_chosen(real_index: int) -> void:
	var min_select: int = int(_dialog_data.get("min_select", 1))
	var max_select: int = int(_dialog_data.get("max_select", 1))
	var is_multi := max_select > 1 or min_select > 1
	if not is_multi:
		_confirm_dialog_selection(PackedInt32Array([real_index]))
		return

	if real_index in _dialog_card_selected_indices:
		_dialog_card_selected_indices.erase(real_index)
	else:
		if max_select > 0 and _dialog_card_selected_indices.size() >= max_select:
			return
		_dialog_card_selected_indices.append(real_index)

	_sync_dialog_card_selection()
	_update_dialog_confirm_state()


func _sync_dialog_card_selection() -> void:
	for child: Node in _dialog_card_row.get_children():
		if not (child is BattleCardView):
			continue
		var card_view: BattleCardView = child
		var idx: int = int(card_view.get_meta("dialog_choice_index", -1))
		card_view.set_selected(idx in _dialog_card_selected_indices)


func _update_dialog_confirm_state() -> void:
	var min_select: int = int(_dialog_data.get("min_select", 1))
	if _dialog_assignment_mode:
		_update_assignment_dialog_state()
		return
	if _dialog_card_mode:
		_dialog_confirm.disabled = _dialog_card_selected_indices.size() < min_select
		_update_dialog_status_text()
		return

	if _dialog_list.select_mode == ItemList.SELECT_SINGLE:
		_dialog_confirm.disabled = _dialog_list.get_selected_items().size() < min_select
	else:
		_dialog_confirm.disabled = _dialog_multi_selected_indices.size() < min_select


func _update_dialog_status_text() -> void:
	if _dialog_status_lbl == null or not _dialog_status_lbl.visible:
		return
	var min_select: int = int(_dialog_data.get("min_select", 1))
	var max_select: int = int(_dialog_data.get("max_select", 1))
	_dialog_status_lbl.text = "已选择 %d / %d" % [_dialog_card_selected_indices.size(), min_select]
	if max_select > 1:
		_dialog_status_lbl.text += "（最多 %d）" % max_select


func _confirm_dialog_selection(sel_items: PackedInt32Array) -> void:
	_runtime_log(
		"confirm_dialog_selection",
		"choice=%s selected=%s %s" % [_pending_choice, JSON.stringify(sel_items), _dialog_state_snapshot()]
	)
	_dialog_overlay.visible = false
	_handle_dialog_choice(sel_items)


func _on_dialog_item_selected(idx: int) -> void:
	if _dialog_list.select_mode != ItemList.SELECT_SINGLE:
		return
	_dialog_confirm.disabled = false
	if not _dialog_card_mode:
		_confirm_dialog_selection(PackedInt32Array([idx]))


func _on_dialog_item_multi_selected(idx: int, selected: bool) -> void:
	if _dialog_list.select_mode == ItemList.SELECT_SINGLE:
		return
	if selected:
		if idx not in _dialog_multi_selected_indices:
			_dialog_multi_selected_indices.append(idx)
	else:
		_dialog_multi_selected_indices.erase(idx)
	_update_dialog_confirm_state()

func _on_dialog_confirm() -> void:
	if _dialog_assignment_mode:
		_confirm_assignment_dialog()
		return
	var sel_items := PackedInt32Array()
	if _dialog_card_mode:
		for selected_idx: int in _dialog_card_selected_indices:
			sel_items.append(selected_idx)
	else:
		sel_items = _dialog_list.get_selected_items()
	var min_select: int = int(_dialog_data.get("min_select", 1))
	var max_select: int = int(_dialog_data.get("max_select", 1))
	if sel_items.size() < min_select:
		_log("至少选择 %d 项。" % min_select)
		return
	if max_select > 0 and sel_items.size() > max_select:
		_log("最多选择 %d 项。" % max_select)
		return
	_confirm_dialog_selection(sel_items)

func _on_dialog_cancel() -> void:
	_runtime_log("dialog_cancel", "choice=%s %s" % [_pending_choice, _dialog_state_snapshot()])
	_dialog_overlay.visible = false
	_dialog_card_selected_indices.clear()
	_reset_dialog_assignment_state()
	if _pending_choice == "effect_interaction":
		_reset_effect_interaction()
	_pending_choice = ""


func _confirm_assignment_dialog() -> void:
	var min_select: int = int(_dialog_data.get("min_select", 0))
	var max_select: int = int(_dialog_data.get("max_select", 0))
	var assignment_count: int = _dialog_assignment_assignments.size()
	if assignment_count < min_select:
		_log("至少完成 %d 次分配。" % min_select)
		return
	if max_select > 0 and assignment_count > max_select:
		_log("最多只能完成 %d 次分配。" % max_select)
		return
	if _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
		return
	var stored_assignments: Array[Dictionary] = []
	for assignment: Dictionary in _dialog_assignment_assignments:
		stored_assignments.append(assignment.duplicate())
	_dialog_overlay.visible = false
	_reset_dialog_assignment_state()
	_commit_effect_assignment_selection(stored_assignments)


func _commit_effect_assignment_selection(stored_assignments: Array[Dictionary]) -> void:
	if _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
		return
	var step: Dictionary = _pending_effect_steps[_pending_effect_step_index]
	_pending_effect_context[step.get("id", "step_%d" % _pending_effect_step_index)] = stored_assignments
	_runtime_log(
		"effect_assignment_choice",
		"step=%s assignments=%d" % [str(step.get("id", "step_%d" % _pending_effect_step_index)), stored_assignments.size()]
	)
	_pending_effect_step_index += 1
	_inject_followup_steps()
	_show_next_effect_interaction_step()


func _handle_dialog_choice(selected_indices: PackedInt32Array) -> void:
	var idx: int = selected_indices[0] if not selected_indices.is_empty() else -1
	var handled_choice := _pending_choice
	_pending_choice = ""
	_runtime_log(
		"handle_dialog_choice",
		"handled=%s idx=%d selected=%s" % [handled_choice, idx, JSON.stringify(selected_indices)]
	)
	match handled_choice:
		"mulligan_extra_draw":
			var beneficiary: int = _dialog_data.get("beneficiary", 0)
			_gsm.resolve_mulligan_choice(beneficiary, idx == 0)
			# resolve_mulligan_choice handles mulligan follow-up and may return to setup_ready
		"attack":
			var cp: int = _dialog_data.get("player", 0)
			if idx < _dialog_data.get("attack_count", 0):
				if _gsm.use_attack(cp, idx):
					_refresh_ui()
					_check_two_player_handover()
				else:
					_log(_gsm.get_attack_unusable_reason(cp, idx))
		"pokemon_action":
			var cp_action: int = _dialog_data.get("player", 0)
			var actions: Array = _dialog_data.get("actions", [])
			if idx >= 0 and idx < actions.size():
				var action: Variant = actions[idx]
				if action is Dictionary:
					var action_data: Dictionary = action
					var action_slot: Variant = action_data.get("slot", null)
					var action_type: String = str(action_data.get("type", ""))
					if not bool(action_data.get("enabled", true)):
						_log(str(action_data.get("reason", "当前无法执行该操作")))
						return
					if action_slot is PokemonSlot and action_type == "ability":
						_try_use_ability_with_interaction(
							cp_action,
							action_slot,
							int(action_data.get("ability_index", 0))
						)
					elif action_slot is PokemonSlot and action_type == "attack":
						_try_use_attack_with_interaction(
							cp_action,
							action_slot,
							int(action_data.get("attack_index", 0))
						)
					elif action_slot is PokemonSlot and action_type == "granted_attack":
						_try_use_granted_attack_with_interaction(
							cp_action,
							action_slot,
							action_data.get("granted_attack", {})
						)
					elif action_type == "retreat":
						if _gsm.rule_validator.can_retreat(_gsm.game_state, cp_action):
							_show_retreat_dialog(cp_action)
						else:
							_log("当前无法撤退")
		"send_out":
			var pi: int = _dialog_data.get("player", 0)
			var bench_raw: Array = _dialog_data.get("bench", [])
			var bench_so: Array[PokemonSlot] = []
			for s: Variant in bench_raw:
				if s is PokemonSlot:
					bench_so.append(s)
			if idx < bench_so.size():
				if _gsm.send_out_pokemon(pi, bench_so[idx]):
					_view_player = _gsm.game_state.current_player_index
					_refresh_ui()
					_check_two_player_handover()
				else:
					_log("无法派出该宝可梦")
		"heavy_baton_target":
			var pi_hb: int = _dialog_data.get("player", 0)
			var bench_raw_hb: Array = _dialog_data.get("bench", [])
			var bench_hb: Array[PokemonSlot] = []
			for s: Variant in bench_raw_hb:
				if s is PokemonSlot:
					bench_hb.append(s)
			if idx < bench_hb.size():
				if _gsm.resolve_heavy_baton_choice(pi_hb, bench_hb[idx]):
					_refresh_ui()
				else:
					_log("Invalid Heavy Baton target")
		"retreat_bench":
			var cp: int = _dialog_data.get("player", 0)
			var bench_raw2: Array = _dialog_data.get("bench", [])
			var bench_rb: Array[PokemonSlot] = []
			for s: Variant in bench_raw2:
				if s is PokemonSlot:
					bench_rb.append(s)
			var energy_raw: Array = _dialog_data.get("energy_discard", [])
			var energy_discard: Array[CardInstance] = []
			for e: Variant in energy_raw:
				if e is CardInstance:
					energy_discard.append(e)
			if idx < bench_rb.size():
				_gsm.retreat(cp, energy_discard, bench_rb[idx])
				_refresh_ui()
		"confirm_exit":
			if idx == 0:
				GameManager.goto_battle_setup()
		"zeus_help":
			var zeus_player_index: int = int(_dialog_data.get("player", _view_player))
			var zeus_dialog_cards: Array = _dialog_data.get("deck_cards", [])
			var selected_cards: Array[CardInstance] = _resolve_zeus_help_selected_cards(
				zeus_player_index,
				zeus_dialog_cards,
				selected_indices
			)
			_apply_zeus_help(zeus_player_index, selected_cards)
		"game_over":
			if idx == 1:
				GameManager.goto_battle_setup()
		"effect_interaction":
			_handle_effect_interaction_choice(selected_indices)
		_:
			if handled_choice.begins_with("setup_active_"):
				var pi: int = int(handled_choice.split("_")[-1])
				var basics_raw: Array = _dialog_data.get("basics", [])
				var basics: Array[CardInstance] = []
				for c: Variant in basics_raw:
					if c is CardInstance:
						basics.append(c)
				if idx < basics.size():
					_gsm.setup_place_active_pokemon(pi, basics[idx])
					_after_setup_active(pi)
			elif handled_choice.begins_with("setup_bench_"):
				var pi: int = int(handled_choice.split("_")[-1])
				if idx == 0:
					# Stop placing bench Pokemon and finish the setup bench step
					_after_setup_bench(pi)
				else:
					var cards_raw: Array = _dialog_data.get("cards", [])
					var cards: Array[CardInstance] = []
					for c: Variant in cards_raw:
						if c is CardInstance:
							cards.append(c)
					var card_idx: int = idx - 1
					if card_idx < cards.size():
						_gsm.setup_place_bench_pokemon(pi, cards[card_idx])
						_refresh_ui()
						_show_setup_bench_dialog(pi)


func _prompt_send_out_dialog(pi: int) -> void:
	_pending_choice = "send_out"
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER and pi != _view_player:
		_show_handover_prompt(pi, func() -> void:
			_set_handover_panel_visible(false, "send_out_follow_up")
			_view_player = pi
			_refresh_ui()
			_show_send_out_dialog(pi)
		)
		return

	_set_handover_panel_visible(false, "send_out_direct")
	_view_player = pi
	_refresh_ui()
	_show_send_out_dialog(pi)


func _show_send_out_dialog(pi: int) -> void:
	var player: PlayerState = _gsm.game_state.players[pi]
	_pending_choice = "send_out"
	_dialog_data = {
		"player": pi,
		"bench": player.bench,
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	}
	_show_field_slot_choice("玩家 %d：选择要派出的宝可梦" % (pi + 1), player.bench, _dialog_data)


func _prompt_heavy_baton_dialog(
	pi: int,
	bench_targets: Array[PokemonSlot],
	energy_count: int,
	source_name: String
) -> void:
	_pending_choice = "heavy_baton_target"
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER and pi != _view_player:
		_show_handover_prompt(pi, func() -> void:
			_set_handover_panel_visible(false, "heavy_baton_follow_up")
			_view_player = pi
			_refresh_ui()
			_show_heavy_baton_dialog(pi, bench_targets, energy_count, source_name)
		)
		return
	_view_player = pi
	_refresh_ui()
	_show_heavy_baton_dialog(pi, bench_targets, energy_count, source_name)


func _show_heavy_baton_dialog(
	pi: int,
	bench_targets: Array[PokemonSlot],
	energy_count: int,
	source_name: String
) -> void:
	_pending_choice = "heavy_baton_target"
	_dialog_data = {
		"player": pi,
		"bench": bench_targets.duplicate(),
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}
	_show_field_slot_choice(
		"%s：选择接收 %d 个能量的备战宝可梦" % [source_name, energy_count],
		bench_targets,
		_dialog_data
	)


func _try_handle_field_interaction_slot_click(slot_id: String, target_slot: PokemonSlot) -> void:
	if not _is_field_interaction_active():
		return
	if not _field_interaction_slot_index_by_id.has(slot_id):
		return
	var target_index: int = int(_field_interaction_slot_index_by_id.get(slot_id, -1))
	if target_index < 0:
		return
	match _field_interaction_mode:
		"slot_select":
			_handle_field_slot_select_index(target_index)
		"assignment":
			_handle_field_assignment_target_index(target_index)


func _handle_field_slot_select_index(target_index: int) -> void:
	var min_select: int = int(_field_interaction_data.get("min_select", 1))
	var max_select: int = int(_field_interaction_data.get("max_select", 1))
	if max_select <= 1 and min_select <= 1:
		_field_interaction_selected_indices = [target_index]
		_finalize_field_slot_selection()
		return
	if target_index in _field_interaction_selected_indices:
		_field_interaction_selected_indices.erase(target_index)
	else:
		if max_select > 0 and _field_interaction_selected_indices.size() >= max_select:
			return
		_field_interaction_selected_indices.append(target_index)
	_refresh_field_interaction_status()
	_refresh_ui()
	if min_select == max_select and max_select > 1 and _field_interaction_selected_indices.size() == max_select:
		_finalize_field_slot_selection()


func _handle_field_assignment_target_index(target_index: int) -> void:
	if _field_interaction_assignment_selected_source_index < 0:
		_log("请先在中间面板选择1张卡。")
		return
	var source_items: Array = _field_interaction_data.get("source_items", [])
	var target_items: Array = _field_interaction_data.get("target_items", [])
	if _field_interaction_assignment_selected_source_index >= source_items.size():
		return
	if target_index < 0 or target_index >= target_items.size():
		return
	var exclude_map: Dictionary = _field_interaction_data.get("source_exclude_targets", {})
	var excluded: Array = exclude_map.get(_field_interaction_assignment_selected_source_index, [])
	if target_index in excluded:
		_log("当前选择不能分配到该目标。")
		return
	_field_interaction_assignment_entries.append({
		"source_index": _field_interaction_assignment_selected_source_index,
		"source": source_items[_field_interaction_assignment_selected_source_index],
		"target_index": target_index,
		"target": target_items[target_index],
	})
	_field_interaction_assignment_selected_source_index = -1
	_refresh_field_interaction_status()
	_refresh_ui()
	var min_assignments: int = int(_field_interaction_data.get("min_select", 0))
	var max_assignments: int = int(_field_interaction_data.get("max_select", 0))
	if min_assignments == max_assignments and max_assignments > 0 and _field_interaction_assignment_entries.size() == max_assignments:
		_finalize_field_assignment_selection()


func _finalize_field_slot_selection() -> void:
	var min_select: int = int(_field_interaction_data.get("min_select", 1))
	if _field_interaction_selected_indices.size() < min_select:
		_log("至少选择 %d 项。" % min_select)
		return
	var selected := PackedInt32Array(_field_interaction_selected_indices)
	_hide_field_interaction()
	if _pending_choice == "effect_interaction":
		_handle_effect_interaction_choice(selected)
	else:
		_handle_dialog_choice(selected)


func _finalize_field_assignment_selection() -> void:
	var min_select: int = int(_field_interaction_data.get("min_select", 0))
	if _field_interaction_assignment_entries.size() < min_select:
		_log("至少完成 %d 次分配。" % min_select)
		return
	if _pending_choice != "effect_interaction":
		_hide_field_interaction()
		return
	var stored_assignments: Array[Dictionary] = []
	for assignment: Dictionary in _field_interaction_assignment_entries:
		stored_assignments.append(assignment.duplicate())
	_hide_field_interaction()
	_commit_effect_assignment_selection(stored_assignments)


func _resolve_zeus_help_selected_cards(
	player_index: int,
	dialog_cards: Array,
	selected_indices: PackedInt32Array
) -> Array[CardInstance]:
	var selected_cards: Array[CardInstance] = []
	if _gsm == null or _gsm.game_state == null:
		return selected_cards
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return selected_cards
	var player: PlayerState = _gsm.game_state.players[player_index]
	for selected_idx: int in selected_indices:
		if selected_idx < 0 or selected_idx >= dialog_cards.size():
			continue
		var candidate: Variant = dialog_cards[selected_idx]
		if candidate is CardInstance and candidate in player.deck and candidate not in selected_cards:
			selected_cards.append(candidate)
	return selected_cards


func _apply_zeus_help(player_index: int, selected_cards: Array[CardInstance]) -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return
	var player: PlayerState = _gsm.game_state.players[player_index]
	var added_count: int = 0
	for card: CardInstance in selected_cards:
		if card in player.deck:
			player.deck.erase(card)
			card.face_up = true
			player.hand.append(card)
			added_count += 1
	player.shuffle_deck()
	if is_inside_tree():
		if added_count > 0:
			_log("宙斯帮我：加入了 %d 张牌到手牌。" % added_count)
		else:
			_log("宙斯帮我：未选择卡牌。")
		_refresh_ui()


func _show_pokemon_action_dialog(cp: int, slot: PokemonSlot, include_attacks: bool) -> void:
	var cd: CardData = slot.get_card_data()
	var items: Array[String] = []
	var actions: Array[Dictionary] = []

	var effect: BaseEffect = _gsm.effect_processor.get_effect(cd.effect_id)
	if effect != null:
		for i: int in cd.abilities.size():
			var ability: Dictionary = cd.abilities[i]
			if not effect.has_method("can_use_ability"):
				continue
			var can_use: bool = _gsm.effect_processor.can_use_ability(slot, _gsm.game_state, i)
			var ability_reason := "" if can_use else "%s 的特性当前无法使用" % cd.name
			var prefix: String = "" if can_use else "[不可用] "
			items.append("%s[特性] %s" % [prefix, ability.get("name", "")])
			actions.append({
				"type": "ability",
				"slot": slot,
				"ability_index": i,
				"enabled": can_use,
				"reason": ability_reason,
			})

	for granted: Dictionary in _gsm.effect_processor.get_granted_abilities(slot, _gsm.game_state):
		var can_use_granted: bool = bool(granted.get("enabled", false))
		var granted_name: String = str(granted.get("name", ""))
		var granted_reason := "" if can_use_granted else "%s 的特性当前无法使用" % cd.name
		var granted_prefix: String = "" if can_use_granted else "[不可用] "
		items.append("%s[特性] %s" % [granted_prefix, granted_name])
		actions.append({
			"type": "ability",
			"slot": slot,
			"ability_index": int(granted.get("ability_index", cd.abilities.size())),
			"enabled": can_use_granted,
			"reason": granted_reason,
		})

	if include_attacks:
		for i: int in cd.attacks.size():
			var atk: Dictionary = cd.attacks[i]
			var can: bool = _gsm.can_use_attack(cp, i)
			var attack_reason := "" if can else _gsm.get_attack_unusable_reason(cp, i)
			var prefix: String = "" if can else "[不可用] "
			var preview_damage: int = _gsm.get_attack_preview_damage(cp, i)
			var preview_text: String = ""
			if String(atk.get("damage", "")) != "" or preview_damage > 0:
				preview_text = " 预计伤害:%d" % preview_damage
			items.append("%s[招式] %s [%s] %s%s" % [prefix, atk.get("name", ""), atk.get("cost", ""), atk.get("damage", ""), preview_text])
			actions.append({
				"type": "attack",
				"slot": slot,
				"attack_index": i,
				"enabled": can,
				"reason": attack_reason,
			})
		for granted_attack: Dictionary in _gsm.effect_processor.get_granted_attacks(slot, _gsm.game_state):
			var granted_can_use: bool = _can_use_granted_attack(cp, slot, granted_attack)
			var granted_prefix: String = "" if granted_can_use else "[不可用] "
			var granted_reason: String = "" if granted_can_use else _get_granted_attack_unusable_reason(cp, slot, granted_attack)
			items.append("%s[招式] %s [%s]" % [
				granted_prefix,
				str(granted_attack.get("name", "")),
				str(granted_attack.get("cost", "")),
			])
			actions.append({
				"type": "granted_attack",
				"slot": slot,
				"granted_attack": granted_attack,
				"enabled": granted_can_use,
				"reason": granted_reason,
			})

		if slot == _gsm.game_state.players[cp].active_pokemon:
			var can_retreat: bool = _gsm.rule_validator.can_retreat(_gsm.game_state, cp)
			var retreat_prefix: String = "" if can_retreat else "[不可用] "
			items.append("%s[行动] 撤退" % retreat_prefix)
			actions.append({
				"type": "retreat",
				"enabled": can_retreat,
				"reason": "当前无法撤退",
			})

	if actions.is_empty():
		_log("%s 当前没有可执行的行动" % cd.name)
		return

	_pending_choice = "pokemon_action"
	_show_dialog("选择行动：%s" % cd.name, items, {"player": cp, "actions": actions})
	_dialog_cancel.visible = true


func _show_attack_dialog(cp: int, active_slot: PokemonSlot) -> void:
	_show_pokemon_action_dialog(cp, active_slot, true)


func _try_use_attack_with_interaction(player_index: int, slot: PokemonSlot, attack_index: int) -> void:
	if not _gsm.can_use_attack(player_index, attack_index):
		_log(_gsm.get_attack_unusable_reason(player_index, attack_index))
		return
	var card: CardInstance = slot.get_top_card()
	if card == null:
		return
	var attack: Dictionary = card.card_data.attacks[attack_index]
	var steps: Array[Dictionary] = []
	var effects: Array[BaseEffect] = _gsm.effect_processor.get_attack_effects_for_slot(slot, attack_index)
	for effect: BaseEffect in effects:
		steps.append_array(effect.get_attack_interaction_steps(card, attack, _gsm.game_state))
	if steps.is_empty():
		if _gsm.use_attack(player_index, attack_index):
			_refresh_ui()
			_check_two_player_handover()
		else:
			_log(_gsm.get_attack_unusable_reason(player_index, attack_index))
		return
	_start_effect_interaction("attack", player_index, steps, card, slot, attack_index, {}, effects)


func _try_use_granted_attack_with_interaction(player_index: int, slot: PokemonSlot, granted_attack: Dictionary) -> void:
	if not _can_use_granted_attack(player_index, slot, granted_attack):
		_log(_get_granted_attack_unusable_reason(player_index, slot, granted_attack))
		return
	var card: CardInstance = slot.get_top_card()
	if card == null:
		return
	var steps: Array[Dictionary] = _gsm.effect_processor.get_granted_attack_interaction_steps(
		slot,
		granted_attack,
		_gsm.game_state
	)
	if steps.is_empty():
		if _gsm.use_granted_attack(player_index, slot, granted_attack):
			_refresh_ui()
			_check_two_player_handover()
		else:
			_log(_get_granted_attack_unusable_reason(player_index, slot, granted_attack))
		return
	_start_effect_interaction("granted_attack", player_index, steps, card, slot, -1, granted_attack)


func _can_use_granted_attack(player_index: int, slot: PokemonSlot, granted_attack: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return false
	if _gsm.game_state.current_player_index != player_index:
		return false
	if _gsm.game_state.phase != GameState.GamePhase.MAIN:
		return false
	if slot == null or slot.get_top_card() == null:
		return false
	if slot != _gsm.game_state.players[player_index].active_pokemon:
		return false
	if slot.attached_tool == null:
		return false
	if _gsm.effect_processor.is_tool_effect_suppressed(slot, _gsm.game_state):
		return false
	var cost: String = str(granted_attack.get("cost", ""))
	return _gsm.rule_validator.has_enough_energy(slot, cost, _gsm.effect_processor, _gsm.game_state)


func _get_granted_attack_unusable_reason(player_index: int, slot: PokemonSlot, granted_attack: Dictionary) -> String:
	if _gsm == null or _gsm.game_state == null:
		return "当前无法使用该招式"
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return "当前无法使用该招式"
	if _gsm.game_state.current_player_index != player_index:
		return "当前不是你的回合"
	if _gsm.game_state.phase != GameState.GamePhase.MAIN:
		return "当前阶段无法使用招式"
	if slot == null or slot.get_top_card() == null:
		return "当前无法使用该招式"
	if slot != _gsm.game_state.players[player_index].active_pokemon:
		return "只有战斗宝可梦可以使用该招式"
	if slot.attached_tool == null:
		return "当前没有可用的招式来源"
	if _gsm.effect_processor.is_tool_effect_suppressed(slot, _gsm.game_state):
		return "当前该宝可梦道具效果被无效化"
	var cost: String = str(granted_attack.get("cost", ""))
	if not _gsm.rule_validator.has_enough_energy(slot, cost, _gsm.effect_processor, _gsm.game_state):
		return "能量不足，无法使用该招式"
	return "当前无法使用该招式"


func _try_start_evolve_trigger_ability_interaction(player_index: int, slot: PokemonSlot) -> void:
	if _gsm == null or slot == null or slot.get_top_card() == null:
		return
	var steps: Array[Dictionary] = _gsm.get_evolve_ability_interaction_steps(slot)
	if steps.is_empty():
		return
	_start_effect_interaction("ability", player_index, steps, slot.get_top_card(), slot, 0)


func _show_retreat_dialog(cp: int) -> void:
	var player: PlayerState = _gsm.game_state.players[cp]
	var active: PokemonSlot = player.active_pokemon
	var cost: int = _gsm.effect_processor.get_effective_retreat_cost(active, _gsm.game_state)

	var energy_discard: Array[CardInstance] = []
	var paid_units: int = 0
	for energy: CardInstance in active.attached_energy:
		if paid_units >= cost:
			break
		energy_discard.append(energy)
		paid_units += _gsm.effect_processor.get_energy_colorless_count(energy)

	_pending_choice = "retreat_bench"
	_dialog_data = {
		"player": cp,
		"bench": player.bench,
		"energy_discard": energy_discard,
		"allow_cancel": true,
		"min_select": 1,
		"max_select": 1,
	}
	_show_field_slot_choice(
		"选择要换上的备战宝可梦（弃掉 %d 个能量）" % cost,
		player.bench,
		_dialog_data
	)


func _show_handover_prompt(target_player: int, follow_up: Callable = Callable()) -> void:
	if follow_up.is_valid():
		_set_pending_handover_action(follow_up, "show_prompt_follow_up")
	elif not _pending_handover_action.is_valid():
		_set_pending_handover_action(Callable(), "show_prompt_generic")
	else:
		_runtime_log(
			"handover_action_preserved",
			"reason=show_prompt_generic target=%d %s" % [target_player, _state_snapshot()]
		)
	_set_handover_panel_visible(true, "show_prompt_target_%d" % target_player)
	_handover_lbl.text = "请将设备交给玩家 %d" % (target_player + 1)


func _check_two_player_handover() -> void:
	if GameManager.current_mode != GameManager.GameMode.TWO_PLAYER:
		_set_pending_handover_action(Callable(), "handover_check_non_two_player")
		_set_handover_panel_visible(false, "handover_check_non_two_player")
		return
	if _gsm == null or _gsm.game_state.phase == GameState.GamePhase.GAME_OVER:
		_set_pending_handover_action(Callable(), "handover_check_game_over")
		_set_handover_panel_visible(false, "handover_check_game_over")
		return
	if _pending_handover_action.is_valid():
		_runtime_log("handover_check_deferred", _state_snapshot())
		return
	var cp: int = _gsm.game_state.current_player_index
	if cp != _view_player:
		_show_handover_prompt(cp)
		_runtime_log("handover_required", _state_snapshot())
		return
	_set_pending_handover_action(Callable(), "handover_check_aligned")
	_set_handover_panel_visible(false, "handover_check_aligned")


func _on_handover_confirmed() -> void:
	_runtime_log(
		"handover_confirm_requested",
		"follow_up_valid=%s %s" % [str(_pending_handover_action.is_valid()), _state_snapshot()]
	)
	_set_handover_panel_visible(false, "handover_confirm")
	var follow_up := _pending_handover_action
	_set_pending_handover_action(Callable(), "handover_confirm")
	if follow_up.is_valid():
		follow_up.call()
	else:
		var cp: int = _gsm.game_state.current_player_index
		_view_player = cp
		_refresh_ui()
	_runtime_log("handover_confirmed", _state_snapshot())


func _on_hand_card_clicked(inst: CardInstance, _panel: PanelContainer) -> void:
	_runtime_log(
		"hand_card_clicked",
		"card=%s selected_before=%s %s" % [
			_card_instance_label(inst),
			_card_instance_label(_selected_hand_card),
			_state_snapshot()
		]
	)
	if _is_field_interaction_active():
		return
	if _selected_hand_card == inst:
		_selected_hand_card = null
		_refresh_hand()
		return

	var cp: int = _gsm.game_state.current_player_index
	var cd := inst.card_data

	if cd.card_type == "Supporter":
		if _gsm.rule_validator.can_play_supporter(_gsm.game_state, cp):
			_try_play_trainer_with_interaction(cp, inst)
		else:
			_log("当前不能使用支援者卡")
		return
	if cd.card_type == "Item":
		_try_play_trainer_with_interaction(cp, inst)
		return
	if cd.card_type == "Stadium":
		_try_play_stadium_with_interaction(cp, inst)
		return
	if cd.is_basic_pokemon():
		_selected_hand_card = inst
		_refresh_hand()
		_log("已选中 %s，点击备战区进行放置" % cd.name)
		return
	if cd.is_pokemon() and cd.stage != "Basic":
		_selected_hand_card = inst
		_refresh_hand()
		_log("已选中 %s，点击一只宝可梦进行进化" % cd.name)
		return
	if cd.card_type == "Basic Energy" or cd.card_type == "Special Energy":
		_selected_hand_card = inst
		_refresh_hand()
		_log("已选中 %s，点击一只宝可梦附着能量" % cd.name)
		return
	if cd.card_type == "Tool":
		_selected_hand_card = inst
		_refresh_hand()
		_log("已选中 %s，点击一只宝可梦附着道具" % cd.name)
		return


func _try_play_trainer_with_interaction(player_index: int, card: CardInstance) -> void:
	var effect: BaseEffect = _gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		if not _gsm.play_trainer(player_index, card, []):
			_log("无法使用 %s" % card.card_data.name)
		_refresh_ui()
		return

	if not effect.can_execute(card, _gsm.game_state):
		_log("%s 当前无法使用" % card.card_data.name)
		return

	var steps: Array[Dictionary] = effect.get_interaction_steps(card, _gsm.game_state)
	if steps.is_empty():
		if not _gsm.play_trainer(player_index, card, []):
			_log("无法使用 %s" % card.card_data.name)
		else:
			var empty_message: String = effect.get_empty_interaction_message(card, _gsm.game_state)
			if empty_message != "":
				_log(empty_message)
		_refresh_ui()
		return

	_start_effect_interaction("trainer", player_index, steps, card)


func _try_play_stadium_with_interaction(player_index: int, card: CardInstance) -> void:
	var effect: BaseEffect = _gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		if not _gsm.play_stadium(player_index, card):
			_log("无法打出这张竞技场卡")
		_refresh_ui()
		return

	var steps: Array[Dictionary] = effect.get_on_play_interaction_steps(card, _gsm.game_state)
	if steps.is_empty():
		if not _gsm.play_stadium(player_index, card):
			_log("无法打出这张竞技场卡")
		_refresh_ui()
		return

	_start_effect_interaction("play_stadium", player_index, steps, card)


func _try_use_ability_with_interaction(player_index: int, slot: PokemonSlot, ability_index: int) -> void:
	var card: CardInstance = _gsm.effect_processor.get_ability_source_card(
		slot,
		ability_index,
		_gsm.game_state
	)
	if card == null:
		return
	var effect: BaseEffect = _gsm.effect_processor.get_ability_effect(
		slot,
		ability_index,
		_gsm.game_state
	)
	if effect == null:
		if _gsm.use_ability(player_index, slot, ability_index):
			_refresh_ui()
			_check_two_player_handover()
		else:
			_log("%s 的特性当前无法使用" % card.card_data.name)
		return
	if not _gsm.effect_processor.can_use_ability(slot, _gsm.game_state, ability_index):
		_log("%s 的特性当前无法使用" % card.card_data.name)
		return
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, _gsm.game_state)
	if steps.is_empty():
		if _gsm.use_ability(player_index, slot, ability_index):
			var ability_name: String = _gsm.effect_processor.get_ability_name(
				slot,
				ability_index,
				_gsm.game_state
			)
			_log("已使用特性：%s" % ability_name)
			_refresh_ui()
			_check_two_player_handover()
		else:
			_log("%s 的特性当前没有可选目标" % card.card_data.name)
		return
	_start_effect_interaction("ability", player_index, steps, card, slot, ability_index)


func _try_use_stadium_with_interaction(player_index: int) -> void:
	if _gsm == null or _gsm.game_state.stadium_card == null:
		return
	var stadium_card: CardInstance = _gsm.game_state.stadium_card
	var effect: BaseEffect = _gsm.effect_processor.get_effect(stadium_card.card_data.effect_id)
	if effect == null:
		if _gsm.use_stadium_effect(player_index):
			_refresh_ui()
		else:
			_log("当前竞技场效果无法使用")
		return
	if not _gsm.can_use_stadium_effect(player_index):
		_log("当前竞技场效果无法使用")
		return
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium_card, _gsm.game_state)
	if steps.is_empty():
		if _gsm.use_stadium_effect(player_index):
			_refresh_ui()
		else:
			_log("当前竞技场效果无法使用")
		return
	_start_effect_interaction("stadium", player_index, steps, stadium_card)


func _start_effect_interaction(
	kind: String,
	player_index: int,
	steps: Array[Dictionary],
	card: CardInstance,
	slot: PokemonSlot = null,
	ability_index: int = -1,
	attack_data: Dictionary = {},
	attack_effects: Array[BaseEffect] = []
) -> void:
	# Defensive reset so a previous interactive effect cannot leak state into the next one.
	_reset_effect_interaction()
	_pending_effect_kind = kind
	_pending_effect_player_index = player_index
	_pending_effect_card = card
	_pending_effect_slot = slot
	_pending_effect_ability_index = ability_index
	_pending_effect_attack_data = attack_data.duplicate(true)
	_pending_effect_attack_effects = attack_effects.duplicate()
	_pending_effect_steps = steps
	_pending_effect_step_index = 0
	_pending_effect_context = {}
	_runtime_log(
		"start_effect_interaction",
		"kind=%s player=%d card=%s steps=%d" % [
			kind,
			player_index,
			_card_instance_label(card),
			steps.size()
		]
	)
	_show_next_effect_interaction_step()


func _effect_step_uses_field_slot_ui(step: Dictionary) -> bool:
	if str(step.get("ui_mode", "")) == "card_assignment":
		return false
	var items: Array = step.get("items", [])
	if items.is_empty():
		return false
	for item: Variant in items:
		if not (item is PokemonSlot):
			return false
	return true


func _effect_step_uses_field_assignment_ui(step: Dictionary) -> bool:
	if str(step.get("ui_mode", "")) != "card_assignment":
		return false
	var target_items: Array = step.get("target_items", [])
	if target_items.is_empty():
		return false
	for item: Variant in target_items:
		if not (item is PokemonSlot):
			return false
	return true


func _resolve_effect_step_chooser_player(step: Dictionary) -> int:
	if step.has("chooser_player_index"):
		var chooser_index: int = int(step.get("chooser_player_index", -1))
		if chooser_index >= 0:
			return chooser_index
	if bool(step.get("opponent_chooses", false)) and _pending_effect_player_index >= 0:
		return 1 - _pending_effect_player_index
	return _pending_effect_player_index


func _show_next_effect_interaction_step() -> void:
	if _pending_effect_card == null:
		_runtime_log("effect_step_skipped", "pending card missing")
		return

	if _pending_effect_step_index >= _pending_effect_steps.size():
		var success := false
		var resolved_player_index: int = _pending_effect_player_index
		var followup_evolve_slot: PokemonSlot = null
		match _pending_effect_kind:
			"trainer":
				success = _gsm.play_trainer(
					_pending_effect_player_index,
					_pending_effect_card,
					[_pending_effect_context]
				)
				if success:
					followup_evolve_slot = _get_trainer_followup_evolve_slot()
			"play_stadium":
				success = _gsm.play_stadium(
					_pending_effect_player_index,
					_pending_effect_card,
					[_pending_effect_context]
				)
			"ability":
				success = _gsm.use_ability(
					_pending_effect_player_index,
					_pending_effect_slot,
					_pending_effect_ability_index,
					[_pending_effect_context]
				)
			"stadium":
				success = _gsm.use_stadium_effect(
					_pending_effect_player_index,
					[_pending_effect_context]
				)
			"attack":
				success = _gsm.use_attack(
					_pending_effect_player_index,
					_pending_effect_ability_index,
					[_pending_effect_context]
				)
			"granted_attack":
				success = _gsm.use_granted_attack(
					_pending_effect_player_index,
					_pending_effect_slot,
					_pending_effect_attack_data,
					[_pending_effect_context]
				)
		if not success and _pending_effect_card != null:
			_log("无法使用 %s" % _pending_effect_card.card_data.name)
		_runtime_log("effect_interaction_complete", "success=%s %s" % [str(success), _state_snapshot()])
		_reset_effect_interaction()
		_refresh_ui()
		if success:
			if followup_evolve_slot != null:
				_try_start_evolve_trigger_ability_interaction(resolved_player_index, followup_evolve_slot)
				if _pending_choice == "effect_interaction":
					return
			_check_two_player_handover()
		return

	var step: Dictionary = _pending_effect_steps[_pending_effect_step_index]
	var chooser_player: int = _resolve_effect_step_chooser_player(step)
	if (
		GameManager.current_mode == GameManager.GameMode.TWO_PLAYER
		and chooser_player >= 0
		and chooser_player != _view_player
	):
		_pending_choice = "effect_interaction"
		_show_handover_prompt(chooser_player, func() -> void:
			_set_handover_panel_visible(false, "effect_step_handover_%d" % _pending_effect_step_index)
			_view_player = chooser_player
			_refresh_ui()
			_show_next_effect_interaction_step()
		)
		return
	if _effect_step_uses_field_assignment_ui(step):
		_pending_choice = "effect_interaction"
		_runtime_log(
			"effect_step",
			"step=%d/%d title=%s options=%d mode=field_assignment" % [
				_pending_effect_step_index + 1,
				_pending_effect_steps.size(),
				str(step.get("title", "请选择")),
				int(step.get("source_items", []).size())
			]
		)
		_show_field_assignment_interaction(step)
		return
	if _effect_step_uses_field_slot_ui(step):
		_pending_choice = "effect_interaction"
		_runtime_log(
			"effect_step",
			"step=%d/%d title=%s options=%d mode=field_slots" % [
				_pending_effect_step_index + 1,
				_pending_effect_steps.size(),
				str(step.get("title", "请选择")),
				int(step.get("items", []).size())
			]
		)
		_show_field_slot_choice(str(step.get("title", "请选择")), step.get("items", []), step)
		return
	if str(step.get("ui_mode", "")) == "card_assignment":
		_pending_choice = "effect_interaction"
		_runtime_log(
			"effect_step",
			"step=%d/%d title=%s options=%d mode=assignment" % [
				_pending_effect_step_index + 1,
				_pending_effect_steps.size(),
				str(step.get("title", "请选择")),
				int(step.get("source_items", []).size())
			]
		)
		_show_dialog(str(step.get("title", "请选择")), [], step)
		return

	var labels_raw: Array = step.get("labels", [])
	var labels: Array[String] = []
	for label: Variant in labels_raw:
		labels.append(str(label))
	var items_raw: Array = step.get("items", [])
	var use_card_presentation := true
	for item: Variant in items_raw:
		if not _dialog_item_has_card_visual(item):
			use_card_presentation = false
			break

	_pending_choice = "effect_interaction"
	_runtime_log(
		"effect_step",
		"step=%d/%d title=%s options=%d" % [
			_pending_effect_step_index + 1,
			_pending_effect_steps.size(),
			str(step.get("title", "请选择")),
			items_raw.size()
		]
	)
	_show_dialog(step.get("title", "请选择"), labels, {
		"min_select": int(step.get("min_select", 1)),
		"max_select": int(step.get("max_select", 1)),
		"allow_cancel": step.get("allow_cancel", true),
		"presentation": "cards" if use_card_presentation else "list",
		"card_items": items_raw,
		"choice_labels": labels,
	})


func _handle_effect_interaction_choice(selected_indices: PackedInt32Array) -> void:
	if _pending_effect_card == null or _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
		_runtime_log("effect_choice_ignored", "invalid pending state")
		_reset_effect_interaction()
		return

	var step: Dictionary = _pending_effect_steps[_pending_effect_step_index]
	var items_raw: Array = step.get("items", [])
	var selected_items: Array = []
	for selected_idx: int in selected_indices:
		if selected_idx >= 0 and selected_idx < items_raw.size():
			selected_items.append(items_raw[selected_idx])

	_pending_effect_context[step.get("id", "step_%d" % _pending_effect_step_index)] = selected_items
	_runtime_log(
		"effect_choice",
		"step=%s selected=%s" % [str(step.get("id", "step_%d" % _pending_effect_step_index)), JSON.stringify(selected_indices)]
	)
	_pending_effect_step_index += 1
	_inject_followup_steps()
	_show_next_effect_interaction_step()


## 在每个交互步骤完成后，检查所有招式效果是否有后续动态步骤需要追加。
## 典型场景：巨龙无双选择招式后，被复制招式可能需要额外交互（如伤害指示物分配）。
func _inject_followup_steps() -> void:
	if _pending_effect_kind != "attack" or _pending_effect_card == null:
		return
	if _pending_effect_attack_effects.is_empty():
		return
	var card: CardInstance = _pending_effect_card
	var attack_index: int = _pending_effect_ability_index
	if card.card_data == null or attack_index < 0 or attack_index >= card.card_data.attacks.size():
		return
	var attack: Dictionary = card.card_data.attacks[attack_index]
	var followup_steps: Array[Dictionary] = []
	for effect: BaseEffect in _pending_effect_attack_effects:
		followup_steps.append_array(
			effect.get_followup_attack_interaction_steps(card, attack, _gsm.game_state, _pending_effect_context)
		)
	if followup_steps.is_empty():
		return
	var existing_step_ids: Dictionary = {}
	for i: int in range(_pending_effect_step_index, _pending_effect_steps.size()):
		var existing_id: String = str(_pending_effect_steps[i].get("id", ""))
		if existing_id != "":
			existing_step_ids[existing_id] = true
	var unique_followup_steps: Array[Dictionary] = []
	for step: Dictionary in followup_steps:
		var step_id: String = str(step.get("id", ""))
		if step_id != "" and (_pending_effect_context.has(step_id) or existing_step_ids.has(step_id)):
			continue
		unique_followup_steps.append(step)
		if step_id != "":
			existing_step_ids[step_id] = true
	if unique_followup_steps.is_empty():
		return
	# 将后续步骤插入到当前位置之后
	var insert_pos: int = _pending_effect_step_index
	for i: int in unique_followup_steps.size():
		_pending_effect_steps.insert(insert_pos + i, unique_followup_steps[i])
	_runtime_log(
		"followup_steps_injected",
		"count=%d total_steps=%d" % [unique_followup_steps.size(), _pending_effect_steps.size()]
	)


func _reset_effect_interaction() -> void:
	_runtime_log("reset_effect_interaction", _effect_state_snapshot())
	var clearing_effect_dialog: bool = _pending_choice == "effect_interaction"
	var clearing_field_interaction: bool = _is_field_interaction_active()
	_pending_effect_kind = ""
	_pending_effect_player_index = -1
	_pending_effect_card = null
	_pending_effect_slot = null
	_pending_effect_ability_index = -1
	_pending_effect_attack_data.clear()
	_pending_effect_attack_effects.clear()
	_pending_effect_steps.clear()
	_pending_effect_step_index = -1
	_pending_effect_context.clear()
	if clearing_field_interaction:
		_hide_field_interaction()
	if clearing_effect_dialog:
		_pending_choice = ""
		_dialog_data.clear()
		_dialog_items_data.clear()
		_dialog_multi_selected_indices.clear()
		_dialog_card_selected_indices.clear()
		_reset_dialog_assignment_state()
		if _dialog_overlay != null:
			_dialog_overlay.visible = false


func _set_handover_panel_visible(is_visible: bool, reason: String) -> void:
	if _handover_panel == null:
		return
	if _handover_panel.visible == is_visible:
		_runtime_log(
			"handover_visibility_noop",
			"visible=%s reason=%s %s" % [str(is_visible), reason, _state_snapshot()]
		)
		return
	_handover_panel.visible = is_visible
	_runtime_log(
		"handover_visibility",
		"visible=%s reason=%s %s" % [str(is_visible), reason, _state_snapshot()]
	)


func _set_pending_handover_action(action: Callable, reason: String) -> void:
	var was_valid: bool = _pending_handover_action.is_valid()
	var is_valid: bool = action.is_valid()
	_pending_handover_action = action
	_runtime_log(
		"handover_action",
		"reason=%s valid=%s was_valid=%s %s" % [reason, str(is_valid), str(was_valid), _state_snapshot()]
	)


func _get_trainer_followup_evolve_slot() -> PokemonSlot:
	if _gsm == null or _pending_effect_card == null or _pending_effect_card.card_data == null:
		return null
	var effect: BaseEffect = _gsm.effect_processor.get_effect(_pending_effect_card.card_data.effect_id)
	if not effect is EffectRareCandy:
		return null
	var target_raw: Array = _pending_effect_context.get("target_pokemon", [])
	if target_raw.is_empty():
		return null
	var candidate: Variant = target_raw[0]
	if candidate is PokemonSlot:
		return candidate as PokemonSlot
	return null


func _refresh_ui() -> void:
	if _gsm == null:
		return
	var gs: GameState = _gsm.game_state
	var cp: int = gs.current_player_index
	var vp: int = _view_player
	var op: int = 1 - vp

	var my: PlayerState = gs.players[vp]
	var opp: PlayerState = gs.players[op]

	_lbl_phase.text = "当前回合：%s | 对方手牌：%d" % [_get_selected_deck_name(cp), opp.hand.size()]
	_lbl_turn.text = "第 %d 回合 | 玩家 %d 行动" % [gs.turn_number, cp + 1]

	_opp_prizes.text = "x%d" % opp.prizes.size()
	_opp_deck.text = "%d" % opp.deck.size()
	_opp_discard.text = "%d" % opp.discard_pile.size()
	_opp_hand_lbl.text = "对方手牌：%d" % opp.hand.size()
	_opp_hand_bar.visible = false
	_opp_prize_hud_count.text = "x%d" % opp.prizes.size()
	_opp_deck_hud_value.text = "%d张" % opp.deck.size()
	_opp_discard_hud_value.text = "%d张" % opp.discard_pile.size()

	_my_prizes.text = "x%d" % my.prizes.size()
	_my_deck.text = "%d" % my.deck.size()
	_my_discard.text = "%d" % my.discard_pile.size()
	_my_prize_hud_count.text = "x%d" % my.prizes.size()
	_my_deck_hud_value.text = "%d张" % my.deck.size()
	_my_discard_hud_value.text = "%d张" % my.discard_pile.size()
	_update_side_previews(opp, my)

	_refresh_field_card_views(gs)

	var is_my_turn: bool = cp == vp and gs.phase == GameState.GamePhase.MAIN
	_btn_end_turn.disabled = not is_my_turn
	_hud_end_turn_btn.disabled = _btn_end_turn.disabled
	_refresh_stadium_area(gs, cp, is_my_turn)
	_refresh_info_hud(gs, vp, op)

	_refresh_hand()
	if _is_field_interaction_active():
		_refresh_field_interaction_status()
	_runtime_log_ui_state_if_changed()


func _get_selected_deck_name(player_index: int) -> String:
	if player_index < 0 or player_index >= GameManager.selected_deck_ids.size():
		return "未知卡组"
	var deck_id: int = GameManager.selected_deck_ids[player_index]
	var deck_data: DeckData = CardDatabase.get_deck(deck_id)
	if deck_data != null and deck_data.deck_name != "":
		return deck_data.deck_name
	return "卡组 %d" % (player_index + 1)


func _update_side_previews(opp: PlayerState, my: PlayerState) -> void:
	_update_prize_slots(
		_opp_prize_slots,
		opp.get_prize_layout(),
		_pending_choice == "take_prize" and _pending_prize_player_index == (1 - _view_player) and not _pending_prize_animating
	)
	_update_prize_slots(
		_my_prize_slots,
		my.get_prize_layout(),
		_pending_choice == "take_prize" and _pending_prize_player_index == _view_player and not _pending_prize_animating
	)
	_update_pile_preview(_opp_deck_preview, null, not opp.deck.is_empty())
	_update_pile_preview(_my_deck_preview, null, not my.deck.is_empty())
	_update_pile_preview(_opp_discard_preview, opp.discard_pile.back() if not opp.discard_pile.is_empty() else null, false)
	_update_pile_preview(_my_discard_preview, my.discard_pile.back() if not my.discard_pile.is_empty() else null, false)


func _refresh_stadium_area(gs: GameState, current_player: int, is_my_turn: bool) -> void:
	if gs.stadium_card == null:
		_stadium_lbl.visible = true
		_stadium_lbl.text = "竞技场区域"
		_btn_stadium_action.visible = false
		_btn_stadium_action.disabled = true
		return

	var stadium_name: String = gs.stadium_card.card_data.name
	var effect: BaseEffect = _gsm.effect_processor.get_effect(gs.stadium_card.card_data.effect_id)
	var is_action_stadium := effect != null and effect.can_use_as_stadium_action(gs.stadium_card, gs)
	if is_action_stadium:
		_stadium_lbl.visible = false
		_btn_stadium_action.visible = true
		_btn_stadium_action.text = "使用竞技场%s" % stadium_name
		_btn_stadium_action.disabled = not (is_my_turn and _gsm.can_use_stadium_effect(current_player))
		return

	_stadium_lbl.visible = true
	_stadium_lbl.text = "竞技场：%s" % stadium_name
	_btn_stadium_action.visible = false
	_btn_stadium_action.disabled = true


func _refresh_info_hud(gs: GameState, view_player: int, opponent_player: int) -> void:
	var my_player: PlayerState = gs.players[view_player]
	var opp_player: PlayerState = gs.players[opponent_player]
	_apply_info_metric(_enemy_vstar_value, gs.vstar_power_used[opponent_player], "敌VSTAR 待命", "敌VSTAR 已用")
	_apply_info_metric(_my_vstar_value, gs.vstar_power_used[view_player], "我VSTAR 待命", "我VSTAR 已用")
	if _enemy_lost_value != null:
		_enemy_lost_value.text = "敌放逐 %02d张" % opp_player.lost_zone.size()
	if _my_lost_value != null:
		_my_lost_value.text = "我放逐 %02d张" % my_player.lost_zone.size()


func _apply_info_metric(label: Label, is_used: bool, ready_text: String, used_text: String) -> void:
	if label == null:
		return
	label.text = used_text if is_used else ready_text
	label.add_theme_color_override(
		"font_color",
		Color(0.98, 0.43, 0.43) if is_used else Color(0.41, 1.0, 0.75)
	)


func _update_prize_slots(slots: Array[BattleCardView], prize_layout: Array, is_selectable: bool) -> void:
	for i: int in slots.size():
		var prize_view: BattleCardView = slots[i]
		if prize_view == null:
			continue
		var prize_card: CardInstance = null
		if i < prize_layout.size() and prize_layout[i] is CardInstance:
			prize_card = prize_layout[i] as CardInstance
		var filled := prize_card != null
		prize_view.visible = true
		if filled:
			prize_view.setup_from_instance(prize_card, BATTLE_CARD_VIEW.MODE_PREVIEW)
			prize_view.set_face_down(true)
		else:
			prize_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
			prize_view.set_face_down(true)
		prize_view.set_selected(filled and is_selectable)
		prize_view.set_disabled(not filled or (_pending_choice == "take_prize" and not is_selectable))
		prize_view.self_modulate = Color(1, 1, 1, 1) if filled else Color(1, 1, 1, 0.02)

func _update_pile_preview(preview: BattleCardView, card: CardInstance, face_down: bool) -> void:
	if preview == null:
		return
	if card != null:
		preview.setup_from_instance(card, BATTLE_CARD_VIEW.MODE_PREVIEW)
		preview.set_face_down(false)
	else:
		preview.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
		preview.set_face_down(face_down)
	preview.set_selected(false)
	preview.set_disabled(false)
	preview.set_badges("", "")
	preview.set_info("", "")


func _refresh_field_card_views(gs: GameState) -> void:
	var vp: int = _view_player
	var op: int = 1 - vp

	_refresh_slot_card_view("my_active", gs.players[vp].active_pokemon, true)
	_refresh_slot_card_view("opp_active", gs.players[op].active_pokemon, true)

	for i: int in BENCH_SIZE:
		var my_bench_slot: PokemonSlot = gs.players[vp].bench[i] if i < gs.players[vp].bench.size() else null
		var opp_bench_slot: PokemonSlot = gs.players[op].bench[i] if i < gs.players[op].bench.size() else null
		_refresh_slot_card_view("my_bench_%d" % i, my_bench_slot, false)
		_refresh_slot_card_view("opp_bench_%d" % i, opp_bench_slot, false)


func _refresh_slot_card_view(slot_id: String, slot: PokemonSlot, is_active: bool) -> void:
	var card_view = _slot_card_views.get(slot_id)
	if card_view == null:
		return
	var slot_panel := card_view.get_parent() as PanelContainer
	var is_selectable := _field_interaction_slot_index_by_id.has(slot_id)
	var selected_slot_ids: Array[String] = _field_interaction_selected_slot_ids()
	var is_selected := slot_id in selected_slot_ids
	var should_disable := _is_field_interaction_active() and not is_selectable

	if slot == null or slot.pokemon_stack.is_empty():
		card_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_SLOT_ACTIVE if is_active else BATTLE_CARD_VIEW.MODE_SLOT_BENCH)
		card_view.set_badges()
		card_view.clear_battle_status()
		card_view.set_info("", "")
		card_view.set_tilt_degrees(0.0)
		card_view.set_disabled(false)
		card_view.set_selected(false)
		_apply_field_slot_style(slot_panel, slot_id, false, is_active)
		return

	var top_card: CardInstance = slot.get_top_card()
	card_view.setup_from_instance(top_card, BATTLE_CARD_VIEW.MODE_SLOT_ACTIVE if is_active else BATTLE_CARD_VIEW.MODE_SLOT_BENCH)
	card_view.set_disabled(should_disable)
	card_view.set_selected(is_selected or is_selectable)
	card_view.set_badges()
	card_view.set_battle_status(_build_battle_status(slot))
	card_view.set_tilt_degrees(USED_ABILITY_TILT_DEGREES if _slot_used_ability_this_turn(slot) else 0.0)
	_apply_field_slot_style(slot_panel, slot_id, true, is_active)

func _apply_field_slot_style(panel: PanelContainer, slot_id: String, occupied: bool, is_active: bool) -> void:
	if panel == null:
		return
	var is_player_slot := slot_id.begins_with("my_")
	var is_selectable := _field_interaction_slot_index_by_id.has(slot_id)
	var is_selected := slot_id in _field_interaction_selected_slot_ids()
	var border_color := Color(0.52, 0.72, 0.58) if is_player_slot else Color(0.63, 0.68, 0.79)
	if not is_active:
		border_color = Color(0.32, 0.5, 0.44) if is_player_slot else Color(0.33, 0.39, 0.5)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(18 if is_active else 16)
	style.set_border_width_all(2)
	if occupied:
		if is_selected:
			style.bg_color = Color(0.95, 0.75, 0.14, 0.12)
			style.border_color = Color(0.98, 0.82, 0.22, 0.98)
			style.set_border_width_all(3)
		elif is_selectable:
			style.bg_color = Color(0.14, 0.72, 0.84, 0.10)
			style.border_color = Color(0.38, 0.88, 0.98, 0.94)
		else:
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0, 0, 0, 0)
	else:
		style.bg_color = Color(0.04, 0.07, 0.1, 0.18)
		style.border_color = Color(border_color.r, border_color.g, border_color.b, 0.65)
	panel.add_theme_stylebox_override("panel", style)

func _slot_overlay_text(slot: PokemonSlot) -> String:
	var parts: Array[String] = []
	parts.append("%d/%d" % [_get_display_remaining_hp(slot), _get_display_max_hp(slot)])
	var energy_summary := _slot_energy_summary(slot)
	if energy_summary != "":
		parts.append(energy_summary)
	if slot.attached_tool != null:
		parts.append(slot.attached_tool.card_data.name)
	return " | ".join(parts)


func _build_battle_status(slot: PokemonSlot) -> Dictionary:
	var hp_current := _get_display_remaining_hp(slot)
	var hp_max := maxi(_get_display_max_hp(slot), 1)
	return {
		"hp_current": hp_current,
		"hp_max": hp_max,
		"hp_ratio": float(hp_current) / float(hp_max),
		"energy_icons": _slot_energy_icon_codes(slot),
		"tool_name": slot.attached_tool.card_data.name if slot.attached_tool != null else "",
		"ability_used_this_turn": _slot_used_ability_this_turn(slot),
	}


func _slot_used_ability_this_turn(slot: PokemonSlot) -> bool:
	if slot == null or _gsm == null or _gsm.game_state == null:
		return false
	var current_turn: int = _gsm.game_state.turn_number
	for effect_data: Dictionary in slot.effects:
		if int(effect_data.get("turn", -999)) != current_turn:
			continue
		var effect_type: String = str(effect_data.get("type", ""))
		if effect_type.contains("ability"):
			return true
	return false


func _get_display_max_hp(slot: PokemonSlot) -> int:
	if _gsm != null and _gsm.effect_processor != null and _gsm.game_state != null:
		return _gsm.effect_processor.get_effective_max_hp(slot, _gsm.game_state)
	return slot.get_max_hp()


func _get_display_remaining_hp(slot: PokemonSlot) -> int:
	if _gsm != null and _gsm.effect_processor != null and _gsm.game_state != null:
		return _gsm.effect_processor.get_effective_remaining_hp(slot, _gsm.game_state)
	return slot.get_remaining_hp()


func _battle_card_mode_for_slot(slot: PokemonSlot) -> String:
	if _gsm == null or _gsm.game_state == null:
		return BATTLE_CARD_VIEW.MODE_SLOT_BENCH
	for player: PlayerState in _gsm.game_state.players:
		if player.active_pokemon == slot:
			return BATTLE_CARD_VIEW.MODE_SLOT_ACTIVE
	return BATTLE_CARD_VIEW.MODE_SLOT_BENCH


func _slot_energy_icon_codes(slot: PokemonSlot) -> Array[String]:
	var codes: Array[String] = []
	for energy: CardInstance in slot.attached_energy:
		var energy_type := "C"
		var provided_count := 1
		if energy != null and energy.card_data != null:
			if _gsm != null and _gsm.effect_processor != null:
				energy_type = _gsm.effect_processor.get_energy_type(energy)
				provided_count = _gsm.effect_processor.get_energy_colorless_count(energy)
			else:
				energy_type = energy.card_data.energy_provides if energy.card_data.energy_provides != "" else energy.card_data.energy_type
		if energy_type == "":
			energy_type = "C"
		for _unit: int in maxi(provided_count, 1):
			codes.append(energy_type)
	return codes


func _slot_energy_summary(slot: PokemonSlot) -> String:
	if slot.attached_energy.is_empty():
		return ""

	var emap := {
		"R": "火",
		"W": "水",
		"G": "草",
		"L": "雷",
		"P": "超",
		"F": "斗",
		"D": "恶",
		"M": "钢",
		"N": "龙",
		"C": "无",
	}
	var counts: Dictionary = {}
	for energy: CardInstance in slot.attached_energy:
		var energy_type := "C"
		var provided_count := 1
		if energy != null and energy.card_data != null:
			if _gsm != null and _gsm.effect_processor != null:
				energy_type = _gsm.effect_processor.get_energy_type(energy)
				provided_count = _gsm.effect_processor.get_energy_colorless_count(energy)
			else:
				energy_type = energy.card_data.energy_provides if energy.card_data.energy_provides != "" else energy.card_data.energy_type
			if energy_type == "":
				energy_type = "C"
		counts[energy_type] = int(counts.get(energy_type, 0)) + provided_count

	var ordered_types := ["R", "W", "G", "L", "P", "F", "D", "M", "N", "C"]
	var parts: Array[String] = []
	for energy_type: String in ordered_types:
		if counts.has(energy_type):
			parts.append("%s x%d" % [emap.get(energy_type, energy_type), counts[energy_type]])

	for key: Variant in counts.keys():
		var energy_type := str(key)
		if energy_type in ordered_types:
			continue
		parts.append("%s x%d" % [emap.get(energy_type, energy_type), counts[energy_type]])

	return " ".join(parts)


func _refresh_slot_label(lbl: RichTextLabel, slot: PokemonSlot) -> void:
	if slot == null or slot.pokemon_stack.is_empty():
		lbl.text = "[空]"
		return
	var cd := slot.get_card_data()
	var emap := {
		"R":"火",
		"W":"水",
		"G":"草",
		"L":"雷",
		"P":"超",
		"F":"斗",
		"D":"恶",
		"M":"钢",
		"N":"龙",
		"C":"无"
	}
	var energy_str := ""
	var ecounts: Dictionary = {}
	for e: CardInstance in slot.attached_energy:
		var t := "C"
		var provided_count := 1
		if _gsm != null and _gsm.effect_processor != null:
			t = _gsm.effect_processor.get_energy_type(e)
			provided_count = _gsm.effect_processor.get_energy_colorless_count(e)
		elif e.card_data.energy_provides != "":
			t = e.card_data.energy_provides
		ecounts[t] = ecounts.get(t, 0) + provided_count
	var eparts: Array[String] = []
	for k: String in ecounts:
		eparts.append("%s x%d" % [emap.get(k, k), ecounts[k]])
	energy_str = ", ".join(eparts) if not eparts.is_empty() else "无"

	var status_parts: Array[String] = []
	var snames := {
		"poisoned":"中毒",
		"burned":"灼伤",
		"asleep":"睡眠",
		"paralyzed":"麻痹",
		"confused":"混乱"
	}
	for k: String in snames:
		if slot.status_conditions.get(k, false):
			status_parts.append(snames[k])

	lbl.text = "[b]%s[/b]  HP:%d/%d\n能量：%s%s" % [
		cd.name,
		slot.get_remaining_hp(),
		slot.get_max_hp(),
		energy_str,
		("  [" + ", ".join(status_parts) + "]") if not status_parts.is_empty() else ""
	]


func _refresh_bench(container: HBoxContainer, bench: Array[PokemonSlot]) -> void:
	var children := container.get_children()
	for i: int in children.size():
		var slot_panel: Node = children[i]
		var lbl: RichTextLabel = null
		for sub: Node in slot_panel.get_children():
			if sub is RichTextLabel:
				lbl = sub as RichTextLabel
				break
		if lbl == null:
			continue
		if i < bench.size():
			var s: PokemonSlot = bench[i]
			lbl.text = "[b]%s[/b]\nHP:%d/%d" % [s.get_pokemon_name(), s.get_remaining_hp(), s.get_max_hp()]
		else:
			lbl.text = "[空]"


func _refresh_hand() -> void:
	if _gsm == null:
		return
	_clear_container_children(_hand_container)

	var gs: GameState = _gsm.game_state
	var cp: int = gs.current_player_index

	if gs.phase == GameState.GamePhase.SETUP:
		var setup_hand: Array[CardInstance] = gs.players[_view_player].hand
		for inst: CardInstance in setup_hand:
			_hand_container.add_child(_build_hand_card(inst))
		return

	if cp != _view_player:
		var lbl := Label.new()
		lbl.text = "等待对方操作..."
		_hand_container.add_child(lbl)
		return

	var hand: Array[CardInstance] = gs.players[_view_player].hand
	for inst: CardInstance in hand:
		_hand_container.add_child(_build_hand_card(inst))


func _clear_container_children(container: Node) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_hand_card(inst: CardInstance) -> PanelContainer:
	var card_view = BATTLE_CARD_VIEW.new()
	card_view.custom_minimum_size = _play_card_size
	card_view.setup_from_instance(inst, BATTLE_CARD_VIEW.MODE_HAND)
	card_view.set_selected(_selected_hand_card == inst)
	card_view.set_info(inst.card_data.name, _hand_card_subtext(inst.card_data))
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		_on_hand_card_clicked(inst, card_view)
	)
	card_view.right_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		_show_card_detail(inst.card_data)
	)
	return card_view


func _hand_card_subtext(cd: CardData) -> String:
	var emap := {
		"R":"火",
		"W":"水",
		"G":"草",
		"L":"雷",
		"P":"超",
		"F":"斗",
		"D":"恶",
		"M":"钢",
		"N":"龙",
		"C":"无"
	}
	match cd.card_type:
		"Pokemon":
			return "%s / %s / HP%d" % [cd.stage, emap.get(cd.energy_type, "?"), cd.hp]
		"Item":
			return "物品"
		"Supporter":
			return "支援者"
		"Tool":
			return "宝可梦道具"
		"Stadium":
			return "竞技场"
		"Basic Energy":
			return "基本能量 / %s" % emap.get(cd.energy_provides, "")
		"Special Energy":
			return "特殊能量"
		_:
			return cd.card_type


func _slot_from_id(slot_id: String, gs: GameState) -> PokemonSlot:
	var vp: int = _view_player
	var op: int = 1 - vp
	if slot_id == "my_active":
		return gs.players[vp].active_pokemon
	if slot_id == "opp_active":
		return gs.players[op].active_pokemon
	if slot_id.begins_with("my_bench_"):
		var my_idx: int = int(slot_id.split("_")[-1])
		var my_bench: Array[PokemonSlot] = gs.players[vp].bench
		return my_bench[my_idx] if my_idx < my_bench.size() else null
	if slot_id.begins_with("opp_bench_"):
		var opp_idx: int = int(slot_id.split("_")[-1])
		var opp_bench: Array[PokemonSlot] = gs.players[op].bench
		return opp_bench[opp_idx] if opp_idx < opp_bench.size() else null
	return null


func _log(msg: String) -> void:
	_log_list.add_item(msg)
	_log_list.ensure_current_is_visible()
	while _log_list.item_count > 200:
		_log_list.remove_item(0)
	_runtime_log("ui_log", msg)


func _on_coin_flipped(result: bool) -> void:
	var text: String = "正面" if result else "反面"
	_runtime_log("coin_flipped", text)
	_coin_flip_queue.append(result)
	if not _coin_animating:
		_play_next_coin_animation()


func _play_next_coin_animation() -> void:
	if _coin_flip_queue.is_empty():
		_coin_animating = false
		return
	_coin_animating = true
	var result: bool = _coin_flip_queue.pop_front()
	_coin_animator.play(result)


func _on_coin_animation_finished() -> void:
	_play_next_coin_animation()


func _show_discard_pile(player_index: int, title: String) -> void:
	if _gsm == null:
		return
	var player: PlayerState = _gsm.game_state.players[player_index]
	_discard_title.text = "%s（%d 张）" % [title, player.discard_pile.size()]
	_discard_list.clear()
	if _discard_card_row != null:
		_clear_container_children(_discard_card_row)
		if player.discard_pile.is_empty():
			var empty_label := Label.new()
			empty_label.text = "（空）"
			_discard_card_row.add_child(empty_label)
		else:
			var i: int = player.discard_pile.size() - 1
			while i >= 0:
				var card: CardInstance = player.discard_pile[i]
				var card_view := BATTLE_CARD_VIEW.new()
				card_view.custom_minimum_size = _dialog_card_size
				card_view.set_clickable(true)
				card_view.setup_from_instance(card, BATTLE_CARD_VIEW.MODE_PREVIEW)
				card_view.set_badges("", "")
				card_view.set_info("", "")
				card_view.left_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						_show_card_detail(cd)
				)
				card_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						_show_card_detail(cd)
				)
				_discard_card_row.add_child(card_view)
				i -= 1
	else:
		if player.discard_pile.is_empty():
			_discard_list.add_item("（空）")
		else:
			var j: int = player.discard_pile.size() - 1
			while j >= 0:
				var listed_card: CardInstance = player.discard_pile[j]
				var cd: CardData = listed_card.card_data
				_discard_list.add_item("%s [%s]" % [cd.name, _card_type_cn(cd)])
				j -= 1
	_discard_overlay.visible = true
	_runtime_log("show_discard", "player=%d title=%s count=%d" % [player_index, title, player.discard_pile.size()])


func _show_prize_cards(player_index: int, title: String) -> void:
	if _gsm == null:
		return
	var player: PlayerState = _gsm.game_state.players[player_index]
	_discard_title.text = "%s（%d 张）" % [title, player.prizes.size()]
	_discard_list.clear()
	if _discard_card_row != null:
		_clear_container_children(_discard_card_row)
		if player.prizes.is_empty():
			var empty_label := Label.new()
			empty_label.text = "（空）"
			_discard_card_row.add_child(empty_label)
		else:
			for prize: CardInstance in player.prizes:
				var card_view := BATTLE_CARD_VIEW.new()
				card_view.custom_minimum_size = _dialog_card_size
				card_view.set_clickable(true)
				card_view.setup_from_instance(prize, BATTLE_CARD_VIEW.MODE_PREVIEW)
				card_view.set_badges("", "")
				card_view.set_info("", "")
				card_view.left_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						_show_card_detail(cd)
				)
				card_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						_show_card_detail(cd)
				)
				_discard_card_row.add_child(card_view)
	else:
		if player.prizes.is_empty():
			_discard_list.add_item("（空）")
		else:
			for prize: CardInstance in player.prizes:
				var cd: CardData = prize.card_data
				_discard_list.add_item("%s [%s]" % [cd.name, _card_type_cn(cd)])
	_discard_overlay.visible = true
	_runtime_log("show_prizes", "player=%d title=%s count=%d" % [player_index, title, player.prizes.size()])


func _show_deck_cards(player_index: int, title: String) -> void:
	if _gsm == null:
		return
	var player: PlayerState = _gsm.game_state.players[player_index]
	_discard_title.text = "%s（%d 张）" % [title, player.deck.size()]
	_discard_list.clear()
	if _discard_card_row != null:
		_clear_container_children(_discard_card_row)
		if player.deck.is_empty():
			var empty_label := Label.new()
			empty_label.text = "（空）"
			_discard_card_row.add_child(empty_label)
		else:
			for deck_card: CardInstance in player.deck:
				var card_view := BATTLE_CARD_VIEW.new()
				card_view.custom_minimum_size = _dialog_card_size
				card_view.set_clickable(true)
				card_view.setup_from_instance(deck_card, BATTLE_CARD_VIEW.MODE_PREVIEW)
				card_view.set_badges("", "")
				card_view.set_info("", "")
				card_view.left_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						_show_card_detail(cd)
				)
				card_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						_show_card_detail(cd)
				)
				_discard_card_row.add_child(card_view)
	else:
		if player.deck.is_empty():
			_discard_list.add_item("（空）")
		else:
			for deck_card: CardInstance in player.deck:
				var cd: CardData = deck_card.card_data
				_discard_list.add_item("%s [%s]" % [cd.name, _card_type_cn(cd)])
	_discard_overlay.visible = true
	_runtime_log("show_deck", "player=%d title=%s count=%d" % [player_index, title, player.deck.size()])


func _init_battle_runtime_log() -> void:
	var logs_dir := ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(logs_dir)
	var file := FileAccess.open(BATTLE_RUNTIME_LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("BattleScene：初始化运行日志失败：%s" % BATTLE_RUNTIME_LOG_PATH)
		return
	file.store_line("=== Battle Runtime Log %s ===" % Time.get_datetime_string_from_system())
	file.close()
	_runtime_log("session_start", "scene=%s mode=%s" % [name, str(GameManager.current_mode)])


func _runtime_log(event: String, detail: String = "") -> void:
	var timestamp := Time.get_datetime_string_from_system()
	var line := "[%s] %s" % [timestamp, event]
	if detail != "":
		line += " | %s" % detail
	var file := FileAccess.open(BATTLE_RUNTIME_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()


func _runtime_log_ui_state_if_changed() -> void:
	var signature := _state_snapshot()
	if signature == _last_ui_state_signature:
		return
	_last_ui_state_signature = signature
	_runtime_log("ui_state", signature)


func _state_snapshot() -> String:
	if _gsm == null:
		return "gsm=null pending=%s overlays=%s" % [_pending_choice, _overlay_snapshot()]
	var gs: GameState = _gsm.game_state
	return "phase=%d turn=%d current=%d view=%d pending=%s selected=%s hand=%d/%d overlays=%s effect=%s" % [
		gs.phase,
		gs.turn_number,
		gs.current_player_index,
		_view_player,
		_pending_choice,
		_card_instance_label(_selected_hand_card),
		gs.players[_view_player].hand.size() if _view_player < gs.players.size() else -1,
		gs.players[1 - _view_player].hand.size() if gs.players.size() > 1 else -1,
		_overlay_snapshot(),
		_effect_state_snapshot(),
	]


func _dialog_state_snapshot() -> String:
	return "dialog=%s pending=%s card_mode=%s assignment_mode=%s selected_cards=%s selected_list=%s assignments=%d allow_cancel=%s" % [
		str(_dialog_overlay.visible),
		_pending_choice,
		str(_dialog_card_mode),
		str(_dialog_assignment_mode),
		JSON.stringify(_dialog_card_selected_indices),
		JSON.stringify(_dialog_multi_selected_indices),
		_dialog_assignment_assignments.size(),
		str(_dialog_cancel.visible),
	]


func _overlay_snapshot() -> String:
	return "dialog=%s handover=%s coin=%s detail=%s discard=%s" % [
		str(_dialog_overlay.visible),
		str(_handover_panel.visible),
		str(_coin_overlay.visible),
		str(_detail_overlay.visible),
		str(_discard_overlay.visible),
	]


func _effect_state_snapshot() -> String:
	return "kind=%s player=%d step=%d/%d card=%s ctx_keys=%d" % [
		_pending_effect_kind,
		_pending_effect_player_index,
		_pending_effect_step_index,
		_pending_effect_steps.size(),
		_card_instance_label(_pending_effect_card),
		_pending_effect_context.size(),
	]


func _card_instance_label(card: CardInstance) -> String:
	if card == null:
		return "-"
	if card.card_data == null:
		return "null-data#%d" % card.instance_id
	return "%s#%d" % [card.card_data.name, card.instance_id]


func _card_type_cn(cd: CardData) -> String:
	var emap := {
		"R":"火",
		"W":"水",
		"G":"草",
		"L":"雷",
		"P":"超",
		"F":"斗",
		"D":"恶",
		"M":"钢",
		"N":"龙",
		"C":"无"
	}
	match cd.card_type:
		"Pokemon":
			return "%s宝可梦 / HP%d" % [cd.stage, cd.hp]
		"Item":
			return "物品"
		"Supporter":
			return "支援者"
		"Tool":
			return "宝可梦道具"
		"Stadium":
			return "竞技场"
		"Basic Energy":
			return "基本能量 / %s" % emap.get(cd.energy_provides, "")
		"Special Energy":
			return "特殊能量"
		_:
			return cd.card_type


func _show_card_detail(cd: CardData) -> void:
	_detail_title.text = cd.name
	if _detail_card_view != null:
		_detail_card_view.setup_from_card_data(cd, BATTLE_CARD_VIEW.MODE_PREVIEW)
		_detail_card_view.set_badges("", "")
		_detail_card_view.set_info("", "")
	var emap := {
		"R":"火",
		"W":"水",
		"G":"草",
		"L":"雷",
		"P":"超",
		"F":"斗",
		"D":"恶",
		"M":"钢",
		"N":"龙",
		"C":"无"
	}
	var lines: Array[String] = []

	if cd.is_pokemon():
		lines.append("[b]%s[/b]  %s宝可梦" % [cd.name, cd.stage])
		if cd.mechanic != "":
			lines.append("机制：%s" % cd.mechanic)
		lines.append("属性：%s  HP：%d" % [emap.get(cd.energy_type, cd.energy_type), cd.hp])
		var weak: String = "无"
		if cd.weakness_energy != "":
			weak = "%s %s" % [emap.get(cd.weakness_energy, cd.weakness_energy), cd.weakness_value]
		var resist: String = "无"
		if cd.resistance_energy != "":
			resist = "%s %s" % [emap.get(cd.resistance_energy, cd.resistance_energy), cd.resistance_value]
		lines.append("弱点：%s  抵抗：%s" % [weak, resist])
		lines.append("撤退：%d" % cd.retreat_cost)
		if cd.evolves_from != "":
			lines.append("由 %s 进化" % cd.evolves_from)
		for ab: Dictionary in cd.abilities:
			lines.append("")
			lines.append("[b]特性：%s[/b]" % ab.get("name", ""))
			var ab_text: String = ab.get("text", "")
			if ab_text != "":
				lines.append(ab_text)
		for atk: Dictionary in cd.attacks:
			lines.append("")
			var cost_str: String = atk.get("cost", "")
			var cost_display: String = ""
			for c: String in cost_str:
				cost_display += emap.get(c, c)
			var dmg: String = atk.get("damage", "")
			lines.append("[b]招式：%s[/b]  [%s]  %s" % [atk.get("name", ""), cost_display, dmg])
			var atk_text: String = atk.get("text", "")
			if atk_text != "":
				lines.append(atk_text)
	else:
		lines.append("[b]%s[/b]  %s" % [cd.name, _card_type_cn(cd)])
		if cd.description != "":
			lines.append("")
			lines.append(cd.description)

	_detail_content.text = "\n".join(lines)
	_detail_overlay.visible = true
