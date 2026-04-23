extends Node3D

var selected_cassette: Node = null
var pending_cassette: Node = null
var input_locked: bool = false

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

@export var switch_lock_time: float = 2.0
@export var music_start_delay: float = 1.0
@export var cassette_start_sounds: Array[AudioStream] = []

# Какая кассета должна быть активна при старте
@export var startup_cassette_path: NodePath = ^"Cas/cas6"

# Включать ли кассету автоматически при запуске
@export var autoplay_startup_cassette: bool = true


func _ready():
	randomize()

	for cassette in $Cas.get_children():
		if cassette.has_signal("cassette_clicked"):
			cassette.cassette_clicked.connect(_on_cassette_clicked)

	music_player.finished.connect(_on_music_finished)

	if autoplay_startup_cassette:
		_activate_startup_cassette()


func _activate_startup_cassette():
	var cassette = get_node_or_null(startup_cassette_path)
	if cassette == null:
		return

	if cassette.music == null:
		return

	# Если вдруг что-то уже выделено — снимаем
	if selected_cassette != null and selected_cassette != cassette:
		selected_cassette.set_normal()

	selected_cassette = cassette
	pending_cassette = cassette

	# Визуальный маркер включенности
	selected_cassette.set_selected()

	# Сразу запускаем музыку без задержки
	music_player.stop()
	music_player.stream = cassette.music
	music_player.play()


func _on_cassette_clicked(cassette):
	# Повторный клик по уже выбранной кассете:
	# снять выделение, остановить музыку, проиграть звук кассеты
	if selected_cassette == cassette:
		selected_cassette.set_normal()
		selected_cassette = null
		_stop_music_with_cassette_sfx()
		return

	# Во время блокировки нельзя выбрать другую кассету
	if input_locked:
		return

	# Снять выделение с предыдущей кассеты
	if selected_cassette != null and selected_cassette != cassette:
		selected_cassette.set_normal()

	selected_cassette = cassette
	pending_cassette = cassette
	selected_cassette.set_selected()

	input_locked = true

	# Остановить текущую музыку перед запуском новой
	music_player.stop()

	# Проиграть звук кассеты
	_play_random_start_sfx()

	# Через delay запустить музыку, не останавливая sfx
	_start_music_with_delay(cassette)

	# Разблокировка выбора
	await get_tree().create_timer(switch_lock_time).timeout
	input_locked = false


func _start_music_with_delay(cassette):
	await get_tree().create_timer(music_start_delay).timeout

	# За время ожидания кассета могла быть выключена
	if pending_cassette != cassette:
		return

	if cassette.music == null:
		return

	music_player.stream = cassette.music
	music_player.play()


func _stop_music_with_cassette_sfx():
	pending_cassette = null
	music_player.stop()
	_play_random_start_sfx()


func _play_random_start_sfx():
	if cassette_start_sounds.is_empty():
		return

	var random_index = randi() % cassette_start_sounds.size()
	var random_sfx = cassette_start_sounds[random_index]

	if random_sfx == null:
		return

	sfx_player.stream = random_sfx
	sfx_player.play()


func _on_music_finished():
	if selected_cassette == null:
		return
	if selected_cassette.music == null:
		return

	music_player.stream = selected_cassette.music
	music_player.play()
