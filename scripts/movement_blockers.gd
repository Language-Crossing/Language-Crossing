class_name MovementBlockers
extends RefCounted

## UI that should freeze the player (dialogue, the dictionary) joins this group.
## While any member is visible, the player can't move or start a new conversation.
const GROUP := &"blocks_player_movement"


static func register(node: Node) -> void:
	node.add_to_group(GROUP)


static func is_blocking(tree: SceneTree) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		if node is CanvasItem and node.is_visible_in_tree():
			return true
	return false
