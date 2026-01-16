extends Control

@onready var popup = $PlayerCountPopup
@onready var spin_box = $PlayerCountPopup/VBoxContainer/SpinBox

func _on_open_table_pressed() -> void:
	popup.popup_centered()

func _on_confirm_players_pressed() -> void:
	# Store selected number of players in Global Singleton
	GameGlobals.num_players = int(spin_box.value)
	get_tree().change_scene_to_file("res://Maumau/manager.tscn")

func _on_options_pressed() -> void:
	print("Options Placeholder")

func _on_quit_desktop_pressed() -> void:
	get_tree().quit()
