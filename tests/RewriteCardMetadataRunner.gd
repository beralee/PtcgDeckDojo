extends SceneTree


func _initialize() -> void:
	var db := get_root().get_node_or_null("CardDatabase")
	if db == null:
		print("CardDatabase autoload not available.")
		quit(1)
		return

	var cards: Array = db.get_all_cards()
	print("Rewriting metadata for %d cards..." % cards.size())
	for card in cards:
		if card == null:
			continue
		db.cache_card(card)
	print("Done.")
	quit(0)
