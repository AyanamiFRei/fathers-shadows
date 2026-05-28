extends CharacterBody3D

signal turning_started  # испускается при переходе в Phase.FOLLOW_PATH

@export var base_speed: float = 13.0
@export var boost_speed: float = 30.0
@export var slow_speed: float = 7.0

@export var lane_change_speed: float = 10.0
@export var road_half_width: float = 6.0

@export var path_search_distance: float = 150.0

# Радиус «достижения» первой точки пути перед тем как начать следовать кривой
@export var path_reach_threshold: float = 1.5

@export var ColShape: CollisionShape3D

# --- Торможение перед трафиком во время финальной анимации ---
# Дистанция, с которой начинается торможение
@export var traffic_slow_distance: float = 12.0
# Минимальная дистанция до машины впереди (стоп-дистанция)
@export var traffic_stop_distance: float = 5.0

var current_speed: float

# --- End animation ---
enum Phase { NONE, STRAIGHT_TO_PATH, FOLLOW_PATH }
var phase: Phase = Phase.NONE

var path_node: Path3D = null
var path_progress: float = 0.0
var path_start_world: Vector3  # первая точка пути в мировом пространстве

# --- Столкновение с трафиком ---
# Импульс должен быть БОЛЬШЕ base_speed, чтобы velocity.z стал отрицательным (назад)
const PUSHBACK_IMPULSE  := 14.0
const PUSHBACK_DECAY    := 35.0   # за ~0.7 с импульс затухает до нуля
const HIT_COOLDOWN_TIME := 0.5
var _pushback_velocity: float = 0.0
var _hit_cooldown: float = 0.0

@export var ambient_sound: AudioStream
var ambient_vol: float = 6.0


func _ready():
	current_speed = base_speed
	ColShape.disabled = false
	
	if ambient_sound:
		var ambient_player = AudioStreamPlayer.new()
		ambient_player.volume_db = ambient_vol
		ambient_player.stream = ambient_sound
		ambient_player.bus = "Ambient"
		add_child(ambient_player)
		ambient_player.play()
	


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
			_apply_pushback(delta)
			move_and_slide()
			_check_traffic_collision()


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
	velocity.z = current_speed


# ──────────────────────────────────────────────
#  Физика отброса при столкновении
# ──────────────────────────────────────────────

func _apply_pushback(delta: float) -> void:
	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta
	if _pushback_velocity > 0.0:
		# Вычитаем из velocity.z — если импульс > current_speed, игрок едет назад
		velocity.z -= _pushback_velocity
		_pushback_velocity = move_toward(_pushback_velocity, 0.0, PUSHBACK_DECAY * delta)


func _check_traffic_collision() -> void:
	if _hit_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		if not collider.is_in_group("traffic"):
			continue

		# Отброс игрока назад: impulse > base_speed → velocity.z < 0
		_pushback_velocity = PUSHBACK_IMPULSE
		_hit_cooldown = HIT_COOLDOWN_TIME

		# Покраснение экрана
		_trigger_hit_flash()

		# Снижение лояльности текущего персонажа
		_trigger_loyalty_penalty()

		# Отброс встречной машины
		if collider.has_method("apply_bounce"):
			collider.apply_bounce()

		break  # одного столкновения за кадр достаточно


func _trigger_hit_flash() -> void:
	var flash_nodes := get_tree().get_nodes_in_group("collision_flash")
	if flash_nodes.size() > 0:
		flash_nodes[0].play_flash()


func _trigger_loyalty_penalty() -> void:
	var dm_nodes := get_tree().get_nodes_in_group("dialogue_manager")
	if dm_nodes.size() > 0:
		dm_nodes[0].apply_traffic_hit_penalty()


# ──────────────────────────────────────────────
#  Финальная анимация
# ──────────────────────────────────────────────

func end_anim():
	print("END")
	ColShape.disabled = true
	path_node = _find_nearest_path3d_ahead()
	if path_node == null:
		push_error("player_car: Path3D впереди не найден!")
		return

	# Стартуем с ближайшей к машине точки кривой, а не с нулевого конца
	var local_pos    := path_node.to_local(global_position)
	path_progress    = path_node.curve.get_closest_offset(local_pos)
	path_start_world = path_node.to_global(path_node.curve.sample_baked(path_progress, true))

	phase = Phase.STRAIGHT_TO_PATH


