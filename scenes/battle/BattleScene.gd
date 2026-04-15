## BattleScene
extends Control

# ===================== Constants =====================
const BENCH_SIZE := 5
const BATTLE_CARD_VIEW := preload("res://scenes/battle/BattleCardView.gd")
const AIOpponentScript := preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript := preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DeckStrategyGardevoirScript := preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const DeckStrategyMiraidonScript := preload("res://scripts/ai/DeckStrategyMiraidon.gd")
const AIVersionRegistryScript := preload("res://scripts/ai/AIVersionRegistry.gd")
const AIFixedDeckOrderRegistryScript := preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")
const AgentVersionStoreScript := preload("res://scripts/ai/AgentVersionStore.gd")
const BattleRecorderScript := preload("res://scripts/engine/BattleRecorder.gd")
const BattleReplaySnapshotLoaderScript := preload("res://scripts/engine/BattleReplaySnapshotLoader.gd")
const BattleReplayStateRestorerScript := preload("res://scripts/engine/BattleReplayStateRestorer.gd")
const BattleAdviceServiceScript := preload("res://scripts/engine/BattleAdviceService.gd")
const BattleReviewArtifactStoreScript := preload("res://scripts/engine/BattleReviewArtifactStore.gd")
const BattleReviewServiceScript := preload("res://scripts/engine/BattleReviewService.gd")
const BattleSceneRefsScript := preload("res://scenes/battle/BattleSceneRefs.gd")
const BattleI18nScript := preload("res://scripts/ui/battle/BattleI18n.gd")
const BattleAdviceFormatterScript := preload("res://scripts/ui/battle/BattleAdviceFormatter.gd")
const BattleAdviceControllerScript := preload("res://scripts/ui/battle/BattleAdviceController.gd")
const BattleActionControllerScript := preload("res://scripts/ui/battle/BattleActionController.gd")
const BattleAttackVfxControllerScript := preload("res://scripts/ui/battle/BattleAttackVfxController.gd")
const BattleAttackVfxRegistryScript := preload("res://scripts/ui/battle/BattleAttackVfxRegistry.gd")
const BattleDisplayControllerScript := preload("res://scripts/ui/battle/BattleDisplayController.gd")
const BattleDialogControllerScript := preload("res://scripts/ui/battle/BattleDialogController.gd")
const BattleDrawRevealControllerScript := preload("res://scripts/ui/battle/BattleDrawRevealController.gd")
const BattleEffectInteractionControllerScript := preload("res://scripts/ui/battle/BattleEffectInteractionController.gd")
const BattleInteractionControllerScript := preload("res://scripts/ui/battle/BattleInteractionController.gd")
const BattleLayoutControllerScript := preload("res://scripts/ui/battle/BattleLayoutController.gd")
const BattleOverlayControllerScript := preload("res://scripts/ui/battle/BattleOverlayController.gd")
const BattleReplayControllerScript := preload("res://scripts/ui/battle/BattleReplayController.gd")
const BattleRecordingControllerScript := preload("res://scripts/ui/battle/BattleRecordingController.gd")
const BattleRuntimeLogControllerScript := preload("res://scripts/ui/battle/BattleRuntimeLogController.gd")
const BattleReviewFormatterScript := preload("res://scripts/ui/battle/BattleReviewFormatter.gd")
const CARD_ASPECT := 0.716
const BATTLE_RUNTIME_LOG_PATH := "user://logs/battle_runtime.log"
const BATTLE_BACKDROP_RESOURCE := "res://assets/ui/background.png"
const PLAYER_CARD_BACK_RESOURCE := "res://assets/ui/card_back_player.svg"
const OPPONENT_CARD_BACK_RESOURCE := "res://assets/ui/card_back_opponent.svg"
const USED_ABILITY_TILT_DEGREES := 15.0
const CoinFlipAnimatorScript := preload("res://scenes/battle/CoinFlipAnimator.gd")
const AI_MAX_ACTIONS_PER_TURN := 20
const AI_ACTION_PAUSE_SECONDS := 2.0

# ===================== State =====================
# These scene-owned fields are intentionally accessed reflectively by extracted
# battle controllers via scene.get()/set()/call(). Godot's static analyzer can't
# follow those accesses, so suppress private-field false positives for the
# declaration blocks and restore warnings before method bodies.
@warning_ignore_start("unused_private_class_variable")
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
var _deck_shuffle_counts: Dictionary = {}
var _deck_preview_base_positions: Dictionary = {}
var _deck_shuffle_effect_serial: int = 0
var _my_deck_shuffle_tween: Variant = null
var _opp_deck_shuffle_tween: Variant = null
var _draw_reveal_overlay: Control = null
var _attack_vfx_overlay: Control = null
var _draw_reveal_queue: Array[GameAction] = []
var _draw_reveal_active: bool = false
var _draw_reveal_waiting_for_confirm: bool = false
var _draw_reveal_auto_continue_pending: bool = false
var _draw_reveal_pending_hand_refresh: bool = false
var _draw_reveal_current_action: GameAction = null
var _draw_reveal_card_views: Array[BattleCardView] = []
var _draw_reveal_resume_timer: Variant = null
var _draw_reveal_allow_hand_refresh_during_fly: bool = false
var _draw_reveal_visible_instance_ids: Array[int] = []
var _pending_prize_player_index: int = -1
var _pending_prize_remaining: int = 0
var _pending_prize_animating: bool = false
var _ai_opponent = null
var _ai_running: bool = false
var _ai_step_scheduled: bool = false
var _ai_followup_requested: bool = false
var _ai_turn_marker: String = ""
var _ai_actions_this_turn: int = 0
var _ai_action_pause_seconds: float = AI_ACTION_PAUSE_SECONDS
var _ai_action_pause_timer: Variant = null
var _latest_opponent_action_text: String = ""
var _latest_opponent_action_turn_number: int = -1
var _battle_mode: String = "live"
var _replay_match_dir: String = ""
var _replay_turn_numbers: Array[int] = []
var _replay_current_turn_index: int = -1
var _replay_entry_source: String = ""
var _replay_loaded_raw_snapshot: Dictionary = {}
var _replay_loaded_view_snapshot: Dictionary = {}
var _ai_version_registry: RefCounted = AIVersionRegistryScript.new()
var _ai_fixed_deck_order_registry: RefCounted = AIFixedDeckOrderRegistryScript.new()
var _agent_version_store: RefCounted = AgentVersionStoreScript.new()
var _deck_strategy_registry: RefCounted = DeckStrategyRegistryScript.new()

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
var _battle_recorder: RefCounted = null
var _battle_recording_started: bool = false
var _battle_recording_context_captured: bool = false
var _battle_recording_output_root: String = ""
var _battle_review_service: RefCounted = null
var _battle_review_store: RefCounted = BattleReviewArtifactStoreScript.new()
var _battle_review_match_dir: String = ""
var _battle_review_last_review: Dictionary = {}
var _battle_review_busy: bool = false
var _battle_review_progress_text: String = ""
var _battle_review_winner_index: int = -1
var _battle_review_reason: String = ""
var _battle_review_formatter: RefCounted = BattleReviewFormatterScript.new()
var _battle_advice_controller: RefCounted = BattleAdviceControllerScript.new()
var _battle_advice_service: RefCounted = null
var _battle_action_controller: RefCounted = BattleActionControllerScript.new()
var _battle_attack_vfx_controller: RefCounted = BattleAttackVfxControllerScript.new()
var _battle_attack_vfx_registry: RefCounted = BattleAttackVfxRegistryScript.new()
var _battle_display_controller: RefCounted = BattleDisplayControllerScript.new()
var _battle_dialog_controller: RefCounted = BattleDialogControllerScript.new()
var _battle_draw_reveal_controller: RefCounted = BattleDrawRevealControllerScript.new()
var _battle_effect_interaction_controller: RefCounted = BattleEffectInteractionControllerScript.new()
var _battle_interaction_controller: RefCounted = BattleInteractionControllerScript.new()
var _battle_layout_controller: RefCounted = BattleLayoutControllerScript.new()
var _battle_overlay_controller: RefCounted = BattleOverlayControllerScript.new()
var _battle_replay_snapshot_loader: RefCounted = BattleReplaySnapshotLoaderScript.new()
var _battle_replay_state_restorer: RefCounted = BattleReplayStateRestorerScript.new()
var _battle_scene_refs: RefCounted = BattleSceneRefsScript.new()
var _battle_replay_controller: RefCounted = BattleReplayControllerScript.new()
var _battle_recording_controller: RefCounted = BattleRecordingControllerScript.new()
var _battle_runtime_log_controller: RefCounted = BattleRuntimeLogControllerScript.new()
var _battle_advice_last_result: Dictionary = {}
var _battle_advice_busy: bool = false
var _battle_advice_progress_text: String = ""
var _battle_advice_initial_snapshot: Dictionary = {}
var _battle_advice_pinned: bool = false
var _battle_advice_formatter: RefCounted = BattleAdviceFormatterScript.new()
var _battle_advice_panel: PanelContainer = null
var _battle_advice_panel_title: Label = null
var _battle_advice_panel_toggle_btn: Button = null
var _battle_advice_panel_content: RichTextLabel = null
var _battle_advice_panel_collapsed: bool = false
var _review_pin_btn: Button = null
var _review_overlay_mode: String = ""

# ===================== UI References =====================
@onready var _log_list: RichTextLabel = %LogList
@onready var _log_title: Label = $MainArea/LogPanel/LogPanelVBox/LogTitle

# Top status
@onready var _lbl_phase: Label = %LblPhase
@onready var _lbl_turn: Label = %LblTurn
@onready var _top_bar: PanelContainer = $TopBar

# Top actions
@onready var _btn_end_turn: Button = %BtnEndTurn
@onready var _btn_back: Button = %BtnBack
@onready var _btn_ai_advice: Button = %BtnAiAdvice
@onready var _btn_attack_vfx_preview: Button = %BtnAttackVfxPreview
@onready var _btn_opponent_hand: Button = %BtnOpponentHand
@onready var _btn_zeus_help: Button = %BtnZeusHelp
@onready var _btn_replay_prev_turn: Button = %BtnReplayPrevTurn
@onready var _btn_replay_next_turn: Button = %BtnReplayNextTurn
@onready var _btn_replay_continue: Button = %BtnReplayContinue
@onready var _btn_replay_back_to_list: Button = %BtnReplayBackToList
@onready var _hud_end_turn_btn: Button = %HudEndTurnBtn
@onready var _opp_hand_bar: PanelContainer = $MainArea/CenterField/OppHandBar
@onready var _left_panel: VBoxContainer = $MainArea/LeftPanel
@onready var _right_panel: VBoxContainer = $MainArea/RightPanel

# --- Opponent field ---
@onready var _opp_prizes: Label = %OppPrizesCount
@onready var _opp_prizes_title: Label = $MainArea/LeftPanel/OppPrizesBox/OppPrizesLbl
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
@onready var _opp_prize_hud_title: Label = $MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox/OppHudLeftTitle
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
@onready var _my_prizes_title: Label = $MainArea/LeftPanel/MyPrizesBox/MyPrizesLbl
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
@onready var _my_prize_hud_title: Label = $MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox/MyHudLeftTitle
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

# Coin flip overlay
@onready var _coin_overlay: Panel = %CoinFlipOverlay
@onready var _coin_result_lbl: Label = %CoinResultLbl
@onready var _coin_ok_btn: Button = %CoinOkBtn

# Coin flip animation state
var _coin_animator: Node = null
var _coin_flip_queue: Array[bool] = []
var _coin_animating: bool = false
var _coin_animation_resume_effect_step: bool = false

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
@onready var _review_overlay: Panel = %ReviewOverlay
@onready var _review_title: Label = %ReviewTitle
@onready var _review_content: RichTextLabel = %ReviewContent
@onready var _review_close_btn: Button = %ReviewCloseBtn
@onready var _review_regenerate_btn: Button = %ReviewRegenerateBtn
@warning_ignore_restore("unused_private_class_variable")


# ===================== Lifecycle =====================

