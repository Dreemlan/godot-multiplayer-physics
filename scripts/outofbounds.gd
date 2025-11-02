extends Area3D

func _ready() -> void:
	body_entered.connect(_body_entered)

func _body_entered(body: Node) -> void:
	if multiplayer.is_server():
		# "Respawn" by moving to center of level in the air
		body.linear_velocity = Vector3.ZERO
		body.global_position = Vector3(0, 10, 0)
