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
var _opp_prize_slots: Array[PanelContainer] = []
var _my_prize_slots: Array[PanelContainer] = []
var _opp_deck_preview: BattleCardView = null
var _my_deck_preview: BattleCardView = null
var _opp_discard_preview: BattleCardView = null
var _my_discard_preview: BattleCardView = null

var _player_card_back_texture: Texture2D = null
var _opponent_card_back_texture: Texture2D = null

# ===================== UI References =====================
@onready var _log_list: ItemList = %LogList

# Top status
@onready var _lbl_phase: Label = %LblPhase
@onready var _lbl_turn: Label = %LblTurn

# Top actions
@onready var _btn_end_turn: Button = %BtnEndTurn
@onready var _btn_back: Button = %BtnBack

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

# --- Stadium ---
@onready var _stadium_lbl: Label = %StadiumLbl
@onready var _btn_stadium_action: Button = %BtnStadiumAction

# --- Player field ---
@onready var _my_prizes: Label = %MyPrizesCount
@onready var _my_deck: Label = %MyDeck
@onready var _my_discard: Label = %MyDiscard
@onready var _my_prizes_box: VBoxContainer = $MainArea/LeftPanel/MyPrizesBox
@onready var _my_deck_box: VBoxContainer = $MainArea/RightPanel/MyDeckBox
@onready var _my_active: PanelContainer = %MyActive
@onready var _my_bench: HBoxContainer = %MyBench
@onready var _my_active_lbl: RichTextLabel = %MyActiveLbl

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
	_btn_stadium_action.pressed.connect(_on_stadium_action_pressed)
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
	($MainArea/CenterField/HandArea/HandVBox as VBoxContainer).add_theme_constant_override("separation", 0)
	_setup_side_previews()
	_install_field_card_views()
	_setup_detail_preview()
	_setup_dialog_gallery()
	_setup_discard_gallery()
	_setup_prize_viewer()
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
	var hand_area: PanelContainer = $MainArea/CenterField/HandArea
	var opp_hand_bar: HBoxContainer = $MainArea/CenterField/OppHandBar
	var field_area: VBoxContainer = $MainArea/CenterField/FieldArea
	var stadium_bar: PanelContainer = $MainArea/CenterField/FieldArea/StadiumBar
	var opp_field_inner: VBoxContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldInner
	var my_field_inner: VBoxContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldInner
	var opp_active_row: HBoxContainer = $MainArea/CenterField/FieldArea/OppField/OppFieldInner/OppActiveRow
	var my_active_row: HBoxContainer = $MainArea/CenterField/FieldArea/MyField/MyFieldInner/MyActiveRow
	var top_bar: HBoxContainer = $TopBar

	var side_width: float = clampf(viewport_size.x * 0.05, 72.0, 108.0)
	var right_width: float = side_width + 6.0
	var log_width: float = clampf(viewport_size.x * 0.125, 124.0, 204.0)
	left_panel.custom_minimum_size = Vector2(side_width, 0)
	right_panel.custom_minimum_size = Vector2(right_width, 0)
	log_panel.custom_minimum_size = Vector2(log_width, 0)

	top_bar.offset_bottom = clampf(viewport_size.y * 0.042, 26.0, 38.0)
	opp_hand_bar.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.032, 24.0, 34.0))
	field_area.add_theme_constant_override("separation", clampi(int(viewport_size.y * 0.004), 2, 6))
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
	var deck_preview_h: float = clampf(viewport_size.y * 0.12, 74.0, 108.0)
	var deck_preview_size := Vector2(round(deck_preview_h * CARD_ASPECT), round(deck_preview_h))
	var prize_slot_w: float = clampf((side_width - 14.0) / 2.0, 26.0, 40.0)
	var prize_slot_size := Vector2(round(prize_slot_w), round(prize_slot_w / CARD_ASPECT))

	_play_card_size = Vector2(round(play_h * CARD_ASPECT), round(play_h))
	_dialog_card_size = Vector2(round(dialog_h * CARD_ASPECT), round(dialog_h))
	_detail_card_size = Vector2(round(detail_h * CARD_ASPECT), round(detail_h))

	hand_area.custom_minimum_size = Vector2(0, _play_card_size.y + 10.0)
	stadium_bar.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.018, 16.0, 20.0))
	_hand_container.add_theme_constant_override("separation", clampi(int(_play_card_size.x * 0.08), 4, 10))
	_my_active.custom_minimum_size = _play_card_size
	_opp_active.custom_minimum_size = _play_card_size
	_my_active.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_opp_active.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_my_active.clip_contents = true
	_opp_active.clip_contents = true
	_my_bench.custom_minimum_size = Vector2(0, _play_card_size.y)
	_opp_bench.custom_minimum_size = Vector2(0, _play_card_size.y)
	for panel: PanelContainer in _my_bench.get_children():
		panel.custom_minimum_size = _play_card_size
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.clip_contents = true
	for panel: PanelContainer in _opp_bench.get_children():
		panel.custom_minimum_size = _play_card_size
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.clip_contents = true
	for slot: PanelContainer in _opp_prize_slots:
		slot.custom_minimum_size = prize_slot_size
	for slot: PanelContainer in _my_prize_slots:
		slot.custom_minimum_size = prize_slot_size
	for preview: BattleCardView in [_opp_deck_preview, _my_deck_preview, _opp_discard_preview, _my_discard_preview]:
		if preview != null:
			preview.custom_minimum_size = deck_preview_size

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
	var backdrop_res := load(BATTLE_BACKDROP_RESOURCE)
	if backdrop_res is Texture2D:
		return backdrop_res as Texture2D

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
	_style_panel($MainArea/CenterField/HandArea, Color(0.05, 0.09, 0.13, 0.88), Color(0.42, 0.58, 0.74))
	_style_panel($MainArea/CenterField/FieldArea/StadiumBar, Color(0.15, 0.2, 0.15, 0.9), Color(0.73, 0.87, 0.62), 14)
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
	for prize_slot: PanelContainer in _opp_prize_slots:
		_style_panel(prize_slot, Color(0.05, 0.09, 0.13, 0.22), Color(0.37, 0.47, 0.64), 10)
	for prize_slot: PanelContainer in _my_prize_slots:
		_style_panel(prize_slot, Color(0.05, 0.09, 0.13, 0.22), Color(0.35, 0.6, 0.5), 10)

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
	_opp_prize_slots = _build_prize_slots(_opp_prizes_box, _opponent_card_back_texture)
	_my_prize_slots = _build_prize_slots(_my_prizes_box, _player_card_back_texture)
	_opp_deck_preview = _insert_pile_preview(_opp_deck_box, 2, false, _opponent_card_back_texture)
	_opp_discard_preview = _insert_pile_preview(_opp_deck_box, 5, true)
	_my_deck_preview = _insert_pile_preview(_my_deck_box, 2, false, _player_card_back_texture)
	_my_discard_preview = _insert_pile_preview(_my_deck_box, 5, true)


