extends RigidBody3D

@export var push_force: float = 1.2

func push_from(world_point: Vector3, dir: Vector3) -> void:
	if dir.length() < 0.01:
		return

	var strength: float = clamp(dir.length(), 0.0, 2.0)
	var force: Vector3 = dir.normalized() * push_force * strength

	apply_force(force, world_point - global_position)
