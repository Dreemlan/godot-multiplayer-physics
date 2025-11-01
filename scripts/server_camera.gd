extends Camera3D

@onready var rigidbody = get_parent() as RigidBody3D

var mouse_sensitivity := 0.1
var twist_input := 0.0
var pitch_input := 0.0

var fly_speed := 2.0 


func _ready():
	current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	_move_spawn_position()


func _physics_process(_delta: float) -> void:
	_movement()


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_rotation(event)
	
	if event is InputEventKey:
		_free_mouse()


func _movement() -> void:
	# WASD movement (set bindings in project settings).
	# Shift and CTRL are recommended fly_up/down.
	if Input.is_action_pressed("move_up"):
		rigidbody.apply_central_impulse(-basis.z * fly_speed)
	if Input.is_action_pressed("move_down"):
		rigidbody.apply_central_impulse(basis.z * fly_speed)
	if Input.is_action_pressed("move_left"):
		rigidbody.apply_central_impulse(-basis.x * fly_speed)
	if Input.is_action_pressed("move_right"):
		rigidbody.apply_central_impulse(basis.x * fly_speed)
	if Input.is_action_pressed("fly_up"):
		rigidbody.apply_central_impulse(Vector3.UP * fly_speed)
	if Input.is_action_pressed("fly_down"):
		rigidbody.apply_central_impulse(-Vector3.UP * fly_speed)


func _rotation(event: InputEventMouseMotion) -> void:
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


func _move_spawn_position() -> void:
	global_position = Vector3(1, 5, 10)