func _ready() -> void:
	_init_battle_runtime_log()
	_btn_end_turn.pressed.connect(_on_end_turn)
	_hud_end_turn_btn.pressed.connect(_on_end_turn)
	_btn_stadium_action.pressed.connect(_on_stadium_action_pressed)
	_btn_opponent_hand.pressed.connect(_on_opponent_hand_pressed)
	_btn_attack_vfx_preview.pressed.connect(_on_attack_vfx_preview_pressed)
	_btn_ai_advice.pressed.connect(_on_ai_advice_pressed)
	_btn_zeus_help.pressed.connect(_on_zeus_help_pressed)
	_btn_replay_prev_turn.pressed.connect(_on_replay_prev_turn_pressed)
	_btn_replay_next_turn.pressed.connect(_on_replay_next_turn_pressed)
	_btn_replay_continue.pressed.connect(_on_replay_continue_pressed)
	_btn_replay_back_to_list.pressed.connect(_on_replay_back_to_list_pressed)
	_battle_scene_refs.call(
		"bind_replay_buttons",
		_btn_replay_prev_turn,
		_btn_replay_next_turn,
		_btn_replay_continue,
		_btn_replay_back_to_list
	)
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
	_review_overlay.visible = false
	_hand_title.visible = false
	_left_panel.visible = false
	_right_panel.visible = false
	_btn_opponent_hand.visible = false
	_btn_replay_prev_turn.visible = false
	_btn_replay_next_turn.visible = false
	_btn_replay_continue.visible = false
	_btn_replay_back_to_list.visible = false
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
	_refresh_prize_titles()
	_setup_field_interaction_panel()
	_setup_battle_layout()
	_start_battle_music()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Coin flip overlay setup
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
	_review_close_btn.pressed.connect(func() -> void:
		_review_overlay.visible = false
	)
	_review_regenerate_btn.pressed.connect(_on_review_regenerate_pressed)
	_setup_battle_advice_ui()
	var stadium_sections := $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections as HBoxContainer
	if stadium_sections != null:
		stadium_sections.move_child(_stadium_center_section, 0)
		stadium_sections.move_child(_lost_zone_section, 1)
	_refresh_replay_controls()
	var replay_launch: Dictionary = GameManager.consume_battle_replay_launch()
	if not replay_launch.is_empty():
		_apply_replay_launch(replay_launch)

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

	if not _is_review_mode():
		_start_battle()


func _exit_tree() -> void:
	_stop_all_deck_shuffle_effects()
	BattleMusicManager.stop_battle_music()


func _build_game_state_machine() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.state_changed.connect(_on_state_changed)
	gsm.action_logged.connect(_on_action_logged)
	gsm.player_choice_required.connect(_on_player_choice_required)
	gsm.game_over.connect(_on_game_over)
	gsm.coin_flipper.coin_flipped.connect(_on_coin_flipped)
	return gsm


func _ensure_game_state_machine() -> void:
	if _gsm == null:
		_gsm = _build_game_state_machine()


func _start_battle() -> void:
	var deck1_data: DeckData = GameManager.resolve_selected_battle_deck(0)
	var deck2_data: DeckData = GameManager.resolve_selected_battle_deck(1)
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

	_gsm = _build_game_state_machine()
	_apply_ai_fixed_deck_order_override(deck2_data)

	_setup_done = [false, false]
	# Reset visible player before starting a new match.
	_view_player = 0
	_battle_recording_started = false
	_battle_recording_context_captured = false
	_ensure_battle_recording_started()
	_gsm.start_game(deck1_data, deck2_data, GameManager.first_player_choice)
	_capture_battle_recording_context_if_ready()
	# Setup flow continues through state change callbacks and mulligan prompts.
	# The visible player may be switched later by setup and handover logic.


func _apply_ai_fixed_deck_order_override(ai_deck: DeckData) -> void:
	if _gsm == null or GameManager.current_mode != GameManager.GameMode.VS_AI:
		return
	var selection: Dictionary = GameManager.ai_selection
	if str(selection.get("opening_mode", "default")) != "fixed_order":
		return
	if _ai_fixed_deck_order_registry == null:
		return
	var fixed_order_path := str(selection.get("fixed_deck_order_path", ""))
	var fixed_order: Array[Dictionary] = _ai_fixed_deck_order_registry.call("load_fixed_order_from_path", fixed_order_path)
	if fixed_order.is_empty():
		_runtime_log("fixed_deck_order_missing", "deck=%d path=%s" % [ai_deck.id if ai_deck != null else -1, fixed_order_path])
		return
	_gsm.call("set_deck_order_override", 1, fixed_order)
	_runtime_log("fixed_deck_order_applied", "deck=%d cards=%d" % [ai_deck.id if ai_deck != null else -1, fixed_order.size()])

func _setup_battle_layout() -> void:
	_install_battle_backdrop()
	_apply_battle_surface_styles()
	_apply_responsive_layout()


func _start_battle_music() -> void:
	BattleMusicManager.set_battle_music_volume_percent(int(GameManager.battle_bgm_volume_percent))
	BattleMusicManager.play_battle_music(GameManager.selected_battle_music_id)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var left_panel: VBoxContainer = $MainArea/LeftPanel
	var right_panel: VBoxContainer = $MainArea/RightPanel
	var log_panel: PanelContainer = $MainArea/LogPanel
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
	var measured_variant: Variant = _battle_layout_controller.call(
		"measure_card_layout",
		viewport_size,
		center_width,
		bench_spacing,
		BENCH_SIZE,
		CARD_ASPECT
	)
	var measured: Dictionary = measured_variant if measured_variant is Dictionary else {}
	_play_card_size = measured.get("play_card_size", _play_card_size)
	_dialog_card_size = measured.get("dialog_card_size", _dialog_card_size)
	_detail_card_size = measured.get("detail_card_size", _detail_card_size)
	var preview_card_size: Vector2 = measured.get("preview_card_size", Vector2(roundf(_play_card_size.x * 0.9), roundf(_play_card_size.y * 0.9)))
	var prize_slot_size: Vector2 = measured.get("prize_slot_size", preview_card_size)

	hand_area.custom_minimum_size = Vector2(0, _play_card_size.y + 10.0)
	var stadium_height: float = float(measured.get("stadium_height", roundf(clampf(viewport_size.y * 0.082, 54.0, 72.0) * (4.0 / 9.0))))
	var stadium_inner_vpad: int = int(measured.get("stadium_inner_vpad", clampi(int(stadium_height * 0.08), 1, 3)))
	var vstar_stack_gap: int = int(measured.get("vstar_stack_gap", clampi(int(stadium_height * 0.08), 1, 2)))
	var vstar_panel_vpad: int = int(measured.get("vstar_panel_vpad", clampi(int(stadium_height * 0.06), 1, 2)))
	var prize_panel_height: float = float(measured.get("prize_panel_height", roundf((preview_card_size.y * 2.0 + 24.0) * 0.95)))
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
		_battle_layout_controller.call("apply_backdrop_rect", backdrop, viewport_size, log_width)
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
		clampf(viewport_size.x * 0.62, 640.0, 1120.0), 0
	)
	if _dialog_card_scroll != null:
		_dialog_card_scroll.custom_minimum_size = Vector2(0, _dialog_card_size.y + 2.0)
	if _dialog_assignment_source_scroll != null:
		_dialog_assignment_source_scroll.custom_minimum_size = Vector2(0, _dialog_card_size.y + 2.0)
	if _dialog_assignment_target_scroll != null:
		_dialog_assignment_target_scroll.custom_minimum_size = Vector2(0, _dialog_card_size.y + 2.0)

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
	return _battle_layout_controller.call(
		"compute_play_card_height",
		viewport_size,
		center_width,
		bench_spacing,
		BENCH_SIZE,
		CARD_ASPECT
	)


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
	return _battle_layout_controller.call(
		"load_battle_backdrop_texture",
		GameManager.selected_battle_background,
		BATTLE_BACKDROP_RESOURCE
	)


func _resolve_battle_backdrop_path() -> String:
	return _battle_layout_controller.call(
		"resolve_backdrop_path",
		GameManager.selected_battle_background,
		BATTLE_BACKDROP_RESOURCE
	)


func _load_card_back_texture(resource_path: String, is_player_side: bool) -> Texture2D:
	return _battle_layout_controller.call("load_card_back_texture", resource_path, is_player_side)

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
	_style_hud_button(_btn_opponent_hand)
	_style_hud_button(_btn_attack_vfx_preview)
	_style_hud_button(_btn_ai_advice)
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
	# 操作日志 — 与手牌区统一 HUD 风格
	_style_panel($MainArea/LogPanel, Color(0.05, 0.09, 0.13, 0.88), Color(0.42, 0.58, 0.74))
	if _log_title != null:
		_log_title.add_theme_font_size_override("font_size", 16)
		_log_title.add_theme_color_override("font_color", Color(0.72, 0.88, 0.96))
		_log_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _log_list != null:
		_log_list.add_theme_font_size_override("normal_font_size", 15)
		_log_list.add_theme_color_override("default_color", Color(0.82, 0.93, 0.98))
		var log_list_bg := StyleBoxEmpty.new()
		_log_list.add_theme_stylebox_override("normal", log_list_bg)
		_log_list.add_theme_stylebox_override("focus", log_list_bg)
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
	_stop_all_deck_shuffle_effects()
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
	_deck_preview_base_positions[_view_player] = _my_deck_preview.position if _my_deck_preview != null else Vector2.ZERO
	_deck_preview_base_positions[1 - _view_player] = _opp_deck_preview.position if _opp_deck_preview != null else Vector2.ZERO


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


func _get_deck_preview_for_player(player_index: int) -> BattleCardView:
	if player_index == _view_player:
		return _my_deck_preview
	if player_index == 1 - _view_player:
		return _opp_deck_preview
	return null


func _get_deck_shuffle_tween_for_player(player_index: int) -> Variant:
	return _my_deck_shuffle_tween if player_index == _view_player else _opp_deck_shuffle_tween


func _set_deck_shuffle_tween_for_player(player_index: int, tween_value: Variant) -> void:
	if player_index == _view_player:
		_my_deck_shuffle_tween = tween_value
	elif player_index == 1 - _view_player:
		_opp_deck_shuffle_tween = tween_value


func _stop_deck_shuffle_effect(player_index: int) -> void:
	var existing: Variant = _get_deck_shuffle_tween_for_player(player_index)
	var preview := _get_deck_preview_for_player(player_index)
	if existing is Tween:
		(existing as Tween).kill()
	if preview != null:
		preview.rotation_degrees = 0.0
		preview.scale = Vector2.ONE
	_set_deck_shuffle_tween_for_player(player_index, null)


func _stop_all_deck_shuffle_effects() -> void:
	for player_index: int in [0, 1]:
		_stop_deck_shuffle_effect(player_index)


func _play_deck_shuffle_effect(player_index: int) -> void:
	var preview := _get_deck_preview_for_player(player_index)
	if preview == null:
		return
	_stop_deck_shuffle_effect(player_index)
	preview.pivot_offset = preview.size * 0.5
	_deck_preview_base_positions[player_index] = preview.position
	_deck_shuffle_effect_serial += 1
	if not is_inside_tree():
		_set_deck_shuffle_tween_for_player(player_index, {"serial": _deck_shuffle_effect_serial})
		return
	var tween := create_tween()
	_set_deck_shuffle_tween_for_player(player_index, tween)
	var rotations := [
		5.0,
		-5.0,
		4.0,
		-4.0,
		3.0,
		-3.0,
		2.0,
		-2.0,
		1.0,
		0.0,
	]
	var scales := [
		Vector2(1.02, 1.02),
		Vector2(0.99, 0.99),
		Vector2(1.02, 1.02),
		Vector2(0.99, 0.99),
		Vector2(1.015, 1.015),
		Vector2(0.995, 0.995),
		Vector2(1.01, 1.01),
		Vector2(0.998, 0.998),
		Vector2(1.005, 1.005),
		Vector2.ONE,
	]
	for step_index: int in rotations.size():
		tween.tween_property(preview, "rotation_degrees", rotations[step_index], 0.08)
		tween.parallel().tween_property(preview, "scale", scales[step_index], 0.08)
	tween.finished.connect(func() -> void:
		if is_instance_valid(preview):
			preview.rotation_degrees = 0.0
			preview.scale = Vector2.ONE
		_set_deck_shuffle_tween_for_player(player_index, null)
	)


