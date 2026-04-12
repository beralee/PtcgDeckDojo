class_name AutoloadResolver
extends RefCounted


static func get_autoload(name: String) -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree := main_loop as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("/root/%s" % name))


static func get_card_database() -> Node:
	return get_autoload("CardDatabase")


static func get_game_manager() -> Node:
	return get_autoload("GameManager")


static func get_battle_music_manager() -> Node:
	return get_autoload("BattleMusicManager")
