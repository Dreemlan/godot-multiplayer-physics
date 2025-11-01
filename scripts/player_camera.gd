extends Camera3D

var mouse_sensitivity := 0.1
var twist_input := 0.0
var pitch_input := 0.0

@onready var look: Node3D = $".."


func _ready():
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if is_multiplayer_authority():
		
		if event is InputEventMouseMotion:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_rotate_camera(event)
		
		if event is InputEventKey:
			_free_mouse()


func _rotate_camera(event: InputEventMouseMotion) -> void:
	twist_input -= event.relative.x * mouse_sensitivity
	pitch_input -= event.relative.y * mouse_sensitivity
	pitch_input = clamp(pitch_input, -89, 89)
	look.basis = _quat_rotate(twist_input, pitch_input)
	server_receive_camera_basis.rpc(look.basis)


@rpc("authority", "call_remote")
func server_receive_camera_basis(target_basis: Basis) -> void:
	look.basis = target_basis


#region Helper
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
#endregion
