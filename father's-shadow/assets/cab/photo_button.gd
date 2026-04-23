extends Button

var normal_style: StyleBoxFlat
var hover_style: StyleBoxFlat

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

	# Берём текущий стиль кнопки
	normal_style = get_theme_stylebox("normal").duplicate()

	# Создаём hover-версию
	hover_style = normal_style.duplicate()
	hover_style.bg_color = normal_style.bg_color.darkened(0.2) # делает серее

	add_theme_stylebox_override("normal", normal_style)


func _on_mouse_entered():
	add_theme_stylebox_override("normal", hover_style)


func _on_mouse_exited():
	add_theme_stylebox_override("normal", normal_style)


func _on_pressed():
	CycleManager.start_day()
	