func _refresh_deck_shuffle_detection(gs: GameState) -> void:
	if gs == null:
		return
	for player_index: int in gs.players.size():
		var player: PlayerState = gs.players[player_index]
		if player == null:
			continue
		var current_count: int = player.shuffle_count
		var previous_count: int = int(_deck_shuffle_counts.get(player_index, 0))
		if current_count > previous_count:
			_play_deck_shuffle_effect(player_index)
		_deck_shuffle_counts[player_index] = current_count

# ===================== Scene Callbacks =====================

func _on_state_changed(_new_phase: GameState.GamePhase) -> void:
	_capture_battle_recording_context_if_ready()
	if _new_phase == GameState.GamePhase.DRAW:
		_record_battle_state_snapshot("turn_start")
	_refresh_ui()
	_check_two_player_handover()
	_maybe_run_ai()
	_runtime_log("state_changed", _state_snapshot())


func _on_action_logged(action: GameAction) -> void:
	_capture_battle_recording_context_if_ready()
	if action.description != "":
		if action.player_index != _view_player:
			_latest_opponent_action_text = action.description
			_latest_opponent_action_turn_number = action.turn_number
		_log(action.description)
	if (
		action != null
		and action.action_type == GameAction.ActionType.DRAW_CARD
		and _gsm != null
		and _gsm.game_state != null
		and _gsm.game_state.phase != GameState.GamePhase.SETUP
		and not _is_review_mode()
		and not (action.data.get("card_instance_ids", []) as Array).is_empty()
	):
		_battle_draw_reveal_controller.call("enqueue_reveal", self, action)
	elif (
		action != null
		and action.action_type == GameAction.ActionType.DISCARD
		and not _is_review_mode()
		and str(action.data.get("source_zone", "")) == "hand"
		and not (action.data.get("card_instance_ids", []) as Array).is_empty()
	):
		_battle_draw_reveal_controller.call("enqueue_reveal", self, action)
	elif (
		action != null
		and action.action_type == GameAction.ActionType.ATTACK
		and not _is_review_mode()
	):
		_battle_attack_vfx_controller.call("play_attack_vfx", self, action)
	_record_battle_event({
		"event_type": "action_resolved",
		"action_type": action.action_type,
		"player_index": action.player_index,
		"turn_number": action.turn_number,
		"phase": _recording_phase_name(),
		"description": action.description,
		"data": action.data.duplicate(true),
	})
	_record_battle_state_snapshot("after_action_resolved", {
		"action_type": action.action_type,
		"description": action.description,
		"resolved_player_index": action.player_index,
	})


func _on_player_choice_required(choice_type: String, data: Dictionary) -> void:
	_capture_battle_recording_context_if_ready()
	_runtime_log("player_choice_required", "%s data=%s" % [choice_type, JSON.stringify(data)])
	match choice_type:
		"mulligan_extra_draw":
			var beneficiary: int = data.get("beneficiary", 0)
			var count: int = data.get("mulligan_count", 1)
			_pending_choice = "mulligan_extra_draw"
			_show_dialog(
				"对手第 %d 次重抽" % count,
				["让玩家 %d 多抽 1 张牌" % (beneficiary + 1), "暂不额外抽牌"],
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
				str(data.get("source_name", "重负球棒"))
			)
	_maybe_run_ai()


func _start_prize_selection(player_index: int, count: int) -> void:
	_battle_overlay_controller.call("start_prize_selection", self, player_index, count)


func _clear_prize_selection() -> void:
	_battle_overlay_controller.call("clear_prize_selection", self)


func _refresh_prize_titles() -> void:
	_battle_overlay_controller.call("refresh_prize_titles", self)


func _update_prize_title(label: Label, player_index: int, default_text: String, is_hud: bool) -> void:
	_battle_overlay_controller.call("update_prize_title", self, label, player_index, default_text, is_hud)


func _focus_prize_panel(player_index: int) -> void:
	_battle_overlay_controller.call("focus_prize_panel", self, player_index)


func _on_game_over(winner_index: int, reason: String) -> void:
	_runtime_log("game_over", "winner=%d reason=%s" % [winner_index, reason])
	_clear_prize_selection()
	_refresh_ui()
	_battle_review_winner_index = winner_index
	_battle_review_reason = reason
	_record_battle_state_snapshot("match_end", {
		"winner_index": winner_index,
		"reason": reason,
	})
	_record_battle_event({
		"event_type": "match_ended",
		"player_index": winner_index,
		"turn_number": _gsm.game_state.turn_number if _gsm != null and _gsm.game_state != null else 0,
		"phase": _recording_phase_name(),
		"reason": reason,
		"winner_index": winner_index,
	})
	if _battle_recorder != null and _battle_recorder.has_method("get_match_dir"):
		_battle_review_match_dir = str(_battle_recorder.call("get_match_dir"))
	_show_match_end_dialog(winner_index, reason)
	_finalize_battle_recording({
		"winner_index": winner_index,
		"reason": reason,
		"turn_number": _gsm.game_state.turn_number if _gsm != null and _gsm.game_state != null else 0,
	})


# ===================== Setup Flow (UI-driven) =====================

func _begin_setup_flow() -> void:
	_setup_done = [false, false]
	_refresh_ui()
	_maybe_run_ai()
	_setup_player_active(0)


func _setup_player_active(pi: int) -> void:
	_view_player = _preferred_live_view_player(pi)
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
	_battle_dialog_controller.call("show_setup_active_dialog", self, pi)


func _preferred_live_view_player(target_player: int) -> int:
	if GameManager.current_mode == GameManager.GameMode.VS_AI:
		return 0
	return target_player


func _after_setup_active(pi: int) -> void:
	_view_player = _preferred_live_view_player(pi)
	_refresh_ui()
	_show_setup_bench_dialog(pi)
	_maybe_run_ai()


func _show_setup_bench_dialog(pi: int) -> void:
	_battle_dialog_controller.call("show_setup_bench_dialog", self, pi)


func _after_setup_bench(pi: int) -> void:
	_setup_done[pi] = true
	_view_player = _preferred_live_view_player(pi)
	_refresh_ui()
	if pi == 0 and not _setup_done[1]:
		_setup_player_active(1)
	else:
		if _gsm.setup_complete(0):
			_view_player = _preferred_live_view_player(_gsm.game_state.current_player_index)
			_refresh_ui()
			_check_two_player_handover()
	if _ai_running and GameManager.current_mode == GameManager.GameMode.VS_AI:
		_ensure_ai_opponent()
		if _ai_opponent != null and _gsm != null and _gsm.game_state != null:
			var next_setup_owner: int = _get_ai_prompt_player_index()
			if (_pending_choice != "" and next_setup_owner == _ai_opponent.player_index) \
				or _gsm.game_state.current_player_index == _ai_opponent.player_index:
				_ai_followup_requested = true
	_maybe_run_ai()


# ===================== Field Interactions =====================

func _on_end_turn(action_player_index: int = -1) -> void:
	if not _can_accept_live_action() or _gsm == null or _is_field_interaction_active():
		return
	_selected_hand_card = null
	_refresh_hand()
	_gsm.end_turn(_gsm.game_state.current_player_index)
	_check_two_player_handover()
	if _should_pause_after_ai_action(action_player_index):
		_start_ai_action_pause()


func _on_stadium_action_pressed() -> void:
	if not _can_accept_live_action() or _gsm == null or _is_field_interaction_active():
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
	if not _can_accept_live_action() or _gsm == null or _gsm.game_state == null or _is_field_interaction_active():
		return
	if _view_player < 0 or _view_player >= _gsm.game_state.players.size():
		return
	# 输出双方卡牌总数到日志，方便验证不变量
	for pi: int in 2:
		var total: int = _gsm.count_player_total_cards(pi)
		_log("玩家%d卡牌总计: %d 张 (牌库%d 手牌%d 奖赏%d 弃牌%d 放逐%d 场上%d)" % [
			pi + 1,
			total,
			_gsm.game_state.players[pi].deck.size(),
			_gsm.game_state.players[pi].hand.size(),
			_gsm.game_state.players[pi].prizes.size(),
			_gsm.game_state.players[pi].discard_pile.size(),
			_gsm.game_state.players[pi].lost_zone.size(),
			total - _gsm.game_state.players[pi].deck.size() - _gsm.game_state.players[pi].hand.size() - _gsm.game_state.players[pi].prizes.size() - _gsm.game_state.players[pi].discard_pile.size() - _gsm.game_state.players[pi].lost_zone.size(),
		])
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


func _on_opponent_hand_pressed() -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return
	_show_opponent_hand_cards()


func _show_opponent_hand_cards() -> void:
	_battle_overlay_controller.call("show_opponent_hand_cards", self)


