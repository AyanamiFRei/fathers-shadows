extends Node

@export var player_path: NodePath
@export var dialogue_manager_path: NodePath
@export var collision_loyalty_penalty: int = -3

var player = null
var dialogue_manager = null


func _ready() -> void:
	player = get_node_or_null(player_path)
	dialogue_manager = get_node_or_null(dialogue_manager_path)

	print("player = ", player)
	print("dialogue_manager = ", dialogue_manager)

	if player == null:
		print("LoyaltyCollisionHandler: player not found")
		return

	if dialogue_manager == null:
		print("LoyaltyCollisionHandler: dialogue_manager not found")
		return

	if not player.has_signal("traffic_collision"):
		print("LoyaltyCollisionHandler: player has no traffic_collision signal")
		return

	player.traffic_collision.connect(_on_player_traffic_collision)
	print("LoyaltyCollisionHandler: connected")


func _on_player_traffic_collision() -> void:
	print("collision received in handler")

	if dialogue_manager.current_npc_id.is_empty():
		print("current_npc_id is empty")
		return

	if dialogue_manager.loyalty_state == null:
		print("loyalty_state is null")
		return

	dialogue_manager.loyalty_state.change_loyalty(
		dialogue_manager.current_npc_id,
		collision_loyalty_penalty
	)

	dialogue_manager.update_loyalty_ui()
	print("loyalty changed for ", dialogue_manager.current_npc_id)
