# 01. Client simulates locally and sends input state (containing input sequence) to server
# 02. Server marks down the input sequence and applies its corresponding movement
# 03. Server then sends an RPC back to client with the transform result from its physics simulation
# 04. Client receives the server state and immediately snaps to its position
# 05. Client then drops any inputs that the server has already acknowledged (prevent rubber-banding)
# 06. Client also 
extends Node

@onready var rigidbody = get_parent() as RigidBody3D

var input_seq: int = 0
var pending_inputs: Array = []
var last_confirmed_input: int = 0
var needs_reconcile: bool = false
var pending_state: Dictionary = {}

var input_dir: Vector2 = Vector2.ZERO
var move_dir: Vector2 = Vector2.ZERO # Doesn't include pitch

const MOVE_SPEED: int = 1
const MAX_INPUTS: int = 32


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		pass
	else:
		_client_process(delta)


func _client_process(_delta: float) -> void:
	if needs_reconcile:
		_apply_server_snapshot()
		needs_reconcile = false
	
	input_seq += 1
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()
	var input_state = {"seq": input_seq, "move_dir": input_dir}
	
	_apply_movement(input_dir) # Client-side prediction
	
	pending_inputs.append(input_state)
	
	rpc_id(1, "server_receive_input", input_state)


func _apply_server_snapshot() -> void:
	if pending_state.is_empty(): return
	
	rigidbody.global_position = pending_state["pos"]
	rigidbody.global_basis = pending_state["basis"]
	rigidbody.linear_velocity = pending_state["lin_vel"]
	rigidbody.angular_velocity = pending_state["ang_vel"]
	
	# Always drop inputs that the server already knows about
	pending_inputs = pending_inputs.filter(
		func(i): return i["seq"] > last_confirmed_input
	)
	# Optional hard cap to avoid pathological growth
	if pending_inputs.size() > MAX_INPUTS:
		pending_inputs = pending_inputs.slice(-MAX_INPUTS, MAX_INPUTS)


@rpc("authority")
func client_receive_state(server_state: Dictionary, confirmed_input: int) -> void:
	pending_state = server_state
	last_confirmed_input = confirmed_input
	needs_reconcile = true


@rpc("any_peer")
func server_receive_input(input_state: Dictionary) -> void:
	_apply_movement(input_state["move_dir"])

	last_confirmed_input = input_state["seq"]
	
	var server_state: Dictionary = {
		"pos": rigidbody.global_position,
		"basis": rigidbody.global_basis,
		"lin_vel": rigidbody.linear_velocity,
		"ang_vel": rigidbody.angular_velocity
	}

	rpc("client_receive_state", server_state, input_state["seq"])


func _apply_movement(dir: Vector2) -> void:
	if dir == Vector2.ZERO: return
	var force = Vector3(dir.x, 0, dir.y) * MOVE_SPEED
	rigidbody.apply_central_impulse(force)
