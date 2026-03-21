## 投币动画 - 展示硬币翻转并落定到指定结果
class_name CoinFlipAnimator
extends Control

const HEADS_TEXTURE_PATH := "res://assets/ui/coin_heads.png"
const TAILS_TEXTURE_PATH := "res://assets/ui/coin_tails.png"

## 动画完成信号
signal animation_finished()

## 硬币显示尺寸
var coin_display_size: float = 180.0
## 翻转总次数（快速交替正反面模拟旋转）
var flip_count: int = 10
## 每次翻转时长（逐渐变慢）
var base_flip_duration: float = 0.06

var _heads_texture: Texture2D = null
var _tails_texture: Texture2D = null
var _coin_sprite: TextureRect = null
var _result_label: Label = null
var _tween: Tween = null


func _ready() -> void:
	_heads_texture = load(HEADS_TEXTURE_PATH) as Texture2D
	_tails_texture = load(TAILS_TEXTURE_PATH) as Texture2D
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	visible = false


func _build_ui() -> void:
	# 半透明背景遮罩（铺满全屏）
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# 居中容器
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# 硬币图像
	_coin_sprite = TextureRect.new()
	_coin_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_coin_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_coin_sprite.custom_minimum_size = Vector2(coin_display_size, coin_display_size)
	_coin_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _heads_texture != null:
		_coin_sprite.texture = _heads_texture
	vbox.add_child(_coin_sprite)

	# 结果文字
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 24)
	_result_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45))
	_result_label.text = ""
	vbox.add_child(_result_label)


## 播放投币动画，result=true 表示正面，false 表示反面
func play(result: bool) -> void:
	visible = true
	_result_label.text = ""

	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()

	# 确保从正常状态开始
	_coin_sprite.texture = _heads_texture if _heads_texture != null else _tails_texture
	_coin_sprite.pivot_offset = _coin_sprite.size / 2.0
	_coin_sprite.scale = Vector2.ONE

	# 硬币快速翻转：scale.x 从 1 -> 0 -> 1 模拟翻面
	var showing_heads := true
	for i: int in flip_count:
		var is_last: bool = i == flip_count - 1
		var next_heads: bool
		if is_last:
			next_heads = result
		else:
			next_heads = not showing_heads

		# 逐渐变慢
		var duration: float = base_flip_duration + float(i) * 0.02

		# 压扁到侧面
		_tween.tween_property(_coin_sprite, "scale:x", 0.05, duration * 0.5).set_trans(Tween.TRANS_SINE)
		# 在最窄时切换贴图
		var target_heads: bool = next_heads
		_tween.tween_callback(func() -> void:
			if target_heads and _heads_texture != null:
				_coin_sprite.texture = _heads_texture
			elif not target_heads and _tails_texture != null:
				_coin_sprite.texture = _tails_texture
		)
		# 展开回来
		_tween.tween_property(_coin_sprite, "scale:x", 1.0, duration * 0.5).set_trans(Tween.TRANS_SINE)

		showing_heads = next_heads

	# 落定：轻弹放大 + 显示结果文字
	_tween.tween_property(_coin_sprite, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(_coin_sprite, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void:
		_result_label.text = "正面" if result else "反面"
	)
	# 让玩家看清结果
	_tween.tween_interval(0.9)
	_tween.tween_callback(func() -> void:
		visible = false
		animation_finished.emit()
	)
