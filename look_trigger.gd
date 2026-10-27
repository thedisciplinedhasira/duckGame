extends Node3D
class_name LookTrigger

signal seen
signal unseen

@export var size := Vector3(4, 4, 4)       # box that counts as "in view"
@export var targets: Array[Node3D] = []    # stuff this trigger controls
@export var visible_when_seen := false     # false = targets show only when NOT looked at

@onready var notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D

func _ready():
	notifier.aabb = AABB(-size / 2.0, size)
	notifier.screen_entered.connect(_on_enter)
	notifier.screen_exited.connect(_on_exit)
	# wait a frame so the notifier has a real answer
	await get_tree().process_frame
	_apply(notifier.is_on_screen())

func _on_enter():
	seen.emit()
	_apply(true)

func _on_exit():
	unseen.emit()
	_apply(false)

func _apply(is_seen: bool):
	for t in targets:
		t.visible = is_seen if visible_when_seen else not is_seen
