extends CanvasLayer
class_name WeaponWheel

signal weapon_selected(ability_index)
signal locked_ability_selected(ability_index)

@export_group("Wheel Nodes")
## Drag your TextureRect nodes from the Scene tree here in order (0: Top, 1: Bottom-Right, 2: Bottom-Left)
@export var icon_nodes: Array[TextureRect] = []
@export var highlight_nodes: Array[TextureRect] = [] 
@export var dot_nodes: Array[TextureRect] = []
@export var locked_overlay_nodes: Array[TextureRect] = [] ## Custom TextureRect overlays for locked slots
## The "Not Available" TextureRect, shown while hovering a locked slot
@export var not_available_rect: TextureRect

@export_group("Ability Lock Settings")
## Starting values only, the player overwrites these on _ready and owns the real state
@export var unlocked_abilities: Array[bool] = [true, false, false]

@export_group("Animation Settings")
## Time in seconds for the red comic dots to fade/flash in (increase to slow down)
@export var dot_fade_in_duration: float = 0.30
## Time in seconds for the red comic dots to fade out when switching slots
@export var dot_fade_out_duration: float = 0.20
## Time in seconds for the "Not Available" popup to fade in
@export var not_available_fade_duration: float = 0.12
## Time in seconds for the "Not Available" popup to scale up
@export var not_available_pop_duration: float = 0.18

@export_group("Data & Text")
@export var ability_names: Array[String] = [] 
@export var ability_colors: Array[Color] = [] 
@export var custom_font: Font 
@export var font_size: int = 32
@export var font_color: Color = Color.WHITE
@export var outline_size: int = 6
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.8)

@export_group("HUD Settings")
@export var hud_icon_size: Vector2 = Vector2(64, 64)
@export var hud_margin: Vector2 = Vector2(32, 32) 

var is_open: bool = false
var selected_weapon_index: int = -1

var name_label: Label 
var equipped_icon_rect: TextureRect 
var dot_tweens: Array[Tween] = []
var not_available_tween: Tween

@onready var center_control = $CenterControl
@onready var ring_background = $CenterControl/RingBackground
@onready var popup_sound = $PopupSound
@onready var hover_sound = $HoverSound
@onready var ability_meter: AbilityMeter = $AbilityMeter

func _ready():
	center_control.hide() 
	dot_tweens.resize(dot_nodes.size())
	
	# Prepare highlight background wedges (start invisible)
	for highlight in highlight_nodes:
		if highlight:
			highlight.modulate = Color(1, 1, 1, 0)
			
	# Initialize locked overlay textures based on unlock status
	for i in range(locked_overlay_nodes.size()):
		if locked_overlay_nodes[i]:
			var is_unlocked = i < unlocked_abilities.size() and unlocked_abilities[i]
			locked_overlay_nodes[i].visible = not is_unlocked
			
	# Prepare accent dots/lines (start invisible)
	for dot in dot_nodes:
		if dot:
			dot.modulate = Color(1, 1, 1, 0)
			
	# Prepare icon pivots for hover scaling
	for icon in icon_nodes:
		if icon:
			icon.pivot_offset = icon.size / 2.0

	# popup stays hidden until a locked slot is hovered
	if not_available_rect:
		not_available_rect.pivot_offset = not_available_rect.size / 2.0
		not_available_rect.hide()
		
	# Setup Label
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var font_settings = LabelSettings.new()
	if custom_font: font_settings.font = custom_font
	font_settings.font_size = font_size
	font_settings.font_color = font_color
	font_settings.outline_size = outline_size
	font_settings.outline_color = outline_color
	name_label.label_settings = font_settings
	
	name_label.custom_minimum_size = Vector2(400, 50)
	var rect_size = ring_background.size
	var label_offset = min(rect_size.x, rect_size.y) * 0.28 + 80.0
	name_label.position = Vector2(-200, label_offset)
	center_control.add_child(name_label)
	name_label.text = ""
	
	# HUD Setup
	equipped_icon_rect = TextureRect.new()
	equipped_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipped_icon_rect.custom_minimum_size = hud_icon_size
	equipped_icon_rect.size = hud_icon_size
	equipped_icon_rect.position = hud_margin 
	add_child(equipped_icon_rect) 
	equipped_icon_rect.hide()

func _input(event):
	if event.is_action_pressed("open_weapon_wheel"):
		open_wheel()
	elif event.is_action_released("open_weapon_wheel"):
		close_wheel()

func _process(delta):
	if not is_open or icon_nodes.is_empty(): return
	
	var pointer_dir = center_control.get_local_mouse_position()
	
	# Center deadzone
	if pointer_dir.length() < 30.0:
		_highlight_weapon(-1, delta)
		return
		
	var segment_arc = TAU / icon_nodes.size()
	var mouse_angle = atan2(pointer_dir.y, pointer_dir.x) + (PI / 2.0) + (segment_arc / 2.0)
	if mouse_angle < 0.0:
		mouse_angle += TAU
	mouse_angle = fmod(mouse_angle, TAU) 
	
	var hovered_index = int(mouse_angle / segment_arc) % icon_nodes.size()
	_highlight_weapon(hovered_index, delta)

