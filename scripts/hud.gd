extends CanvasLayer

@onready var anxiety_bar = $AnxietyContainer/AnxietyBar
@onready var sanity_bar = $SanityContainer/SanityBar
@onready var anxiety_label = $AnxietyContainer/AnxietyLabel
@onready var sanity_label = $SanityContainer/SanityLabel

# 1. Grab your new clock labels!
@onready var day_label = $day_panel/TimeContainer/DayLabel
@onready var time_label = $day_panel/TimeContainer/TimeLabel

func _ready():
	GameManager.stats_updated.connect(_on_stats_updated)
	GameManager.time_advanced.connect(_on_time_advanced)
	
	# Listen for the toggle signal
	GameManager.toggle_hud.connect(_on_toggle_hud)
	
	# THE BULLETPROOF FIX: Check the memory! 
	# If we haven't seen the intro yet, instantly hide!
	if GameManager.has_seen_intro == false:
		self.hide()
	
	# Wait 1 frame for the graphics card to build the room
	await get_tree().process_frame
	
	anxiety_bar.value = GameManager.anxiety
	sanity_bar.value = GameManager.sanity
	
	_on_time_advanced(GameManager.get_formatted_time(), GameManager.day)

func _on_stats_updated(new_anxiety, new_sanity):
	anxiety_bar.value = new_anxiety
	sanity_bar.value = new_sanity
	anxiety_label.modulate.a = 1.0
	sanity_label.modulate.a = 1.0

# 4. The function that physically updates the text on screen
func _on_time_advanced(new_time: String, new_day: int):
	day_label.text = "Day " + str(new_day)
	time_label.text = new_time
	
func _on_toggle_hud(show_hud: bool):
	self.visible = show_hud
