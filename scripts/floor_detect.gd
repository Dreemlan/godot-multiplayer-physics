extends RayCast3D

@onready var body = get_parent() as RigidBody3D

func _process(_delta: float) -> void:
	if is_on_floor():
		body.linear_damp = 5
	else:
		body.linear_damp = 0

func is_on_floor() -> bool:
	force_raycast_update()
	if is_colliding():
		return true
	else:
		return false
