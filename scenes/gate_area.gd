extends Area3D

@onready var interaction_prompt: Label3D = $Label3D
var player_in_range := false
var player_node: CharacterBody3D = null

func _ready() -> void:
	interaction_prompt.hide()
	# Connect the Area3D signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	# Make sure your 3D Player node is named "Player" or is in a "Player" group
	if body.name == "Player": 
		player_in_range = true
		player_node = body
		interaction_prompt.show()

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_in_range = false
		player_node = null
		interaction_prompt.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return
		
	# Check if the player presses the Left Ctrl key
	if event is InputEventKey and event.keycode == KEY_CTRL and event.pressed:
		interaction_prompt.hide()
		execute_dimension_shift()

func execute_dimension_shift() -> void:
	if player_node:
		# Call the perspective toggle on your player
		player_node.toggle_perspective()
		
		# ADD YOUR SCENE TRANSITION LOGIC HERE
		# Example: get_tree().change_scene_to_file("res://levels/2d_dimension.tscn")
