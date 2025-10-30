extends MeshInstance3D

@onready var rigidbody = get_parent() as RigidBody3D

var lerp_speed: float = 20.0


func _ready() -> void:
	top_level = true


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(rigidbody.global_position, delta * lerp_speed)