func _is_slot_unlocked(index: int) -> bool:
	return index >= 0 and index < unlocked_abilities.size() and unlocked_abilities[index]

# shows the popup with a quick pop, hides it instantly
func _set_not_available_visible(show_it: bool) -> void:
	if not_available_rect == null:
		return

	if not_available_tween and not_available_tween.is_valid():
		not_available_tween.kill()

	if not show_it:
		not_available_rect.hide()
		return

	not_available_rect.show()
	not_available_rect.modulate.a = 0.0
	not_available_rect.scale = Vector2(0.6, 0.6)

	not_available_tween = create_tween().set_parallel(true)
	not_available_tween.tween_property(not_available_rect, "modulate:a", 1.0, not_available_fade_duration)
	not_available_tween.tween_property(not_available_rect, "scale", Vector2.ONE, not_available_pop_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _highlight_weapon(index: int, delta: float):
	if index != selected_weapon_index:
		var prev_index = selected_weapon_index
		selected_weapon_index = index

		# popup only for a real slot that is locked, dead zone and unlocked slots hide it
		_set_not_available_visible(index != -1 and not _is_slot_unlocked(index))
		
		# --- SMOOTH FADE IN ON HOVER CHANGE ---
		if index != -1:
			if hover_sound:
				hover_sound.pitch_scale = randf_range(0.95, 1.05)
				hover_sound.play()
				
			if index < dot_nodes.size() and dot_nodes[index]:
				var dot = dot_nodes[index]
				if dot_tweens[index]: dot_tweens[index].kill()
				
				dot.modulate = Color(1.8, 0.6, 0.6, 0.0)
				
				var tween = create_tween()
				tween.tween_property(dot, "modulate", Color(1.0, 1.0, 1.0, 1.0), dot_fade_in_duration)\
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				dot_tweens[index] = tween
		
		if prev_index != -1 and prev_index < dot_nodes.size() and dot_nodes[prev_index]:
			var old_dot = dot_nodes[prev_index]
			if dot_tweens[prev_index]: dot_tweens[prev_index].kill()
			
			var tween = create_tween()
			tween.tween_property(old_dot, "modulate:a", 0.0, dot_fade_out_duration)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			dot_tweens[prev_index] = tween

	# Update Name Label, the popup handles the locked message now so this is just the name
	if index != -1 and index < ability_names.size():
		name_label.text = ability_names[index]
	else:
		name_label.text = ""
	
	# Smoothly fade red wedge background fill and scale icons
	for i in range(icon_nodes.size()):
		var icon = icon_nodes[i]
		var highlight = highlight_nodes[i] if i < highlight_nodes.size() else null
		
		if i == index:
			if icon: 
				icon.scale = icon.scale.lerp(Vector2(1.2, 1.2), 15.0 * delta)
			if highlight: 
				highlight.modulate.a = lerpf(highlight.modulate.a, 1.0, 8.0 * delta) 
		else:
			if icon: 
				icon.scale = icon.scale.lerp(Vector2(1.0, 1.0), 15.0 * delta)
			if highlight: 
				highlight.modulate.a = lerpf(highlight.modulate.a, 0.0, 15.0 * delta)
				
func open_wheel():
	is_open = true
	center_control.show()
	if popup_sound: popup_sound.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_wheel():
	is_open = false
	center_control.hide() 
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if selected_weapon_index != -1 and selected_weapon_index < icon_nodes.size():
		# Prevent equipping if the ability is locked
		if not _is_slot_unlocked(selected_weapon_index):
			print("Ability is locked! Cannot equip.")
			# emit before the highlight reset, that call wipes selected_weapon_index
			locked_ability_selected.emit(selected_weapon_index)
			_highlight_weapon(-1, 1.0)
			return
			
		var selected_icon = icon_nodes[selected_weapon_index]
		if selected_icon and selected_icon.texture:
			ability_meter.set_icon(selected_icon.texture)
			
		if selected_weapon_index < ability_colors.size():
			ability_meter.set_color(ability_colors[selected_weapon_index])
			
		weapon_selected.emit(selected_weapon_index)
		
	_highlight_weapon(-1, 1.0)

# the player calls this whenever a slot changes, the overlay follows the state
func set_slot_unlocked(index: int, unlocked: bool) -> void:
	if index < 0 or index >= unlocked_abilities.size():
		return
	unlocked_abilities[index] = unlocked
	if index < locked_overlay_nodes.size() and locked_overlay_nodes[index]:
		locked_overlay_nodes[index].visible = not unlocked

	# keep the popup honest if the slot changes while the wheel is open and hovered
	if is_open and index == selected_weapon_index:
		_set_not_available_visible(not unlocked)

func unlock_ability(index: int) -> void:
	set_slot_unlocked(index, true)
