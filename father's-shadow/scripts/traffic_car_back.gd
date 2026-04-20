extends Node3D

@export var car_speed: float = randfn(11.0, 2.0)
@export var same_direction: bool = false

var player_speed: float = 10.0

func _ready():
	if not same_direction:
		rotation.y = deg_to_rad(180)
