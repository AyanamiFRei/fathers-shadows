extends Node3D

@export var car_speed: float = randfn(11.0, 2.0)
@export var same_direction: bool = true

# Дистанции для адаптации скорости
const DETECTION_RANGE = 50.0  # дальность обнаружения машины впереди
const BRAKE_DISTANCE  = 30.0  # начало торможения
const SAFE_DISTANCE   =  10.0  # минимальный зазор

var player_speed: float = 10.0
var current_speed: float

func _ready() -> void:
	add_to_group("traffic")
	current_speed = car_speed
	if not same_direction:
		rotation.y = deg_to_rad(180)

func _process(delta: float) -> void:
	_adapt_speed(delta)

	var relative_speed: float
	if same_direction:
		relative_speed = player_speed - current_speed
	else:
		relative_speed = player_speed + current_speed

	position.z += relative_speed * delta

func _adapt_speed(delta: float) -> void:
	var car_ahead := _find_car_ahead()

	if car_ahead == null:
		# Плавно возвращаем базовую скорость
		current_speed = move_toward(current_speed, car_speed, 2.0 * delta)
		return

	var dist := _distance_to(car_ahead)

	if dist < SAFE_DISTANCE:
		# Слишком близко — встаём вровень со скоростью впередиидущего
		current_speed = car_ahead.current_speed
	elif dist < BRAKE_DISTANCE:
		# Начинаем тормозить: чем ближе, тем сильнее
		var t := (dist - SAFE_DISTANCE) / (BRAKE_DISTANCE - SAFE_DISTANCE)
		var target := lerpf(car_ahead.current_speed, car_speed, t)
		current_speed = move_toward(current_speed, target, 4.0 * delta)
	else:
		# Далеко — едем в своём темпе
		current_speed = move_toward(current_speed, car_speed, 2.0 * delta)

func _find_car_ahead() -> Node:
	var best: Node3D  = null
	var best_dist: float = DETECTION_RANGE

	for node in get_tree().get_root().get_children():
		if node == self:
			continue
		# Только машины того же типа (того же скрипта)
		if not node.get_script() == get_script():
			continue
		# Та же полоса
		if abs(node.global_position.x - global_position.x) > 1.0:
			continue

		var dist := _distance_to(node)
		if dist < 0.0 or dist >= best_dist:
			continue  # сзади или слишком далеко

		best_dist = dist
		best      = node

	return best

# Возвращает дистанцию до узла впереди в направлении движения.
# Отрицательное значение означает, что узел сзади.
func _distance_to(other: Node) -> float:
	var dz: float = other.global_position.z - global_position.z
	return dz if same_direction else -dz  # было наоборот
