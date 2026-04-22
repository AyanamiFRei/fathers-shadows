extends CharacterBody3D

var current_item = null

@onready var interact_area: Area3D = $InteractArea
@onready var interact_key: Sprite3D = $InteractionKey

# -------------------------
# ДВИЖЕНИЕ
# -------------------------

@export var move_speed: float = 5.0
@export var rotation_speed: float = 12.0

# -------------------------
# ЗУМ КАМЕРЫ (SpringArm)
# -------------------------

@export var camera_normal_length: float = 15.0
@export var camera_zoomed_length: float = 18.0
@export var camera_lerp_speed: float = 10.0

# -------------------------
# СМЕЩЕНИЕ КАМЕРЫ К КУРСОРУ
# -------------------------

@export var camera_offset_strength: float = 2.5
@export var camera_offset_max_distance: float = 3.5
@export var camera_offset_zoom_multiplier: float = 1.35
@export var camera_offset_lerp_speed: float = 8.0

# -------------------------
# ШУМ
# -------------------------

@export var max_noise: float = 100.0
@export var noise_decay_delay: float = 3.0      # Через сколько секунд после последнего шума начнется спад
@export var noise_decay_duration: float = 30.0  # За сколько секунд шум упадет с max до 0
@export var noise_immunity_time: float = 2.0    # Защита от повторного шума на короткое время

var current_noise: float = 0.0
var last_noise_time: float = -999.0
var noise_immunity_timer: float = 0.0

# -------------------------
# ССЫЛКИ НА НОДЫ
# -------------------------

@onready var pivot: Node3D = $Pivot
@onready var spring_arm: SpringArm3D = $Pivot/SpringArm3D
@onready var camera: Camera3D = $Pivot/SpringArm3D/Camera3D
@onready var mesh: MeshInstance3D = $MeshInstance3D2


func _ready() -> void:
	interact_key.hide()


func _process(_delta: float) -> void:
	if current_item != null and Input.is_action_just_pressed("interact"):
		current_item.interact()


func _physics_process(delta: float) -> void:
	handle_movement()
	rotate_to_mouse(delta)
	handle_camera_zoom(delta)
	handle_camera_offset(delta)
	update_noise_system(delta)

	var push_dir := velocity
	push_dir.y = 0.0

	move_and_slide()

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider is RigidBody3D and collider.has_method("push_from"):
			if push_dir.length() > 0.01:
				collider.push_from(collision.get_position(), push_dir)


func _on_interact_area_body_entered(body) -> void:
	if body.has_method("interact"):
		current_item = body
		interact_key.show()
		print("зашел в зону: ", body.name)


func _on_interact_area_body_exited(body) -> void:
	if body == current_item:
		current_item = null
		interact_key.hide()
		print("вышел из зоны: ", body.name)


# -------------------------
# ДВИЖЕНИЕ (WASD)
# -------------------------

func handle_movement() -> void:
	var input_dir: Vector2 = Vector2.ZERO

	input_dir.x = Input.get_action_strength("Car_D") - Input.get_action_strength("Car_A")
	input_dir.y = Input.get_action_strength("Car_S") - Input.get_action_strength("Car_W")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y = 0.0


# -------------------------
# ПОВОРОТ К МЫШКЕ
# -------------------------

func rotate_to_mouse(delta: float) -> void:
	var mouse_world: Variant = get_mouse_world_point()
	if mouse_world == null:
		return

	var target_pos: Vector3 = mouse_world as Vector3
	var look_dir: Vector3 = target_pos - global_position
	look_dir.y = 0.0

	if look_dir.length() < 0.001:
		return

	var target_angle: float = atan2(look_dir.x, look_dir.z)
	mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, rotation_speed * delta)


# -------------------------
# ЗУМ КАМЕРЫ (ПКМ)
# -------------------------

func handle_camera_zoom(delta: float) -> void:
	var target_length: float = camera_normal_length

	if Input.is_action_pressed("night_zoom_out"):
		target_length = camera_zoomed_length

	spring_arm.spring_length = lerpf(
		spring_arm.spring_length,
		target_length,
		camera_lerp_speed * delta
	)


# -------------------------
# СМЕЩЕНИЕ КАМЕРЫ К КУРСОРУ
# -------------------------

func handle_camera_offset(delta: float) -> void:
	var mouse_world: Variant = get_mouse_world_point()
	var target_offset: Vector3 = Vector3.ZERO

	if mouse_world != null:
		var mouse_pos: Vector3 = mouse_world as Vector3
		var to_mouse: Vector3 = mouse_pos - global_position
		to_mouse.y = 0.0

		if to_mouse.length() > 0.001:
			var distance: float = min(
				to_mouse.length() * camera_offset_strength,
				camera_offset_max_distance
			)

			var zoom_mult: float = 1.0

			if Input.is_action_pressed("night_zoom_out"):
				zoom_mult = camera_offset_zoom_multiplier

			target_offset = to_mouse.normalized() * distance * zoom_mult

	pivot.position = pivot.position.lerp(
		target_offset,
		camera_offset_lerp_speed * delta
	)


# -------------------------
# ПОЛУЧЕНИЕ ТОЧКИ МЫШИ В МИРЕ
# -------------------------

func get_mouse_world_point() -> Variant:
	if camera == null:
		return null

	var viewport := get_viewport()
	if viewport == null:
		return null

	var mouse_pos: Vector2 = viewport.get_mouse_position()

	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)

	var plane: Plane = Plane(Vector3.UP, global_position.y)

	return plane.intersects_ray(ray_origin, ray_dir)


# -------------------------
# СИСТЕМА ШУМА
# -------------------------

func add_noise(amount: float) -> void:
	if noise_immunity_timer > 0.0:
		return

	current_noise = clamp(current_noise + amount, 0.0, max_noise)
	last_noise_time = Time.get_ticks_msec() / 1000.0
	noise_immunity_timer = noise_immunity_time

	print("Шум добавлен: ", amount, " | Текущий шум: ", current_noise)


func update_noise_system(delta: float) -> void:
	if noise_immunity_timer > 0.0:
		noise_immunity_timer -= delta

	var current_time := Time.get_ticks_msec() / 1000.0
	var time_since_last_noise := current_time - last_noise_time

	if time_since_last_noise >= noise_decay_delay and current_noise > 0.0:
		var decay_per_second := max_noise / noise_decay_duration
		current_noise = max(current_noise - decay_per_second * delta, 0.0)
