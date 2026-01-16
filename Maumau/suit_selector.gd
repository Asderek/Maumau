extends PanelContainer

signal suit_selected(suit_name: String)

func _ready() -> void:
	# Connect buttons dynamically or rely on scene setup
	# Assuming children are Buttons named "Club", "Diamond", "Heart", "Spade"
	# or similar structure.
	pass

func _on_club_pressed() -> void:
	suit_selected.emit("club")
	queue_free()

func _on_diamond_pressed() -> void:
	suit_selected.emit("diamond")
	queue_free()

func _on_heart_pressed() -> void:
	suit_selected.emit("heart")
	queue_free()

func _on_spade_pressed() -> void:
	suit_selected.emit("spade")
	queue_free()
