extends Node

var total_dialogue_time: float = 0.0
var is_dialogue_running: bool = false

var current_window_time: float = 0.0
var current_window_limit: float = 5.0
var is_window_timer_running: bool = false

var between_window_time: float = 0.0
var between_window_limit: float = 0.0
var is_between_window_timer_running: bool = false


func _process(delta: float) -> void:
	if is_dialogue_running:
		total_dialogue_time += delta
	if is_window_timer_running:
		current_window_time += delta
	if is_between_window_timer_running:
		between_window_time += delta


# ОБЩИЙ ТАЙМЕР ДИАЛОГА
func start_dialogue_timer() -> void:
	is_dialogue_running = true

func stop_dialogue_timer() -> void:
	is_dialogue_running = false

func reset_dialogue_timer() -> void:
	total_dialogue_time = 0.0

func get_total_dialogue_time() -> float:
	return total_dialogue_time


# ТАЙМЕР ОКНА ДИАЛОГА
func start_window_timer(limit: float = 10.0) -> void:
	current_window_time = 0.0
	current_window_limit = limit
	is_window_timer_running = true

func stop_window_timer() -> void:
	is_window_timer_running = false

func reset_window_timer() -> void:
	current_window_time = 0.0

func is_window_time_over() -> bool:
	return current_window_time >= current_window_limit

func get_current_window_time() -> float:
	return current_window_time

func get_current_window_limit() -> float:
	return current_window_limit

# ПАУЗЫ В ДИАЛОГАХ
func start_between_window_timer(limit: float) -> void:
	between_window_time = 0.0
	between_window_limit = limit
	is_between_window_timer_running = true

func stop_between_window_timer() -> void:
	is_between_window_timer_running = false

func is_between_window_time_over() -> bool:
	return between_window_time >= between_window_limit
