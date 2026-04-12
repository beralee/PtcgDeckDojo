## 卡组编辑器 - 逐张替换卡组中的卡牌
extends Control

## 分类标签定义：显示名 -> 匹配的 card_type 值列表
const CATEGORY_TABS: Array[Dictionary] = [
	{"label": "宝可梦", "types": ["Pokemon"]},
	{"label": "支援者", "types": ["Supporter"]},
	{"label": "物品", "types": ["Item"]},
	{"label": "道具", "types": ["Tool"]},
	{"label": "场地", "types": ["Stadium"]},
	{"label": "能量", "types": ["Basic Energy", "Special Energy"]},
]

## 宝可梦属性子分类：能量代码 -> 显示名
const ENERGY_TYPE_LABELS: Dictionary = {
	"R": "火", "W": "水", "G": "草", "L": "雷",
	"P": "超", "F": "斗", "D": "恶", "M": "钢", "N": "龙", "C": "无色",
}
## 属性展示顺序
const ENERGY_TYPE_ORDER: Array[String] = ["R", "W", "G", "L", "P", "F", "D", "M", "N", "C"]

## 测试用卡牌系列前缀，不在编辑器中展示
const EXCLUDED_SET_PREFIXES: Array[String] = ["UTEST"]

## 卡图尺寸（标准卡牌比例约 63:88）
const CARD_WIDTH := 100
const CARD_HEIGHT := 140
const POOL_GRID_COLUMNS := 5

## AI 优化方向选项
const AI_GOALS: Array[Dictionary] = [
	{"id": "opening", "label": "提升起手铺场能力", "desc": "优化基础宝可梦和检索卡配比，降低开局卡手概率"},
	{"id": "damage", "label": "提升伤害输出效率", "desc": "优化攻击线和能量加速，缩短击倒关键目标所需回合"},
	{"id": "sustain", "label": "增强后期续航能力", "desc": "补充资源回收和恢复手段，避免后期资源枯竭"},
	{"id": "energy", "label": "优化能量配比", "desc": "调整能量数量和类型，减少能量卡手或能量不足的情况"},
	{"id": "disrupt", "label": "增加干扰/控制手段", "desc": "加入手牌干扰、道具锁、场地压制等控制类卡牌"},
]

const COLOR_SELECTED := Color(0.3, 0.6, 1.0, 1.0)
const COLOR_NORMAL := Color(0.2, 0.22, 0.3, 1.0)
const COLOR_HOVER := Color(0.25, 0.27, 0.35, 1.0)
const COLOR_BORDER_SELECTED := Color(0.4, 0.7, 1.0, 1.0)

var _deck: DeckData = null
var _original_deck_id: int = -1
var _return_context: Dictionary = {}
var _dirty: bool = false

## 左侧选中的卡 UID（展开后每张卡一个 flat 索引）
var _selected_deck_index: int = -1
## 右侧选中的卡牌 UID
var _selected_pool_uid: String = ""

## 左侧当前激活的分类标签索引
var _deck_active_tab: int = 0
## 右侧当前激活的分类标签索引
var _pool_active_tab: int = 0

## 按分类分组的卡牌池：category_index -> Array[CardData]
var _pool_by_category: Array[Array] = []
## 按分类分组的卡组卡牌：category_index -> Array[Dictionary]
## 每项 = {"entry_index": int, "flat_index": int, "entry": Dictionary}
var _deck_by_category: Array[Array] = []

## 标签按钮引用
var _deck_tab_buttons: Array[Button] = []
var _pool_tab_buttons: Array[Button] = []

## AI 分析
const AI_TIMEOUT_SECONDS := 180.0
var _ai_client = preload("res://scripts/network/ZenMuxClient.gd").new()
var _ai_loading_dialog: AcceptDialog = null
var _ai_loading_bar: ProgressBar = null
var _ai_loading_elapsed_label: Label = null
var _ai_loading_start_time: float = 0.0
var _ai_loading_active: bool = false
## AI 建议与历史
var _ai_replacements: Array[Dictionary] = []
var _ai_summary: String = ""
var _ai_history: Array[Dictionary] = []

## 纹理缓存
var _texture_cache: Dictionary = {}
var _failed_texture_paths: Dictionary = {}


func _ready() -> void:
	%BtnSave.pressed.connect(_on_save_pressed)
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnReplace.pressed.connect(_on_replace_pressed)
	%BtnStrategy.pressed.connect(_on_strategy_pressed)
	%BtnAI.pressed.connect(_on_ai_pressed)
	%UnsavedDialog.confirmed.connect(_do_go_back)

	_original_deck_id = GameManager.consume_deck_editor_id()
	_return_context = GameManager.consume_deck_editor_return_context()
	if _original_deck_id < 0:
		_go_back_to_return_scene()
		return

	var source_deck := CardDatabase.get_deck(_original_deck_id)
	if source_deck == null:
		_go_back_to_return_scene()
		return

	_deck = DeckData.from_dict(source_deck.to_dict())
	%TitleLabel.text = "编辑卡组：%s" % _deck.deck_name

	_build_pool()
	_build_deck_categories()
	_build_tab_bar(%DeckTabBar, _deck_tab_buttons, true)
	_build_tab_bar(%PoolTabBar, _pool_tab_buttons, false)
	_refresh_deck_grid()
	_refresh_pool_grid()
	_update_footer()


# -- 分类构建 --

func _build_pool() -> void:
	var all_cards := CardDatabase.get_all_cards()
	_pool_by_category.clear()
	for _i: int in CATEGORY_TABS.size():
		_pool_by_category.append([])

	for card: CardData in all_cards:
		if _is_excluded_card(card):
			continue
		for i: int in CATEGORY_TABS.size():
			var types: Array = CATEGORY_TABS[i]["types"]
			if card.card_type in types:
				_pool_by_category[i].append(card)
				break

	for i: int in _pool_by_category.size():
		var arr: Array = _pool_by_category[i]
		arr.sort_custom(func(a: CardData, b: CardData) -> bool:
			return a.name < b.name
		)


func _is_excluded_card(card: CardData) -> bool:
	for prefix: String in EXCLUDED_SET_PREFIXES:
		if card.set_code.begins_with(prefix):
			return true
	return false


