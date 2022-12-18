# Typical lobby implementation; imagine this being in /root/lobby.

extends Node

# Connect all functions

func _ready():
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_server_disconnected)
	
	if multiplayer.is_server():
		$StartGameButton.visible = true

# Player info, associate ID to data
var player_info = {}
# Info we send to other players
var my_info = { name = "Jordan Belfort", favorite_color = Color8(255, 0, 255) }

func _player_connected(id):
	# Called on both clients and server when a peer connects. Send my info to it.
	rpc_id(id, "register_player", my_info)

func _player_disconnected(id):
	print("player " + str(id) + " disconnected")
	player_info.erase(id) # Erase player from info.

func _connected_ok():
	print("connected ok")
	# Only called on clients, not server

func _server_disconnected():
	print("server disconnected: Server kicked us")
	# Server kicked us; show error and abort.

func _connected_fail():
	print("failed connect to server")

@rpc(any_peer)
func register_player(info):
	# Get the id of the RPC sender.
	var id = multiplayer.get_remote_sender_id()
	# Store the info
	player_info[id] = info

	$PlayerList.add_new_player_to_list(id, info["name"])

var players_done = []
@rpc(any_peer, call_local)
func done_preconfiguring():
	var who = multiplayer.get_remote_sender_id()
	# Here are some checks
	assert(multiplayer.is_server())
	assert(who in player_info or who == 1)# Exists
	assert(not who in players_done) # Was not added yet

	players_done.append(who)

	if players_done.size() == player_info.size()+1:
		rpc("post_configure_game")

@rpc(any_peer, call_local)
func pre_configure_game():
	get_tree().set_pause(true) # Pre-pause
	
	var selfPeerID = multiplayer.get_unique_id()

	# Load world
	var world = load("res://Scenes/Game.tscn").instantiate()
	get_node("/root").add_child(world)

	# Load my player
	var my_player = preload("res://Scenes/Player.tscn").instantiate()
	my_player.set_name(str(selfPeerID))
	my_player.set_multiplayer_authority(selfPeerID) # Will be explained later
	get_node("/root/World/players").add_child(my_player)

	# Load other players
	for p in player_info:
		var player = preload("res://Scenes/Player.tscn").instantiate()
		player.set_name(str(p))
		player.set_multiplayer_authority(p) # Will be explained later
		player.position.y = 50
		player.position.x = randi_range(50, 500)
		get_node("/root/World/players").add_child(player)

	# Tell server (remember, server is always ID=1) that this peer is done pre-configuring.
	# The server can call get_tree().get_rpc_sender_id() to find out who said they were done.
	rpc_id(1, "done_preconfiguring")

@rpc(call_local)
func post_configure_game():
	# Only the server is allowed to tell a client to unpause
	if 1 == multiplayer.get_remote_sender_id():
		get_tree().set_pause(false)
		# Game starts now!

# если лидер лобби жмет start
func _on_start_game_button_pressed():
	# запускаем сдадию пре-конфигурации
	rpc("pre_configure_game")
