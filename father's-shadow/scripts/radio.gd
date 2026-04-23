extends Node3D

var selected_cassette: Node = null
var pending_cassette: Node = null
var input_locked: bool = false

const SAVE_FILE := "user://radio_settings.cfg"
const SAVE_SECTION := "radio"
const SAVE_KEY := "last_cassette"

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

@export var switch_lock_time: float = 2.0
@export var music_start_delay: float = 1.0
@export var cassette_start_sounds: Array[AudioStream] = []

@export var startup_cassette_path: NodePath = ^"Cas/cas6"
@export var autoplay_startup_cassette: bool = true



func _ready():
	randomize()

	for cassette in $Cas.get_children():
		if cassette.has_signal("cassette_clicked"):
			cassette.cassette_clicked.connect(_on_cassette_clicked)

	music_player.finished.connect(_on_music_finished)

	if autoplay_startup_cassette:
		_activate_saved_or_default_cassette()


func _activate_saved_or_default_cassette():
	var cassette = _get_saved_cassette()

	if cassette == null:
		cassette = get_node_or_null(startup_cassette_path)

	if cassette == null:
		return

	if cassette.music == null:
		return

	if selected_cassette != null and selected_cassette != cassette:
		selected_cassette.set_normal()

	selected_cassette = cassette
	pending_cassette = cassette
	selected_cassette.set_selected()

	music_player.stop()
	music_player.stream = cassette.music
	music_player.play()


func _on_cassette_clicked(cassette):
	if selected_cassette == cassette:
		selected_cassette.set_normal()
		selected_cassette = null
		pending_cassette = null
		music_player.stop()
		_play_random_start_sfx()
		return

	if input_locked:
		return

	if selected_cassette != null and selected_cassette != cassette:
		selected_cassette.set_normal()

	selected_cassette = cassette
	pending_cassette = cassette
	selected_cassette.set_selected()

	_save_selected_cassette(cassette)

	input_locked = true

	music_player.stop()
	_play_random_start_sfx()
	_start_music_with_delay(cassette)

	await get_tree().create_timer(switch_lock_time).timeout
	input_locked = false


func _start_music_with_delay(cassette):
	await get_tree().create_timer(music_start_delay).timeout

	if pending_cassette != cassette:
		return

	if cassette.music == null:
		return

	music_player.stream = cassette.music
	music_player.play()


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


func _save_selected_cassette(cassette):
	var config = ConfigFile.new()
	config.set_value(SAVE_SECTION, SAVE_KEY, str(cassette.get_path()))
	config.save(SAVE_FILE)


func _get_saved_cassette():
	var config = ConfigFile.new()
	var err = config.load(SAVE_FILE)

	if err != OK:
		return null

	var saved_path = config.get_value(SAVE_SECTION, SAVE_KEY, "")
	if saved_path == "":
		return null

	return get_node_or_null(saved_path)