func _build_deck_categories() -> void:
	_deck_by_category.clear()
	for _i: int in CATEGORY_TABS.size():
		_deck_by_category.append([])

	var flat_index := 0
	for entry_idx: int in _deck.cards.size():
		var entry: Dictionary = _deck.cards[entry_idx]
		var card_type: String = entry.get("card_type", "")
		var count: int = entry.get("count", 0)
		var cat_idx := _category_for_type(card_type)
		for _c: int in count:
			_deck_by_category[cat_idx].append({
				"entry_index": entry_idx,
				"flat_index": flat_index,
				"entry": entry,
			})
			flat_index += 1


func _category_for_type(card_type: String) -> int:
	for i: int in CATEGORY_TABS.size():
		var types: Array = CATEGORY_TABS[i]["types"]
		if card_type in types:
			return i
	return 0


func _count_deck_cards_in_category(cat_idx: int) -> int:
	return _deck_by_category[cat_idx].size() if cat_idx < _deck_by_category.size() else 0


# -- 标签栏 --

func _build_tab_bar(tab_bar: HBoxContainer, buttons: Array[Button], is_deck: bool) -> void:
	buttons.clear()
	for child: Node in tab_bar.get_children():
		child.queue_free()

	var active := _deck_active_tab if is_deck else _pool_active_tab

	for i: int in CATEGORY_TABS.size():
		var btn := Button.new()
		var tab_label: String = CATEGORY_TABS[i]["label"]
		var count: int
		if is_deck:
			count = _count_deck_cards_in_category(i)
		else:
			count = _pool_by_category[i].size()
		btn.text = "%s(%d)" % [tab_label, count]
		btn.toggle_mode = true
		btn.button_pressed = (i == active)
		if is_deck:
			btn.pressed.connect(_on_deck_tab_pressed.bind(i))
		else:
			btn.pressed.connect(_on_pool_tab_pressed.bind(i))
		tab_bar.add_child(btn)
		buttons.append(btn)


func _on_deck_tab_pressed(tab_index: int) -> void:
	_deck_active_tab = tab_index
	for i: int in _deck_tab_buttons.size():
		_deck_tab_buttons[i].button_pressed = (i == _deck_active_tab)
	_refresh_deck_grid()


func _on_pool_tab_pressed(tab_index: int) -> void:
	_pool_active_tab = tab_index
	for i: int in _pool_tab_buttons.size():
		_pool_tab_buttons[i].button_pressed = (i == _pool_active_tab)
	_refresh_pool_grid()


# -- 左侧卡组网格 --

func _refresh_deck_grid() -> void:
	for child: Node in %DeckGrid.get_children():
		child.queue_free()

	%LeftTitle.text = "当前卡组 (%d张)" % _deck.total_cards

	if _deck_active_tab < 0 or _deck_active_tab >= _deck_by_category.size():
		return

	var items: Array = _deck_by_category[_deck_active_tab]
	for item: Dictionary in items:
		var entry: Dictionary = item["entry"]
		var flat_idx: int = item["flat_index"]
		var card_name: String = entry.get("name", "?")
		var set_code: String = entry.get("set_code", "")
		var card_index: String = entry.get("card_index", "")
		var is_selected := (flat_idx == _selected_deck_index)

		var tile := _create_card_tile(card_name, set_code, card_index, is_selected)
		tile.gui_input.connect(_on_deck_tile_input.bind(flat_idx, set_code, card_index))
		%DeckGrid.add_child(tile)


func _on_deck_tile_input(event: InputEvent, flat_index: int, set_code: String, card_index: String) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		var card := CardDatabase.get_card(set_code, card_index)
		if card != null:
			_show_card_detail(card)
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		_on_deck_card_pressed(flat_index)


func _on_deck_card_pressed(flat_index: int) -> void:
	if _selected_deck_index == flat_index:
		_selected_deck_index = -1
	else:
		_selected_deck_index = flat_index
	_restyle_deck_grid()
	_update_footer()


func _restyle_deck_grid() -> void:
	if _deck_active_tab < 0 or _deck_active_tab >= _deck_by_category.size():
		return
	var items: Array = _deck_by_category[_deck_active_tab]
	var idx := 0
	for child: Node in %DeckGrid.get_children():
		if child is PanelContainer:
			var is_selected := false
			if idx < items.size():
				is_selected = (int(items[idx]["flat_index"]) == _selected_deck_index)
			_apply_tile_style(child as PanelContainer, is_selected)
			idx += 1


# -- 右侧卡牌池网格 --

func _refresh_pool_grid() -> void:
	for child: Node in %PoolGrid.get_children():
		child.queue_free()

	if _pool_active_tab < 0 or _pool_active_tab >= _pool_by_category.size():
		return

	var cards: Array = _pool_by_category[_pool_active_tab]

	# 宝可梦分类（索引 0）按属性子分组
	if _pool_active_tab == 0:
		_refresh_pool_grid_pokemon(cards)
		return

	# 其他分类：平铺一个 GridContainer
	var grid := _create_pool_sub_grid()
	for card: CardData in cards:
		grid.add_child(_make_pool_tile(card))
	%PoolGrid.add_child(grid)


func _refresh_pool_grid_pokemon(cards: Array) -> void:
	# 按属性分组
	var by_energy: Dictionary = {}
	for card: CardData in cards:
		var etype: String = card.energy_type if card.energy_type != "" else "C"
		if not by_energy.has(etype):
			by_energy[etype] = []
		by_energy[etype].append(card)

	for etype: String in ENERGY_TYPE_ORDER:
		if not by_energy.has(etype):
			continue
		var group: Array = by_energy[etype]
		var label_text: String = ENERGY_TYPE_LABELS.get(etype, etype)

		var header := Label.new()
		header.text = "-- %s (%d) --" % [label_text, group.size()]
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		%PoolGrid.add_child(header)

		var grid := _create_pool_sub_grid()
		for card: CardData in group:
			grid.add_child(_make_pool_tile(card))
		%PoolGrid.add_child(grid)

	# 处理未知属性
	for etype: String in by_energy:
		if etype in ENERGY_TYPE_ORDER:
			continue
		var group: Array = by_energy[etype]
		var header := Label.new()
		header.text = "-- %s (%d) --" % [etype, group.size()]
		header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		%PoolGrid.add_child(header)

		var grid := _create_pool_sub_grid()
		for card: CardData in group:
			grid.add_child(_make_pool_tile(card))
		%PoolGrid.add_child(grid)


