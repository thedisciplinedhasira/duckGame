extends Area3D
class_name AbilityZone

# ENABLE_ALL: every ability on, the checkboxes are ignored
# DISABLE_ALL: every ability off, the checkboxes are ignored
# ENABLE_SELECTED: turns on the ticked ones, leaves the rest as they are
# DISABLE_SELECTED: turns off the ticked ones, leaves the rest as they are
# SET_EXACT: ticked ones on, everything else off
enum Mode { ENABLE_ALL, DISABLE_ALL, ENABLE_SELECTED, DISABLE_SELECTED, SET_EXACT }

@export var mode: Mode = Mode.ENABLE_SELECTED
# 3 checkboxes in the inspector, bit 0 = hover, 1 = telekinesis, 2 = micro
@export_flags("Hover", "Telekinesis", "Micro-Duck") var abilities: int = 0
# puts everything back how it was when the player walks out
@export var restore_on_exit := false
# only triggers once, dont combine with restore_on_exit
@export var one_shot := false

var _saved: Array = []
var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	# anything without this function (rocks, props) gets ignored
	if not body.has_method("set_ability_unlocked"):
		return
	if one_shot and _used:
		return
	_used = true

	if restore_on_exit:
		_saved = body.unlocked_abilities.duplicate()

	for i in body.unlocked_abilities.size():
		var selected: bool = (abilities & (1 << i)) != 0
		match mode:
			Mode.ENABLE_ALL:
				body.set_ability_unlocked(i, true)
			Mode.DISABLE_ALL:
				body.set_ability_unlocked(i, false)
			Mode.ENABLE_SELECTED:
				if selected:
					body.set_ability_unlocked(i, true)
			Mode.DISABLE_SELECTED:
				if selected:
					body.set_ability_unlocked(i, false)
			Mode.SET_EXACT:
				body.set_ability_unlocked(i, selected)


func _on_body_exited(body: Node3D) -> void:
	if not restore_on_exit or _saved.is_empty():
		return
	if not body.has_method("set_ability_unlocked"):
		return

	for i in _saved.size():
		body.set_ability_unlocked(i, _saved[i])
	_saved.clear()
