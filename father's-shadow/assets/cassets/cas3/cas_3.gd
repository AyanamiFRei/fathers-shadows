extends Node3D

signal cassette_clicked(cassette)

@export var music: AudioStream
@export var hover_color: Color = Color(0.9, 0.9, 0.9)
@export var selected_color: Color = Color(0.75, 0.85, 1.0)

enum State {
	NORMAL,
	HOVER,
	SELECTED
}

var current_state: State = State.NORMAL
var mesh_nodes: Array[MeshInstance3D] = []

# Храним исходные и подсвеченные материалы по каждому мешу и surface
var original_materials := {}
var hover_materials := {}
var selected_materials := {}


func _ready():
	_collect_meshes(self)
	_cache_materials()
	_connect_area()
	_apply_state()


func _collect_meshes(node: Node):
	for child in node.get_children():
		if child is MeshInstance3D:
			mesh_nodes.append(child)
		_collect_meshes(child)


func _connect_area():
	var area = $Area3D
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	area.input_event.connect(_on_input_event)


func _cache_materials():
	for mesh in mesh_nodes:
		var mesh_key = str(mesh.get_path())
		original_materials[mesh_key] = []
		hover_materials[mesh_key] = []
		selected_materials[mesh_key] = []

		if mesh.mesh == null:
			continue

		var surface_count = mesh.mesh.get_surface_count()

		for i in range(surface_count):
			var original_material = mesh.get_active_material(i)
			if original_material == null:
				original_material = mesh.mesh.surface_get_material(i)

			original_materials[mesh_key].append(original_material)
			hover_materials[mesh_key].append(_make_highlight_material(original_material, hover_color, 0.15, 0.35))
			selected_materials[mesh_key].append(_make_highlight_material(original_material, selected_color, 0.08, 0.25))


func _make_highlight_material(base_material: Material, tint: Color, tint_alpha: float, emission_energy: float) -> Material:
	if base_material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(tint.r, tint.g, tint.b, tint_alpha)
		fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fallback.emission_enabled = true
		fallback.emission = tint
		fallback.emission_energy_multiplier = emission_energy
		return fallback

	var mat = base_material.duplicate(true)

	if mat is StandardMaterial3D:
		var std := mat as StandardMaterial3D

		# Сохраняем текстуры и прозрачность исходного материала,
		# только слегка тонируем и добавляем emission.
		std.albedo_color = std.albedo_color.lerp(Color(tint.r, tint.g, tint.b, std.albedo_color.a), tint_alpha)
		std.emission_enabled = true
		std.emission = tint
		std.emission_energy_multiplier = emission_energy

		# Если материал уже был прозрачным, оставляем как есть.
		# Если нет - не насилуем прозрачность, чтобы не ломать вид.
		return std

	return mat


func _on_mouse_entered():
	if current_state != State.SELECTED:
		set_hover()


func _on_mouse_exited():
	if current_state != State.SELECTED:
		set_normal()


func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cassette_clicked.emit(self)


func set_normal():
	current_state = State.NORMAL
	_apply_state()


func set_hover():
	current_state = State.HOVER
	_apply_state()


func set_selected():
	current_state = State.SELECTED
	_apply_state()


func _apply_state():
	for mesh in mesh_nodes:
		if mesh.mesh == null:
			continue

		var mesh_key = str(mesh.get_path())
		var surface_count = mesh.mesh.get_surface_count()

		for i in range(surface_count):
			match current_state:
				State.NORMAL:
					mesh.set_surface_override_material(i, null)
				State.HOVER:
					mesh.set_surface_override_material(i, hover_materials[mesh_key][i])
				State.SELECTED:
					mesh.set_surface_override_material(i, selected_materials[mesh_key][i])
