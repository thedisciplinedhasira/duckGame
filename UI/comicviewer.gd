extends Control

# Added the back button reference here
@onready var back_button: Button = $BackButton
@onready var left_button: Button = $HBoxContainer/LeftButton
@onready var right_button: Button = $HBoxContainer/RightButton

@export var comic_titles: Array[String]
@onready var title_label: Label = $TitleLabel

@export var comic_pages: Array[Texture2D]
var sprites: Array[Sprite3D] = []
var current_index: int = 0

# --- Polish Settings ---
var target_image_height: float = 4.0 
var center_z_offset: float = 3.0
var center_gap: float = 2.5 
var side_spacing: float = 0.6 
var side_angle: float = 65.0 
var side_scale: float = 0.85 

# Update this path to match exactly where you saved your shader file!
const ROUNDED_SHADER = preload("res://comicViewer.gdshader") 


func _ready():
	var carousel_root = $SubViewportContainer/SubViewport/CarouselRoot
	
	for tex in comic_pages:
		var sprite = Sprite3D.new()
		
		var mat = ShaderMaterial.new()
		mat.shader = ROUNDED_SHADER
		mat.set_shader_parameter("image_texture", tex)
		
		if tex.get_height() > 0:
			# Calculate aspect ratio for perfect rounded corners
			var aspect = float(tex.get_width()) / float(tex.get_height())
			mat.set_shader_parameter("aspect_ratio", aspect)
			mat.set_shader_parameter("corner_radius", 0.04) 
			
			# Normalize the 3D size of the image regardless of pixel resolution
			sprite.pixel_size = target_image_height / float(tex.get_height())
			sprite.texture = tex 
		
		sprite.material_override = mat
		
		carousel_root.add_child(sprite)
		sprites.append(sprite)
		
	# Connect buttons
	left_button.pressed.connect(shift_carousel.bind(-1))
	right_button.pressed.connect(shift_carousel.bind(1))
	
	# Connected the back button
	back_button.pressed.connect(_on_back_pressed)
  
	update_carousel(0.0)

func _input(event):
	if event.is_action_pressed("ui_right"):
		shift_carousel(1)
	elif event.is_action_pressed("ui_left"):
		shift_carousel(-1)
	elif event.is_action_pressed("ui_cancel"):
		queue_free()

func shift_carousel(direction: int):
	var new_index = clamp(current_index + direction, 0, sprites.size() - 1)
	if new_index != current_index:
		current_index = new_index
		update_carousel(0.5) 

func update_carousel(duration: float):
	# 1. Only create the Tween IF the duration is greater than 0
	var tween: Tween
	if duration > 0.0:
		tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# --- LABEL LOGIC ---
	if current_index < comic_titles.size():
		title_label.text = comic_titles[current_index]
		
		if duration > 0.0:
			title_label.modulate.a = 0.0
			tween.tween_property(title_label, "modulate:a", 1.0, duration)
		else:
			title_label.modulate.a = 1.0
	else:
		title_label.text = "" 
	# -----------------------	
	
	for i in range(sprites.size()):
		var sprite = sprites[i]
		var diff = i - current_index
		
		var target_pos = Vector3.ZERO
		var target_rot = Vector3.ZERO
		var target_scale = Vector3.ONE
		var target_alpha = 1.0
		
		if diff == 0:
			# Focused center image
			target_pos = Vector3(0, 0, center_z_offset)
			target_rot = Vector3.ZERO
			target_scale = Vector3.ONE
			target_alpha = 1.0
		else:
			# Unfocused side images
			var direction_sign = sign(diff)
			var distance = abs(diff)
			
			var x_offset = direction_sign * (center_gap + (distance - 1) * side_spacing)
			var z_offset = -distance * 0.5 
			
			target_pos = Vector3(x_offset, 0, z_offset)
			target_rot = Vector3(0, deg_to_rad(-direction_sign * side_angle), 0)
			target_scale = Vector3(side_scale, side_scale, side_scale)
			
			target_alpha = max(0.2, 0.7 - (distance * 0.15))

		if duration > 0.0:
			tween.tween_property(sprite, "position", target_pos, duration)
			tween.tween_property(sprite, "rotation", target_rot, duration)
			tween.tween_property(sprite, "scale", target_scale, duration)
			tween.tween_property(sprite, "modulate:a", target_alpha, duration)
		else:
			sprite.position = target_pos
			sprite.rotation = target_rot
			sprite.scale = target_scale
			sprite.modulate.a = target_alpha
# --- BACK BUTTON LOGIC ---
func _on_back_pressed():
	queue_free()
