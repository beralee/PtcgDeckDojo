## 卡组管理场景
extends Control

const CARD_IMAGE_DOWNLOADER := preload("res://scripts/network/CardImageDownloader.gd")

var _importer: DeckImporter = null
var _image_syncer = null
var _current_operation: String = ""
var _panel_mode: String = "import"


func _ready() -> void:
	%BtnImport.pressed.connect(_on_import_pressed)
	%BtnSyncImages.pressed.connect(_on_sync_images_pressed)
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnDoImport.pressed.connect(_on_do_import)
	%BtnCloseImport.pressed.connect(_on_close_import)

	CardDatabase.decks_changed.connect(_refresh_deck_list)
	_refresh_deck_list()

	# 创建导入器
	_importer = DeckImporter.new()
	add_child(_importer)
	_importer.import_progress.connect(_on_import_progress)
	_importer.import_completed.connect(_on_import_completed)
	_importer.import_failed.connect(_on_import_failed)

	_image_syncer = CARD_IMAGE_DOWNLOADER.new()
	add_child(_image_syncer)
	_image_syncer.progress.connect(_on_image_sync_progress)
	_image_syncer.completed.connect(_on_image_sync_completed)
	_image_syncer.failed.connect(_on_image_sync_failed)


func _refresh_deck_list() -> void:
	var deck_list_container: VBoxContainer = %DeckList
	# 清除现有子节点（保留空提示）
	for child: Node in deck_list_container.get_children():
		if child != %EmptyLabel:
			child.queue_free()

	var decks := CardDatabase.get_all_decks()
	%EmptyLabel.visible = decks.is_empty()

	for deck: DeckData in decks:
		var item := _create_deck_item(deck)
		deck_list_container.add_child(item)


func _create_deck_item(deck: DeckData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# 卡组信息
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = deck.deck_name
	info_vbox.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = "%d 张卡牌 | 导入于 %s" % [deck.total_cards, deck.import_date.substr(0, 10)]
	detail_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(detail_label)

	# 查看按钮
	var btn_view := Button.new()
	btn_view.text = "查看"
	btn_view.custom_minimum_size = Vector2(70, 35)
	btn_view.pressed.connect(_on_view_deck.bind(deck))
	hbox.add_child(btn_view)

	# 删除按钮
	var btn_delete := Button.new()
	btn_delete.text = "删除"
	btn_delete.custom_minimum_size = Vector2(70, 35)
	btn_delete.pressed.connect(_on_delete_deck.bind(deck))
	hbox.add_child(btn_delete)

	return panel


# === 导入面板 ===

func _on_import_pressed() -> void:
	if _current_operation != "":
		return
	_panel_mode = "import"
	_configure_operation_panel()
	%UrlInput.text = ""
	%ProgressLabel.text = ""
	%ProgressBar.visible = false
	%BtnDoImport.disabled = false
	%ImportPanel.visible = true


func _on_close_import() -> void:
	if _current_operation != "":
		return
	%ImportPanel.visible = false


func _on_do_import() -> void:
	if _panel_mode != "import":
		return
	var url: String = %UrlInput.text.strip_edges()
	if url.is_empty():
		%ProgressLabel.text = "请输入卡组链接"
		return

	_current_operation = "import"
	_set_operation_busy(true)
	%BtnDoImport.disabled = true
	%ProgressBar.visible = true
	%ProgressBar.value = 0
	%ProgressLabel.text = "正在导入..."
	_importer.import_deck(url)


func _on_sync_images_pressed() -> void:
	if _current_operation != "":
		return
	_panel_mode = "sync_images"
	_configure_operation_panel()
	%ImportPanel.visible = true
	_current_operation = "sync_images"
	_set_operation_busy(true)
	%ProgressBar.visible = true
	%ProgressBar.value = 0
	%ProgressLabel.text = "正在同步本地卡图..."
	_image_syncer.sync_cached_cards()


func _on_import_progress(current: int, total: int, message: String) -> void:
	%ProgressLabel.text = message
	if total > 0:
		%ProgressBar.value = (float(current) / total) * 100.0


func _on_import_completed(deck: DeckData, errors: PackedStringArray) -> void:
	CardDatabase.save_deck(deck)
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)
	%BtnDoImport.disabled = false

	if errors.is_empty():
		%ProgressLabel.text = "导入成功: %s (%d 张)" % [deck.deck_name, deck.total_cards]
	else:
		%ProgressLabel.text = "导入完成（有 %d 个警告）" % errors.size()
		for err: String in errors:
			push_warning("导入警告: %s" % err)


