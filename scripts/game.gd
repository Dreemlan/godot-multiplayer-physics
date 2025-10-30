extends Node3D

const SERVER_CAMERA_SCENE = preload("uid://dhkfp6t1n5kor")


func _enter_tree() -> void:
	_add_server_camera()


func _add_server_camera() -> void:
	if multiplayer.is_server():
		var server_camera = SERVER_CAMERA_SCENE.instantiate()
		add_child(server_camera)