func _on_slot_input(event: InputEvent, slot_id: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return
	if _pending_choice == "take_prize":
		_runtime_log("slot_input_blocked", "slot=%s reason=take_prize %s" % [slot_id, _state_snapshot()])
		var prize_viewport := get_viewport()
		if prize_viewport != null:
			prize_viewport.set_input_as_handled()
		return
	if not _can_accept_live_action():
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
		# 进化、能量、道具只能操作自己的宝可梦
		if slot_id.begins_with("opp"):
			_log("不能对对方的宝可梦使用手牌")
			return
		var card := _selected_hand_card
		var cd := card.card_data
		if cd.is_pokemon() and cd.stage != "Basic":
			if _gsm.evolve_pokemon(cp, card, target_slot):
				_selected_hand_card = null
				_refresh_ui()
				_try_start_evolve_trigger_ability_interaction(cp, target_slot)
				_maybe_run_ai()
			else:
				_log("无法让这只宝可梦进化")
		elif cd.card_type == "Basic Energy" or cd.card_type == "Special Energy":
			if _gsm.attach_energy(cp, card, target_slot):
				_selected_hand_card = null
				_refresh_ui_after_successful_action(false, cp)
			else:
				_log("无法附着能量")
		elif cd.card_type == "Tool":
			if _gsm.attach_tool(cp, card, target_slot):
				_selected_hand_card = null
				_refresh_ui_after_successful_action(false, cp)
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
		_refresh_ui_after_successful_action(false, player_index)
	else:
		_log("无法将这只宝可梦放到备战区")


# ===================== Dialog State =====================

@warning_ignore_start("unused_private_class_variable")
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
@warning_ignore_restore("unused_private_class_variable")


func _setup_dialog_gallery() -> void:
	_dialog_box.custom_minimum_size = Vector2(860, 420)
	var buttons_row: Control = _dialog_confirm.get_parent()

	_dialog_card_scroll = ScrollContainer.new()
	_dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog_card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_card_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_dialog_card_scroll.custom_minimum_size = Vector2(0, _dialog_card_size.y + 2.0)
	_dialog_card_scroll.visible = false
	_dialog_vbox.add_child(_dialog_card_scroll)
	_dialog_vbox.move_child(_dialog_card_scroll, buttons_row.get_index())

	_dialog_card_row = HBoxContainer.new()
	_dialog_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_card_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_dialog_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dialog_card_row.add_theme_constant_override("separation", 10)
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
	source_title.text = "来源卡牌"
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
	target_title.text = "闂勫嫮娼冮惄顔界垼"
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
	_battle_interaction_controller.call("setup_field_interaction_panel", self)


func _ensure_field_interaction_panel() -> void:
	_battle_interaction_controller.call("ensure_field_interaction_panel", self)


func _hide_field_interaction() -> void:
	_battle_interaction_controller.call("hide_field_interaction", self)


func _update_field_interaction_panel_metrics(viewport_size: Vector2 = Vector2.ZERO) -> void:
	_battle_interaction_controller.call("update_field_interaction_panel_metrics", self, viewport_size)


func _is_field_interaction_active() -> bool:
	return _battle_interaction_controller.call("is_field_interaction_active", self)


func _field_interaction_target_owner(slot: PokemonSlot) -> int:
	return _battle_interaction_controller.call("field_interaction_target_owner", self, slot)


func _resolve_field_interaction_position(slots: Array) -> String:
	return _battle_interaction_controller.call("resolve_field_interaction_position", self, slots)


func _apply_field_interaction_position(panel_position: String) -> void:
	_battle_interaction_controller.call("apply_field_interaction_position", self, panel_position)


func _show_field_slot_choice(title: String, items: Array, data: Dictionary = {}) -> void:
	_battle_interaction_controller.call("show_field_slot_choice", self, title, items, data)


func _show_field_assignment_interaction(step: Dictionary) -> void:
	_battle_interaction_controller.call("show_field_assignment_interaction", self, step)


func _rebuild_field_slot_index_map(items: Array) -> void:
	_battle_interaction_controller.call("rebuild_field_slot_index_map", self, items)


func _build_field_assignment_source_cards() -> void:
	_battle_interaction_controller.call("build_field_assignment_source_cards", self)


func _add_field_assignment_source_card(source_items: Array, source_labels: Array, source_index: int) -> void:
	_battle_interaction_controller.call("add_field_assignment_source_card", self, source_items, source_labels, source_index)


func _on_field_assignment_source_chosen(source_index: int) -> void:
	_battle_interaction_controller.call("on_field_assignment_source_chosen", self, source_index)


func _find_field_assignment_index_for_source(source_index: int) -> int:
	return _battle_interaction_controller.call("find_field_assignment_index_for_source", self, source_index)


func _field_interaction_selected_slot_ids() -> Array[String]:
	return _battle_interaction_controller.call("field_interaction_selected_slot_ids", self)


func _refresh_field_interaction_status() -> void:
	_battle_interaction_controller.call("refresh_field_interaction_status", self)


func _refresh_field_assignment_source_views() -> void:
	_battle_interaction_controller.call("refresh_field_assignment_source_views", self)


func _on_field_interaction_clear_pressed() -> void:
	_battle_interaction_controller.call("on_field_interaction_clear_pressed", self)


func _on_field_interaction_cancel_pressed() -> void:
	_cancel_field_interaction()


func _on_field_interaction_confirm_pressed() -> void:
	if _field_interaction_mode == "slot_select":
		_finalize_field_slot_selection()
	elif _field_interaction_mode == "counter_distribution":
		_battle_interaction_controller.call("finalize_counter_distribution", self)
	else:
		_finalize_field_assignment_selection()


func _cancel_field_interaction() -> void:
	_battle_interaction_controller.call("cancel_field_interaction", self)


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
			_on_prize_slot_input(event, 1 - _view_player, "对方奖赏", slot_index)
		)
	for i: int in _my_prize_slots.size():
		var prize_slot: BattleCardView = _my_prize_slots[i]
		if prize_slot == null:
			continue
		prize_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_index := i
		prize_slot.gui_input.connect(func(event: InputEvent) -> void:
			_on_prize_slot_input(event, _view_player, "己方奖赏", slot_index)
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
		_maybe_run_ai()
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
	_battle_dialog_controller.call("show_dialog", self, title, items, extra_data)

func _dialog_should_use_card_mode(items: Array, extra_data: Dictionary) -> bool:
	return _battle_dialog_controller.call("dialog_should_use_card_mode", items, extra_data)


func _show_text_dialog(items: Array, extra_data: Dictionary) -> void:
	_battle_dialog_controller.call("show_text_dialog", self, items, extra_data)


func _show_card_dialog(items: Array, extra_data: Dictionary) -> void:
	_battle_dialog_controller.call("show_card_dialog", self, items, extra_data)


func _show_assignment_dialog(extra_data: Dictionary) -> void:
	_battle_dialog_controller.call("show_assignment_dialog", self, extra_data)


func _populate_grouped_source_items(
	source_items: Array,
	source_labels: Array,
	source_groups: Array
) -> void:
	_battle_dialog_controller.call("populate_grouped_source_items", self, source_items, source_labels, source_groups)


func _add_assignment_source_card(source_items: Array, source_labels: Array, i: int) -> void:
	_battle_dialog_controller.call("add_assignment_source_card", self, source_items, source_labels, i)


func _on_assignment_source_chosen(source_index: int) -> void:
	_battle_dialog_controller.call("on_assignment_source_chosen", self, source_index)


func _on_assignment_target_chosen(target_index: int) -> void:
	_battle_dialog_controller.call("on_assignment_target_chosen", self, target_index)


func _refresh_assignment_dialog_views() -> void:
	_battle_dialog_controller.call("refresh_assignment_dialog_views", self)


func _update_assignment_dialog_state() -> void:
	_battle_dialog_controller.call("update_assignment_dialog_state", self)


func _find_assignment_index_for_source(source_index: int) -> int:
	return _battle_dialog_controller.call("find_assignment_index_for_source", self, source_index)


func _dialog_assignment_last_target_index() -> int:
	return _battle_dialog_controller.call("dialog_assignment_last_target_index", self)


func _reset_dialog_assignment_state() -> void:
	_battle_dialog_controller.call("reset_dialog_assignment_state", self)


func _setup_dialog_card_view(card_view: BattleCardView, item: Variant, label: String) -> void:
	_battle_dialog_controller.call("setup_dialog_card_view", self, card_view, item, label)


func _dialog_choice_subtitle(item: Variant, label: String) -> String:
	return _battle_dialog_controller.call("dialog_choice_subtitle", self, item, label)


func _dialog_item_has_card_visual(item: Variant) -> bool:
	return _battle_dialog_controller.call("dialog_item_has_card_visual", item)


func _selection_label_from_item(item: Variant, fallback: String = "") -> String:
	return _battle_dialog_controller.call("selection_label_from_item", item, fallback)


func _selected_dialog_labels(sel_items: PackedInt32Array) -> Array[String]:
	return _battle_dialog_controller.call("selected_dialog_labels", self, sel_items)


func _selected_field_slot_labels(sel_items: PackedInt32Array) -> Array[String]:
	var labels: Array[String] = []
	var items: Array = _field_interaction_data.get("items", [])
	for idx: int in sel_items:
		if idx < 0 or idx >= items.size():
			continue
		labels.append(_selection_label_from_item(items[idx]))
	return labels


func _selected_assignment_labels(assignments: Array[Dictionary]) -> Array[String]:
	return _battle_dialog_controller.call("selected_assignment_labels", assignments)


func _on_dialog_card_chosen(real_index: int) -> void:
	_battle_dialog_controller.call("on_dialog_card_chosen", self, real_index)


func _on_dialog_card_left_signal(_ci: CardInstance, _cd: CardData, real_index: int) -> void:
	_on_dialog_card_chosen(real_index)


func _on_dialog_card_right_signal(_ci: CardInstance, cd: CardData) -> void:
	if cd != null:
		_show_card_detail(cd)


func _toggle_dialog_card_choice(real_index: int, max_select: int) -> bool:
	if real_index in _dialog_card_selected_indices:
		_dialog_card_selected_indices.erase(real_index)
		return true
	if max_select > 0 and _dialog_card_selected_indices.size() >= max_select:
		return false
	_dialog_card_selected_indices.append(real_index)
	return true


func _sync_dialog_card_selection() -> void:
	_battle_dialog_controller.call("sync_dialog_card_selection", self)


func _update_dialog_confirm_state() -> void:
	_battle_dialog_controller.call("update_dialog_confirm_state", self)


func _update_dialog_status_text() -> void:
	_battle_dialog_controller.call("update_dialog_status_text", self)


func _confirm_dialog_selection(sel_items: PackedInt32Array) -> void:
	_battle_dialog_controller.call("confirm_dialog_selection", self, sel_items)


func _on_dialog_item_selected(idx: int) -> void:
	_battle_dialog_controller.call("on_dialog_item_selected", self, idx)


func _on_dialog_item_multi_selected(idx: int, selected: bool) -> void:
	_battle_dialog_controller.call("on_dialog_item_multi_selected", self, idx, selected)

func _on_dialog_confirm() -> void:
	_battle_dialog_controller.call("on_dialog_confirm", self)

func _on_dialog_cancel() -> void:
	_battle_dialog_controller.call("on_dialog_cancel", self)


func _confirm_assignment_dialog() -> void:
	_battle_dialog_controller.call("confirm_assignment_dialog", self)


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
		"attack_vfx_preview":
			var preview_entries: Array = _dialog_data.get("entries", [])
			if idx >= 0 and idx < preview_entries.size():
				var entry: Variant = preview_entries[idx]
				if entry is Dictionary:
					var preview_profile: Variant = (entry as Dictionary).get("profile", null)
					if preview_profile is RefCounted:
						_battle_attack_vfx_controller.call("play_preview_vfx", self, preview_profile)
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
					_view_player = _preferred_live_view_player(_gsm.game_state.current_player_index)
					_refresh_ui()
					_check_two_player_handover()
				else:
					_log("无法让这只宝可梦进化")
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
		"retreat_energy":
			var cp_energy: int = _dialog_data.get("player", 0)
			var retreat_cost: int = int(_dialog_data.get("retreat_cost", 0))
			var energy_options_raw: Array = _dialog_data.get("energy_options", [])
			var energy_options: Array[CardInstance] = []
			for option: Variant in energy_options_raw:
				if option is CardInstance:
					energy_options.append(option)
			var chosen_energy: Array[CardInstance] = _resolve_retreat_energy_selection(selected_indices, energy_options)
			var active_slot: PokemonSlot = null
			if _gsm != null and _gsm.game_state != null and cp_energy >= 0 and cp_energy < _gsm.game_state.players.size():
				active_slot = _gsm.game_state.players[cp_energy].active_pokemon
			if active_slot == null or not _retreat_selection_is_valid(active_slot, chosen_energy, retreat_cost):
				_log("当前选择的能量不符合撤退费用")
				_show_retreat_energy_dialog(cp_energy, active_slot, retreat_cost)
				return
			if not _gsm.rule_validator.has_enough_energy_to_retreat(
				active_slot,
				chosen_energy,
				retreat_cost,
				_gsm.effect_processor,
				_gsm.game_state
			):
				_log("当前选择的能量不足以支付撤退费用")
				_show_retreat_energy_dialog(cp_energy, active_slot, retreat_cost)
				return
			_show_retreat_bench_choice(cp_energy, chosen_energy)
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
				if _gsm.retreat(cp, energy_discard, bench_rb[idx]):
					_refresh_ui_after_successful_action(false, cp)
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
			var review_action_kind: String = str(_dialog_data.get("review_action", ""))
			if review_action_kind != "":
				if idx == 1:
					match review_action_kind:
						"generate", "retry":
							_begin_battle_review_generation()
						"view":
							_open_cached_battle_review()
				elif idx == 2:
					GameManager.goto_battle_setup()
			elif idx == 1:
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
	var player: PlayerState = _gsm.game_state.players[pi]
	var available_bench: Array[PokemonSlot] = []
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and not _gsm.effect_processor.is_effectively_knocked_out(bench_slot, _gsm.game_state):
			available_bench.append(bench_slot)
	var dialog_data := {
		"player": pi,
		"bench": available_bench,
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	}
	_ensure_ai_opponent()
	var is_ai_prompt: bool = GameManager.current_mode == GameManager.GameMode.VS_AI and _ai_opponent != null and pi == _ai_opponent.player_index
	if is_ai_prompt:
		_dialog_data = dialog_data
		_dialog_items_data = available_bench.duplicate()
		_hide_field_interaction()
		if _dialog_overlay != null:
			_dialog_overlay.visible = false
		if _dialog_cancel != null:
			_dialog_cancel.visible = false
		_refresh_ui()
		_maybe_run_ai()
		return
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
	_battle_dialog_controller.call("show_send_out_dialog", self, pi)


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
	_battle_dialog_controller.call("show_heavy_baton_dialog", self, pi, bench_targets, energy_count, source_name)


func _try_handle_field_interaction_slot_click(slot_id: String, _target_slot: PokemonSlot) -> void:
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
		"counter_distribution":
			_handle_counter_distribution_target(target_index)


func _handle_field_slot_select_index(target_index: int) -> void:
	_battle_interaction_controller.call("handle_field_slot_select_index", self, target_index)


func _handle_field_assignment_target_index(target_index: int) -> void:
	_battle_interaction_controller.call("handle_field_assignment_target_index", self, target_index)


func _show_field_counter_distribution(step: Dictionary) -> void:
	_battle_interaction_controller.call("show_field_counter_distribution", self, step)


func _on_counter_distribution_amount_chosen(amount: int) -> void:
	_battle_interaction_controller.call("on_counter_distribution_amount_chosen", self, amount)


func _handle_counter_distribution_target(target_index: int) -> void:
	_battle_interaction_controller.call("handle_counter_distribution_target", self, target_index)


func _finalize_field_slot_selection() -> void:
	_battle_interaction_controller.call("finalize_field_slot_selection", self)


func _finalize_field_assignment_selection() -> void:
	_battle_interaction_controller.call("finalize_field_assignment_selection", self)


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
	_battle_dialog_controller.call("show_pokemon_action_dialog", self, cp, slot, include_attacks)


func _show_attack_dialog(cp: int, active_slot: PokemonSlot) -> void:
	_show_pokemon_action_dialog(cp, active_slot, true)


func _try_use_attack_with_interaction(
	player_index: int,
	slot: PokemonSlot,
	attack_index: int,
	preselected_targets: Array = []
) -> void:
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
	if not preselected_targets.is_empty():
		if _gsm.use_attack(player_index, attack_index, preselected_targets):
			_refresh_ui_after_successful_action(true, player_index)
		else:
			_log(_gsm.get_attack_unusable_reason(player_index, attack_index))
		return
	if steps.is_empty():
		if _gsm.use_attack(player_index, attack_index):
			_refresh_ui_after_successful_action(true, player_index)
		else:
			_log(_gsm.get_attack_unusable_reason(player_index, attack_index))
		return
	_start_effect_interaction("attack", player_index, steps, card, slot, attack_index, {}, effects)
	_maybe_run_ai()


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
			_refresh_ui_after_successful_action(true, player_index)
		else:
			_log(_get_granted_attack_unusable_reason(player_index, slot, granted_attack))
		return
	_start_effect_interaction("granted_attack", player_index, steps, card, slot, -1, granted_attack)
	_maybe_run_ai()


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
		return "当前无法执行该操作"
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return "当前无法执行该操作"
	if _gsm.game_state.current_player_index != player_index:
		return "当前不是你的回合"
	if _gsm.game_state.phase != GameState.GamePhase.MAIN:
		return "当前阶段无法使用该招式"
	if slot == null or slot.get_top_card() == null:
		return "当前无法执行该操作"
	if slot != _gsm.game_state.players[player_index].active_pokemon:
		return "只有战斗宝可梦可以使用这个招式"
	if slot.attached_tool == null:
		return "这只宝可梦没有附着工具"
	if _gsm.effect_processor.is_tool_effect_suppressed(slot, _gsm.game_state):
		return "这只宝可梦身上的道具效果当前不可用"
	var cost: String = str(granted_attack.get("cost", ""))
	if not _gsm.rule_validator.has_enough_energy(slot, cost, _gsm.effect_processor, _gsm.game_state):
		return "能量不足，无法满足这个招式的费用"
	return "能量不足，无法使用该招式"


func _try_start_evolve_trigger_ability_interaction(player_index: int, slot: PokemonSlot) -> void:
	if _gsm == null or slot == null or slot.get_top_card() == null:
		return
	var steps: Array[Dictionary] = _gsm.get_evolve_ability_interaction_steps(slot)
	if steps.is_empty():
		return
	_start_effect_interaction("ability", player_index, steps, slot.get_top_card(), slot, 0)


func _retreat_requires_energy_choice(active: PokemonSlot, retreat_cost: int) -> bool:
	if active == null or retreat_cost <= 0:
		return false
	if active.attached_energy.size() <= 1:
		return false
	return _retreat_has_valid_partial_subset(active.attached_energy, retreat_cost, 0, 0, 0)


func _retreat_has_valid_partial_subset(
	attached_energy: Array[CardInstance],
	retreat_cost: int,
	index: int,
	provided: int,
	used_count: int
) -> bool:
	if provided >= retreat_cost:
		return used_count > 0 and used_count < attached_energy.size()
	if index >= attached_energy.size():
		return false
	var next_provided := provided + _gsm.effect_processor.get_energy_colorless_count(attached_energy[index], _gsm.game_state)
	if _retreat_has_valid_partial_subset(attached_energy, retreat_cost, index + 1, next_provided, used_count + 1):
		return true
	return _retreat_has_valid_partial_subset(attached_energy, retreat_cost, index + 1, provided, used_count)


func _show_retreat_energy_dialog(cp: int, active: PokemonSlot, retreat_cost: int) -> void:
	if _gsm == null or _gsm.game_state == null or active == null:
		return
	var player: PlayerState = _gsm.game_state.players[cp]
	var energy_options: Array[CardInstance] = active.attached_energy.duplicate()
	var choice_labels: Array[String] = []
	for energy: CardInstance in energy_options:
		var label := energy.card_data.name
		var provided := _gsm.effect_processor.get_energy_colorless_count(energy, _gsm.game_state)
		if provided > 1:
			label += " (%d)" % provided
		choice_labels.append(label)
	_pending_choice = "retreat_energy"
	_show_dialog("选择要弃掉的能量", choice_labels, {
		"player": cp,
		"bench": player.bench,
		"energy_options": energy_options,
		"retreat_cost": retreat_cost,
		"allow_cancel": true,
		"min_select": 1,
		"max_select": energy_options.size(),
		"presentation": "cards",
		"card_items": energy_options,
		"choice_labels": choice_labels,
		"prompt_type": "retreat_energy",
	})


func _show_retreat_bench_choice(cp: int, energy_discard: Array[CardInstance]) -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	var player: PlayerState = _gsm.game_state.players[cp]
	_pending_choice = "retreat_bench"
	_dialog_data = {
		"player": cp,
		"bench": player.bench,
		"energy_discard": energy_discard.duplicate(),
		"allow_cancel": true,
		"min_select": 1,
		"max_select": 1,
		"prompt_type": "retreat_bench",
	}
	_show_field_slot_choice("选择接替撤退的备战宝可梦", player.bench, _dialog_data)


func _retreat_selection_is_valid(active: PokemonSlot, chosen_energy: Array[CardInstance], retreat_cost: int) -> bool:
	if active == null:
		return false
	if retreat_cost <= 0:
		return chosen_energy.is_empty()
	if chosen_energy.is_empty():
		return false
	if not _gsm.rule_validator.has_enough_energy_to_retreat(
		active,
		chosen_energy,
		retreat_cost,
		_gsm.effect_processor,
		_gsm.game_state
	):
		return false
	for remove_index: int in chosen_energy.size():
		var reduced_selection: Array[CardInstance] = chosen_energy.duplicate()
		reduced_selection.remove_at(remove_index)
		if _gsm.rule_validator.has_enough_energy_to_retreat(
			active,
			reduced_selection,
			retreat_cost,
			_gsm.effect_processor,
			_gsm.game_state
		):
			return false
	return true


func _default_retreat_energy_selection(active: PokemonSlot, retreat_cost: int) -> Array[CardInstance]:
	if active == null or retreat_cost <= 0:
		return []
	return active.attached_energy.duplicate()


func _resolve_retreat_energy_selection(selected_indices: PackedInt32Array, energy_options: Array[CardInstance]) -> Array[CardInstance]:
	var chosen_energy: Array[CardInstance] = []
	for selected_index: int in selected_indices:
		if selected_index < 0 or selected_index >= energy_options.size():
			continue
		chosen_energy.append(energy_options[selected_index])
	return chosen_energy


func _show_retreat_dialog(cp: int) -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	if cp < 0 or cp >= _gsm.game_state.players.size():
		return
	var player: PlayerState = _gsm.game_state.players[cp]
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return
	var retreat_cost: int = _gsm.effect_processor.get_effective_retreat_cost(active, _gsm.game_state)
	if _retreat_requires_energy_choice(active, retreat_cost):
		_show_retreat_energy_dialog(cp, active, retreat_cost)
		return
	_show_retreat_bench_choice(cp, _default_retreat_energy_selection(active, retreat_cost))


func _show_handover_prompt(target_player: int, follow_up: Callable = Callable()) -> void:
	_battle_overlay_controller.call("show_handover_prompt", self, target_player, follow_up)


func _check_two_player_handover() -> void:
	_battle_overlay_controller.call("check_two_player_handover", self)


func _on_handover_confirmed() -> void:
	_battle_overlay_controller.call("on_handover_confirmed", self)


func _refresh_ui_after_successful_action(check_handover: bool = false, action_player_index: int = -1) -> void:
	_refresh_ui()
	if check_handover:
		_check_two_player_handover()
	if _should_pause_after_ai_action(action_player_index):
		_start_ai_action_pause()
		return
	_maybe_run_ai()


func _setup_ai_for_tests() -> void:
	if _dialog_overlay != null:
		_dialog_overlay.visible = false
	if _handover_panel != null:
		_handover_panel.visible = false
	if _field_interaction_overlay != null:
		_field_interaction_overlay.visible = false
	_pending_prize_animating = false
	_ai_running = false
	_ai_step_scheduled = false
	_ai_followup_requested = false
	_ai_action_pause_timer = null
	_ai_action_pause_seconds = AI_ACTION_PAUSE_SECONDS
	_coin_animation_resume_effect_step = false
	_ai_opponent = null
	_ai_turn_marker = ""
	_ai_actions_this_turn = 0


func _set_battle_recording_output_root(root_path: String) -> void:
	_battle_recording_controller.call("set_battle_recording_output_root", self, root_path)


func _should_record_local_battle() -> bool:
	return _battle_recording_controller.call("should_record_local_battle", self)


func _can_capture_battle_recording_context() -> bool:
	return _battle_recording_controller.call("can_capture_battle_recording_context", self)


func _capture_battle_recording_context_if_ready() -> void:
	_battle_recording_controller.call("capture_battle_recording_context_if_ready", self)


func _ensure_battle_recording_started() -> void:
	_battle_recording_controller.call("ensure_battle_recording_started", self)


func _record_battle_event(event_data: Dictionary) -> void:
	_battle_recording_controller.call("record_battle_event", self, event_data)


func _finalize_battle_recording(result_data: Dictionary) -> void:
	_battle_recording_controller.call("finalize_battle_recording", self, result_data)


func _show_match_end_dialog(winner_index: int, reason: String) -> void:
	_battle_dialog_controller.call("show_match_end_dialog", self, winner_index, reason)


func _match_end_summary_text(winner_index: int, reason: String) -> String:
	return _battle_dialog_controller.call("match_end_summary_text", winner_index, reason)


func _current_match_end_review_action() -> Dictionary:
	return _battle_dialog_controller.call("current_match_end_review_action", self)


func _should_offer_battle_review() -> bool:
	return GameManager.current_mode == GameManager.GameMode.TWO_PLAYER


func _load_cached_battle_review() -> Dictionary:
	if _battle_review_match_dir.strip_edges() == "" or _battle_review_store == null:
		return {}
	if not _battle_review_store.has_method("read_review"):
		return {}
	var review: Variant = _battle_review_store.call("read_review", _battle_review_match_dir)
	return review if review is Dictionary else {}


func _ensure_battle_review_service() -> void:
	_battle_advice_controller.call("ensure_battle_review_service", self)


func _begin_battle_review_generation() -> void:
	_battle_advice_controller.call("begin_battle_review_generation", self)


func _on_battle_review_status_changed(status: String, context: Dictionary) -> void:
	_battle_advice_controller.call("on_battle_review_status_changed", self, status, context)


func _on_battle_review_completed(review: Dictionary) -> void:
	_battle_advice_controller.call("on_battle_review_completed", self, review)


func _refresh_match_end_dialog_if_visible() -> void:
	_battle_overlay_controller.call("refresh_match_end_dialog_if_visible", self)


func _open_cached_battle_review() -> void:
	_battle_overlay_controller.call("open_cached_battle_review", self)


func _show_battle_review_overlay(review: Dictionary) -> void:
	_battle_overlay_controller.call("show_battle_review_overlay", self, review)


func _format_battle_review(review: Dictionary) -> String:
	return _battle_advice_controller.call("format_battle_review", self, review)


func _on_review_regenerate_pressed() -> void:
	_battle_advice_controller.call("on_review_regenerate_pressed", self)


func _setup_battle_advice_ui() -> void:
	_battle_advice_controller.call("setup_battle_advice_ui", self)


func _should_offer_battle_advice() -> bool:
	return _battle_advice_controller.call("should_offer_battle_advice", self)


func _current_battle_advice_match_dir() -> String:
	return _battle_advice_controller.call("current_battle_advice_match_dir", self)


func _ensure_battle_advice_service() -> void:
	_battle_advice_controller.call("ensure_battle_advice_service", self)


func _on_ai_advice_pressed() -> void:
	_battle_advice_controller.call("on_ai_advice_pressed", self)


func _on_attack_vfx_preview_pressed() -> void:
	var entries_variant: Variant = _battle_attack_vfx_registry.call("get_preview_entries")
	var entries: Array = entries_variant if entries_variant is Array else []
	var labels: Array = []
	for entry_variant: Variant in entries:
		if entry_variant is Dictionary:
			labels.append(str((entry_variant as Dictionary).get("label", "未命名特效")))
	_pending_choice = "attack_vfx_preview"
	_show_dialog("放烟花：选择特效", labels, {"entries": entries})


func _on_battle_advice_status_changed(status: String, _context: Dictionary) -> void:
	_battle_advice_controller.call("on_battle_advice_status_changed", self, status, _context)


func _on_battle_advice_completed(result: Dictionary) -> void:
	_battle_advice_controller.call("on_battle_advice_completed", self, result)


func _show_battle_advice_overlay(result: Dictionary) -> void:
	_battle_advice_controller.call("show_battle_advice_overlay", self, result)


func _format_battle_advice(result: Dictionary) -> String:
	return _battle_advice_controller.call("format_battle_advice", self, result)


func _on_review_pin_pressed() -> void:
	_battle_advice_controller.call("on_review_pin_pressed", self)


func _on_battle_advice_panel_toggle_pressed() -> void:
	_battle_advice_controller.call("on_battle_advice_panel_toggle_pressed", self)


func _refresh_battle_advice_panel() -> void:
	_battle_advice_controller.call("refresh_battle_advice_panel", self)


func _build_battle_record_meta() -> Dictionary:
	var meta_variant: Variant = _battle_recording_controller.call("build_battle_record_meta", self)
	return meta_variant if meta_variant is Dictionary else {}


func _build_battle_initial_state() -> Dictionary:
	var state_variant: Variant = _battle_recording_controller.call("build_battle_initial_state", self)
	return state_variant if state_variant is Dictionary else {}


func _build_battle_advice_initial_snapshot() -> Dictionary:
	return _battle_advice_controller.call("build_battle_advice_initial_snapshot", self)


func _build_battle_state_snapshot() -> Dictionary:
	var snapshot_variant: Variant = _battle_recording_controller.call("build_battle_state_snapshot", self)
	return snapshot_variant if snapshot_variant is Dictionary else {}


func _build_battle_initial_player_state(player: PlayerState) -> Dictionary:
	var state_variant: Variant = _battle_recording_controller.call("build_battle_initial_player_state", player)
	return state_variant if state_variant is Dictionary else {}


func _slot_record_names(slots: Array) -> Array[String]:
	var names_variant: Variant = _battle_recording_controller.call("slot_record_names", slots)
	return names_variant if names_variant is Array[String] else []


func _slot_record_name(slot: PokemonSlot) -> String:
	return str(_battle_recording_controller.call("slot_record_name", slot))


func _recording_phase_name() -> String:
	return str(_battle_recording_controller.call("recording_phase_name", self))


func _record_battle_state_snapshot(snapshot_reason: String, extra_data: Dictionary = {}) -> void:
	_battle_recording_controller.call("record_battle_state_snapshot", self, snapshot_reason, extra_data)


func _serialize_slot_list(slots: Array) -> Array[Dictionary]:
	var serialized_variant: Variant = _battle_recording_controller.call("serialize_slot_list", slots)
	return serialized_variant if serialized_variant is Array[Dictionary] else []


func _serialize_card_list(cards: Array) -> Array[Dictionary]:
	var serialized_variant: Variant = _battle_recording_controller.call("serialize_card_list", cards)
	return serialized_variant if serialized_variant is Array[Dictionary] else []


func _serialize_pokemon_slot(slot: PokemonSlot) -> Dictionary:
	var serialized_variant: Variant = _battle_recording_controller.call("serialize_pokemon_slot", slot)
	return serialized_variant if serialized_variant is Dictionary else {}


func _serialize_card_instance(card: CardInstance) -> Dictionary:
	var serialized_variant: Variant = _battle_recording_controller.call("serialize_card_instance", card)
	return serialized_variant if serialized_variant is Dictionary else {}


func _sanitize_recording_value(value: Variant) -> Variant:
	return _battle_recording_controller.call("sanitize_recording_value", self, value)


func set_ai_version_registry_for_test(registry: RefCounted) -> void:
	_ai_version_registry = registry


func set_agent_version_store_for_test(store: RefCounted) -> void:
	_agent_version_store = store


func _ensure_ai_opponent() -> void:
	if _ai_opponent == null:
		_ai_opponent = _build_selected_ai_opponent()
		_log_ai_loaded(
			str(_ai_opponent.get_meta("ai_source", "default")),
			str(_ai_opponent.get_meta("ai_version_id", "")),
			str(_ai_opponent.get_meta("ai_display_name", "Default AI"))
		)


func _build_default_ai_opponent() -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(1, GameManager.ai_difficulty)
	ai.use_mcts = true
	ai.mcts_config = {
		"branch_factor": 2,
		"rollouts_per_sequence": 3,
		"rollout_max_steps": 30,
		"time_budget_ms": 2000,
	}
	var strategy_label := "Default AI"
	var deck_strategy = _resolve_selected_ai_deck_strategy()
	if deck_strategy != null:
		ai.set_deck_strategy(deck_strategy)
		strategy_label = str(deck_strategy.call("get_strategy_id")) if deck_strategy.has_method("get_strategy_id") else "Default AI"
	elif GameManager.selected_deck_ids.size() < 2:
		match GameManager.ai_deck_strategy:
			"gardevoir_mcts":
				var strategy := DeckStrategyGardevoirScript.new()
				ai.set_deck_strategy(strategy)
				ai.use_mcts = true
				ai.mcts_config = strategy.get_mcts_config()
				# 尝试加载沙奈朵 value net
				var vnet_path := "user://ai_agents/gardevoir_value_net.json"
				if strategy.load_value_net(vnet_path):
					ai._mcts_planner.value_net = strategy.get_value_net()
					ai._mcts_planner.state_encoder_class = strategy.get_state_encoder_class()
					strategy_label = "沙奈朵 v8 ValueNet"
				else:
					strategy_label = "沙奈朵 v8 MCTS"
			"gardevoir_greedy":
				var strategy := DeckStrategyGardevoirScript.new()
				ai.set_deck_strategy(strategy)
				ai.use_mcts = false
				strategy_label = "沙奈朵 %s 规则驱动" % DeckStrategyGardevoirScript.VERSION
			"gardevoir":
				# 兼容旧值
				var strategy_version: String = DeckStrategyGardevoirScript.VERSION
				strategy_label = "沙奈朵策略 %s" % strategy_version
			"miraidon_mcts":
				var m_strategy := DeckStrategyMiraidonScript.new()
				ai.set_deck_strategy(m_strategy)
				ai.use_mcts = true
				ai.mcts_config = m_strategy.get_mcts_config()
				var m_vnet_path := "user://ai_agents/miraidon_value_net.json"
				if m_strategy.load_value_net(m_vnet_path):
					ai._mcts_planner.value_net = m_strategy.get_value_net()
					ai._mcts_planner.state_encoder_class = m_strategy.get_state_encoder_class()
					strategy_label = "密勒顿 v1 ValueNet"
				else:
					strategy_label = "密勒顿 v1 MCTS"
			"miraidon_greedy":
				var m_strategy := DeckStrategyMiraidonScript.new()
				ai.set_deck_strategy(m_strategy)
				ai.use_mcts = false
				strategy_label = "密勒顿 %s 规则驱动" % DeckStrategyMiraidonScript.VERSION
			"generic":
				pass
	ai.set_meta("ai_source", "default")
	ai.set_meta("ai_version_id", "")
	ai.set_meta("ai_display_name", strategy_label)

	return ai


func _build_selected_ai_opponent() -> AIOpponent:
	var selection: Dictionary = GameManager.ai_selection
	var source := str(selection.get("source", "default"))
	if source == "default":
		return _build_default_ai_opponent()

	var version_record := _resolve_selected_ai_version_record(selection)
	if version_record.is_empty():
		return _build_default_ai_opponent()

	var agent_config_path := str(version_record.get("agent_config_path", selection.get("agent_config_path", "")))
	if not _ai_path_exists(agent_config_path):
		return _build_default_ai_opponent()

	var agent_config := _load_selected_agent_config(agent_config_path)
	if agent_config.is_empty():
		return _build_default_ai_opponent()

	var ai := _build_default_ai_opponent()
	var config_weights: Variant = agent_config.get("heuristic_weights", {})
	if config_weights is Dictionary and not (config_weights as Dictionary).is_empty():
		ai.heuristic_weights = (config_weights as Dictionary).duplicate(true)

	var config_mcts: Variant = agent_config.get("mcts_config", {})
	if config_mcts is Dictionary and not (config_mcts as Dictionary).is_empty():
		ai.use_mcts = true
		ai.mcts_config = (config_mcts as Dictionary).duplicate(true)

	var value_net_path := str(version_record.get("value_net_path", selection.get("value_net_path", agent_config.get("value_net_path", ""))))
	if value_net_path != "":
		if not _ai_path_exists(value_net_path):
			return _build_default_ai_opponent()
		ai.value_net_path = value_net_path
	var action_scorer_path := str(version_record.get("action_scorer_path", selection.get("action_scorer_path", agent_config.get("action_scorer_path", ""))))
	if action_scorer_path != "":
		if not _ai_path_exists(action_scorer_path):
			return _build_default_ai_opponent()
		ai.action_scorer_path = action_scorer_path
	var interaction_scorer_path := str(version_record.get("interaction_scorer_path", selection.get("interaction_scorer_path", agent_config.get("interaction_scorer_path", ""))))
	if interaction_scorer_path != "":
		if not _ai_path_exists(interaction_scorer_path):
			return _build_default_ai_opponent()
		ai.interaction_scorer_path = interaction_scorer_path

	var version_id := str(version_record.get("version_id", selection.get("version_id", "")))
	var display_name := str(version_record.get("display_name", selection.get("display_name", version_id)))
	ai.set_meta("ai_source", source)
	ai.set_meta("ai_version_id", version_id)
	ai.set_meta("ai_display_name", display_name)

	return ai


func _resolve_selected_ai_version_record(selection: Dictionary) -> Dictionary:
	var source := str(selection.get("source", "default"))
	if source == "latest_trained":
		if _ai_version_registry != null and _ai_version_registry.has_method("get_latest_playable_version"):
			var latest: Variant = _ai_version_registry.call("get_latest_playable_version")
			if latest is Dictionary:
				var latest_record: Dictionary = (latest as Dictionary).duplicate(true)
				return latest_record if _is_version_record_compatible_with_selected_ai(latest_record) else {}
		return {}
	if source == "specific_version":
		var version_id := str(selection.get("version_id", ""))
		if version_id != "" and _ai_version_registry != null and _ai_version_registry.has_method("get_version"):
			var version: Variant = _ai_version_registry.call("get_version", version_id)
			if version is Dictionary and not (version as Dictionary).is_empty():
				var version_record: Dictionary = (version as Dictionary).duplicate(true)
				return version_record if _is_version_record_compatible_with_selected_ai(version_record) else {}
	return {}


func _resolve_selected_ai_deck_strategy() -> RefCounted:
	if _deck_strategy_registry == null or not _deck_strategy_registry.has_method("resolve_strategy_for_deck"):
		return null
	if GameManager.selected_deck_ids.size() < 2:
		return null
	var ai_deck: DeckData = GameManager.resolve_selected_battle_deck(1)
	if ai_deck == null:
		return null
	return _deck_strategy_registry.call("resolve_strategy_for_deck", ai_deck)


func _selected_ai_strategy_id() -> String:
	if _deck_strategy_registry == null or not _deck_strategy_registry.has_method("resolve_strategy_id_for_deck"):
		return ""
	if GameManager.selected_deck_ids.size() < 2:
		return ""
	var ai_deck: DeckData = GameManager.resolve_selected_battle_deck(1)
	if ai_deck == null:
		return ""
	return str(_deck_strategy_registry.call("resolve_strategy_id_for_deck", ai_deck))


func _is_version_record_compatible_with_selected_ai(version_record: Dictionary) -> bool:
	var compatible_strategy_id := str(version_record.get("compatible_strategy_id", ""))
	if compatible_strategy_id == "":
		return true
	var selected_strategy_id := _selected_ai_strategy_id()
	if selected_strategy_id == "":
		return false
	return compatible_strategy_id == selected_strategy_id


func _load_selected_agent_config(agent_config_path: String) -> Dictionary:
	if _agent_version_store == null or not _agent_version_store.has_method("load_version"):
		return {}
	var loaded: Variant = _agent_version_store.call("load_version", agent_config_path)
	return (loaded as Dictionary).duplicate(true) if loaded is Dictionary else {}


func _ai_path_exists(path: String) -> bool:
	if path == "":
		return false
	if FileAccess.file_exists(path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


func _log_ai_loaded(source: String, version_id: String, display_name: String) -> void:
	_runtime_log("ai_loaded", "source=%s version=%s display=%s" % [source, version_id, display_name])
	if GameManager.current_mode == GameManager.GameMode.VS_AI:
		print("[AI] %s" % display_name)

func _reset_ai_action_counter_if_needed() -> void:
	if _gsm == null or _gsm.game_state == null:
		_ai_turn_marker = ""
		_ai_actions_this_turn = 0
		return
	var marker := "%d:%d" % [_gsm.game_state.turn_number, _gsm.game_state.current_player_index]
	if marker != _ai_turn_marker:
		_ai_turn_marker = marker
		_ai_actions_this_turn = 0


func _is_ai_setup_prompt(pending_choice: String = _pending_choice) -> bool:
	return (
		pending_choice == "mulligan_extra_draw"
		or pending_choice.begins_with("setup_active_")
		or pending_choice.begins_with("setup_bench_")
	)


func _get_ai_prompt_player_index() -> int:
	if _pending_choice == "mulligan_extra_draw":
		return int(_dialog_data.get("beneficiary", -1))
	if _pending_choice.begins_with("setup_active_") or _pending_choice.begins_with("setup_bench_"):
		return int(_pending_choice.split("_")[-1])
	return -1


func _get_effect_interaction_prompt_player_index() -> int:
	if _pending_choice != "effect_interaction":
		return -1
	if _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
		return -1
	return _resolve_effect_step_chooser_player(_pending_effect_steps[_pending_effect_step_index])


func _is_ai_prize_prompt() -> bool:
	if _ai_opponent == null:
		return false
	return (
		_pending_choice == "take_prize"
		and _pending_prize_player_index == _ai_opponent.player_index
		and _pending_prize_remaining > 0
	)


func _is_ai_send_out_prompt() -> bool:
	if _ai_opponent == null:
		return false
	return (
		_pending_choice == "send_out"
		and int(_dialog_data.get("player", -1)) == _ai_opponent.player_index
	)


func _is_ai_effect_prompt() -> bool:
	if _ai_opponent == null:
		return false
	return _get_effect_interaction_prompt_player_index() == _ai_opponent.player_index


func _is_ui_blocking_ai() -> bool:
	var dialog_blocks_ai := _dialog_overlay != null and _dialog_overlay.visible and not (_is_ai_setup_prompt() or _is_ai_effect_prompt())
	return (
		_draw_reveal_active
		or _is_ai_action_pause_active()
		or dialog_blocks_ai
		or (_handover_panel != null and _handover_panel.visible)
		or _has_pending_coin_animation()
		or (_pending_choice == "take_prize" and not _is_ai_prize_prompt())
		or _pending_prize_animating
		or (_field_interaction_overlay != null and _field_interaction_overlay.visible and not _is_ai_effect_prompt())
	)


func _is_ai_turn_ready() -> bool:
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return false
	if _gsm == null:
		return false
	_ensure_ai_opponent()
	if _gsm.game_state != null and _gsm.game_state.phase == GameState.GamePhase.SETUP and not _is_ai_setup_prompt():
		return false
	if _is_ai_setup_prompt():
		if _is_ui_blocking_ai():
			return false
		return _get_ai_prompt_player_index() == _ai_opponent.player_index
	if _pending_choice == "take_prize":
		if _is_ui_blocking_ai():
			return false
		return _is_ai_prize_prompt()
	if _pending_choice == "send_out":
		if _is_ui_blocking_ai():
			return false
		return _is_ai_send_out_prompt()
	if _pending_choice == "effect_interaction":
		if _is_ui_blocking_ai():
			return false
		return _get_effect_interaction_prompt_player_index() == _ai_opponent.player_index
	return _ai_opponent.should_control_turn(_gsm.game_state, _is_ui_blocking_ai())


func _try_auto_continue_ai_draw_reveal() -> bool:
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return false
	if _draw_reveal_active != true or _draw_reveal_auto_continue_pending != true:
		return false
	if self is Node and (self as Node).is_inside_tree():
		return false
	_ensure_ai_opponent()
	if _ai_opponent == null or _draw_reveal_current_action == null:
		return false
	if _draw_reveal_current_action.player_index != _ai_opponent.player_index:
		return false
	if _battle_draw_reveal_controller == null or not _battle_draw_reveal_controller.has_method("run_auto_continue"):
		return false
	_battle_draw_reveal_controller.call("run_auto_continue", self)
	return true


func _is_ai_action_pause_active() -> bool:
	return _ai_action_pause_timer != null


func _should_pause_after_ai_action(action_player_index: int) -> bool:
	if action_player_index < 0:
		return false
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return false
	if _battle_mode != "live":
		return false
	_ensure_ai_opponent()
	return _ai_opponent != null and action_player_index == _ai_opponent.player_index


func _start_ai_action_pause() -> void:
	_ai_action_pause_timer = null
	if _ai_action_pause_seconds <= 0.0:
		_on_ai_action_pause_finished()
		return
	if not is_inside_tree():
		_ai_action_pause_timer = true
		return
	var timer: SceneTreeTimer = get_tree().create_timer(_ai_action_pause_seconds)
	_ai_action_pause_timer = timer
	timer.timeout.connect(func() -> void:
		if _ai_action_pause_timer != timer:
			return
		_on_ai_action_pause_finished()
	)


func _on_ai_action_pause_finished() -> void:
	_ai_action_pause_timer = null
	_maybe_run_ai()


func _maybe_run_ai() -> void:
	if _try_auto_continue_ai_draw_reveal():
		return
	if _ai_running:
		if _is_ai_turn_ready():
			_ai_followup_requested = true
		return
	if _ai_step_scheduled or not _is_ai_turn_ready():
		return
	_ai_step_scheduled = true
	call_deferred("_run_ai_step")


func _run_ai_step() -> void:
	if _ai_running:
		return
	if _try_auto_continue_ai_draw_reveal():
		_ai_step_scheduled = false
		return
	_ai_step_scheduled = false
	if not _is_ai_turn_ready():
		return
	_reset_ai_action_counter_if_needed()
	if _ai_actions_this_turn >= AI_MAX_ACTIONS_PER_TURN:
		if _pending_choice == "" and _gsm != null and _gsm.game_state != null and _gsm.game_state.phase == GameState.GamePhase.MAIN:
			_on_end_turn()
		return
	var starting_pending_choice: String = _pending_choice
	_ai_running = true
	_ai_followup_requested = false
	_ensure_ai_opponent()
	var handled: bool = _ai_opponent.run_single_step(self, _gsm)
	_ai_running = false
	if handled:
		_ai_actions_this_turn += 1
	var started_in_setup_prompt: bool = starting_pending_choice.begins_with("setup_active_") \
		or starting_pending_choice.begins_with("setup_bench_")
	if started_in_setup_prompt \
		and not _ai_step_scheduled \
		and _pending_choice == "" \
		and _gsm != null \
		and _gsm.game_state != null \
		and _gsm.game_state.phase != GameState.GamePhase.SETUP \
		and _ai_opponent != null \
		and _gsm.game_state.current_player_index == _ai_opponent.player_index:
		_ai_step_scheduled = true
		call_deferred("_run_ai_step")
	if _ai_followup_requested and not _ai_step_scheduled and _is_ai_turn_ready():
		_ai_step_scheduled = true
		call_deferred("_run_ai_step")
	_ai_followup_requested = false


func _on_hand_card_clicked(inst: CardInstance, _panel: PanelContainer) -> void:
	_battle_action_controller.call("on_hand_card_clicked", self, inst, _panel)


func _try_play_trainer_with_interaction(player_index: int, card: CardInstance) -> void:
	_battle_action_controller.call("try_play_trainer_with_interaction", self, player_index, card)


func _try_play_stadium_with_interaction(player_index: int, card: CardInstance) -> void:
	_battle_action_controller.call("try_play_stadium_with_interaction", self, player_index, card)


func _try_use_ability_with_interaction(player_index: int, slot: PokemonSlot, ability_index: int) -> void:
	_battle_action_controller.call("try_use_ability_with_interaction", self, player_index, slot, ability_index)


func _try_use_stadium_with_interaction(player_index: int) -> void:
	_battle_action_controller.call("try_use_stadium_with_interaction", self, player_index)


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
	_battle_effect_interaction_controller.call(
		"start_effect_interaction",
		self,
		kind,
		player_index,
		steps,
		card,
		slot,
		ability_index,
		attack_data,
		attack_effects
	)


func _effect_step_uses_field_slot_ui(step: Dictionary) -> bool:
	return bool(_battle_effect_interaction_controller.call("effect_step_uses_field_slot_ui", self, step))


func _effect_step_uses_field_assignment_ui(step: Dictionary) -> bool:
	return bool(_battle_effect_interaction_controller.call("effect_step_uses_field_assignment_ui", self, step))


func _effect_step_uses_counter_distribution_ui(step: Dictionary) -> bool:
	return bool(_battle_effect_interaction_controller.call("effect_step_uses_counter_distribution_ui", self, step))


func _resolve_effect_step_chooser_player(step: Dictionary) -> int:
	return int(_battle_effect_interaction_controller.call("resolve_effect_step_chooser_player", self, step))


func _hide_ai_owned_effect_step_ui(chooser_player: int) -> void:
	_battle_effect_interaction_controller.call("hide_ai_owned_effect_step_ui", self, chooser_player)


func _show_next_effect_interaction_step() -> void:
	_battle_effect_interaction_controller.call("show_next_effect_interaction_step", self)


func _handle_effect_interaction_choice(selected_indices: PackedInt32Array) -> void:
	_battle_effect_interaction_controller.call("handle_effect_interaction_choice", self, selected_indices)


## After each interaction step completes, check whether the copied effect injected any follow-up dynamic steps.
## Example: Regidrago VSTAR copying Dragapult ex may append a second assignment step for damage counters.
func _inject_followup_steps() -> void:
	_battle_effect_interaction_controller.call("inject_followup_steps", self)


func _reset_effect_interaction() -> void:
	_battle_effect_interaction_controller.call("reset_effect_interaction", self)


func _set_handover_panel_visible(visible_state: bool, reason: String) -> void:
	if _handover_panel == null:
		return
	if _handover_panel.visible == visible_state:
		_runtime_log(
			"handover_visibility_noop",
			"visible=%s reason=%s %s" % [str(visible_state), reason, _state_snapshot()]
		)
		return
	_handover_panel.visible = visible_state
	_runtime_log(
		"handover_visibility",
		"visible=%s reason=%s %s" % [str(visible_state), reason, _state_snapshot()]
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


func _is_review_mode() -> bool:
	return _battle_mode == "review_readonly"


func _can_accept_live_action() -> bool:
	return not _is_review_mode() and not _draw_reveal_active and not _is_ai_action_pause_active() and _pending_choice != "take_prize"


func _refresh_replay_controls() -> void:
	_battle_replay_controller.call(
		"refresh_controls",
		_battle_scene_refs,
		_battle_mode,
		_replay_current_turn_index,
		_replay_turn_numbers,
		_replay_loaded_raw_snapshot
	)


func _apply_replay_launch(launch: Dictionary) -> void:
	_battle_mode = "review_readonly"
	var prepared_variant: Variant = _battle_replay_controller.call("prepare_launch", launch)
	if not (prepared_variant is Dictionary):
		return
	var prepared: Dictionary = prepared_variant
	_replay_match_dir = str(prepared.get("match_dir", ""))
	_replay_entry_source = str(prepared.get("entry_source", ""))
	_replay_turn_numbers.clear()
	for turn_variant: Variant in prepared.get("turn_numbers", []):
		_replay_turn_numbers.append(int(turn_variant))
	var entry_turn_number := int(prepared.get("entry_turn_number", 0))
	_replay_current_turn_index = int(prepared.get("current_turn_index", -1))
	_refresh_replay_controls()
	if _replay_match_dir.strip_edges() != "" and entry_turn_number > 0:
		_load_replay_turn(entry_turn_number)


func _load_replay_turn(turn_number: int) -> void:
	var replay_variant: Variant = _battle_replay_controller.call(
		"load_turn",
		_battle_replay_snapshot_loader,
		_battle_replay_state_restorer,
		_replay_match_dir,
		turn_number,
		_view_player
	)
	if not (replay_variant is Dictionary):
		return
	var replay: Dictionary = replay_variant
	_replay_loaded_raw_snapshot = (replay.get("loaded_raw_snapshot", {}) as Dictionary).duplicate(true)
	_replay_loaded_view_snapshot = (replay.get("loaded_view_snapshot", {}) as Dictionary).duplicate(true)
	_view_player = int(replay.get("view_player_index", _view_player))
	var restored_game_state: Variant = replay.get("restored_game_state", null)
	if restored_game_state != null:
		_ensure_game_state_machine()
		_gsm.game_state = restored_game_state
	_refresh_replay_controls()
	_refresh_ui()


func _on_replay_prev_turn_pressed() -> void:
	var step_variant: Variant = _battle_replay_controller.call(
		"step_previous_turn",
		_replay_current_turn_index,
		_replay_turn_numbers
	)
	if not (step_variant is Dictionary):
		return
	var step: Dictionary = step_variant
	_replay_current_turn_index = int(step.get("current_turn_index", _replay_current_turn_index))
	_load_replay_turn(int(step.get("turn_number", 0)))


func _on_replay_next_turn_pressed() -> void:
	var step_variant: Variant = _battle_replay_controller.call(
		"step_next_turn",
		_replay_current_turn_index,
		_replay_turn_numbers
	)
	if not (step_variant is Dictionary):
		return
	var step: Dictionary = step_variant
	_replay_current_turn_index = int(step.get("current_turn_index", _replay_current_turn_index))
	_load_replay_turn(int(step.get("turn_number", 0)))


func _register_effects_from_game_state(gs: GameState) -> void:
	if gs == null or _gsm == null:
		return
	for player: PlayerState in gs.players:
		var all_cards: Array[CardInstance] = []
		all_cards.append_array(player.hand)
		all_cards.append_array(player.deck)
		all_cards.append_array(player.prizes)
		all_cards.append_array(player.discard_pile)
		all_cards.append_array(player.lost_zone)
		if player.active_pokemon != null:
			all_cards.append_array(player.active_pokemon.pokemon_stack)
			all_cards.append_array(player.active_pokemon.attached_energy)
			if player.active_pokemon.attached_tool != null:
				all_cards.append(player.active_pokemon.attached_tool)
		for bench_slot: PokemonSlot in player.bench:
			if bench_slot == null:
				continue
			all_cards.append_array(bench_slot.pokemon_stack)
			all_cards.append_array(bench_slot.attached_energy)
			if bench_slot.attached_tool != null:
				all_cards.append(bench_slot.attached_tool)
		for card: CardInstance in all_cards:
			if card != null and card.card_data != null:
				_gsm.effect_processor.register_pokemon_card(card.card_data)


func _on_replay_continue_pressed() -> void:
	var restored_game_state: Variant = _battle_replay_controller.call(
		"restore_live_game_state",
		_battle_replay_state_restorer,
		_replay_loaded_raw_snapshot
	)
	if restored_game_state == null:
		return
	_ensure_game_state_machine()
	_gsm.game_state = restored_game_state
	_register_effects_from_game_state(_gsm.game_state)
	_clear_replay_ui_state()
	_battle_mode = "live"
	# 将 phase 推进到 MAIN 让玩家可以操作
	if _gsm.game_state.phase != GameState.GamePhase.MAIN and _gsm.game_state.phase != GameState.GamePhase.GAME_OVER:
		_gsm.game_state.phase = GameState.GamePhase.MAIN
	_refresh_replay_controls()
	_refresh_ui()
	_check_two_player_handover()
	_maybe_run_ai()


func _on_replay_back_to_list_pressed() -> void:
	if _is_review_mode():
		GameManager.goto_replay_browser()


func _clear_replay_ui_state() -> void:
	var empty_state_variant: Variant = _battle_replay_controller.call("empty_state")
	if empty_state_variant is Dictionary:
		var empty_state: Dictionary = empty_state_variant
		_replay_match_dir = str(empty_state.get("match_dir", ""))
		_replay_turn_numbers.clear()
		for turn_variant: Variant in empty_state.get("turn_numbers", []):
			_replay_turn_numbers.append(int(turn_variant))
		_replay_current_turn_index = int(empty_state.get("current_turn_index", -1))
		_replay_entry_source = str(empty_state.get("entry_source", ""))
		_replay_loaded_raw_snapshot = (empty_state.get("loaded_raw_snapshot", {}) as Dictionary).duplicate(true)
		_replay_loaded_view_snapshot = (empty_state.get("loaded_view_snapshot", {}) as Dictionary).duplicate(true)
	_pending_choice = ""
	_set_pending_handover_action(Callable(), "replay_continue")
	_set_handover_panel_visible(false, "replay_continue")
	if _dialog_overlay != null:
		_dialog_overlay.visible = false
	if _review_overlay != null:
		_review_overlay.visible = false


func _refresh_ui() -> void:
	_battle_display_controller.call("refresh_ui", self)


func _get_selected_deck_name(player_index: int) -> String:
	return str(_battle_display_controller.call("get_selected_deck_name", player_index))


func _update_side_previews(opp: PlayerState, my: PlayerState) -> void:
	_battle_display_controller.call("update_side_previews", self, opp, my)


func _refresh_stadium_area(gs: GameState, current_player: int, is_my_turn: bool) -> void:
	_battle_display_controller.call("refresh_stadium_area", self, gs, current_player, is_my_turn)


func _refresh_info_hud(gs: GameState, view_player: int, opponent_player: int) -> void:
	_battle_display_controller.call("refresh_info_hud", self, gs, view_player, opponent_player)


func _apply_info_metric(label: Label, is_used: bool, ready_text: String, used_text: String) -> void:
	_battle_display_controller.call("apply_info_metric", label, is_used, ready_text, used_text)


func _update_prize_slots(slots: Array[BattleCardView], prize_layout: Array, is_selectable: bool) -> void:
	_battle_display_controller.call("update_prize_slots", self, slots, prize_layout, is_selectable)

func _update_pile_preview(preview: BattleCardView, card: CardInstance, face_down: bool) -> void:
	_battle_display_controller.call("update_pile_preview", preview, card, face_down)


func _refresh_field_card_views(gs: GameState) -> void:
	_battle_display_controller.call("refresh_field_card_views", self, gs)


func _refresh_slot_card_view(slot_id: String, slot: PokemonSlot, is_active: bool) -> void:
	_battle_display_controller.call("refresh_slot_card_view", self, slot_id, slot, is_active)

func _apply_field_slot_style(panel: PanelContainer, slot_id: String, occupied: bool, is_active: bool) -> void:
	_battle_display_controller.call("apply_field_slot_style", self, panel, slot_id, occupied, is_active)

func _slot_overlay_text(slot: PokemonSlot) -> String:
	return str(_battle_display_controller.call("slot_overlay_text", self, slot))


func _build_battle_status(slot: PokemonSlot) -> Dictionary:
	var status_variant: Variant = _battle_display_controller.call("build_battle_status", self, slot)
	return status_variant if status_variant is Dictionary else {}


func _slot_used_ability_this_turn(slot: PokemonSlot) -> bool:
	return bool(_battle_display_controller.call("slot_used_ability_this_turn", self, slot))


func _get_display_max_hp(slot: PokemonSlot) -> int:
	return int(_battle_display_controller.call("get_display_max_hp", self, slot))


func _get_display_remaining_hp(slot: PokemonSlot) -> int:
	return int(_battle_display_controller.call("get_display_remaining_hp", self, slot))


func _battle_card_mode_for_slot(slot: PokemonSlot) -> String:
	return str(_battle_display_controller.call("battle_card_mode_for_slot", self, slot))


func _slot_energy_icon_codes(slot: PokemonSlot) -> Array[String]:
	var codes_variant: Variant = _battle_display_controller.call("slot_energy_icon_codes", self, slot)
	return codes_variant if codes_variant is Array[String] else []


func _slot_energy_summary(slot: PokemonSlot) -> String:
	return str(_battle_display_controller.call("slot_energy_summary", self, slot))


func _refresh_slot_label(lbl: RichTextLabel, slot: PokemonSlot) -> void:
	_battle_display_controller.call("refresh_slot_label", self, lbl, slot)


func _refresh_bench(container: HBoxContainer, bench: Array[PokemonSlot]) -> void:
	_battle_display_controller.call("refresh_bench", container, bench)


func _refresh_hand() -> void:
	_battle_display_controller.call("refresh_hand", self)


func _clear_container_children(container: Node) -> void:
	_battle_display_controller.call("clear_container_children", container)


func _build_hand_card(inst: CardInstance) -> PanelContainer:
	return _battle_display_controller.call("build_hand_card", self, inst)


func _hand_card_subtext(cd: CardData) -> String:
	return str(_battle_display_controller.call("hand_card_subtext", cd))


func _slot_from_id(slot_id: String, gs: GameState) -> PokemonSlot:
	return _battle_display_controller.call("slot_from_id", self, slot_id, gs)


func _bt(key: String, params: Dictionary = {}) -> String:
	return BattleI18nScript.t(key, params)


func _log(msg: String) -> void:
	if _log_list != null:
		if _log_list.get_parsed_text().length() > 12000:
			var full := _log_list.text
			var cut := full.find("\n", full.length() / 3)
			if cut >= 0:
				_log_list.text = full.substr(cut + 1)
		_log_list.append_text(msg + "\n")
	_runtime_log("ui_log", msg)


func _on_coin_flipped(result: bool) -> void:
	var text: String = "正面" if result else "反面"
	_runtime_log("coin_flipped", text)
	_coin_flip_queue.append(result)
	if not _coin_animating:
		_play_next_coin_animation()


func _has_pending_coin_animation() -> bool:
	return _coin_animating or not _coin_flip_queue.is_empty()


func _delay_effect_step_until_coin_animation_finishes() -> void:
	_coin_animation_resume_effect_step = true
	_pending_choice = "effect_interaction"
	_runtime_log("effect_step_waiting_for_coin_animation", _effect_state_snapshot())


func _play_next_coin_animation() -> void:
	if _coin_flip_queue.is_empty():
		_coin_animating = false
		if _coin_animation_resume_effect_step:
			_coin_animation_resume_effect_step = false
			_show_next_effect_interaction_step()
			_maybe_run_ai()
		return
	if _coin_animator == null or not _coin_animator.has_method("play"):
		_coin_flip_queue.clear()
		_coin_animating = false
		if _coin_animation_resume_effect_step:
			_coin_animation_resume_effect_step = false
			_show_next_effect_interaction_step()
			_maybe_run_ai()
		return
	_coin_animating = true
	var result: bool = _coin_flip_queue.pop_front()
	_coin_animator.play(result)


func _on_coin_animation_finished() -> void:
	_play_next_coin_animation()


func _show_discard_pile(player_index: int, title: String) -> void:
	_battle_display_controller.call("show_discard_pile", self, player_index, title)


func _show_prize_cards(player_index: int, title: String) -> void:
	_battle_display_controller.call("show_prize_cards", self, player_index, title)


func _show_deck_cards(player_index: int, title: String) -> void:
	_battle_display_controller.call("show_deck_cards", self, player_index, title)


func _init_battle_runtime_log() -> void:
	_battle_runtime_log_controller.call("init_battle_runtime_log", self)


func _runtime_log(event: String, detail: String = "") -> void:
	_battle_runtime_log_controller.call("runtime_log", self, event, detail)


func _runtime_log_ui_state_if_changed() -> void:
	_battle_runtime_log_controller.call("runtime_log_ui_state_if_changed", self)


func _state_snapshot() -> String:
	return str(_battle_runtime_log_controller.call("state_snapshot", self))


func _dialog_state_snapshot() -> String:
	return str(_battle_runtime_log_controller.call("dialog_state_snapshot", self))


func _overlay_snapshot() -> String:
	return str(_battle_runtime_log_controller.call("overlay_snapshot", self))


func _effect_state_snapshot() -> String:
	return str(_battle_runtime_log_controller.call("effect_state_snapshot", self))


func _card_instance_label(card: CardInstance) -> String:
	return str(_battle_runtime_log_controller.call("card_instance_label", card))


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
