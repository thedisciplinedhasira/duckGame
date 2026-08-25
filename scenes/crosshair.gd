
extends CanvasLayer 

#@onready var dot = $Dot
#@onready var reticle = $Reticle
@onready var dot: TextureRect = $Dot
@onready var reticle: TextureRect = $Reticle

func set_state_default():
	dot.visible = true
	reticle.visible = false

func set_state_can_interact():
	dot.visible = false
	reticle.visible = true