func _create_pool_sub_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = POOL_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	return grid


func _make_pool_tile(card: CardData) -> PanelContainer:
	var uid := card.get_uid()
	var is_selected := (uid == _selected_pool_uid)
	var tile := _create_card_tile(card.name, card.set_code, card.card_index, is_selected)
	tile.gui_input.connect(_on_pool_tile_input.bind(uid))
	return tile


func _on_pool_tile_input(event: InputEvent, uid: String) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		var card := _find_pool_card(uid)
		if card != null:
			_show_card_detail(card)
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		_on_pool_card_pressed(uid)


func _on_pool_card_pressed(uid: String) -> void:
	if _selected_pool_uid == uid:
		_selected_pool_uid = ""
	else:
		_selected_pool_uid = uid
	_restyle_pool_grid()
	_update_footer()


func _restyle_pool_grid() -> void:
	if _pool_active_tab < 0 or _pool_active_tab >= _pool_by_category.size():
		return
	# 收集所有 PanelContainer 子节点（可能嵌套在子 GridContainer 中）
	var all_tiles: Array[PanelContainer] = []
	_collect_pool_tiles(%PoolGrid, all_tiles)

	var cards: Array = _pool_by_category[_pool_active_tab]
	# 宝可梦分类需要按属性重排顺序匹配
	var ordered_cards: Array = cards
	if _pool_active_tab == 0:
		ordered_cards = _ordered_pokemon_cards(cards)

	for i: int in all_tiles.size():
		var is_selected := false
		if i < ordered_cards.size():
			is_selected = ((ordered_cards[i] as CardData).get_uid() == _selected_pool_uid)
		_apply_tile_style(all_tiles[i], is_selected)


func _collect_pool_tiles(node: Node, result: Array[PanelContainer]) -> void:
	for child: Node in node.get_children():
		if child is PanelContainer:
			result.append(child as PanelContainer)
		elif child is GridContainer:
			_collect_pool_tiles(child, result)


func _ordered_pokemon_cards(cards: Array) -> Array:
	var by_energy: Dictionary = {}
	for card: CardData in cards:
		var etype: String = card.energy_type if card.energy_type != "" else "C"
		if not by_energy.has(etype):
			by_energy[etype] = []
		by_energy[etype].append(card)

	var result: Array = []
	for etype: String in ENERGY_TYPE_ORDER:
		if by_energy.has(etype):
			result.append_array(by_energy[etype])
	for etype: String in by_energy:
		if etype not in ENERGY_TYPE_ORDER:
			result.append_array(by_energy[etype])
	return result


# -- 卡图块创建 --

func _create_card_tile(card_name: String, set_code: String, card_index: String, selected: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT + 20)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_tile_style(panel, selected)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(CARD_WIDTH - 8, CARD_HEIGHT - 8)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var texture := _load_card_texture(set_code, card_index)
	if texture != null:
		tex_rect.texture = texture
	else:
		# 无图时显示灰底占位
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(CARD_WIDTH - 8, CARD_HEIGHT - 8)
		tex_rect.texture = placeholder
	vbox.add_child(tex_rect)

	var label := Label.new()
	label.text = card_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(CARD_WIDTH - 8, 0)
	vbox.add_child(label)

	return panel


func _apply_tile_style(panel: PanelContainer, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = COLOR_SELECTED
		sb.border_color = COLOR_BORDER_SELECTED
		sb.set_border_width_all(3)
	else:
		sb.bg_color = COLOR_NORMAL
		sb.border_color = Color(0.3, 0.32, 0.4, 1.0)
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)


# -- 纹理加载 --

func _load_card_texture(set_code: String, card_index: String) -> Texture2D:
	var local_path := CardData.build_local_image_path(set_code, card_index)
	if local_path == "":
		return null

	var file_path := ProjectSettings.globalize_path(local_path)
	if not FileAccess.file_exists(file_path):
		return null

	if _texture_cache.has(file_path):
		return _texture_cache[file_path]
	if _failed_texture_paths.has(file_path):
		return null

	var image_bytes := FileAccess.get_file_as_bytes(file_path)
	if image_bytes.is_empty():
		_failed_texture_paths[file_path] = true
		return null

	var image := Image.new()
	var err := _load_image_from_buffer(image, image_bytes)
	if err != OK:
		_failed_texture_paths[file_path] = true
		return null

	var texture := ImageTexture.create_from_image(image)
	_texture_cache[file_path] = texture
	return texture


func _load_image_from_buffer(image: Image, image_bytes: PackedByteArray) -> int:
	if image_bytes.size() >= 12:
		if image_bytes[0] == 0x89 and image_bytes[1] == 0x50 and image_bytes[2] == 0x4E and image_bytes[3] == 0x47:
			return image.load_png_from_buffer(image_bytes)
		if image_bytes[0] == 0xFF and image_bytes[1] == 0xD8:
			return image.load_jpg_from_buffer(image_bytes)
		if image_bytes[0] == 0x52 and image_bytes[1] == 0x49 and image_bytes[2] == 0x46 and image_bytes[3] == 0x46:
			if image_bytes[8] == 0x57 and image_bytes[9] == 0x45 and image_bytes[10] == 0x42 and image_bytes[11] == 0x50:
				return image.load_webp_from_buffer(image_bytes)
	return ERR_FILE_UNRECOGNIZED


# -- 底部状态与替换 --

func _update_footer() -> void:
	var deck_name := _get_selected_deck_card_name()
	var pool_name := _get_selected_pool_card_name()

	var parts: PackedStringArray = []
	if deck_name != "":
		parts.append("替换：%s" % deck_name)
	if pool_name != "":
		parts.append("目标：%s" % pool_name)

	%SelectionLabel.text = "  ".join(parts) if parts.size() > 0 else ""

	var can_replace := deck_name != "" and pool_name != ""
	%BtnReplace.visible = can_replace
	if can_replace:
		%BtnReplace.text = "替换：%s → %s" % [deck_name, pool_name]


