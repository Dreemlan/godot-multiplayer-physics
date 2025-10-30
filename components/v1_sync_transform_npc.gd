extends Node

@onready var rigidbody = get_parent() as RigidBody3D

@export var network_tick_rate: float = 20.0  # times per second to send updates

var _tick_accumulator: float = 0.0
var server_state_to_interpolate: Dictionary = {}

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_process(delta)
	else:
		_client_process(delta)


func _server_process(delta: float) -> void:
	
	var server_state: Dictionary = {
		"pos": rigidbody.global_position,
		"rot": rigidbody.global_rotation,
		"lin_vel": rigidbody.linear_velocity,
		"ang_vel": rigidbody.angular_velocity
	}
	rpc("client_update_state", server_state)

	## Using ticks
	#_tick_accumulator += delta
	#var interval = 1.0 / network_tick_rate
	#if _tick_accumulator >= interval:
		#_tick_accumulator -= interval
		
		#var server_state: Dictionary = {
			#"pos": rigidbody.global_position,
			#"rot": rigidbody.global_rotation,
			#"lin_vel": rigidbody.linear_velocity,
			#"ang_vel": rigidbody.angular_velocity
		#}
		#
		#rpc("client_update_state", server_state)


func _client_process(delta) -> void:
	_interpolate_server_state(delta)


func _interpolate_server_state(delta) -> void:
	var lerp_speed: float = 30.0
	if not server_state_to_interpolate.size() == 0:
		var pos = server_state_to_interpolate["pos"]
		var rot = server_state_to_interpolate["rot"]
		var lin_vel = server_state_to_interpolate["lin_vel"]
		var ang_vel = server_state_to_interpolate["ang_vel"] # CAUSING STUTTER
		rigidbody.global_position = rigidbody.global_position.lerp(pos, delta * lerp_speed)
		rigidbody.global_rotation = rigidbody.global_rotation.lerp(rot, delta * lerp_speed)
		rigidbody.linear_velocity = rigidbody.linear_velocity.lerp(lin_vel, delta * lerp_speed)
		rigidbody.angular_velocity = rigidbody.angular_velocity.lerp(ang_vel, delta * lerp_speed) # CAUSING STUTTER


@rpc("authority")
func client_update_state(server_state: Dictionary) -> void:
	server_state_to_interpolate = server_state
