extends CanvasLayer

@onready var background = $Background
@onready var progress_bar = $Background/ProgressBar
@onready var anim = $Background/AnimatedSprite2D
@onready var animation_player = $AnimationPlayer

var is_transitioning: bool = false 

func _ready():
	background.modulate.a = 0
	background.hide()

func change_scene(target_scene_path: String):
	if is_transitioning:
		return 
		
	is_transitioning = true
	
	# 1. Fade to Black
	background.show()
	progress_bar.value = 0
	animation_player.play("fade_in")
	anim.play()
	await animation_player.animation_finished
	
	# 2. Fake Loading Bar (This completely bypasses the Godot Threading bug!)
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 100.0, 0.2)
	await tween.finished
	
	# 3. Change Scene safely without background threads
	get_tree().change_scene_to_file(target_scene_path)
	
	# 4. Wait one frame for safely settling the new room
	await get_tree().process_frame
	
	# 5. Fade out
	animation_player.play("fade_out")
	await animation_player.animation_finished
	background.hide()
	
	is_transitioning = false
