extends Camera3D

@export var player_path: NodePath
@export var normal_offset := Vector3(0, 12, 8)
@export var slow_offset   := Vector3(0, 12, 10)
@export var follow_smooth: float = 5.0
@export var catch_up_smooth: float = 2.0  # жёсткость резинки

var player: Node3D
var current_offset: Vector3

func _ready():
	player = get_node(player_path)
	current_offset = normal_offset
	global_position = player.global_position + current_offset

func _physics_process(delta):
	if player == null:
		return

	var target_offset = slow_offset if Input.is_action_pressed("Car_S") else normal_offset
	current_offset = current_offset.lerp(target_offset, follow_smooth * delta)

	global_position = Vector3(
		current_offset.x,
		player.global_position.y + current_offset.y,
		lerpf(global_position.z, player.global_position.z + current_offset.z, catch_up_smooth * delta)
	)
