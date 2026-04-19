extends Node3D

@export var player: Node3D
@export var recycle_distance: float = 30.0

var road_segments: Array[Node3D] = []

func _ready():
	road_segments = [
		$Road1,
		$Road2
	]

	_align_segments()


func _process(_delta):
	if player == null:
		return

	_recycle_if_needed()


func _align_segments():
	# Ставим каждый следующий сегмент в конец предыдущего
	for i in range(1, road_segments.size()):
		var prev = road_segments[i - 1]
		var current = road_segments[i]

		var prev_end: Marker3D = prev.get_node("End")
		var current_start: Marker3D = current.get_node("Start")

		var offset = current.global_position - current_start.global_position
		current.global_position = prev_end.global_position + offset


func _recycle_if_needed():
	if road_segments.size() < 2:
		return

	var first_segment = road_segments[0]
	var second_segment = road_segments[1]

	var first_end: Marker3D = first_segment.get_node("End")
	var second_end: Marker3D = second_segment.get_node("Start")

	# Когда игрок уже проехал первый сегмент,
	# переносим его вперед за второй
	if player.global_position.distance_to(first_end.global_position) < recycle_distance:
		_move_segment_after(first_segment, second_segment)

		# меняем порядок в массиве
		road_segments.pop_front()
		road_segments.append(first_segment)


func _move_segment_after(segment_to_move: Node3D, target_segment: Node3D):
	var target_end: Marker3D = target_segment.get_node("End")
	var moving_start: Marker3D = segment_to_move.get_node("Start")

	var offset = segment_to_move.global_position - moving_start.global_position
	segment_to_move.global_position = target_end.global_position + offset
