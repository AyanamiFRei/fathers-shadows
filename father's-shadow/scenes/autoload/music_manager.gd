extends AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_music(stream_resource: AudioStream) -> void:
	if stream_resource == null:
		return

	if stream == stream_resource and playing:
		return

	stream = stream_resource
	play()

func stop_music() -> void:
	stop()
