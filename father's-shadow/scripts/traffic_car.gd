extends Node3D

@export var car_speed: float = randfn(9.0, 2.0)
@export var same_direction: bool = true

const DETECTION_RANGE := 50.0
const BRAKE_DISTANCE  := 30.0
const SAFE_DISTANCE   := 20.0

const RETURN_ACCEL := 2.0
const BRAKE_ACCEL  := 4.0
const LANE_EPSILON := 1.0

# --- Отброс при столкновении (только для встречных, same_direction = false) ---
# Импульс должен быть БОЛЬШЕ car_speed, иначе машина только тормозит, но не едет назад
const BOUNCE_IMPULSE := 11.0
const BOUNCE_DECAY   := 28.0
var _bounce_z: float = 0.0

var current_speed: float


func _ready() -> void:
	add_to_group("traffic")
	current_speed = car_speed

	if not same_direction:
		rotation.y = deg_to_rad(180)


func _process(delta: float) -> void:
	_adapt_speed(delta)

	# Затухание импульса
	if _bounce_z != 0.0:
		_bounce_z = move_toward(_bounce_z, 0.0, BOUNCE_DECAY * delta)

	# Абсолютное движение.
	# Для встречной: (current_speed + _bounce_z) < 0  =>  машина едет назад
	if same_direction:
		position.z -= (current_speed + _bounce_z) * delta
	else:
		position.z += (current_speed + _bounce_z) * delta


# Вызывается игроком при столкновении
func apply_bounce() -> void:
	if same_direction:
		_bounce_z = -BOUNCE_IMPULSE*2   # отрицательный → перекрывает current_speed
	else:
		_bounce_z = BOUNCE_IMPULSE


func _adapt_speed(delta: float) -> void:
	var car_ahead := _find_car_ahead()

	if car_ahead == null:
		current_speed = move_toward(current_speed, car_speed, RETURN_ACCEL * delta)
		return

	var dist := _forward_distance_to(car_ahead)

	if dist <= SAFE_DISTANCE:
		current_speed = move_toward(current_speed, car_ahead.current_speed, BRAKE_ACCEL * delta)
	elif dist < BRAKE_DISTANCE:
		var t := inverse_lerp(SAFE_DISTANCE, BRAKE_DISTANCE, dist)
		var target_speed := lerpf(car_ahead.current_speed, car_speed, t)
		current_speed = move_toward(current_speed, target_speed, BRAKE_ACCEL * delta)
	else:
		current_speed = move_toward(current_speed, car_speed, RETURN_ACCEL * delta)


func _find_car_ahead() -> Node3D:
	var best: Node3D = null
	var best_dist := DETECTION_RANGE

	for node in get_tree().get_nodes_in_group("traffic"):
		if node == self:
			continue
		if not (node is Node3D):
			continue
		if node.get_script() != get_script():
			continue
		if node.same_direction != same_direction:
			continue
		if abs(node.global_position.x - global_position.x) > LANE_EPSILON:
			continue

		var dist := _forward_distance_to(node)
		if dist <= 0.0:
			continue
		if dist >= best_dist:
			continue

		best_dist = dist
		best = node

	return best


func _forward_distance_to(other: Node3D) -> float:
	var dz := other.global_position.z - global_position.z

	if same_direction:
		return dz
	else:
		return -dz
