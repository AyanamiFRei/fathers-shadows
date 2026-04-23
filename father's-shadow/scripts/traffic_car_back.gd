extends Node3D

@onready var pause_menu: PauseMenu = $PauseMenu
@export var car_speed: float = randfn(11.0, 2.0)
@export var same_direction: bool = false
@onready var hud: CanvasLayer = $"UI Textboard"


var player_speed: float = 10.0

func _ready():
	if pause_menu == null:
		push_error("PauseMenu не найден в сцене DayShift")
		return

	pause_menu.exit_to_menu_requested.connect(_on_exit_to_menu_requested)
	pause_menu.restart_requested.connect(_on_restart_requested)
	
	pause_menu.pause_opened.connect(_on_pause_opened)
	pause_menu.pause_closed.connect(_on_pause_closed)

	if not same_direction:
		rotation.y = deg_to_rad(180)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			return

		pause_menu.open_pause()

func _on_exit_to_menu_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_restart_requested() -> void:
	get_tree().reload_current_scene()

func _on_pause_opened() -> void:
	if hud != null:
		hud.visible = false

func _on_pause_closed() -> void:
	if hud != null:
		hud.visible = true
