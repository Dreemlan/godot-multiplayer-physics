# INCREASING MAX PHYSICS STEPS PER FRAME HELPS
extends Node

@onready var rigidbody = get_parent() as RigidBody3D

var tick: int = 0
var unacked_inputs: Array = []
var last_processed_tick: int = 0
var needs_reconcile: bool = false

var server_state_to_interpolate: Dictionary = {}

var input_dir: Vector2 = Vector2.ZERO
var move_dir: Vector2 = Vector2.ZERO # Doesn't include pitch

const MOVE_SPEED: float = 1.0
const MAX_UNACKED: int = 32


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		pass
	else:
		_client_process(delta)


func _client_process(_delta: float) -> void:
	tick += 1
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()
	var input_state = {"tick": tick, "move_dir": input_dir}
	
	_apply_movement(input_dir) # Client-side prediction
	
	unacked_inputs.append(input_state)
	
	rpc_id(1, "server_receive_input", input_state)


func _resimulate_physics(confirmed_tick: int) -> void:
	if server_state_to_interpolate.is_empty(): return
	
	var pos = server_state_to_interpolate["pos"]
	var basis = server_state_to_interpolate["basis"]
	var lin_vel = server_state_to_interpolate["lin_vel"]
	var ang_vel = server_state_to_interpolate["ang_vel"]
	
	rigidbody.global_position = pos
	rigidbody.global_basis = basis
	rigidbody.linear_velocity = lin_vel
	rigidbody.angular_velocity = ang_vel
	
	if unacked_inputs.size() > MAX_UNACKED:
		unacked_inputs = unacked_inputs.filter(
			func(i): return i["tick"] > confirmed_tick
		)
		for input_state in unacked_inputs:
			_apply_movement(input_state["move_dir"])


@rpc("authority")
func client_receive_state(server_state: Dictionary, confirmed_tick: int) -> void:
	server_state_to_interpolate = server_state
	_resimulate_physics(confirmed_tick)


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
	var force = Vector3(dir.x, 0, dir.y) * MOVE_SPEED
	rigidbody.apply_central_impulse(force)