func _build_prize_slots(box: VBoxContainer, back_texture: Texture2D) -> Array[PanelContainer]:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)

	var slots: Array[PanelContainer] = []
	for _i: int in 6:
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.clip_contents = true
		var art := TextureRect.new()
		art.name = "BackArt"
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.texture = back_texture
		slot.add_child(art)
		grid.add_child(slot)
		slots.append(slot)
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
		"send_out_pokemon":
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


func _on_game_over(winner_index: int, reason: String) -> void:
	_runtime_log("game_over", "winner=%d reason=%s" % [winner_index, reason])
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
	if _gsm == null:
		return
	_selected_hand_card = null
	_refresh_hand()
	_gsm.end_turn(_gsm.game_state.current_player_index)
	_check_two_player_handover()


func _on_stadium_action_pressed() -> void:
	if _gsm == null:
		return
	_try_use_stadium_with_interaction(_gsm.game_state.current_player_index)


func _on_back_pressed() -> void:
	_pending_choice = "confirm_exit"
	_show_dialog("确认退出对战？当前进度不会保存。", ["确认退出", "取消"], {})
	_dialog_cancel.visible = false


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


func _setup_prize_viewer() -> void:
	for prize_slot: PanelContainer in _opp_prize_slots:
		if prize_slot == null:
			continue
		prize_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		prize_slot.gui_input.connect(func(event: InputEvent) -> void:
			_on_prize_slot_input(event, 1 - _view_player, "对方奖赏卡")
		)
	for prize_slot: PanelContainer in _my_prize_slots:
		if prize_slot == null:
			continue
		prize_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		prize_slot.gui_input.connect(func(event: InputEvent) -> void:
			_on_prize_slot_input(event, _view_player, "己方奖赏卡")
		)


