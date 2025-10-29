extends Control


func _ready() -> void:
	%Server.pressed.connect(_server_pressed)
	%Client.pressed.connect(_client_pressed)


func _server_pressed() -> void:
	NetworkManager.create_server()


func _client_pressed() -> void:
	NetworkManager.create_client()
