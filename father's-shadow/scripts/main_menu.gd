extends Control

@onready var play_button: Button = $CenterContainer/MenuBox/PlayButton
@onready var tutorial_button: Button = $CenterContainer/MenuBox/TutorialButton
@onready var settings_button: Button = $CenterContainer/MenuBox/SettingsButton
@onready var exit_button: Button = $CenterContainer/MenuBox/ExitButton
@onready var center_container: Control = $CenterContainer

@onready var tutorial_panel: Control = $TutorialPanel
@onready var tutorial_close_button: Button = $TutorialPanel/TutorialCloseButton

@onready var settings_panel: Control = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSlider
@onready var volume_value: Label = $SettingsPanel/VolumeValue
@onready var settings_close_button: Button = $SettingsPanel/SettingsCloseButton

@onready var authors_button: Button = $CenterContainer/MenuBox/AuthorsButton
@onready var authors_panel: Control = $AuthorsPanel
@onready var authors_close_button: Button = $AuthorsPanel/AuthorsCloseButton

@export var normal_color: Color = Color(1, 1, 1, 1)
@export var hover_color: Color = Color(0.65, 0.85, 1.0, 1)
@export var pressed_color: Color = Color(0.55, 1.0, 0.7, 1)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	tutorial_panel.visible = false
	settings_panel.visible = false

	_connect_button_fx(play_button)
	_connect_button_fx(tutorial_button)
	_connect_button_fx(settings_button)
	_connect_button_fx(exit_button)
	_connect_button_fx(tutorial_close_button)
	_connect_button_fx(settings_close_button)
	_connect_button_fx(authors_button)
	_connect_button_fx(authors_close_button)

	play_button.pressed.connect(_on_play_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	tutorial_close_button.pressed.connect(_on_tutorial_close_pressed)
	settings_close_button.pressed.connect(_on_settings_close_pressed)
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	
	authors_button.pressed.connect(_on_authors_pressed)
	authors_close_button.pressed.connect(_on_authors_close_pressed)

	_setup_audio()

func _connect_button_fx(button: Button) -> void:
	button.modulate = normal_color

	button.mouse_entered.connect(func():
		button.modulate = hover_color
	)

	button.mouse_exited.connect(func():
		button.modulate = normal_color
	)

	button.button_down.connect(func():
		button.modulate = pressed_color
	)

	button.button_up.connect(func():
		if button.get_global_rect().has_point(get_viewport().get_mouse_position()):
			button.modulate = hover_color
		else:
			button.modulate = normal_color
	)

func _on_play_pressed() -> void:
	print("Нажата кнопка Играть")
	# Здесь потом можно сделать переход в игровую сцену:
	# get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func _on_tutorial_pressed() -> void:
	tutorial_panel.visible = true
	settings_panel.visible = false
	center_container.visible = false

func _on_settings_pressed() -> void:
	settings_panel.visible = true
	tutorial_panel.visible = false
	authors_panel.visible = false
	center_container.visible = false

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_tutorial_close_pressed() -> void:
	tutorial_panel.visible = false
	center_container.visible = true

func _on_settings_close_pressed() -> void:
	settings_panel.visible = false
	center_container.visible = true
	
func _on_authors_pressed() -> void:
	authors_panel.visible = true
	tutorial_panel.visible = false
	settings_panel.visible = false
	center_container.visible = false

func _on_authors_close_pressed() -> void:
	authors_panel.visible = false
	center_container.visible = true

func _setup_audio() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index == -1:
		push_warning("Шина Master не найдена")
		return

	var current_db := AudioServer.get_bus_volume_db(bus_index)
	var linear_value := db_to_linear(current_db)

	volume_slider.value = linear_value
	_update_volume_text(linear_value)

func _on_volume_slider_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return

	var safe_value: float = max(value, 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_value))
	_update_volume_text(value)

func _update_volume_text(value: float) -> void:
	volume_value.text = "Громкость: %d%%" % int(round(value * 100.0))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if tutorial_panel.visible:
			tutorial_panel.visible = false
			center_container.visible = true
		elif settings_panel.visible:
			settings_panel.visible = false
			center_container.visible = true
		elif authors_panel.visible:
			authors_panel.visible = false
			center_container.visible = true