# Этап 1 — едем прямо (только вперёд, без боков) до ближайшей точки пути
func _drive_straight_to_path():
	velocity.x = 0.0
	velocity.z = _get_end_anim_speed(global_transform.basis.z)
	move_and_slide()

	# Переключаемся по дистанции в горизонтальной плоскости (не только по Z)
	var flat_dist := Vector2(
		global_position.x - path_start_world.x,
		global_position.z - path_start_world.z).length()
	if flat_dist <= path_reach_threshold:
		# Разворачиваем машину согласно направлению пути.
		# sample_baked_with_rotation возвращает трансформ где -Z = вперёд по кривой
		# (конвенция Godot PathFollow3D). Поворачиваем на 180° вокруг Y → +Z вперёд.
		var path_transform := path_node.curve.sample_baked_with_rotation(path_progress, true, false)
		var corrected_basis := (path_node.global_transform * path_transform).basis
		corrected_basis = corrected_basis.rotated(Vector3.UP, PI)
		global_basis = corrected_basis
		phase = Phase.FOLLOW_PATH
		turning_started.emit()  # сигнал для dialogue_manager — поворот начался


# Этап 2 — едем по кривой
func _follow_path():
	var delta := get_physics_process_delta_time()

	# -Z кривой = вперёд по конвенции Godot Path3D
	var path_transform := path_node.curve.sample_baked_with_rotation(path_progress, true, false)
	var world_transform := path_node.global_transform * path_transform
	var path_forward := -(world_transform.basis.z).normalized()

	var speed := _get_end_anim_speed(path_forward)
	path_progress += speed * delta
	path_progress = minf(path_progress, path_node.curve.get_baked_length())

	# Пересчитываем трансформ после сдвига прогресса
	path_transform = path_node.curve.sample_baked_with_rotation(path_progress, true, false)
	world_transform = path_node.global_transform * path_transform

	var target_pos := world_transform.origin
	var direction := target_pos - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	else:
		direction = path_forward

	velocity = direction * speed

	# -Z кривой → вперёд, корректируем поворотом на 180° вокруг Y
	global_basis = world_transform.basis.rotated(Vector3.UP, PI)
	move_and_slide()


# Возвращает скорость с учётом трафика впереди.
# Плавно подстраивается под скорость машины впереди вместо резкой остановки.
func _get_end_anim_speed(forward_dir: Vector3) -> float:
	var result := _nearest_traffic_ahead(forward_dir)
	var dist: float = result[0]
	var traffic_speed: float = result[1]

	if dist >= traffic_slow_distance:
		return base_speed

	# t=1 → далеко (base_speed), t=0 → вплотную (скорость машины впереди)
	var t = clamp((dist - traffic_stop_distance) / (traffic_slow_distance - traffic_stop_distance), 0.0, 1.0)
	return lerp(traffic_speed, base_speed, t)


# Возвращает [дистанция, скорость] для ближайшей машины из «traffic» впереди.
# Если таких нет — [INF, 0.0].
func _nearest_traffic_ahead(forward_dir: Vector3) -> Array:
	var fwd := forward_dir
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		return [INF, 0.0]
	fwd = fwd.normalized()

	var best_dist := INF
	var best_speed := 0.0
	for t in get_tree().get_nodes_in_group("traffic"):
		if not t is Node3D:
			continue
		var to_car: Vector3 = (t as Node3D).global_position - global_position
		to_car.y = 0.0
		var dist := to_car.length()
		if dist > traffic_slow_distance + 2.0:
			continue
		if fwd.dot(to_car.normalized()) < 0.5:
			continue
		if dist < best_dist:
			best_dist = dist
			if t is CharacterBody3D:
				var tv: Vector3 = (t as CharacterBody3D).velocity
				tv.y = 0.0
				best_speed = tv.length()
			else:
				best_speed = 0.0
	return [best_dist, best_speed]


# ──────────────────────────────────────────────
#  Поиск ближайшего Path3D впереди
# ──────────────────────────────────────────────

func _find_nearest_path3d_ahead() -> Path3D:
	# Машина движется с velocity.z = base_speed (мировой +Z).
	# Используем фактическое направление движения вместо -basis.z, который указывал НАЗАД.
	var forward: Vector3
	if velocity.length_squared() > 0.01:
		forward = velocity.normalized()
	else:
		forward = global_transform.basis.z  # +basis.z = мировой +Z при нулевом повороте
	forward.y = 0.0
	forward = forward.normalized()
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
	print("Deletion")
	if body.is_in_group("traffic"):
		body.queue_free()
		print("deleted")
