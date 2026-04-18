extends Camera3D

@export var player_path: NodePath
@export var normal_offset := Vector3(0, 12, 2)
@export var slow_offset := Vector3(0, 12, 6)
@export var follow_smooth: float = 5.0

var player: Node3D
var current_offset: Vector3

func _ready():
	player = get_node(player_path)
	current_offset = normal_offset

func _physics_process(delta):
	if player == null:
		return

	var target_offset = normal_offset

	if Input.is_action_pressed("Car_S"):
		target_offset = slow_offset

	current_offset = current_offset.lerp(target_offset, follow_smooth * delta)
	global_position = global_position.lerp(
		player.global_position + current_offset,
		follow_smooth * delta
	)
