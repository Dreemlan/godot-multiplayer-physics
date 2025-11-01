extends Node

const PLAYER_SCENE = preload("res://scenes/player.tscn")


#region Server
func add_player(peer_id: int) -> void:
	spawn_player.rpc(peer_id)


func _remove_player(peer_id: int) -> void:
	despawn_player.rpc(peer_id)
#endregion


#region Server and Client
@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int) -> void:
	if peer_id == 1: return
	
	var player_name = str(peer_id)
	if not has_node(player_name):
		var player_inst = PLAYER_SCENE.instantiate()
		player_inst.name = player_name
		
		player_inst.get_node("PlayerController").set_multiplayer_authority(peer_id)
		
		add_child(player_inst)
		
		if peer_id == multiplayer.get_unique_id():
			for connected_peer in multiplayer.get_peers():
				spawn_player(connected_peer)


@rpc("authority", "call_local", "reliable")
func despawn_player(peer_id: int) -> void:
	var player_name: String = str(peer_id)
	var player_node = get_node_or_null(player_name)
	if player_node:
		player_node.queue_free()
#endregion
