extends Node

const IP_ADDRESS: String = "localhost"
const PORT: int = 42069
const MAX_CLIENTS: int = 8

const GAME_SCENE = "res://scenes/game.tscn"



#region Server
func create_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_CLIENTS)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	
	_load_game_scene()
	
	print("Server created")

func _peer_connected(peer_id: int) -> void:
	PlayerManager.add_player(peer_id)

func _peer_disconnected(peer_id: int) -> void:
	PlayerManager.remove_player(peer_id)
#endregion


#region Client
func create_client() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_connected_to_server)
	
	print("Client created")

func _connected_to_server() -> void:
	_load_game_scene()
#endregion


#region Server and Client
func _load_game_scene() -> void:
	get_tree().call_deferred(&"change_scene_to_packed", preload(GAME_SCENE))
#endregion