func _on_prize_slot_input(event: InputEvent, player_index: int, title: String) -> void:
	if GameManager.current_mode != GameManager.GameMode.TWO_PLAYER:
		return
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed or mbe.button_index != MOUSE_BUTTON_RIGHT:
		return
	_show_prize_cards(player_index, title)


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
		return "HP %d/%d" % [slot.get_remaining_hp(), slot.get_max_hp()]
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

	var step: Dictionary = _pending_effect_steps[_pending_effect_step_index]
	var stored_assignments: Array[Dictionary] = []
	for assignment: Dictionary in _dialog_assignment_assignments:
		stored_assignments.append(assignment.duplicate())

	_pending_effect_context[step.get("id", "step_%d" % _pending_effect_step_index)] = stored_assignments
	_runtime_log(
		"effect_assignment_choice",
		"step=%s assignments=%d" % [str(step.get("id", "step_%d" % _pending_effect_step_index)), stored_assignments.size()]
	)
	_dialog_overlay.visible = false
	_reset_dialog_assignment_state()
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
	var items: Array[String] = []
	for s: PokemonSlot in player.bench:
		items.append("%s (HP %d/%d)" % [s.get_pokemon_name(), s.get_remaining_hp(), s.get_max_hp()])
	_show_dialog("玩家 %d：选择要派出的宝可梦" % (pi + 1), items, {
		"player": pi,
		"bench": player.bench,
		"presentation": "cards",
		"card_items": player.bench,
		"choice_labels": items,
	})


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
	var items: Array[String] = []
	for slot: PokemonSlot in bench_targets:
		items.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	_show_dialog(
		"%s：选择接收 %d 个能量的备战宝可梦" % [source_name, energy_count],
		items,
		{
			"player": pi,
			"bench": bench_targets.duplicate(),
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
			"presentation": "cards",
			"card_items": bench_targets,
			"choice_labels": items,
		}
	)
	_dialog_cancel.visible = false

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
	_pending_effect_attack_effects = effects
	_start_effect_interaction("attack", player_index, steps, card, slot, attack_index)


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

	var items: Array[String] = []
	for s: PokemonSlot in player.bench:
		items.append("%s (HP %d/%d)" % [s.get_pokemon_name(), s.get_remaining_hp(), s.get_max_hp()])
	_pending_choice = "retreat_bench"
	_show_dialog("选择要换上的备战宝可梦（弃掉 %d 个能量）" % cost, items, {
		"player": cp,
		"bench": player.bench,
		"energy_discard": energy_discard,
		"presentation": "cards",
		"card_items": player.bench,
		"choice_labels": items,
		"allow_cancel": true,
	})


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
		if _gsm.play_stadium(cp, inst):
			_refresh_ui()
		else:
			_log("无法打出这张竞技场卡")
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
		_refresh_ui()
		return

	_start_effect_interaction("trainer", player_index, steps, card)


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
	attack_data: Dictionary = {}
) -> void:
	# Defensive reset so a previous interactive effect cannot leak state into the next one.
	_reset_effect_interaction()
	_pending_effect_kind = kind
	_pending_effect_player_index = player_index
	_pending_effect_card = card
	_pending_effect_slot = slot
	_pending_effect_ability_index = ability_index
	_pending_effect_attack_data = attack_data.duplicate(true)
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
	# 将后续步骤插入到当前位置之后
	var insert_pos: int = _pending_effect_step_index
	for i: int in followup_steps.size():
		_pending_effect_steps.insert(insert_pos + i, followup_steps[i])
	_runtime_log(
		"followup_steps_injected",
		"count=%d total_steps=%d" % [followup_steps.size(), _pending_effect_steps.size()]
	)


func _reset_effect_interaction() -> void:
	_runtime_log("reset_effect_interaction", _effect_state_snapshot())
	var clearing_effect_dialog: bool = _pending_choice == "effect_interaction"
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

	var phase_names := {
		GameState.GamePhase.SETUP: "准备阶段",
		GameState.GamePhase.DRAW: "抽牌阶段",
		GameState.GamePhase.MAIN: "主要阶段",
		GameState.GamePhase.ATTACK: "攻击阶段",
		GameState.GamePhase.POKEMON_CHECK: "宝可梦检查",
		GameState.GamePhase.KNOCKOUT_REPLACE: "替换昏厥宝可梦",
		GameState.GamePhase.GAME_OVER: "游戏结束",
	}
	_lbl_phase.text = phase_names.get(gs.phase, "未知阶段")
	_lbl_turn.text = "第 %d 回合 | 玩家 %d 行动" % [gs.turn_number, cp + 1]

	var my: PlayerState = gs.players[vp]
	var opp: PlayerState = gs.players[op]

	_opp_prizes.text = "x%d" % opp.prizes.size()
	_opp_deck.text = "%d" % opp.deck.size()
	_opp_discard.text = "%d" % opp.discard_pile.size()
	_opp_hand_lbl.text = "对方手牌：%d" % opp.hand.size()

	_my_prizes.text = "x%d" % my.prizes.size()
	_my_deck.text = "%d" % my.deck.size()
	_my_discard.text = "%d" % my.discard_pile.size()
	_update_side_previews(opp, my)

	_refresh_field_card_views(gs)

	if gs.stadium_card != null:
		_stadium_lbl.text = "竞技场：%s" % gs.stadium_card.card_data.name
	else:
		_stadium_lbl.text = "竞技场：无"

	_refresh_hand()

	var is_my_turn: bool = cp == vp and gs.phase == GameState.GamePhase.MAIN
	_btn_end_turn.disabled = not is_my_turn
	_btn_stadium_action.visible = gs.stadium_card != null
	_btn_stadium_action.disabled = not (is_my_turn and _gsm.can_use_stadium_effect(cp))
	_runtime_log_ui_state_if_changed()


