extends Node

const IP_ADDRESS: String = "localhost"
const PORT: int = 42069
const MAX_CLIENTS: int = 8

const GAME_SCENE = "res://scenes/game.tscn"


func create_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_CLIENTS)
	multiplayer.multiplayer_peer = peer
	
	_load_game_scene()
	
	print("Server created")


func create_client() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_connected_to_server)
	
	print("Client created")


func _connected_to_server() -> void:
	_load_game_scene()


func _load_game_scene() -> void:
	get_tree().call_deferred(&"change_scene_to_packed", preload(GAME_SCENE))