func _get_selected_deck_card_name() -> String:
	if _selected_deck_index < 0:
		return ""
	var flat := 0
	for entry: Dictionary in _deck.cards:
		var count: int = entry.get("count", 0)
		if _selected_deck_index < flat + count:
			return entry.get("name", "?")
		flat += count
	return ""


func _get_selected_pool_card_name() -> String:
	if _selected_pool_uid == "":
		return ""
	for cat: Array in _pool_by_category:
		for card: CardData in cat:
			if card.get_uid() == _selected_pool_uid:
				return card.name
	return ""


func _on_replace_pressed() -> void:
	if _selected_deck_index < 0 or _selected_pool_uid == "":
		return

	var pool_card := _find_pool_card(_selected_pool_uid)
	if pool_card == null:
		return

	var entry_index := _flat_index_to_entry_index(_selected_deck_index)
	if entry_index < 0:
		return

	_do_replace(entry_index, pool_card)


func _do_replace(entry_index: int, pool_card: CardData) -> void:
	var old_entry: Dictionary = _deck.cards[entry_index]
	var old_count: int = old_entry.get("count", 0)

	# 减少旧卡数量
	if old_count <= 1:
		_deck.cards.remove_at(entry_index)
	else:
		old_entry["count"] = old_count - 1

	# 增加新卡数量
	var new_uid := pool_card.get_uid()
	var found := false
	for entry: Dictionary in _deck.cards:
		var uid := "%s_%s" % [entry.get("set_code", ""), entry.get("card_index", "")]
		if uid == new_uid:
			entry["count"] = entry.get("count", 0) + 1
			found = true
			break

	if not found:
		_deck.cards.append({
			"set_code": pool_card.set_code,
			"card_index": pool_card.card_index,
			"count": 1,
			"card_type": pool_card.card_type,
			"name": pool_card.name,
			"effect_id": pool_card.effect_id,
			"name_en": pool_card.name_en,
		})

	_recalc_total()
	_dirty = true
	_selected_deck_index = -1
	_selected_pool_uid = ""
	if is_inside_tree():
		_build_deck_categories()
		_build_tab_bar(%DeckTabBar, _deck_tab_buttons, true)
		_refresh_deck_grid()
		_restyle_pool_grid()
		_update_footer()


func _recalc_total() -> void:
	var total := 0
	for entry: Dictionary in _deck.cards:
		total += int(entry.get("count", 0))
	_deck.total_cards = total


func _flat_index_to_entry_index(flat_index: int) -> int:
	var flat := 0
	for i: int in _deck.cards.size():
		var count: int = _deck.cards[i].get("count", 0)
		if flat_index < flat + count:
			return i
		flat += count
	return -1


func _find_pool_card(uid: String) -> CardData:
	for cat: Array in _pool_by_category:
		for card: CardData in cat:
			if card.get_uid() == uid:
				return card
	return null


# -- AI 分析 --

func _on_strategy_pressed() -> void:
	var win_size := get_viewport().get_visible_rect().size
	var dlg_h := int(win_size.y * 0.7)
	var text_h := dlg_h - 130  # 留出标题栏+提示+按钮+边距

	var dialog := AcceptDialog.new()
	dialog.title = "编辑打法思路：%s" % _deck.deck_name
	dialog.ok_button_text = "保存"

	var hint := Label.new()
	hint.text = "描述这套卡组的核心战术、关键卡牌配合、各对局要点。AI 分析时会参考此信息。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	dialog.add_child(hint)

	var text_edit := TextEdit.new()
	text_edit.text = _deck.strategy
	text_edit.custom_minimum_size = Vector2(600, text_h)
	text_edit.placeholder_text = "例：核心攻击手是XXex，通过YY加速能量，前两回合目标是展开ZZ线..."
	dialog.add_child(text_edit)

	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void:
		_deck.strategy = text_edit.text
		_dirty = true
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)


func _on_ai_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "AI 卡组分析"
	dialog.ok_button_text = "开始分析"
	dialog.dialog_hide_on_ok = false
	dialog.size = Vector2i(750, 600)

	var scroll := ScrollContainer.new()
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	scroll.offset_left = 8
	scroll.offset_top = 8
	scroll.offset_right = -8
	scroll.offset_bottom = -8
	dialog.add_child(scroll)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(root_vbox)

	# --- 针对卡组 ---
	var target_header := Label.new()
	target_header.text = "针对卡组（最多选2个，可选自身卡组用于内战优化）"
	target_header.add_theme_font_size_override("font_size", 16)
	root_vbox.add_child(target_header)

	var target_desc := Label.new()
	target_desc.text = "AI 会参考所选卡组的战术特点，给出针对性的调整建议。"
	target_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	target_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	root_vbox.add_child(target_desc)

	var deck_grid := GridContainer.new()
	deck_grid.columns = 3
	deck_grid.add_theme_constant_override("h_separation", 16)
	deck_grid.add_theme_constant_override("v_separation", 4)
	root_vbox.add_child(deck_grid)

	const MAX_TARGET_DECKS := 2
	var deck_checks: Array[CheckBox] = []
	var all_decks := CardDatabase.get_all_decks()
	for d: DeckData in all_decks:
		var cb := CheckBox.new()
		var suffix := " (本卡组)" if d.id == _original_deck_id else ""
		cb.text = "%s%s (%d张)" % [d.deck_name, suffix, d.total_cards]
		deck_grid.add_child(cb)
		deck_checks.append(cb)

	# 限制最多选 MAX_TARGET_DECKS 个
	for cb: CheckBox in deck_checks:
		cb.toggled.connect(func(_pressed: bool) -> void:
			var checked_count := 0
			for c: CheckBox in deck_checks:
				if c.button_pressed:
					checked_count += 1
			if checked_count > MAX_TARGET_DECKS:
				cb.set_pressed_no_signal(false)
		)

	if deck_checks.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（无卡组可选）"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		root_vbox.add_child(empty_label)

	# --- 分隔 ---
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	root_vbox.add_child(sep)

	# --- 优化方向 ---
	var goal_header := Label.new()
	goal_header.text = "优化方向（可多选或不选）"
	goal_header.add_theme_font_size_override("font_size", 16)
	root_vbox.add_child(goal_header)

	var goal_desc := Label.new()
	goal_desc.text = "选择希望 AI 重点关注的方向。不选则由 AI 自行判断。"
	goal_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	goal_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	root_vbox.add_child(goal_desc)

	var goal_grid := GridContainer.new()
	goal_grid.columns = 3
	goal_grid.add_theme_constant_override("h_separation", 16)
	goal_grid.add_theme_constant_override("v_separation", 4)
	root_vbox.add_child(goal_grid)

	var goal_checks: Array[CheckBox] = []
	for goal: Dictionary in AI_GOALS:
		var cb := CheckBox.new()
		cb.text = str(goal["label"])
		cb.tooltip_text = str(goal["desc"])
		goal_grid.add_child(cb)
		goal_checks.append(cb)

	add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func() -> void:
		var selected_decks: Array[DeckData] = []
		for i: int in deck_checks.size():
			if deck_checks[i].button_pressed and i < all_decks.size():
				selected_decks.append(all_decks[i])
		var selected_goals: Array[String] = []
		for i: int in goal_checks.size():
			if goal_checks[i].button_pressed and i < AI_GOALS.size():
				selected_goals.append(str(AI_GOALS[i]["id"]))
		dialog.queue_free()
		_run_ai_analysis(selected_decks, selected_goals)
	)
	dialog.canceled.connect(dialog.queue_free)