func _update_side_previews(opp: PlayerState, my: PlayerState) -> void:
	_update_prize_slots(_opp_prize_slots, opp.prizes.size(), Color(0.56, 0.67, 0.84), Color(0.12, 0.17, 0.24))
	_update_prize_slots(_my_prize_slots, my.prizes.size(), Color(0.49, 0.79, 0.66), Color(0.11, 0.17, 0.2))
	_update_pile_preview(_opp_deck_preview, null, not opp.deck.is_empty())
	_update_pile_preview(_my_deck_preview, null, not my.deck.is_empty())
	_update_pile_preview(_opp_discard_preview, opp.discard_pile.back() if not opp.discard_pile.is_empty() else null, false)
	_update_pile_preview(_my_discard_preview, my.discard_pile.back() if not my.discard_pile.is_empty() else null, false)


func _update_prize_slots(slots: Array[PanelContainer], remaining_count: int, active_border: Color, active_bg: Color) -> void:
	for i: int in slots.size():
		var slot := slots[i]
		if slot == null:
			continue
		var art := slot.get_node_or_null("BackArt") as TextureRect
		var filled := i < remaining_count
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color = active_border if filled else Color(active_border.r, active_border.g, active_border.b, 0.24)
		style.bg_color = active_bg if filled else Color(0.05, 0.08, 0.11, 0.22)
		slot.add_theme_stylebox_override("panel", style)
		if art != null:
			art.visible = filled
			art.modulate = Color(1, 1, 1, 1) if filled else Color(1, 1, 1, 0.0)

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

	if slot == null or slot.pokemon_stack.is_empty():
		card_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_SLOT_ACTIVE if is_active else BATTLE_CARD_VIEW.MODE_SLOT_BENCH)
		card_view.set_badges()
		card_view.clear_battle_status()
		card_view.set_info("", "")
		card_view.set_disabled(false)
		_apply_field_slot_style(slot_panel, slot_id, false, is_active)
		return

	var top_card: CardInstance = slot.get_top_card()
	card_view.setup_from_instance(top_card, BATTLE_CARD_VIEW.MODE_SLOT_ACTIVE if is_active else BATTLE_CARD_VIEW.MODE_SLOT_BENCH)
	card_view.set_disabled(false)
	card_view.set_badges()
	card_view.set_battle_status(_build_battle_status(slot))
	_apply_field_slot_style(slot_panel, slot_id, true, is_active)

func _apply_field_slot_style(panel: PanelContainer, slot_id: String, occupied: bool, is_active: bool) -> void:
	if panel == null:
		return
	var is_player_slot := slot_id.begins_with("my_")
	var border_color := Color(0.52, 0.72, 0.58) if is_player_slot else Color(0.63, 0.68, 0.79)
	if not is_active:
		border_color = Color(0.32, 0.5, 0.44) if is_player_slot else Color(0.33, 0.39, 0.5)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(18 if is_active else 16)
	style.set_border_width_all(2)
	if occupied:
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(0, 0, 0, 0)
	else:
		style.bg_color = Color(0.04, 0.07, 0.1, 0.18)
		style.border_color = Color(border_color.r, border_color.g, border_color.b, 0.65)
	panel.add_theme_stylebox_override("panel", style)

func _slot_overlay_text(slot: PokemonSlot) -> String:
	var parts: Array[String] = []
	parts.append("%d/%d" % [slot.get_remaining_hp(), slot.get_max_hp()])
	var energy_summary := _slot_energy_summary(slot)
	if energy_summary != "":
		parts.append(energy_summary)
	if slot.attached_tool != null:
		parts.append(slot.attached_tool.card_data.name)
	return " | ".join(parts)


func _build_battle_status(slot: PokemonSlot) -> Dictionary:
	return {
		"hp_current": slot.get_remaining_hp(),
		"hp_max": slot.get_max_hp(),
		"hp_ratio": float(slot.get_remaining_hp()) / float(maxi(slot.get_max_hp(), 1)),
		"energy_icons": _slot_energy_icon_codes(slot),
		"tool_name": slot.attached_tool.card_data.name if slot.attached_tool != null else "",
	}


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
