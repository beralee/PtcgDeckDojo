extends SceneTree

const CARD_IMAGE_DOWNLOADER := preload("res://scripts/network/CardImageDownloader.gd")

var _syncer = null


func _initialize() -> void:
	print("Starting cached card image sync...")
	_syncer = CARD_IMAGE_DOWNLOADER.new()
	root.add_child(_syncer)
	_syncer.progress.connect(_on_progress)
	_syncer.completed.connect(_on_completed)
	_syncer.failed.connect(_on_failed)
	call_deferred("_start")


func _start() -> void:
	_syncer.sync_cached_cards()


func _on_progress(current: int, total: int, message: String) -> void:
	print("[%d/%d] %s" % [current, total, message])


func _on_completed(stats: Dictionary, errors: PackedStringArray) -> void:
	print(
		"Image sync finished. total=%d downloaded=%d updated=%d skipped=%d" % [
			int(stats.get("total", 0)),
			int(stats.get("downloaded", 0)),
			int(stats.get("updated", 0)),
			int(stats.get("skipped", 0)),
		]
	)
	for err: String in errors:
		print("WARN: %s" % err)
	quit(0 if errors.is_empty() else 1)


func _on_failed(error_message: String) -> void:
	print("ERROR: %s" % error_message)
	quit(1)