func _run_ai_analysis(target_decks: Array[DeckData], goals: Array[String]) -> void:
	var api_config: Dictionary = GameManager.get_battle_review_api_config()
	var endpoint: String = str(api_config.get("endpoint", ""))
	var api_key: String = str(api_config.get("api_key", ""))
	if endpoint == "" or api_key == "":
		_show_ai_result("AI 未配置。请在 user://battle_review_api.json 中设置 endpoint 和 api_key。")
		return

	_ai_client.set_timeout_seconds(maxf(float(api_config.get("timeout_seconds", AI_TIMEOUT_SECONDS)), AI_TIMEOUT_SECONDS))
	var payload := _build_ai_payload(api_config, target_decks, goals)

	_show_ai_loading()
	var err: int = _ai_client.request_json(
		self, endpoint, api_key, payload,
		_on_ai_response
	)
	if err != OK:
		_dismiss_ai_loading()
		_show_ai_result("AI 请求发送失败（错误码 %d）。请检查网络连接和 API 配置。" % err)


func _build_ai_payload(api_config: Dictionary, target_decks: Array[DeckData], goals: Array[String]) -> Dictionary:
	var system_prompt := _build_ai_system_prompt()
	var user_data := _build_ai_user_data(target_decks, goals)
	return {
		"model": str(api_config.get("model", "")),
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": JSON.stringify(user_data, "\t")},
		],
		"temperature": 0.3,
	}


func _build_ai_system_prompt() -> String:
	var lines: PackedStringArray = []
	lines.append("你是一名高水平PTCG构筑分析师。根据玩家卡组、目标环境和优化方向，给出具体替换建议。")
	lines.append("")
	lines.append("规则约束：")
	lines.append("- 卡组必须恰好 60 张")
	lines.append("- 同名卡最多 4 张（基础能量除外）")
	lines.append("- 不要修改超过 max_changes 指定的张数")
	lines.append("- 替换建议中加入的卡牌必须来自 available_pool")
	lines.append("")
	lines.append("ACE SPEC 规则（极其重要，必须严格遵守）：")
	lines.append("- 整副卡组最多只能带 1 张 ACE SPEC 卡（数据中 ace_spec=true）")
	lines.append("- 输入数据的 current_ace_spec 字段标明了当前卡组已有的 ACE SPEC 卡名（为空则没有）")
	lines.append("- 如果卡组已有 ACE SPEC 卡，想换另一张 ACE SPEC 卡，必须同时移除旧的 ACE SPEC")
	lines.append("- 即：一条替换中 remove_name 是旧 ACE SPEC、add_name 是新 ACE SPEC，这是唯一合法方式")
	lines.append("- 绝对不能在其他替换建议中出现\"加入 ACE SPEC 卡\"的情况（否则卡组会有 2 张 ACE SPEC，违规）")
	lines.append("- 如果不需要换 ACE SPEC，就完全不要涉及任何 ACE SPEC 卡")
	lines.append("")
	lines.append("输出前必须自检（逐条验证，不通过则修改建议直到通过）：")
	lines.append("1. 执行完所有 replacements 后，卡组中 ace_spec=true 的卡是否恰好 0 或 1 张？如果 >1 张则违规，必须删除多余的 ACE SPEC 替换")
	lines.append("2. 执行完所有 replacements 后，每张非基本能量卡的数量是否 <=4？如果 >4 则违规，必须调整 add_count")
	lines.append("3. 执行完所有 replacements 后，总卡数是否仍为 60？")
	lines.append("")
	lines.append("打法思路（strategy）字段说明：")
	lines.append("- 输入数据中 current_deck 和每套 target_deck 都可能附带 strategy 字段，由人工编写")
	lines.append("- 其中包含该卡组的核心战术、关键配合、各对局注意事项、单卡效果澄清等")
	lines.append("- 你必须仔细阅读并遵循这些信息，它们比你自身的卡牌知识更准确")
	lines.append("- 当前卡组的 strategy 描述了本卡组的打法——替换建议必须围绕这个核心战术，不能破坏核心引擎")
	lines.append("- 对手卡组的 strategy 描述了对手的打法——你要据此判断哪些卡在该对局中有效、哪些无效")
	lines.append("- 如果 strategy 中指出某张卡在特定对局无效（例如玛纳霏挡不住放指示物），你不得推荐该卡用于该对局")
	lines.append("- 如果选择了本卡组作为针对对象（内战），重点优化先后攻差异和镜像对局中的关键卡位")
	lines.append("- 如果 strategy 为空，则仅根据卡牌数据和通用 PTCG 知识分析，遇到不确定的效果交互请如实说明")
	lines.append("")
	lines.append("分析要求：")
	lines.append("1. 优先基于玩家给出的目标对局和优化方向")
	lines.append("2. 保持卡组核心骨架稳定")
	lines.append("3. 只给出一套方案，不分激进/保守")
	lines.append("4. 优先输出影响最大的 3~5 条替换")
	lines.append("5. 每条替换说明原因和代价")
	lines.append("6. 不确定的地方如实说明")
	lines.append("")
	lines.append("输出格式：严格返回以下 JSON（不要包裹在 markdown 代码块中）：")
	lines.append("{")
	lines.append("  \"summary\": \"总体改牌思路（1~3句话）\",")
	lines.append("  \"replacements\": [")
	lines.append("    {")
	lines.append("      \"remove_name\": \"要移除的卡名\",")
	lines.append("      \"remove_count\": 1,")
	lines.append("      \"add_name\": \"要加入的卡名\",")
	lines.append("      \"add_count\": 1,")
	lines.append("      \"reason\": \"简要原因和代价\"")
	lines.append("    }")
	lines.append("  ],")
	lines.append("  \"core_keep\": \"最不建议改动的核心部分（1~2句话）\"")
	lines.append("}")
	return "\n".join(lines)


