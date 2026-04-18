extends CharacterBody3D

@export var base_speed: float = 10.0
@export var boost_speed: float = 30.0
@export var slow_speed: float = 10.0

@export var lane_change_speed: float = 10.0
@export var road_half_width: float = 6.0

var current_speed: float

func _ready():
	current_speed = base_speed
	

func _physics_process(delta):
	
	handle_speed()
	handle_side_movement()
	handle_forward_movement()
	move_and_slide()

func handle_speed():
	if Input.is_action_pressed("Car_W"): # W
		current_speed = boost_speed
	elif Input.is_action_pressed("Car_S"): # S
		current_speed = slow_speed
	else:
		current_speed = base_speed

func handle_side_movement():
	var side_input := 0.0

	if Input.is_action_pressed("Car_A"): # A
		side_input += 1.0
	if Input.is_action_pressed("Car_D"): # D
		
		
		side_input -= 1.0

	velocity.x = side_input * lane_change_speed

	# Ограничение по ширине дороги
	if position.x <= -road_half_width and velocity.x < 0.0:
		velocity.x = 0.0
	if position.x >= road_half_width and velocity.x > 0.0:
		velocity.x = 0.0

func handle_forward_movement():
	# Пусть машина всегда едет вперёд по оси Z
	# Если у тебя дорога в другую сторону, поменяй знак
	velocity.z = current_speed
