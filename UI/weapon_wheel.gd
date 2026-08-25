extends CanvasLayer

signal weapon_selected(ability_index)

@export var ability_icons: Array[Texture2D] = []
@export var ability_names: Array[String] = [] 
@export var ability_colors: Array[Color] = [] 

@export_group("Text Styling")
@export var custom_font: Font 
@export var font_size: int = 32
@export var font_color: Color = Color.WHITE
@export var outline_size: int = 6
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.8)

@export_group("HUD Settings")
@export var hud_icon_size: Vector2 = Vector2(64, 64) # Tweak the size here!
@export var hud_margin: Vector2 = Vector2(32, 32)    # Tweak the screen position here!

@export_group("Other")
@export var custom_cursor: Texture2D

var is_open: bool = false
var selected_weapon_index: int = -1
var icon_nodes: Array[TextureRect] = []
var name_label: Label 
var equipped_icon_rect: TextureRect 

@onready var center_control = $CenterControl
@onready var ring_shader = $CenterControl/RingBackground 
@onready var popup_sound = $PopupSound
@onready var hover_sound = $HoverSound

func _ready():
	center_control.hide() 
	
	var mat = ring_shader.material as ShaderMaterial
	mat.set_shader_parameter("segment_count", max(ability_icons.size(), 1))
	
	var rect_size = ring_shader.get_rect().size
	if rect_size.y > 0:
		mat.set_shader_parameter("aspect_ratio", rect_size.x / rect_size.y)
	
	var passed_colors = ability_colors.duplicate()
	passed_colors.resize(12) 
	mat.set_shader_parameter("segment_colors", passed_colors)
	
	var outer_rad = mat.get_shader_parameter("outer_radius")
	var thickness = mat.get_shader_parameter("thickness")
	var middle_uv = outer_rad - (thickness / 2.0)
	var auto_icon_radius = middle_uv * min(rect_size.x, rect_size.y)
	
	var segment_arc = TAU / max(ability_icons.size(), 1)
	
	for i in range(ability_icons.size()):
		var tex = TextureRect.new()
		tex.texture = ability_icons[i]
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.custom_minimum_size = Vector2(64, 64)
		tex.pivot_offset = tex.custom_minimum_size / 2.0
		
		var angle = (i * segment_arc) - (PI / 2.0)
		tex.position = (Vector2(cos(angle), sin(angle)) * auto_icon_radius) - tex.pivot_offset
		
		center_control.add_child(tex)
		icon_nodes.append(tex)
		
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var font_settings = LabelSettings.new()
	if custom_font:
		font_settings.font = custom_font
		
	font_settings.font_size = font_size
	font_settings.font_color = font_color
	font_settings.outline_size = outline_size
	font_settings.outline_color = outline_color
	
	name_label.label_settings = font_settings
	
	name_label.custom_minimum_size = Vector2(400, 50)
	name_label.position = Vector2(-200, auto_icon_radius + 40)
	center_control.add_child(name_label)
	name_label.text = ""
	
	# === HUD SETUP ===
	equipped_icon_rect = TextureRect.new()
	equipped_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	# Apply your custom size and margin from the Inspector
	equipped_icon_rect.custom_minimum_size = hud_icon_size
	equipped_icon_rect.size = hud_icon_size
	equipped_icon_rect.position = hud_margin 
	
	add_child(equipped_icon_rect) 
	
	# Start completely hidden until the player actually picks something
	equipped_icon_rect.hide()

func _input(event):
	if event.is_action_pressed("open_weapon_wheel"):
		open_wheel()
	elif event.is_action_released("open_weapon_wheel"):
		close_wheel()

func _process(delta):
	if not is_open or ability_icons.is_empty(): return
	
	var pointer_dir = center_control.get_local_mouse_position()
	
	if pointer_dir.length() < 40.0:
		_highlight_weapon(-1, delta)
		return
		
	var segment_arc = TAU / ability_icons.size()
	
	var mouse_angle = atan2(pointer_dir.y, pointer_dir.x) + (PI / 2.0) + (segment_arc / 2.0)
	if mouse_angle < 0.0:
		mouse_angle += TAU
	mouse_angle = fmod(mouse_angle, TAU) 
	
	var hovered_index = int(mouse_angle / segment_arc) % ability_icons.size()
	
	_highlight_weapon(hovered_index, delta)

func _highlight_weapon(index: int, delta: float):
	if index != selected_weapon_index and index != -1:
		if hover_sound:
			hover_sound.pitch_scale = randf_range(0.95, 1.05)
			hover_sound.play()
			
	selected_weapon_index = index
	
	var mat = ring_shader.material as ShaderMaterial
	mat.set_shader_parameter("selected_index", index)
	
	if index != -1 and index < ability_names.size():
		name_label.text = ability_names[index]
	else:
		name_label.text = ""
	
	for i in range(icon_nodes.size()):
		var icon = icon_nodes[i]
		if i == index:
			icon.modulate = icon.modulate.lerp(Color(1.0, 1.0, 1.0, 1.0), 15.0 * delta)
		else:
			icon.modulate = icon.modulate.lerp(Color(0.5, 0.45, 0.4, 0.8), 10.0 * delta)

func open_wheel():
	is_open = true
	center_control.show()
	if popup_sound: popup_sound.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
func close_wheel():
	is_open = false
	center_control.hide() 
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if selected_weapon_index != -1:
		# Apply the texture and reveal the HUD icon
		equipped_icon_rect.texture = ability_icons[selected_weapon_index]
		equipped_icon_rect.show()
		
		weapon_selected.emit(selected_weapon_index)
		_highlight_weapon(-1, 0.016)
