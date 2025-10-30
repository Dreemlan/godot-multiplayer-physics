extends Camera3D

var mouse_sensitivity := 0.1
var twist_input := 0.0
var pitch_input := 0.0

var lerp_follow_speed := 100.0
var lerp_rotation_speed := 5.0

var move_dir: Vector2 = Vector2.ZERO # Derived from -z basis (forward) and right

@onready var pivot = get_parent() as Node3D


func _ready():
	if multiplayer.is_server(): return
	
	top_level = true # Decouple rotation from parent, so camera can control it
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server(): return
	
	_follow_pivot(delta)
	_rotate_pivot(delta)


func _unhandled_input(event):
	if multiplayer.is_server(): return
	
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_rotate_camera(event)
	
	if event is InputEventKey:
		_free_mouse()


func _rotate_camera(event: InputEventMouseMotion) -> void:
	twist_input -= event.relative.x * mouse_sensitivity
	pitch_input -= event.relative.y * mouse_sensitivity
	pitch_input = clamp(pitch_input, -89, 89) # 90 causes movement issues when looking straight down
	basis = _quat_rotate(twist_input, pitch_input)


func _quat_rotate(twist, pitch) -> Basis:
	var twist_quat = Quaternion(Vector3.UP, deg_to_rad(twist))
	var pitch_quat = Quaternion(Vector3.RIGHT, deg_to_rad(pitch))
	return Basis(twist_quat * pitch_quat)


func _free_mouse() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _follow_pivot(delta: float) -> void:
	global_position = lerp(global_position, pivot.global_position, delta * lerp_follow_speed)


func _rotate_pivot(delta: float) -> void:
	var current_q: Quaternion = pivot.basis.get_rotation_quaternion()
	var target_q: Quaternion = basis.get_rotation_quaternion()
	
	var t = clamp(lerp_rotation_speed * delta, 0.0, 1.0)
	var new_q = current_q.slerp(target_q, t)
	
	var new_basis = Basis(new_q)
	pivot.basis = new_basis