func _build_ai_user_data(target_decks: Array[DeckData], goals: Array[String]) -> Dictionary:
	# 当前卡组卡表
	var deck_cards: Array[Dictionary] = []
	for entry: Dictionary in _deck.cards:
		var sc: String = entry.get("set_code", "")
		var ci: String = entry.get("card_index", "")
		var card_obj := CardDatabase.get_card(sc, ci)
		var item: Dictionary = {
			"name": entry.get("name", ""),
			"card_type": entry.get("card_type", ""),
			"count": entry.get("count", 0),
		}
		if card_obj != null and card_obj.is_ace_spec():
			item["ace_spec"] = true
		deck_cards.append(item)

	# 收集卡组中用到的能量类型
	var deck_energy_types: Dictionary = {}
	for entry: Dictionary in _deck.cards:
		var sc: String = entry.get("set_code", "")
		var ci: String = entry.get("card_index", "")
		var card := CardDatabase.get_card(sc, ci)
		if card != null and card.is_pokemon():
			if card.energy_type != "":
				deck_energy_types[card.energy_type] = true
			for atk: Dictionary in card.attacks:
				var cost: String = str(atk.get("cost", ""))
				for ch: String in cost:
					if ch != "C" and ch != "":
						deck_energy_types[ch] = true

	# 优化方向描述
	var goal_descs: Array[Dictionary] = []
	for gid: String in goals:
		for goal: Dictionary in AI_GOALS:
			if str(goal["id"]) == gid:
				goal_descs.append({"id": gid, "label": str(goal["label"]), "desc": str(goal["desc"])})
				break

	# 针对卡组卡表
	var target_deck_data: Array[Dictionary] = []
	for d: DeckData in target_decks:
		var cards: Array[Dictionary] = []
		for entry: Dictionary in d.cards:
			cards.append({
				"name": entry.get("name", ""),
				"card_type": entry.get("card_type", ""),
				"count": entry.get("count", 0),
			})
		var td: Dictionary = {"deck_name": d.deck_name, "cards": cards}
		if d.strategy != "":
			td["strategy"] = d.strategy
		target_deck_data.append(td)

	# 可选卡池：按需过滤（宝可梦只给相关属性 + 无色，训练家/能量全给）
	var pool: Array[Dictionary] = []
	for cat: Array in _pool_by_category:
		for card: CardData in cat:
			if card.is_pokemon():
				var et: String = card.energy_type if card.energy_type != "" else "C"
				if et != "C" and not deck_energy_types.has(et):
					continue
			var pool_item: Dictionary = {
				"name": card.name,
				"card_type": card.card_type,
				"energy_type": card.energy_type,
				"stage": card.stage,
				"hp": card.hp,
				"description": card.description,
			}
			if card.is_ace_spec():
				pool_item["ace_spec"] = true
			pool.append(pool_item)

	# 找出当前卡组的 ACE SPEC 卡名
	var current_ace_spec := ""
	for entry: Dictionary in _deck.cards:
		var sc2: String = entry.get("set_code", "")
		var ci2: String = entry.get("card_index", "")
		var c := CardDatabase.get_card(sc2, ci2)
		if c != null and c.is_ace_spec():
			current_ace_spec = c.name
			break

	return {
		"current_deck": {
			"deck_name": _deck.deck_name,
			"total_cards": _deck.total_cards,
			"cards": deck_cards,
			"strategy": _deck.strategy if _deck.strategy != "" else "(未填写)",
		},
		"current_ace_spec": current_ace_spec,
		"target_decks": target_deck_data,
		"optimization_goals": goal_descs,
		"available_pool": pool,
		"max_changes": 8,
	}


func _on_ai_response(response: Dictionary) -> void:
	_dismiss_ai_loading()

	var status: String = str(response.get("status", ""))
	var error_type: String = str(response.get("error_type", ""))
	var raw_body: String = str(response.get("raw_body", ""))

	# 真正的请求错误
	if status == "error" and error_type != "invalid_content_json":
		_show_ai_result("AI 分析失败：%s\n\n错误类型：%s" % [str(response.get("message", "")), error_type])
		return

	# 尝试将结果解析为结构化 JSON
	var data: Dictionary = {}
	if response.has("replacements"):
		# ZenMuxClient 成功解析了 JSON，response 本身就是 AI 输出
		data = response
	elif raw_body != "":
		# 可能是纯文本或 JSON 字符串
		var cleaned := raw_body.strip_edges()
		# 去掉可能的 markdown 代码块包裹
		if cleaned.begins_with("```"):
			var first_nl := cleaned.find("\n")
			if first_nl >= 0:
				cleaned = cleaned.substr(first_nl + 1)
			if cleaned.ends_with("```"):
				cleaned = cleaned.substr(0, cleaned.length() - 3).strip_edges()
		var parsed: Variant = JSON.parse_string(cleaned)
		if parsed is Dictionary:
			data = parsed
		else:
			_show_ai_result(raw_body)
			return

	if data.is_empty():
		_show_ai_result(JSON.stringify(response, "\t"))
		return

	# 解析成功，提取建议
	_ai_summary = str(data.get("summary", ""))
	_ai_replacements.clear()
	var replacements_raw: Variant = data.get("replacements", [])
	if replacements_raw is Array:
		for item: Variant in replacements_raw:
			if item is Dictionary:
				_ai_replacements.append(item as Dictionary)

	var core_keep: String = str(data.get("core_keep", ""))
	_refresh_ai_panel(core_keep)


