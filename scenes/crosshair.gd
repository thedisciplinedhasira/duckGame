# res://crosshair.gd (Crosshair Autoload Script)
extends CanvasLayer # Change root to CanvasLayer if you put it on top

@onready var dot = $Dot
@onready var reticle = $Reticle

func set_state_default():
	dot.visible = true
	reticle.visible = false

func set_state_can_interact():
	dot.visible = false
	reticle.visible = true
