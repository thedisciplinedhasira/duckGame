extends Control
class_name AbilityMeter

@onready var stamina_bar: TextureProgressBar = $StaminaBar
@onready var ability_bar: TextureProgressBar = $AbilityBar

@onready var icon_rect: TextureRect = $IconRect
# Create a reference to the new child node
@onready var ability_icon: TextureRect = $IconRect/AbilityIcon

@onready var value_label: Label = $ValueLabel

func update_stamina(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current

func update_ability(current: float, maximum: float) -> void:
	if ability_bar:
		ability_bar.max_value = maximum
		ability_bar.value = current

func set_icon(tex: Texture2D) -> void:
	set_ability_icon(tex)

func set_ability_icon(tex: Texture2D) -> void:
	if ability_icon:
		# Apply the texture to the new child node
		ability_icon.texture = tex
		ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Set this slightly smaller than your IconRect's 40x40 size so it fits inside
		ability_icon.custom_minimum_size = Vector2(28, 28)
