extends ProgressBar

func _ready() -> void:
	min_value = 0
	value = 0
	show_percentage = false

	add_theme_stylebox_override("fill", make_stylebox(Color(0.55, 0.15, 1.0, 1.0)))
	add_theme_stylebox_override("background", make_stylebox(Color(0.08, 0.04, 0.12, 0.85)))

	await get_tree().process_frame

	var player = get_tree().get_first_node_in_group("player")
	if player:
		max_value = player.max_noise
		value = player.current_noise
		player.noise_changed.connect(update_bar)


func update_bar(noise_value: float, noise_max_value: float) -> void:
	max_value = noise_max_value
	value = noise_value


func make_stylebox(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
