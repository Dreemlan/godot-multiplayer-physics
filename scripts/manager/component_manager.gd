extends Node


func add_component(peer_id: int, body: Node, component: PackedScene) -> void:
	var c = component.instantiate()
	c.set_multiplayer_authority(peer_id)
	body.add_child(c)
