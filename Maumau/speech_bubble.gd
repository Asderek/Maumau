extends Control

@onready var label = $Panel/Label
@onready var panel = $Panel

func show_message(text: String, duration: float = 2.0) -> void:
	label.text = text
	visible = true
	
	# Create a tween for fade out/destroy
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _ready() -> void:
	# Optional: Animate pop in
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
