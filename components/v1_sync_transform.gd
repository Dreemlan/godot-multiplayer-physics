# INCREASING MAX PHYSICS STEPS PER FRAME HELPS
extends Node

@onready var rigidbody = get_parent() as RigidBody3D

var tick: int = 0
var unacked_inputs: Array = []
var last_processed_tick: int = 0

var server_state_to_interpolate: Dictionary = {}

var input_dir: Vector2 = Vector2.ZERO
var move_dir: Vector2 = Vector2.ZERO # Doesn't include pitch

const MOVE_SPEED: float = 100.0


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_process(delta)
	else:
		_client_process(delta)


func _server_process(_delta: float) -> void:
	pass


func _client_process(delta: float) -> void:
	tick += 1
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()
	var input_state = {"tick": tick, "move_dir": input_dir}
	
	_apply_movement(input_dir) # Client-side prediction
	
	unacked_inputs.append(input_state)
	
	rpc_id(1, "server_receive_input", input_state)
	
	_interpolate_server_state(delta)


## EXPERIMENT WITH PHYSICS RATE IN PROJECT SETTINGS
func _interpolate_server_state(delta) -> void:
	if server_state_to_interpolate.is_empty(): return
	
	var lerp_speed: float = 10.0 # Lower causes rubberbanding when resimulating physics
	var interp_factor: float = clamp(delta * lerp_speed, 0.0, 1.0)
	
	var target_pos: Vector3 = server_state_to_interpolate["pos"]
	var target_basis: Basis = server_state_to_interpolate["basis"]
	var target_lin_vel: Vector3 = server_state_to_interpolate["lin_vel"]
	var target_ang_vel: Vector3 = server_state_to_interpolate["ang_vel"]
	
	# Position
	rigidbody.global_position = \
		rigidbody.global_position.lerp(target_pos, interp_factor)
	
	# Rotation
	var target_quat : Quaternion = target_basis.get_rotation_quaternion()
	var current_quat : Quaternion = rigidbody.global_basis.get_rotation_quaternion()
	var new_quat : Quaternion = current_quat.slerp(target_quat, interp_factor)
	rigidbody.global_transform.basis = Basis(new_quat)
	
	# Velocities
	rigidbody.linear_velocity = \
		rigidbody.linear_velocity.lerp(target_lin_vel, interp_factor)
	rigidbody.angular_velocity = \
		rigidbody.angular_velocity.lerp(target_ang_vel, interp_factor)
	
	#rigidbody.global_position = rigidbody.global_position.lerp(pos, delta * lerp_speed)
	#rigidbody.global_rotation = rigidbody.global_rotation.lerp(bas, delta * lerp_speed)
	#rigidbody.linear_velocity = rigidbody.linear_velocity.lerp(lin_vel, delta * lerp_speed)
	#rigidbody.angular_velocity = rigidbody.angular_velocity.lerp(ang_vel, delta * lerp_speed)


func _resimulate_physics(confirmed_tick: int) -> void:
	unacked_inputs = unacked_inputs.filter(func(input): return input["tick"] > confirmed_tick)
	for input_state in unacked_inputs:
		_apply_movement(input_state["move_dir"])


@rpc("authority")
func client_receive_state(server_state: Dictionary, confirmed_tick: int) -> void:
	server_state_to_interpolate = server_state
	#_resimulate_physics(confirmed_tick)


@rpc("any_peer")
func server_receive_input(input_state: Dictionary) -> void:
	_apply_movement(input_state["move_dir"])

	last_processed_tick = input_state["tick"]
	
	var server_state: Dictionary = {
		"pos": rigidbody.global_position,
		"basis": rigidbody.global_basis,
		"lin_vel": rigidbody.linear_velocity,
		"ang_vel": rigidbody.angular_velocity
	}

	rpc("client_receive_state", server_state, input_state["tick"])


func _apply_movement(dir: Vector2) -> void:
	if dir == Vector2.ZERO: return
	var force = Vector3(dir.x, 0, dir.y) * MOVE_SPEED * rigidbody.mass
	rigidbody.apply_central_force(force)
