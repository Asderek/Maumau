class_name FiveEffect

static func execute_diamond(manager: Node, card: Node) -> void:
	if manager._get_effective_mode(manager.current_player) == manager.MODE_WANWAN:
		_execute_wanwan_neutral(manager, card, "5")
	else:
		_execute_rotate_right_1_maumau(manager, card)

static func execute_heart(manager: Node, card: Node) -> void:
	if manager._get_effective_mode(manager.current_player) == manager.MODE_WANWAN:
		_execute_wanwan_neutral(manager, card, "5")
	else:
		_execute_rotate_left_2_maumau(manager, card)

static func _execute_wanwan_neutral(manager: Node, _card: Node, rank: String) -> void:
	print("Effect: %s [WAN WAN] -> Neutral" % rank)
	manager.log_message("Wan Wan %s: Just a number." % rank)
	manager.cycle_turn(1)

# 5 Diamond (Mau Mau): Rotate hands Right (1 step)
static func _execute_rotate_right_1_maumau(manager: Node, _card: Node) -> void:
	print("Effect: Rotate Hands Right (5D) [MAU MAU]")
	manager._rotate_hands_content(1)
	manager.cycle_turn(1)

# 5 Heart (Mau Mau): Rotate hands Left (2 steps)
static func _execute_rotate_left_2_maumau(manager: Node, _card: Node) -> void:
	print("Effect: Rotate Hands Left 2 (5H) [MAU MAU]")
	manager._rotate_hands_content(-2)
	manager.cycle_turn(1)
