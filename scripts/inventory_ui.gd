extends CanvasLayer

# --- UPDATED PATHS ---
@onready var inventory_border = $InventoryBorder
@onready var inventory_label = $InventoryBorder/MarginContainer/VBoxContainer/InventoryLabel
@onready var grid = $InventoryBorder/MarginContainer/VBoxContainer/ScrollContainer/GridContainer

# --- POPUP NODES ---
@onready var item_popup = $ItemPopup
@onready var popup_name = $ItemPopup/MarginContainer/VBoxContainer/ItemName
@onready var popup_icon = $ItemPopup/MarginContainer/VBoxContainer/CenterContainer/FruitIcon
@onready var popup_desc = $ItemPopup/MarginContainer/VBoxContainer/Description
@onready var btn_no = $ItemPopup/MarginContainer/VBoxContainer/HBoxContainer/BtnNo
@onready var btn_yes = $ItemPopup/MarginContainer/VBoxContainer/HBoxContainer/BtnYes

var item_slot_scene = preload("res://world/item_slot.tscn")

var pending_fruit_index: int = -1
var pending_fruit_name: String = ""

func _ready():
	inventory_border.hide()
	inventory_label.hide() # Hide the header too!
	item_popup.hide()
	
	btn_yes.pressed.connect(_on_yes_pressed)
	btn_no.pressed.connect(_on_no_pressed)

func _unhandled_input(event):
	if event.is_action_pressed("toggle_inventory"):
		if inventory_border.visible:
			inventory_border.hide()
			inventory_label.hide()
			item_popup.hide() 
		else:
			open_inventory()

func open_inventory():
	for child in grid.get_children():
		child.queue_free()
		
	if GameManager.inventory.is_empty():
		inventory_border.hide()
		inventory_label.hide()
		item_popup.hide()
		return
		
	# Show both the border and the header!
	inventory_border.show()
	inventory_label.show()
	
	for i in range(GameManager.inventory.size()):
		var fruit_name = GameManager.inventory[i]
		var slot = item_slot_scene.instantiate()
		grid.add_child(slot)
		
		slot.setup(fruit_name)
		slot.pressed.connect(func(): _show_item_popup(i, fruit_name))

# --- POPUP LOGIC ---
func _show_item_popup(index: int, fruit_name: String):
	pending_fruit_index = index
	pending_fruit_name = fruit_name
	
	# Clean up the display name for the UI (Turns "god_fruit" into "God Fruit")
	popup_name.text = fruit_name.replace("_", " ").capitalize()
	
	# Format the file name correctly (Turns "God Fruit" into "god_fruit")
	var file_name = fruit_name.to_lower().replace(" ", "_")
	var image_path = "res://resources/items/" + file_name + ".png"
	
	if ResourceLoader.exists(image_path):
		popup_icon.texture = load(image_path)
	else:
		popup_icon.texture = null # Prevent showing the previous item's icon!
	
	# Pull the description
	popup_desc.text = get_fruit_description(fruit_name)
	
	item_popup.show()
	inventory_border.hide()
	inventory_label.hide()
	
func _on_no_pressed():
	# Cancel the action and hide the box
	item_popup.hide()

func _on_yes_pressed():
	# --- THE SAFETY CHECK ---
	# If the index is invalid or the array is already empty, ignore the click
	if pending_fruit_index < 0 or pending_fruit_index >= GameManager.inventory.size():
		return
		
	# Send it to the GameManager to handle the math, stacks, and forgetting!
	GameManager.consume_fruit(pending_fruit_name)
			
	# Remove the fruit and hide the popup
	GameManager.inventory.remove_at(pending_fruit_index)
	item_popup.hide()
	
	# Reset the index so it's mathematically impossible to double-click
	pending_fruit_index = -1
	
	# Redraw the grid
	open_inventory()

# --- DESCRIPTIONS ---
func get_fruit_description(fruit_name: String) -> String:
	# Normalize the name so spaces AND underscores both match perfectly
	var normalized_name = fruit_name.to_lower().replace("_", " ")
	
	match normalized_name:
		"quick hand": 
			return "30% chance to double attack (deals double damage)."
		"iron body": 
			return "Decrease 10% incoming damage."
		"combat master": 
			return "20% chance to nullify incoming attack and counter."
		"profency": 
			return "Increase skill damage by 20%."
		"god fruit": 
			return "Allows you to have 1 additional passive."
		"apple":
			return "Increases stats."
		_: 
			return "A mysterious fruit..."
