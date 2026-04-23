extends ProgressBar

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.noise_changed.connect(update_bar)

func update_bar(value: float, max_value: float) -> void:
	self.max_value = max_value
	self.value = value

	var percent := value / max_value

	# Цвет полоски
	if percent < 0.5:
		modulate = Color.WHITE
	elif percent < 0.8:
		modulate = Color.YELLOW
	else:
		modulate = Color.RED
