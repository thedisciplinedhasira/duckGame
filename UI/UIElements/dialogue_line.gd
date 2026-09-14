extends Resource
class_name DialogueLine

@export var text: String = ""
@export var character_portrait: Texture2D
@export var portrait_position: Vector2 = Vector2.ZERO # (0, 0) falls back to default UI position