func _show_ai_loading() -> void:
	_dismiss_ai_loading()
	_ai_loading_dialog = AcceptDialog.new()
	_ai_loading_dialog.title = "AI 分析中"
	_ai_loading_dialog.ok_button_text = "取消"
	_ai_loading_dialog.size = Vector2i(500, 220)

	var vbox := VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.offset_left = 16
	vbox.offset_top = 12
	vbox.offset_right = -16
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 12)
	_ai_loading_dialog.add_child(vbox)

	var tips: Array[String] = [
		"AI 正在分析卡组构筑，通常需要 30~90 秒...",
		"正在评估卡组骨架和能量曲线...",
		"正在对比环境卡组并生成替换建议...",
	]
	var tip_label := Label.new()
	tip_label.text = tips[randi() % tips.size()]
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(tip_label)

	_ai_loading_bar = ProgressBar.new()
	_ai_loading_bar.custom_minimum_size = Vector2(0, 22)
	_ai_loading_bar.max_value = AI_TIMEOUT_SECONDS
	_ai_loading_bar.value = 0
	vbox.add_child(_ai_loading_bar)

	_ai_loading_elapsed_label = Label.new()
	_ai_loading_elapsed_label.text = "已等待 0 秒"
	_ai_loading_elapsed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ai_loading_elapsed_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(_ai_loading_elapsed_label)

	add_child(_ai_loading_dialog)
	_ai_loading_dialog.popup_centered()
	_ai_loading_dialog.confirmed.connect(_dismiss_ai_loading)

	_ai_loading_start_time = Time.get_ticks_msec() / 1000.0
	_ai_loading_active = true


func _process(_delta: float) -> void:
	if not _ai_loading_active:
		return
	if _ai_loading_bar == null or not is_instance_valid(_ai_loading_bar):
		_ai_loading_active = false
		return
	var elapsed := Time.get_ticks_msec() / 1000.0 - _ai_loading_start_time
	_ai_loading_bar.value = minf(elapsed, AI_TIMEOUT_SECONDS)
	if _ai_loading_elapsed_label != null and is_instance_valid(_ai_loading_elapsed_label):
		_ai_loading_elapsed_label.text = "已等待 %d 秒" % int(elapsed)


func _dismiss_ai_loading() -> void:
	_ai_loading_active = false
	_ai_loading_bar = null
	_ai_loading_elapsed_label = null
	if _ai_loading_dialog != null and is_instance_valid(_ai_loading_dialog):
		_ai_loading_dialog.queue_free()
	_ai_loading_dialog = null


func _show_ai_result(text: String) -> void:
	# 纯文本回退：直接写入右侧面板
	_ai_summary = text
	_ai_replacements.clear()
	_refresh_ai_panel("")


func _refresh_ai_panel(core_keep: String) -> void:
	for child: Node in %AIList.get_children():
		child.queue_free()

	%RightTitle.text = "AI 建议"

	# 总体思路
	if _ai_summary != "":
		var summary_label := Label.new()
		summary_label.text = _ai_summary
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		summary_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		%AIList.add_child(summary_label)
		var sep := HSeparator.new()
		%AIList.add_child(sep)

	# 替换建议（带按钮）
	for i: int in _ai_replacements.size():
		var r: Dictionary = _ai_replacements[i]
		_add_ai_replacement_row(i, r)

	# 核心保留
	if core_keep != "":
		var sep2 := HSeparator.new()
		%AIList.add_child(sep2)
		var keep_title := Label.new()
		keep_title.text = "不建议改动："
		keep_title.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		%AIList.add_child(keep_title)
		var keep_label := Label.new()
		keep_label.text = core_keep
		keep_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		%AIList.add_child(keep_label)

	# 历史记录
	if not _ai_history.is_empty():
		var sep3 := HSeparator.new()
		%AIList.add_child(sep3)
		var hist_title := Label.new()
		hist_title.text = "-- 已执行 (%d) --" % _ai_history.size()
		hist_title.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		%AIList.add_child(hist_title)
		for h: Dictionary in _ai_history:
			var hl := Label.new()
			hl.text = "-%d %s  +%d %s" % [
				h.get("remove_count", 1), h.get("remove_name", "?"),
				h.get("add_count", 1), h.get("add_name", "?")]
			hl.add_theme_font_size_override("font_size", 12)
			hl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
			%AIList.add_child(hl)


func _add_ai_replacement_row(index: int, r: Dictionary) -> void:
	var remove_name: String = str(r.get("remove_name", ""))
	var remove_count: int = int(r.get("remove_count", 1))
	var add_name: String = str(r.get("add_name", ""))
	var add_count: int = int(r.get("add_count", 1))
	var reason: String = str(r.get("reason", ""))

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.2, 0.28, 1.0)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "-%d %s  +%d %s" % [remove_count, remove_name, add_count, add_name]
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	if reason != "":
		var reason_label := Label.new()
		reason_label.text = reason
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		reason_label.add_theme_font_size_override("font_size", 12)
		reason_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		vbox.add_child(reason_label)

	var btn := Button.new()
	btn.text = "执行替换"
	btn.custom_minimum_size = Vector2(0, 28)
	btn.pressed.connect(_on_ai_replace_pressed.bind(index))
	vbox.add_child(btn)

	%AIList.add_child(panel)


