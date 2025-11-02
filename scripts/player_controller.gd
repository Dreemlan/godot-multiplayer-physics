extends Node3D

@onready var body = get_parent() as RigidBody3D
@onready var visual_body = get_parent().get_node("VisualBody")
@onready var camera: Camera3D = $PlayerInput/Camera3D

# Camera
var mouse_sensitivity := 0.1
var twist_input := 0.0
var pitch_input := 0.0

# Input
const MAX_INPUTS: int = 32
var input_dir: Vector2 = Vector2.ZERO
var input_seq: int = 0
var pending_inputs: Array = []
var last_confirmed_input: int = 0

# Interpolation / Smoothing
const SNAPSHOT_BUFFER_SIZE: int = 40
var snapshots: Array = []
const INTERP_DELAY_MS: int = 100
const MAX_VISUAL_DRIFT : float = 0.12
const CORRECTION_FACTOR: float = 0.2

# Movement
const MOVE_SPEED: float = 10.0
var cam_dir: Vector3 = Vector3.ZERO


## Core

func _ready() -> void:
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if is_multiplayer_authority():
		
		if event is InputEventMouseMotion:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_rotate_camera(event)
				cam_dir = -basis.z.normalized()
		elif event.is_action_pressed("esc"):
			_toggle_mouse_mode()


func _process(_delta: float) -> void:
	_smooth_correction_toward_physics()
	_update_visual_transform()


func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		_client_process()


func _client_process() -> void:
	input_seq += 1
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()
	
	var input_state = {
		"seq": input_seq,
		"dir": input_dir
	}
	
	_apply_movement(input_dir)
	
	pending_inputs.append(input_state)
	
	server_receive_input.rpc_id(1, input_state)
	server_receive_camera_basis.rpc(basis)


## Logic
# Camera
func _rotate_camera(event: InputEventMouseMotion) -> void:
	twist_input -= event.relative.x * mouse_sensitivity
	pitch_input -= event.relative.y * mouse_sensitivity
	pitch_input = clamp(pitch_input, -85, 85)
	basis = _quat_rotate(twist_input, pitch_input)


## RPC

@rpc("authority", "call_remote")
func server_receive_camera_basis(target_basis: Basis) -> void:
	basis = target_basis

@rpc("authority", "call_remote")
func server_receive_input(input_state: Dictionary) -> void:
	_apply_movement(input_state["dir"])

	last_confirmed_input = input_state["seq"]
	
	var server_state: Dictionary = {
		"pos": body.global_position,
		"basis": body.global_basis,
		"lin_vel": body.linear_velocity,
		"ang_vel": body.angular_velocity,
		"time": Engine.get_physics_frames()
	}
	
	client_receive_state.rpc(server_state, input_state["seq"])

@rpc("any_peer")
func client_receive_state(server_state: Dictionary, confirmed_input: int) -> void:
	body.global_position = server_state["pos"]
	body.global_basis = server_state["basis"]
	body.linear_velocity = server_state["lin_vel"]
	body.angular_velocity = server_state["ang_vel"]
	
	var snap: Dictionary = {
		"pos":       server_state["pos"],
		"basis":     server_state["basis"],
		"lin_vel":   server_state["lin_vel"],
		"ang_vel":   server_state["ang_vel"],
		"time": server_state["time"]
	}
	snapshots.append(snap)
	if snapshots.size() > SNAPSHOT_BUFFER_SIZE:
		snapshots.pop_front()
	
	last_confirmed_input = confirmed_input
	_prune_pending_inputs()
	for pending in pending_inputs:
		_apply_movement(pending["dir"])


## Helper

func _toggle_mouse_mode() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _quat_rotate(twist, pitch) -> Basis:
	var twist_quat = Quaternion(Vector3.UP, deg_to_rad(twist))
	var pitch_quat = Quaternion(Vector3.RIGHT, deg_to_rad(pitch))
	return Basis(twist_quat * pitch_quat)

func _apply_movement(dir: Vector2) -> void:
	if dir == Vector2.ZERO: return
	var move_dir = basis * Vector3(dir.x, 0, dir.y)
	var force = move_dir * MOVE_SPEED
	force.y = 0
	body.apply_central_impulse(force)

func _prune_pending_inputs() -> void:
	pending_inputs = pending_inputs.filter(
		func(i): return i["seq"] > last_confirmed_input
	)

func _update_visual_transform() -> void:
	if snapshots.size() < 2:
		return

	var fps = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	var delay_frames = int(round(INTERP_DELAY_MS / (1000.0 / fps)))
	var target_frame = Engine.get_physics_frames() - delay_frames

	# ---- locate surrounding snapshots (same as before) -----------------
	var older = null
	var newer = null
	
	for i in range(snapshots.size() - 1, -1, -1):
		var s = snapshots[i]
		if s["time"] <= target_frame:
			older = s
			if i + 1 < snapshots.size():
				newer = snapshots[i + 1]
			break
	
	if older == null:
		# Target is older than the oldest snapshot → use the oldest
		older = snapshots.front()
		newer = snapshots[1] if snapshots.size() > 1 else older
	elif newer == null:
		# Target is newer than the newest snapshot → extrapolate
		newer = older   # makes the later branch treat it as “no newer”

	# ---- interpolation / extrapolation -------------------------------
	if newer["time"] != older["time"]:
		var t = float(target_frame - older["time"]) / float(newer["time"] - older["time"])
		t = clamp(t, 0.0, 1.0)
		var interp_pos = older["pos"].lerp(newer["pos"], t)

		var q_old = Quaternion(older["basis"])
		var q_new = Quaternion(newer["basis"])
		var interp_quat = q_old.slerp(q_new, t)
		var interp_basis = Basis(interp_quat)

		visual_body.global_position = interp_pos
		visual_body.global_basis = interp_basis
	else:
		var latest = older
		var dt = (target_frame - latest["time"]) * (1.0 / fps)
		
		var extrap_pos = latest["pos"] + latest["lin_vel"] * dt
		
		# Only rotate if there is a meaningful angular velocity
		var extrap_basis : Basis
		var ang_vel = latest["ang_vel"]
		if ang_vel.length() > 0.0001:               # epsilon – tweak if you need more sensitivity
			var ang_axis  = ang_vel.normalized()
			var ang_angle = ang_vel.length() * dt
			var delta_rot = Basis().rotated(ang_axis, ang_angle)
			extrap_basis = latest["basis"] * delta_rot
		else:
			# No rotation – keep the basis exactly as it was
			extrap_basis = latest["basis"]
		
		visual_body.global_position = extrap_pos
		visual_body.global_basis    = extrap_basis

	# ---- TETHER: keep visual node close to the physics body ----------
	var drift = visual_body.global_position.distance_to(body.global_position)
	if drift > MAX_VISUAL_DRIFT && drift > 0.0:
		var dir = (visual_body.global_position - body.global_position).normalized()
		visual_body.global_position = body.global_position + dir * MAX_VISUAL_DRIFT

func _smooth_correction_toward_physics() -> void:
	# Position correction
	var pos_error = visual_body.global_position - body.global_position
	if pos_error.length() > 0.001:
		visual_body.global_position = visual_body.global_position.lerp(
		body.global_position,
		CORRECTION_FACTOR
	)

	# Rotation correction (slerp the basis)
	var cur_basis = visual_body.global_basis
	var target_basis = body.global_basis
	var angle_error = cur_basis.get_euler().distance_to(target_basis.get_euler())
	if angle_error > 0.001:
		visual_body.global_basis = cur_basis.slerp(target_basis, CORRECTION_FACTOR)
