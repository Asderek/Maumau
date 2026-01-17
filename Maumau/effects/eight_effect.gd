class_name EightEffect
extends RefCounted

const MODE_MAUMAU = "MAU_MAU"
const MODE_WANWAN = "WAN_WAN"

static func execute(manager: Node, card: Node) -> void:
	var mode = manager._get_effective_mode(manager.current_player)
	
	if mode == MODE_WANWAN:
		_execute_wanwan(manager, card)
	else:
		# Mau Mau: Black vs Red
		# Check suit
		if card.card_name.contains("club") or card.card_name.contains("spade"):
			_execute_maumau_black(manager, card)
		else:
			_execute_maumau_red(manager, card)

static func _execute_wanwan(manager: Node, _card: Node) -> void:
	print("Effect: 8 (Wan Wan)")
	manager.log_message("Wan Wan 8! Play again, next effect is SWAPPED!")
	
	manager.active_effects["swap_next_mode"] = true
	manager.discard_pile.free_play_active = true
	manager._update_hud_effects()
	
	# Do NOT cycle turn
	# Visual feedback
	if manager.hud_layer:
		var bubble = manager.speech_bubble_scene.instantiate()
		manager.hud_layer.add_child(bubble)
		bubble.show_message("Paradigm Shift!", 1.5)

static func _execute_maumau_black(manager: Node, _card: Node) -> void:
	print("Effect: 8 Black (Masquerade) [MAU MAU]")
	
	var is_active = manager.active_effects["eight_black"]
	
	manager.active_effects["eight_black"] = not is_active
	manager.discard_pile.active_effect_eight_black = not is_active
	
	if not is_active:
		manager.log_message("Black 8! Black cards swap suits!")
	else:
		manager.log_message("Black 8! Black cards return to normal!")
	
	manager._update_hud_effects()
	manager.cycle_turn(1)

static func _execute_maumau_red(manager: Node, _card: Node) -> void:
	print("Effect: 8 Red (Masquerade) [MAU MAU]")
	
	var is_active = manager.active_effects["eight_red"]
	
	manager.active_effects["eight_red"] = not is_active
	manager.discard_pile.active_effect_eight_red = not is_active
	
	if not is_active:
		manager.log_message("Red 8! Red cards swap suits!")
	else:
		manager.log_message("Red 8! Red cards return to normal!")
	
	manager._update_hud_effects()
	manager.cycle_turn(1)
