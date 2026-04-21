extends Node3D

@export var player_path: NodePath

const MIN_GAP  = 10.0
const MAX_CARS = 25

var player: Node3D
var traffic_forward  = preload("res://scenes/TrafficCarForward.tscn")
var traffic_backward = preload("res://scenes/TrafficCarBack.tscn")

var is_started = false

# Cooldown чтобы не спаунить каждый кадр
var spawn_cooldown: float = 0.0
const SPAWN_INTERVAL = 0.5  # попытка спауна раз в 0.5 сек

func _ready() -> void:
	player = get_node(player_path)
	await get_tree().create_timer(1.5).timeout
	is_started = true

func _process(delta: float) -> void:
	if !is_started:
		return
		
	spawn_cooldown -= delta
	if spawn_cooldown > 0.0:
		return

	spawn_cooldown = SPAWN_INTERVAL

	# Используем группу — надёжно и без load() каждый кадр
	var cars = get_tree().get_nodes_in_group("traffic")

	if cars.size() >= MAX_CARS:
		return

	var lane: float = [-1.8, 1.8].pick_random()
	var posz: float = randi_range(player.global_position.z + 30, player.global_position.z + 40)

	if not _is_lane_free(lane, posz, cars):
		return

	var instance = (traffic_forward if lane > 0 else traffic_backward).instantiate()
	instance.position = Vector3(lane, 1, posz)
	get_tree().get_root().add_child(instance)

func _is_lane_free(lane: float, posz: float, cars: Array) -> bool:
	for car in cars:
		if abs(car.global_position.x - lane) > 1.0:
			continue
		if abs(car.global_position.z - posz) < MIN_GAP:
			return false
	return true
