extends CharacterBody2D

@export var speed: float = 800.0

@onready var animated_sprite = $AnimatedSprite2D

# Remembers the last direction to play the correct idle animation
var last_direction: String = "front" 

func _physics_process(_delta):
	# 1. NEW: Check if the menu is open. If it is, stop moving
	if GameManager.is_interacting:
		# Force the idle animation before freeze
		match last_direction:
			"front": animated_sprite.play("idle")
			"back": animated_sprite.play("back_idle")
			"right": animated_sprite.play("right_idle")
			"left": animated_sprite.play("left_idle")
		return # 'return' cancels the rest of the movement code below

	var move_dir = Vector2.ZERO
	
	var input_x = Input.get_axis("ui_left", "ui_right")
	var input_y = Input.get_axis("ui_up", "ui_down")
	
	if input_x != 0:
		move_dir.x = input_x
		move_dir.y = 0 
	elif input_y != 0:
		move_dir.x = 0
		move_dir.y = input_y 
		
	# Apply physical movement
	velocity = move_dir * speed
	move_and_slide()
	
	#Use 'move_dir' instead of 'velocity' for animations
	# Now, even if the wall stops velocity, input (move_dir) will still turn the character.
	if move_dir.length() > 0:
		if move_dir.x > 0:
			last_direction = "right"
			animated_sprite.play("right_run")
		elif move_dir.x < 0:
			last_direction = "left"
			animated_sprite.play("left_run")
		elif move_dir.y > 0:
			last_direction = "front"
			animated_sprite.play("front_run")
		elif move_dir.y < 0:
			last_direction = "back"
			animated_sprite.play("back_run")
			
	else:
		match last_direction:
			"front": animated_sprite.play("idle")
			"back": animated_sprite.play("back_idle")
			"right": animated_sprite.play("right_idle")
			"left": animated_sprite.play("left_idle")
