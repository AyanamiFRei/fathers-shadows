extends Node3D

@onready var lamp_light_1: Light3D = $LampLight1
@onready var lamp_light_2: Light3D = $LampLight2

@onready var main_camera: Camera3D = $Camera3D
@onready var board_camera: Camera3D = $BoardCamera
@onready var phone_camera: Camera3D = $PhoneCamera

@onready var pause_menu: PauseMenu = $PauseMenu
@onready var return_button: Button = $CanvasLayer/ReturnButton

var default_camera_transform: Transform3D
var current_view := "default"
var is_camera_moving := false

var board_blink_id := 0
var phone_blink_id := 0

func _ready() -> void:
	if pause_menu == null:
		push_error("PauseMenu не найден в сцене Cab")
		return
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	default_camera_transform = main_camera.global_transform
	return_button.visible = false
	return_button.pressed.connect(_on_return_button_pressed)
	
	pause_menu.exit_to_menu_requested.connect(_on_exit_to_menu_requested)
	pause_menu.pause_opened.connect(_on_pause_opened)
	pause_menu.pause_closed.connect(_on_pause_closed)
	# CycleManager.start_hub()


func _on_return_button_pressed() -> void:
	return_camera()

func toggle_light() -> void:
	lamp_light_1.visible = !lamp_light_1.visible


func move_camera_to_transform(target_transform: Transform3D, view_name: String, duration: float = 0.8) -> void:
	if is_camera_moving:
		return

	is_camera_moving = true

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(main_camera, "global_transform", target_transform, duration)

	await tween.finished

	current_view = view_name
	is_camera_moving = false

	return_button.visible = current_view != "default"


func move_camera_to_camera(target_camera: Camera3D, view_name: String, duration: float = 0.8) -> void:
	move_camera_to_transform(target_camera.global_transform, view_name, duration)


func return_camera() -> void:
	if is_camera_moving:
		return
	if current_view == "default":
		return

	stop_all_blinking()
	return_button.visible = false
	move_camera_to_transform(default_camera_transform, "default")


func blink_light_for_seconds(light_node: Light3D, duration: float, interval: float, blink_id: int, lamp_type: String) -> void:
	var original_visible := true
	var elapsed := 0.0

	while elapsed < duration:
		if lamp_type == "board" and blink_id != board_blink_id:
			light_node.visible = original_visible
			return

		if lamp_type == "phone" and blink_id != phone_blink_id:
			light_node.visible = original_visible
			return

		light_node.visible = !light_node.visible
		await get_tree().create_timer(interval).timeout
		elapsed += interval

	light_node.visible = original_visible


func stop_all_blinking() -> void:
	board_blink_id += 1
	phone_blink_id += 1
	lamp_light_1.visible = true
	lamp_light_2.visible = true


func start_board_hover_effect() -> void:
	phone_blink_id += 1
	lamp_light_2.visible = true

	board_blink_id += 1
	var current_id := board_blink_id
	blink_light_for_seconds(lamp_light_1, 1.5, 0.3, current_id, "board")


func start_phone_hover_effect() -> void:
	board_blink_id += 1
	lamp_light_1.visible = true

	phone_blink_id += 1
	var current_id := phone_blink_id
	blink_light_for_seconds(lamp_light_2, 1.5, 0.3, current_id, "phone")


func _on_board_area_input_event(camera, event, event_position, normal, shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		stop_all_blinking()
		move_camera_to_camera(board_camera, "board")


func _on_phone_area_input_event(camera, event, event_position, normal, shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		stop_all_blinking()
		move_camera_to_camera(phone_camera, "phone")


func _on_board_area_mouse_entered() -> void:
	start_board_hover_effect()


func _on_board_area_mouse_exited() -> void:
	board_blink_id += 1
	lamp_light_1.visible = true


func _on_phone_area_mouse_entered() -> void:
	start_phone_hover_effect()


func _on_phone_area_mouse_exited() -> void:
	phone_blink_id += 1
	lamp_light_2.visible = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			return

		if current_view == "default":
			return_button.visible = false
			pause_menu.open_pause()
			
	#if event.is_action_pressed("ui_cancel"):
		#stop_all_blinking()
		#return_camera()
		#
	#if event.is_action_pressed("ui_cancel"):
		#if pause_menu.is_open:
			#pause_menu.close_pause()
		#else:
			#pause_menu.open_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu == null:
			return

		pause_menu.toggle_pause()

func _on_exit_to_menu_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_pause_opened() -> void:
	return_button.visible = false

func _on_pause_closed() -> void:
	if current_view != "default":
		return_button.visible = true
