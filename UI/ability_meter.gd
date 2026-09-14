extends Control
class_name AbilityMeter

@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var icon_rect: TextureRect = $IconRect
@onready var value_label: Label = $ValueLabel

func update_stamina(current: float, maximum: float) -> void:
	if progress_bar:
		progress_bar.max_value = maximum
		progress_bar.value = current
	if value_label:
		value_label.text = str(int(current))

func set_icon(tex: Texture2D) -> void:
	set_ability_icon(tex)

func set_ability_icon(tex: Texture2D) -> void:
	if icon_rect:
		icon_rect.texture = tex
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.custom_minimum_size = Vector2(48, 48)
