extends Node3D

@export var car_speed: float = randfn(11.0, 2.0)
@export var same_direction: bool = false

var player_speed: float = 10.0

func _ready():
	if not same_direction:
		rotation.y = deg_to_rad(180)

func _process(delta):
	var relative_speed: float
	
	if same_direction:
		relative_speed = player_speed - car_speed
	else:
		relative_speed = player_speed + car_speed
	
	position.z += relative_speed * delta
