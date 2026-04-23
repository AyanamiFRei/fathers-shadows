extends Node3D

var total_collectibles: int = 0
var collected_count: int = 0
var level_completed: bool = false

func _ready() -> void:
	await get_tree().process_frame

	var interactables = get_tree().get_nodes_in_group("interactable_object")
	total_collectibles = interactables.size()

	for item in interactables:
		if item.has_signal("collected"):
			item.collected.connect(_on_item_collected)

	print("Всего предметов на уровне: ", total_collectibles)

func _on_item_collected() -> void:
	if level_completed:
		return

	collected_count += 1
	print("Собрано: ", collected_count, " / ", total_collectibles)

	if collected_count >= total_collectibles:
		complete_level()

func complete_level() -> void:
	level_completed = true
	print("Уровень пройден!")

	# если хочешь просто остановить игру:
	get_tree().paused = true
