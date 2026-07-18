extends Node2D


func _ready():
	ActionMenu.show_message("............", GameManager.player_name)
	await ActionMenu.choice_made
	ActionMenu.show_message("what is this place...", GameManager.player_name)
	await ActionMenu.choice_made
	ActionMenu.show_message("it gives off a familiar feeling..", GameManager.player_name)
	await ActionMenu.choice_made
