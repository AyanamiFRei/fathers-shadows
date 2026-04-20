extends CharacterBody3D

@export var base_speed: float = 10.0
@export var boost_speed: float = 30.0
@export var slow_speed: float = 10.0

@export var lane_change_speed: float = 10.0
@export var road_half_width: float = 6.0

@export var path_search_distance: float = 150.0

# Радиус «достижения» первой точки пути перед тем как начать следовать кривой
@export var path_reach_threshold: float = 1.5

var current_speed: float

# --- End animation ---
enum Phase { NONE, STRAIGHT_TO_PATH, FOLLOW_PATH }
var phase: Phase = Phase.NONE

var path_node: Path3D = null
var path_progress: float = 0.0
var path_start_world: Vector3  # первая точка пути в мировом пространстве


func _ready():
	current_speed = base_speed


func _physics_process(delta):
	match phase:
		Phase.STRAIGHT_TO_PATH:
			_drive_straight_to_path()
		Phase.FOLLOW_PATH:
			_follow_path()
		_:
			handle_speed()
			handle_side_movement()
			handle_forward_movement()
			move_and_slide()


# ──────────────────────────────────────────────
#  Обычное управление
# ──────────────────────────────────────────────

func handle_speed():
	if Input.is_action_pressed("Car_W"):
		current_speed = boost_speed
	elif Input.is_action_pressed("Car_S"):
		current_speed = slow_speed
	else:
		current_speed = base_speed


func handle_side_movement():
	var side_input := 0.0
	if Input.is_action_pressed("Car_A"):
		side_input += 1.0
	if Input.is_action_pressed("Car_D"):
		side_input -= 1.0

	velocity.x = side_input * lane_change_speed

	if position.x <= -road_half_width and velocity.x < 0.0:
		velocity.x = 0.0
	if position.x >= road_half_width and velocity.x > 0.0:
		velocity.x = 0.0


func handle_forward_movement():
	velocity.z = base_speed


# ──────────────────────────────────────────────
#  Финальная анимация
# ──────────────────────────────────────────────

func end_anim():
	print("END")

	path_node = _find_nearest_path3d_ahead()
	if path_node == null:
		push_error("player_car: Path3D впереди не найден!")
		return

	# Первая точка кривой в мировом пространстве
	path_start_world = path_node.to_global(path_node.curve.sample_baked(0.0, true))
	path_progress    = 0.0

	phase = Phase.STRAIGHT_TO_PATH


# Этап 1 — едем прямо (только вперёд, без боков) до первой точки пути
func _drive_straight_to_path():
	velocity.x = 0.0
	velocity.z = base_speed
	move_and_slide()

	# Переключаемся, когда доехали до Z первой точки пути
	if global_position.z >= path_start_world.z - path_reach_threshold:
		# Сразу разворачиваем машину согласно направлению пути
		var path_transform := path_node.curve.sample_baked_with_rotation(path_progress, true, false)
		global_basis = (path_node.global_transform * path_transform).basis
		phase = Phase.FOLLOW_PATH


# Этап 2 — едем по кривой
func _follow_path():
	path_progress += base_speed * get_physics_process_delta_time()
	path_progress = minf(path_progress, path_node.curve.get_baked_length())

	# Позиция и поворот из кривой
	var path_transform := path_node.curve.sample_baked_with_rotation(path_progress, true, false)
	var world_transform := path_node.global_transform * path_transform

	var target_pos := world_transform.origin
	var direction  := (target_pos - global_position).normalized()

	velocity = direction * base_speed
	global_basis = world_transform.basis  # машина смотрит вдоль пути
	move_and_slide()


# ──────────────────────────────────────────────
#  Поиск ближайшего Path3D впереди
# ──────────────────────────────────────────────

func _find_nearest_path3d_ahead() -> Path3D:
	var forward := -global_transform.basis.z
	var all_paths: Array[Path3D] = []
	_collect_all_paths(get_tree().current_scene, all_paths)

	var best_path: Path3D = null
	var best_dist: float  = INF

	for p in all_paths:
		var closest_world := p.to_global(p.curve.get_closest_point(p.to_local(global_position)))
		var to_path       := closest_world - global_position
		var dist          := to_path.length()

		if dist > path_search_distance:
			continue
		if forward.dot(to_path.normalized()) < 0.0:
			continue
		if dist < best_dist:
			best_dist = dist
			best_path = p

	return best_path


func _collect_all_paths(node: Node, result: Array[Path3D]) -> void:
	if node is Path3D:
		result.append(node as Path3D)
	for child in node.get_children():
		_collect_all_paths(child, result)


# ──────────────────────────────────────────────
#  Прочее
# ──────────────────────────────────────────────

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.get_class() == "CharacterBody3D":
		body.queue_free()
