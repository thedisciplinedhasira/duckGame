extends Area3D

@export_multiline var dialogue_lines_text: Array[String] = ["Enter dialogue line here..."]
@export var character_image: Texture2D 
@export var portrait_position: Vector2 = Vector2.ZERO 

var is_player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_any_entered)
	area_entered.connect(_on_any_entered)
	body_exited.connect(_on_any_exited)
	area_exited.connect(_on_any_exited)

func _on_any_entered(node: Node3D) -> void:
	if not node.is_in_group("player"):
		return
		
	if not is_player_inside:
		is_player_inside = true
		
		# Build dialogue lines dynamically from the Inspector text array
		var lines: Array[DialogueLine] = []
		for text_content in dialogue_lines_text:
			var line = DialogueLine.new()
			line.text = text_content
			line.character_portrait = character_image
			line.portrait_position = portrait_position
			lines.append(line)
			
		DialogueUI.show_dialogue(lines)

func _on_any_exited(node: Node3D) -> void:
	if not node.is_in_group("player"):
		return
		
	if is_player_inside:
		is_player_inside = false
		DialogueUI.close_dialogue()
