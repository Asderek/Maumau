class_name FourEffect

static func execute_club(manager: Node, card: Node) -> void:
	if manager._get_effective_mode(manager.current_player) == manager.MODE_WANWAN:
		_execute_wanwan_neutral(manager, card, "4")
	else:
		_execute_club_4_maumau(manager, card)
		
static func execute_spade(manager: Node, card: Node) -> void:
	if manager._get_effective_mode(manager.current_player) == manager.MODE_WANWAN:
		_execute_wanwan_neutral(manager, card, "4")
	else:
		_execute_spade_4_maumau(manager, card)
		
static func execute_red(manager: Node, card: Node) -> void:
	if manager._get_effective_mode(manager.current_player) == manager.MODE_WANWAN:
		_execute_wanwan_neutral(manager, card, "4")
	else:
		_execute_red_4_maumau(manager, card)

static func _execute_wanwan_neutral(manager: Node, _card: Node, rank: String) -> void:
	print("Effect: %s [WAN WAN] -> Neutral" % rank)
	manager.log_message("Wan Wan %s: Just a number." % rank)
	manager.cycle_turn(1)

# Club 4 (Mau Mau): Clears Active Effects
static func _execute_club_4_maumau(manager: Node, _card: Node) -> void:
	print("Effect: Clear Active Effects (Club 4) [MAU MAU]")
	manager.log_message("Effects Cleared (8s, Direction)")
	
	manager.active_effects["eight_black"] = false
	manager.active_effects["eight_red"] = false
	manager.discard_pile.active_effect_eight_red = false
	manager.active_effects["silence"] = false
	
	manager.play_direction = 1
	
	manager._update_hud_effects()
	manager.cycle_turn(1)

# Spade 4 (Mau Mau): Locks Effects
static func _execute_spade_4_maumau(manager: Node, _card: Node) -> void:
	print("Effect: LOCK Effects (Spade 4) [MAU MAU]")
	manager.log_message("Effects are now LOCKED!")
	manager.active_effects["locked"] = true
	manager.discard_pile.active_effect_locked = true
	manager._update_hud_effects()
	manager.cycle_turn(1)

# Red 4 (Mau Mau): Unlocks Effects
static func _execute_red_4_maumau(manager: Node, _card: Node) -> void:
	print("Effect: UNLOCK Effects (Red 4) [MAU MAU]")
	if manager.active_effects["locked"]:
		manager.log_message("Effects are now UNLOCKED!")
		manager.active_effects["locked"] = false
		manager.discard_pile.active_effect_locked = false
	else:
		manager.log_message("Red 4 played (Nothing locked).")
	manager._update_hud_effects()
	manager.cycle_turn(1)