func _on_ai_replace_pressed(index: int) -> void:
	if index < 0 or index >= _ai_replacements.size():
		return
	var r: Dictionary = _ai_replacements[index]
	var remove_name: String = str(r.get("remove_name", ""))
	var remove_count: int = int(r.get("remove_count", 1))
	var add_name: String = str(r.get("add_name", ""))
	var add_count: int = int(r.get("add_count", 1))

	# 查找要加入的卡
	var add_card: CardData = null
	for cat: Array in _pool_by_category:
		for card: CardData in cat:
			if card.name == add_name:
				add_card = card
				break
		if add_card != null:
			break

	if add_card == null:
		push_warning("AI 建议的卡牌 '%s' 不在可选卡池中" % add_name)
		return

	# 逐张执行替换
	var replaced := 0
	for _i: int in remove_count:
		var entry_idx := _find_deck_entry_by_name(remove_name)
		if entry_idx < 0:
			break
		_do_replace(entry_idx, add_card)
		replaced += 1

	if replaced > 0:
		# 记录历史
		_ai_history.append({
			"remove_name": remove_name,
			"remove_count": replaced,
			"add_name": add_name,
			"add_count": replaced,
		})
		# 从建议列表移除已执行的
		_ai_replacements.remove_at(index)
		# 刷新右侧面板
		var core_keep := ""
		_refresh_ai_panel(core_keep)


func _find_deck_entry_by_name(card_name: String) -> int:
	for i: int in _deck.cards.size():
		if str(_deck.cards[i].get("name", "")) == card_name:
			return i
	return -1


# -- 卡牌详情弹窗 --

func _show_card_detail(card: CardData) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = card.name
	dialog.ok_button_text = "关闭"
	dialog.size = Vector2i(500, 480)

	var scroll := ScrollContainer.new()
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	scroll.offset_left = 8
	scroll.offset_top = 8
	scroll.offset_right = -8
	scroll.offset_bottom = -8
	dialog.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	# 卡名与基本信息
	var header := Label.new()
	header.text = card.name
	header.add_theme_font_size_override("font_size", 20)
	content.add_child(header)

	var meta_parts: PackedStringArray = []
	meta_parts.append(card.card_type)
	if card.mechanic != "":
		meta_parts.append(card.mechanic)
	if card.set_code != "":
		meta_parts.append("%s %s" % [card.set_code, card.card_index])
	if card.rarity != "":
		meta_parts.append(card.rarity)
	var meta_label := Label.new()
	meta_label.text = " | ".join(meta_parts)
	meta_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content.add_child(meta_label)

	# 宝可梦专属信息
	if card.is_pokemon():
		_add_separator(content)
		var stat_parts: PackedStringArray = []
		stat_parts.append("HP %d" % card.hp)
		stat_parts.append("属性: %s" % _energy_display(card.energy_type))
		stat_parts.append("阶段: %s" % card.stage)
		stat_parts.append("撤退: %d" % card.retreat_cost)
		var stat_label := Label.new()
		stat_label.text = " | ".join(stat_parts)
		content.add_child(stat_label)

		if card.evolves_from != "":
			var evo_label := Label.new()
			evo_label.text = "从 %s 进化" % card.evolves_from
			content.add_child(evo_label)

		var weakness_text := ""
		if card.weakness_energy != "":
			weakness_text = "弱点: %s %s" % [_energy_display(card.weakness_energy), card.weakness_value]
		var resist_text := ""
		if card.resistance_energy != "":
			resist_text = "抗性: %s %s" % [_energy_display(card.resistance_energy), card.resistance_value]
		if weakness_text != "" or resist_text != "":
			var wr_label := Label.new()
			wr_label.text = "  ".join([weakness_text, resist_text]).strip_edges()
			content.add_child(wr_label)

		# 特性
		for ab: Dictionary in card.abilities:
			_add_separator(content)
			var ab_title := Label.new()
			ab_title.text = "[特性] %s" % ab.get("name", "")
			ab_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			content.add_child(ab_title)
			if ab.get("text", "") != "":
				var ab_text := Label.new()
				ab_text.text = str(ab.get("text", ""))
				ab_text.autowrap_mode = TextServer.AUTOWRAP_WORD
				content.add_child(ab_text)

		# 招式
		for atk: Dictionary in card.attacks:
			_add_separator(content)
			var cost_str: String = str(atk.get("cost", ""))
			var dmg_str: String = str(atk.get("damage", ""))
			var atk_header := Label.new()
			var parts: PackedStringArray = []
			if cost_str != "":
				parts.append("[%s]" % cost_str)
			parts.append(str(atk.get("name", "")))
			if dmg_str != "":
				parts.append(dmg_str)
			atk_header.text = " ".join(parts)
			atk_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
			content.add_child(atk_header)
			if atk.get("text", "") != "":
				var atk_text := Label.new()
				atk_text.text = str(atk.get("text", ""))
				atk_text.autowrap_mode = TextServer.AUTOWRAP_WORD
				content.add_child(atk_text)

	# 训练家/能量描述
	if card.description != "":
		_add_separator(content)
		var desc := Label.new()
		desc.text = card.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(desc)

	# 效果 ID
	if card.effect_id != "":
		_add_separator(content)
		var eid := Label.new()
		eid.text = "效果ID: %s" % card.effect_id
		eid.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content.add_child(eid)

	# 英文名
	if card.name_en != "":
		var en_label := Label.new()
		en_label.text = "英文名: %s" % card.name_en
		en_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content.add_child(en_label)

	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _add_separator(container: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	container.add_child(sep)


func _energy_display(energy_code: String) -> String:
	return ENERGY_TYPE_LABELS.get(energy_code, energy_code)


# -- 保存与返回 --

func _on_save_pressed() -> void:
	if _deck == null:
		return
	CardDatabase.save_deck(_deck)
	_dirty = false


func _on_back_pressed() -> void:
	if _dirty:
		%UnsavedDialog.popup_centered()
	else:
		_do_go_back()


func _do_go_back() -> void:
	_go_back_to_return_scene()


func _go_back_to_return_scene() -> void:
	if str(_return_context.get("return_scene", "")) == "battle_setup":
		GameManager.goto_battle_setup()
		return
	GameManager.goto_deck_manager()
