extends Button 

@onready var fruit_icon = $MarginContainer/FruitIcon

func setup(fruit_name: String):
	# 1. Convert any spaces into underscores and make it lowercase
	var file_name = fruit_name.to_lower().replace(" ", "_")
	
	# 2. Update the path to point to resources/items/
	var image_path = "res://resources/items/" + file_name + ".png"
	
	if ResourceLoader.exists(image_path):
		fruit_icon.texture = load(image_path)
	else:
		print("WARNING: Missing image art for ", fruit_name, " expected at: ", image_path)
