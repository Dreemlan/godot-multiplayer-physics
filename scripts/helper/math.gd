extends Node

func lerp_pos(a: Vector3, b: Vector3, lerp_speed: float, delta: float) -> Vector3:
	var new_pos = a.lerp(b, delta * lerp_speed)
	return new_pos

func slerp_basis(a: Basis, b: Basis, lerp_speed: float, delta: float) -> Basis:
	var current_q: Quaternion = a.get_rotation_quaternion()
	var target_q: Quaternion = b.get_rotation_quaternion()
	
	var t = clamp(lerp_speed * delta, 0.0, 1.0)
	var new_q = current_q.slerp(target_q, t)
	
	var new_basis = Basis(new_q)
	return new_basis
