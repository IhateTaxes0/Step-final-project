extends Node2D

@onready var player = %player 
@onready var room_spawn = $RoomSpawn

func _ready():
	# If player just walked in from the Main Room, teleport to the door
	if GameManager.entrance_door == "room":
		player.global_position = room_spawn.global_position