func _on_import_failed(error_message: String) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)
	%BtnDoImport.disabled = false
	%ProgressLabel.text = "导入失败: %s" % error_message


func _on_image_sync_progress(current: int, total: int, message: String) -> void:
	%ProgressLabel.text = message
	if total > 0:
		%ProgressBar.value = (float(current) / total) * 100.0


func _on_image_sync_completed(stats: Dictionary, errors: PackedStringArray) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)

	var total := int(stats.get("total", 0))
	var downloaded := int(stats.get("downloaded", 0))
	var updated := int(stats.get("updated", 0))
	var skipped := int(stats.get("skipped", 0))

	if errors.is_empty():
		%ProgressLabel.text = "同步完成: 共 %d 张，下载 %d 张，已存在 %d 张，补全 %d 张" % [
			total, downloaded, skipped, updated
		]
	else:
		%ProgressLabel.text = "同步完成: 共 %d 张，下载 %d 张，警告 %d 个" % [
			total, downloaded, errors.size()
		]
		for err: String in errors:
			push_warning("卡图同步警告: %s" % err)


func _on_image_sync_failed(error_message: String) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)
	%ProgressLabel.text = "同步失败: %s" % error_message


# === 查看卡组 ===

func _on_view_deck(deck: DeckData) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = deck.deck_name
	dialog.size = Vector2i(600, 500)
	dialog.ok_button_text = "关闭"

	var scroll := ScrollContainer.new()
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	scroll.offset_left = 8
	scroll.offset_top = 8
	scroll.offset_right = -8
	scroll.offset_bottom = -8
	dialog.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# 显示卡组信息
	var info_label := Label.new()
	info_label.text = "ID: %d | 来源: %s\n总计: %d 张" % [deck.id, deck.source_url, deck.total_cards]
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info_label)

	# 分类显示卡牌
	var categories := {"Pokemon": [], "Item": [], "Supporter": [], "Tool": [], "Stadium": [], "Basic Energy": [], "Special Energy": []}
	for entry: Dictionary in deck.cards:
		var ct: String = entry.get("card_type", "")
		if categories.has(ct):
			categories[ct].append(entry)
		else:
			categories["Item"].append(entry)  # 未知类型归入物品

	var category_names := {
		"Pokemon": "宝可梦", "Item": "物品", "Supporter": "支援者",
		"Tool": "道具", "Stadium": "竞技场", "Basic Energy": "基本能量", "Special Energy": "特殊能量",
	}

	for cat_key: String in categories:
		var cat_cards: Array = categories[cat_key]
		if cat_cards.is_empty():
			continue
		var total_count := 0
		for c: Variant in cat_cards:
			total_count += int(c.get("count", 0))

		var cat_label := Label.new()
		cat_label.text = "\n== %s (%d张) ==" % [category_names.get(cat_key, cat_key), total_count]
		vbox.add_child(cat_label)

		for entry: Variant in cat_cards:
			var card_label := Label.new()
			card_label.text = "  %s × %d" % [entry.get("name", "?"), entry.get("count", 0)]
			vbox.add_child(card_label)

	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


# === 删除卡组 ===

func _on_delete_deck(deck: DeckData) -> void:
	var confirm := ConfirmationDialog.new()
	confirm.title = "确认删除"
	confirm.dialog_text = "确定要删除卡组「%s」吗？" % deck.deck_name
	confirm.ok_button_text = "删除"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func() -> void:
		CardDatabase.delete_deck(deck.id)
		confirm.queue_free()
	)
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()


func _on_back_pressed() -> void:
	GameManager.goto_main_menu()


func _configure_operation_panel() -> void:
	var title_label: Label = $ImportPanel/ImportBox/VBox/TitleLabel
	var hint_label: Label = $ImportPanel/ImportBox/VBox/HintLabel

	if _panel_mode == "sync_images":
		title_label.text = "同步卡图"
		hint_label.visible = false
		%UrlInput.visible = false
		%BtnDoImport.visible = false
	else:
		title_label.text = "导入卡组"
		hint_label.visible = true
		%UrlInput.visible = true
		%BtnDoImport.visible = true

	%BtnCloseImport.text = "关闭"


func _set_operation_busy(busy: bool) -> void:
	%BtnImport.disabled = busy
	%BtnSyncImages.disabled = busy
	%BtnBack.disabled = busy
