extends Node3D

@export var road_scenes: Array[PackedScene] = []
@export var player: Node3D
@export var active_tiles_count: int = 4

# Насколько заранее подгружать следующий тайл
@export var preload_offset: float = -20.0

# {
#   "node": Node3D,
#   "scene_path": String,
#   "start_z": float,
#   "end_z": float,
#   "back_z": float,
#   "front_z": float,
#   "length": float
# }
var _tiles: Array[Dictionary] = []

# Куда ставить StartMarker следующего сегмента
var _spawn_z: float = 0.0

var _initialized: bool = false
var _is_shifting: bool = false
var _scene_index: int = 0


func _ready() -> void:
	call_deferred("_setup_road")


func _setup_road() -> void:
	_clear_spawned_tiles()

	if player == null or not is_instance_valid(player):
		push_error("RoadManager: player не назначен")
		return

	if road_scenes.is_empty():
		push_error("RoadManager: road_scenes пуст")
		return

	_spawn_z = player.global_position.z

	for i in range(active_tiles_count):
		_spawn_tile_forward()

	_initialized = true
	print("RoadManager initialized, tiles: ", _tiles.size())


func _process(_delta: float) -> void:
	if not _initialized:
		return

	if _is_shifting:
		return

	if player == null or not is_instance_valid(player):
		return

	if _tiles.size() == 0:
		return

	var first_tile: Dictionary = _tiles[0]
	var first_back_z: float = first_tile["back_z"]

	# Дорога идёт в +Z.
	# Когда игрок почти доехал до конца первого тайла,
	# заранее переставляем очередь.
	if player.global_position.z > first_back_z - preload_offset:
		_shift_forward_once()


func _shift_forward_once() -> void:
	if _tiles.size() == 0:
		return

	_is_shifting = true

	var old_tile: Dictionary = _tiles[0]

	# Сначала добавляем новый тайл
	_spawn_tile_forward()

	# Потом удаляем самый старый
	if is_instance_valid(old_tile["node"]):
		print(
			"Remove tile: ", old_tile["scene_path"],
			" | player_z=", player.global_position.z,
			" | tile_back_z=", old_tile["back_z"]
		)
		(old_tile["node"] as Node3D).queue_free()

	_tiles.pop_front()

	# На всякий случай жёстко держим ровно active_tiles_count тайлов
	while _tiles.size() > active_tiles_count:
		var extra_tile: Dictionary = _tiles[0]
		if is_instance_valid(extra_tile["node"]):
			(extra_tile["node"] as Node3D).queue_free()
		_tiles.pop_front()

	_is_shifting = false


func _spawn_tile_forward() -> void:
	var packed: PackedScene = road_scenes[_scene_index % road_scenes.size()]
	_scene_index += 1
	if packed == null:
		push_error("RoadManager: в road_scenes есть null")
		return

	var seg: Node3D = packed.instantiate() as Node3D
	if seg == null:
		push_error("RoadManager: не удалось инстанцировать PackedScene")
		return

	add_child(seg)

	var start_marker: Node3D = _find_marker_recursive(seg, "StartMarker")
	var end_marker: Node3D = _find_marker_recursive(seg, "EndMarker")

	if start_marker == null or end_marker == null:
		push_error("RoadManager: у сегмента нет StartMarker или EndMarker: " + str(seg.scene_file_path))
		seg.queue_free()
		return

	# Для твоей текущей сцены:
	# StartMarker нового сегмента ставим в _spawn_z
	var shift_z: float = _spawn_z - start_marker.global_position.z
	seg.global_position.z += shift_z

	var start_z: float = start_marker.global_position.z
	var end_z: float = end_marker.global_position.z

	var back_z: float = max(start_z, end_z)
	var front_z: float = min(start_z, end_z)
	var length: float = abs(end_z - start_z)

	var scene_path: String = seg.scene_file_path
	if scene_path.is_empty():
		scene_path = packed.resource_path

	print(
		"Spawn tile: ", scene_path,
		" | start_z=", start_z,
		" | end_z=", end_z,
		" | back_z=", back_z,
		" | front_z=", front_z,
		" | len=", length
	)

	_tiles.append({
		"node": seg,
		"scene_path": scene_path,
		"start_z": start_z,
		"end_z": end_z,
		"back_z": back_z,
		"front_z": front_z,
		"length": length
	})

	# Следующий сегмент начинается там, где закончился текущий
	_spawn_z = end_z


func _clear_spawned_tiles() -> void:
	for tile in _tiles:
		if tile.has("node") and is_instance_valid(tile["node"]):
			(tile["node"] as Node3D).queue_free()
	_tiles.clear()


func _find_marker_recursive(root: Node, marker_name: String) -> Node3D:
	if root.name == marker_name and root is Node3D:
		return root as Node3D

	for child in root.get_children():
		var found: Node3D = _find_marker_recursive(child, marker_name)
		if found != null:
			return found

	return null
