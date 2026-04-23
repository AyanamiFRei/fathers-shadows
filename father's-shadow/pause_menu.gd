extends Control
class_name PauseMenu

signal restart_requested
signal exit_to_menu_requested
signal pause_opened
signal pause_closed

enum MenuType {
	HUB,
	GAME
}

@export var menu_type: MenuType = MenuType.HUB

@onready var background: Control = $Background

@onready var hub_menu: VBoxContainer = $HubMenu
@onready var game_menu: VBoxContainer = $GameMenu

@onready var hub_continue_button: Button = $HubMenu/ContinueButton
@onready var hub_tutorial_button: Button = $HubMenu/TutorialButton
@onready var hub_settings_button: Button = $HubMenu/SettingsButton
@onready var hub_exit_to_menu_button: Button = $HubMenu/ExitToMenuButton
@onready var hub_quit_button: Button = $HubMenu/QuitButton

@onready var game_continue_button: Button = $GameMenu/ContinueButton
@onready var game_restart_button: Button = $GameMenu/RestartButton
@onready var game_tutorial_button: Button = $GameMenu/TutorialButton
@onready var game_settings_button: Button = $GameMenu/SettingsButton
@onready var game_exit_to_menu_button: Button = $GameMenu/ExitToMenuButton
@onready var game_quit_button: Button = $GameMenu/QuitButton

@onready var tutorial_panel: Panel = $TutorialPanel
@onready var tutorial_close_button: Button = $TutorialPanel/TutorialCloseButton

@onready var settings_panel: Panel = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSlider
@onready var volume_value: Label = $SettingsPanel/VolumeValue
@onready var settings_close_button: Button = $SettingsPanel/SettingsCloseButton

@export var normal_color: Color = Color(1, 1, 1, 1)
@export var hover_color: Color = Color(0.65, 0.85, 1.0, 1)
@export var pressed_color: Color = Color(0.55, 1.0, 0.7, 1)

var is_open: bool = false
var current_submenu: String = "main"

func _ready() -> void:
	visible = false
	hub_menu.visible = false
	game_menu.visible = false
	tutorial_panel.visible = false
	settings_panel.visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	_setup_connections()
	_setup_button_fx()
	_setup_audio()

func toggle_pause() -> void:
	if is_open:
		close_pause()
	else:
		open_pause()
		
func open_pause() -> void:
	is_open = true
	current_submenu = "main"
	visible = true

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_show_main_menu()
	pause_opened.emit()

func close_pause() -> void:
	is_open = false
	current_submenu = "main"
	visible = false

	hub_menu.visible = false
	game_menu.visible = false
	tutorial_panel.visible = false
	settings_panel.visible = false

	get_tree().paused = false
	pause_closed.emit()

func _setup_connections() -> void:
	hub_continue_button.pressed.connect(_on_continue_pressed)
	hub_tutorial_button.pressed.connect(_on_tutorial_pressed)
	hub_settings_button.pressed.connect(_on_settings_pressed)
	hub_exit_to_menu_button.pressed.connect(_on_exit_to_menu_pressed)
	hub_quit_button.pressed.connect(_on_quit_pressed)

	game_continue_button.pressed.connect(_on_continue_pressed)
	game_restart_button.pressed.connect(_on_restart_pressed)
	game_tutorial_button.pressed.connect(_on_tutorial_pressed)
	game_settings_button.pressed.connect(_on_settings_pressed)
	game_exit_to_menu_button.pressed.connect(_on_exit_to_menu_pressed)
	game_quit_button.pressed.connect(_on_quit_pressed)

	tutorial_close_button.pressed.connect(_on_tutorial_close_pressed)
	settings_close_button.pressed.connect(_on_settings_close_pressed)
	volume_slider.value_changed.connect(_on_volume_slider_changed)

func _setup_button_fx() -> void:
	var buttons: Array[Button] = [
		hub_continue_button,
		hub_tutorial_button,
		hub_settings_button,
		hub_exit_to_menu_button,
		hub_quit_button,
		game_continue_button,
		game_restart_button,
		game_tutorial_button,
		game_settings_button,
		game_exit_to_menu_button,
		game_quit_button,
		tutorial_close_button,
		settings_close_button
	]

	for button in buttons:
		_connect_button_fx(button)

func _connect_button_fx(button: Button) -> void:
	button.modulate = normal_color

	button.mouse_entered.connect(func() -> void:
		button.modulate = hover_color
	)

	button.mouse_exited.connect(func() -> void:
		button.modulate = normal_color
	)

	button.button_down.connect(func() -> void:
		button.modulate = pressed_color
	)

	button.button_up.connect(func() -> void:
		if button.get_global_rect().has_point(get_viewport().get_mouse_position()):
			button.modulate = hover_color
		else:
			button.modulate = normal_color
	)


	visible = false
	hub_menu.visible = false
	game_menu.visible = false
	tutorial_panel.visible = false
	settings_panel.visible = false

	get_tree().paused = false

func _show_main_menu() -> void:
	tutorial_panel.visible = false
	settings_panel.visible = false

	match menu_type:
		MenuType.HUB:
			hub_menu.visible = true
			game_menu.visible = false
		MenuType.GAME:
			hub_menu.visible = false
			game_menu.visible = true

func _on_continue_pressed() -> void:
	close_pause()

func _on_tutorial_pressed() -> void:
	current_submenu = "tutorial"
	hub_menu.visible = false
	game_menu.visible = false
	settings_panel.visible = false
	tutorial_panel.visible = true

func _on_settings_pressed() -> void:
	current_submenu = "settings"
	hub_menu.visible = false
	game_menu.visible = false
	tutorial_panel.visible = false
	settings_panel.visible = true

func _on_tutorial_close_pressed() -> void:
	current_submenu = "main"
	_show_main_menu()

func _on_settings_close_pressed() -> void:
	current_submenu = "main"
	_show_main_menu()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	is_open = false
	visible = false
	restart_requested.emit()

func _on_exit_to_menu_pressed() -> void:
	get_tree().paused = false
	is_open = false
	visible = false
	exit_to_menu_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	is_open = false
	visible = false
	get_tree().quit()

func _setup_audio() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return

	var current_db: float = AudioServer.get_bus_volume_db(bus_index)
	var linear_value: float = db_to_linear(current_db)

	volume_slider.value = linear_value
	_update_volume_text(linear_value)

func _on_volume_slider_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return

	var safe_value: float = max(value, 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_value))
	_update_volume_text(value)

func _update_volume_text(value: float) -> void:
	volume_value.text = "Громкость: %d%%" % int(round(value * 100.0))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not is_open:
			return

		if tutorial_panel.visible:
			_on_tutorial_close_pressed()
		elif settings_panel.visible:
			_on_settings_close_pressed()
		else:
			close_pause()

		get_viewport().set_input_as_handled()
