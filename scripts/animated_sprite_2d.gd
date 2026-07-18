extends AnimatedSprite2D

@onready var foreign_outline_sprite: Sprite2D = $area2d/Highlight

func _ready() -> void:
	if is_instance_valid(foreign_outline_sprite):
		foreign_outline_sprite.hframes = 1
		foreign_outline_sprite.vframes = 1
		foreign_outline_sprite.frame = 0

func _process(_delta: float) -> void:
	if is_instance_valid(foreign_outline_sprite):
		var current_frame_texture: Texture2D = sprite_frames.get_frame_texture(animation, frame)
		foreign_outline_sprite.texture = current_frame_texture
		foreign_outline_sprite.flip_h = self.flip_h
		foreign_outline_sprite.flip_v = self.flip_v
		foreign_outline_sprite.offset = self.offset
