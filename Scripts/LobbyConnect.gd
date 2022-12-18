extends Node

func _on_connect_button_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client($ip.text, int($port.text))
	multiplayer.set_multiplayer_peer(peer)
	get_tree().change_scene_to_file("res://Scenes/Lobby.tscn")
