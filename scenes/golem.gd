extends Node3D

@onready var prompt_label: Label3D = $golemTalk/Label3D 
var player_in_range := false
var player_node: Node3D = null

var quest_state := 0 

func _on_golem_talk_body_entered(body: Node3D) -> void:
	if body.name.to_lower() == "player": 
		player_in_range = true
		player_node = body
		prompt_label.visible = true

func _on_golem_talk_body_exited(body: Node3D) -> void:
	if body.name.to_lower() == "player":
		player_in_range = false
		player_node = null
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact") and not DialogueUI.background.visible:
		get_viewport().set_input_as_handled()
		trigger_dialogue()

func trigger_dialogue() -> void:
	if player_node and player_node.has_method("set_input_locked"):
		player_node.set_input_locked(true)
	
	if quest_state == 0:
		# Trigger top screen notification banner + sound
		DialogueUI.show_notification("get your ahh up gng")
		
		# Open multi-line dialogue box (Press E to advance lines)
		DialogueUI.show_dialogue(
			[
				"ay cuh f you doin here",
				"hey am talking to you",
				"are you deaf of some?"
			], 
			func(): player_node.set_input_locked(false)
		)
		quest_state = 1
		
	elif quest_state == 1:
		if player_node and "potions_in_inventory" in player_node and player_node.potions_in_inventory > 0:
			player_node.potions_in_inventory -= 1
			
			if "magic_feathers_collected" in player_node:
				player_node.magic_feathers_collected += 1 
			
			DialogueUI.show_notification("Quest Complete: Thirst Quenched!")
			DialogueUI.show_dialogue(
				[
					"Ahhh, that hits the spot!",
					"Take this Magic Feather as a token of my gratitude."
				], 
				func(): player_node.set_input_locked(false)
			)
			quest_state = 2
		else:
			DialogueUI.show_dialogue(
				[
					"You return empty-handed...",
					"I cannot quench my thirst with your empty wings. Bring me a potion!"
				], 
				func(): player_node.set_input_locked(false)
			)
			
	elif quest_state == 2:
		DialogueUI.show_dialogue(
			[
				"The weather is exceptionally nice today for a statue.",
				"Safe travels, little bird."
			], 
			func(): player_node.set_input_locked(false)
		)
