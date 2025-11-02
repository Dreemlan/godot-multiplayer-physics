extends Node

@onready var body = get_parent() as RigidBody3D
@onready var visual_body = get_parent().get_node("VisualBody")

# Interpolation / Smoothing
var snapshots: Array = []
const SNAPSHOT_BUFFER_SIZE: int = 40
const INTERP_DELAY_MS: int = 200
const MAX_VISUAL_DRIFT : float = 0.4
const CORRECTION_FACTOR: float = 0.05


## Core Logic

func _process(_delta: float) -> void:
	if multiplayer.is_server():
		pass
	else:
		_smooth_correction_toward_physics()
		_update_visual_transform()

func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		_server_process()
	else:
		pass


## Server Logic

func _server_process() -> void:
	var server_state: Dictionary = {
		"pos": body.global_position,
		"basis": body.global_basis,
		"lin_vel": body.linear_velocity,
		"ang_vel": body.angular_velocity,
		"time": Time.get_ticks_msec()
	}
	client_receive_state.rpc(server_state)


## RPC

@rpc("authority", "call_remote")
func client_receive_state(server_state: Dictionary) -> void:
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


## Helper

func _update_visual_transform() -> void:
	if snapshots.size() < 2:
		return

	var now = Time.get_ticks_msec()
	var target_time = now - INTERP_DELAY_MS

	var older = null
	var newer = null
	
	for i in range(snapshots.size() - 1, -1, -1):
		var s = snapshots[i]
		if s["time"] <= target_time:
			older = s
			if i + 1 < snapshots.size():
				newer = snapshots[i + 1]
			break
	
	if older == null:
		older = snapshots.front()
		newer = snapshots[1] if snapshots.size() > 1 else older
	elif newer == null:
		newer = older

	if newer["time"] != older["time"]:
		var t = float(target_time - older["time"]) / float(newer["time"] - older["time"])
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
		var dt = (target_time - older["time"]) / 1000.0  # convert ms → s
		
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
