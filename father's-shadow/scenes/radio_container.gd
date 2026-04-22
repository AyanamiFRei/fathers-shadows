extends SubViewportContainer

# Почему _gui_input не работал:
#   HBoxContainer шириной 968px, SubViewportContainer (камера) имеет expand —
#   VBoxContainer получает 0px ширины. Поэтому _gui_input никогда не вызывается,
#   а get_global_rect() возвращает пустой прямоугольник.
#
# Почему stretch=true убрали:
#   При нулевой ширине контейнера stretch масштабирует SubViewport до 0x0.
#
# Решение:
#   _input() вызывается для всех событий независимо от layout.
#   Bounds считаем через реальный размер SubViewport (960x540) от global_position —
#   именно так контент рендерится даже при overflow из нулевого контейнера.
#
# Почему Area3D.input_event не работает в SubViewport:
#   push_input() (вызывается SubViewportContainer) не запускает 3D physics picking
#   (godotengine/godot#90413). Делаем raycast вручную.

var _hovered_cassette: Node = null


func _ready() -> void:
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return

	var subviewport := $SubViewport as SubViewport
	var vp_size     := Vector2(subviewport.size)          # реальный размер: 960x540

	# SubViewport рендерится от global_position контейнера, размером vp_size
	# (без stretch — нативный размер, overflow из нулевого контейнера)
	var render_rect := Rect2(global_position, vp_size)
	var mouse_pos   := get_global_mouse_position()

	if not render_rect.has_point(mouse_pos):
		if event is InputEventMouseMotion and _hovered_cassette != null:
			_update_hover(null)
		return

	# Координаты мыши в пространстве SubViewport (0..960, 0..540)
	var vp_pos := mouse_pos - render_rect.position

	var radio  := subviewport.get_node_or_null("Radio")
	if radio == null:
		return
	var camera := radio.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return

	var space = radio.get_world_3d().direct_space_state
	if space == null:
		return

	var from  := camera.project_ray_origin(vp_pos)
	var dir   := camera.project_ray_normal(vp_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)
	query.collide_with_areas  = true
	query.collide_with_bodies = false

	var result = space.intersect_ray(query)
	var hit: Node = null
	if result:
		var col = result.get("collider")
		if col is Area3D:
			var par = col.get_parent()
			if par.has_signal("cassette_clicked"):
				hit = par

	if event is InputEventMouseMotion:
		_update_hover(hit)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if hit != null:
				hit.cassette_clicked.emit(hit)
			get_viewport().set_input_as_handled()


func _update_hover(new_cassette: Node) -> void:
	if new_cassette == _hovered_cassette:
		return
	if _hovered_cassette != null and _hovered_cassette.current_state != 2:  # 2 = SELECTED
		_hovered_cassette.set_normal()
	_hovered_cassette = new_cassette
	if new_cassette != null and new_cassette.current_state != 2:
		new_cassette.set_hover()
