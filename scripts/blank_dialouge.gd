extends CanvasLayer

# Prevents the cutscene from accidentally playing twice
var cutscene_played = false 

func _ready():
	if not cutscene_played:
		cutscene_played = true
		await get_tree().create_timer(0.5).timeout
		trigger_cutscene()

func trigger_cutscene():
	# 1. Loop through the Dictionaries!
	for line_data in GameManager.cutscene_dialogues:
		# Extract the text and the speaker from the dictionary
		ActionMenu.show_message(line_data["text"], line_data["speaker"])
		await ActionMenu.choice_made
		
	# 2. Go to the target scene
	if GameManager.cutscene_target_scene != "":
		SceneTransition.change_scene(GameManager.cutscene_target_scene)
	else:
		SceneTransition.change_scene("res://world/dreamland1.tscn")
