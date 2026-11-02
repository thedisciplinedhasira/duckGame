extends Node3D

# animation proximity
@export var activate_distance := 25.0
@export var deactivate_distance := 30.0
@export var check_interval := 0.25

# petting
@export var pet_distance := 4.0
@export var meow_sounds: Array[AudioStream] = []

# prompt press squish
# 0.7 means it shrinks to 70% of its normal size
@export var press_scale := 0.7
@export var squish_time := 0.05
@export var recover_time := 0.15

# smash detection: this many presses inside the window counts as smashing
@export var smash_presses := 6
@export var smash_window := 1.5
# how long the message stays up, in seconds
@export var message_time := 2.0
@export var smash_messages: Array[String] = [
	"ok ok i get it",
	"the cat has had enough",
	"stop smashing the key!",
	"meow meow meow meow",
]

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var prompt: Sprite3D = $PetPrompt
@onready var meow: AudioStreamPlayer3D = $MeowSound
@onready var smash_label: Label3D = $SmashLabel

var player: Node3D
var is_active := false
var timer := 0.0
# timestamps (ms) of recent presses
var press_times: Array[int] = []
var message_timer: Timer
# the size you set in the editor, we always return to this
var prompt_base_scale: Vector3
var squish_tween: Tween

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	# first animation in the list, same as before
	var list := anim.get_animation_list()
	if list.size() > 0:
		anim.play(list[0])
		anim.pause()

	# remember the editor scale before we ever touch it
	prompt_base_scale = prompt.scale

	# both hidden until needed
	prompt.visible = false
	smash_label.visible = false

	# one shot timer that hides the message
	message_timer = Timer.new()
	message_timer.one_shot = true
	message_timer.timeout.connect(smash_label.hide)
	add_child(message_timer)

	# random offset so a bunch of cats dont all check on the same frame
	timer = randf() * check_interval

func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = check_interval

	if player == null:
		return

	# squared distance skips the square root, cheaper
	var dist_sq := global_position.distance_squared_to(player.global_position)

	# animation on/off
	if not is_active and dist_sq < activate_distance * activate_distance:
		is_active = true
		anim.play(anim.current_animation if anim.current_animation != "" else anim.get_animation_list()[0])
	elif is_active and dist_sq > deactivate_distance * deactivate_distance:
		is_active = false
		anim.pause()

	# pet prompt on/off, just visibility
	prompt.visible = dist_sq < pet_distance * pet_distance

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pet"):
		return
	if player == null or meow_sounds.is_empty():
		return
	# check distance right now instead of trusting the timer
	var dist_sq := global_position.distance_squared_to(player.global_position)
	if dist_sq > pet_distance * pet_distance:
		return

	# no waiting, every press restarts the sound
	meow.stream = meow_sounds.pick_random()
	# tiny pitch change so it doesnt sound identical every time
	meow.pitch_scale = randf_range(0.9, 1.1)
	meow.play()

	_squish_prompt()
	_track_smash()

func _squish_prompt() -> void:
	# kill the old tween so rapid presses restart cleanly
	if squish_tween:
		squish_tween.kill()

	squish_tween = create_tween()
	# shrink fast
	squish_tween.tween_property(prompt, "scale", prompt_base_scale * press_scale, squish_time)
	# then spring back with a little overshoot
	squish_tween.tween_property(prompt, "scale", prompt_base_scale, recover_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _track_smash() -> void:
	var now := Time.get_ticks_msec()
	press_times.append(now)

	# throw away presses that are older than the window
	var cutoff := now - int(smash_window * 1000.0)
	while press_times.size() > 0 and press_times[0] < cutoff:
		press_times.pop_front()

	if press_times.size() >= smash_presses:
		# reset so it needs a fresh smash to trigger again
		press_times.clear()
		_show_message()

func _show_message() -> void:
	if smash_messages.is_empty():
		return
	smash_label.text = smash_messages.pick_random()
	smash_label.visible = true
	# restarting the timer extends the message if they keep smashing
	message_timer.start(message_time)
