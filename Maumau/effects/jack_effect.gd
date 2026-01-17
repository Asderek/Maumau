class_name JackEffect
extends RefCounted

const MODE_MAUMAU = "MAU_MAU"
const MODE_WANWAN = "WAN_WAN"

static func execute(manager: Node, card: Node) -> void:
	var mode = manager._get_effective_mode(manager.current_player)
	if mode == MODE_WANWAN:
		_execute_wanwan(manager, card)
	else:
		_execute_maumau(manager, card)

static func _execute_wanwan(manager: Node, _card: Node) -> void:
	print("Effect: Jack [WAN WAN]")
	manager.log_message("Wan Wan Jack! You got a Mirror Force Token!")
	
	if not manager.player_items.has(manager.current_player):
		manager.player_items[manager.current_player] = []
		
	manager.player_items[manager.current_player].append("mirror_force")
	manager._update_player_mode_ui(manager.current_player) # Refresh UI to show token
	
	manager.cycle_turn(1)

static func _execute_maumau(manager: Node, _card: Node) -> void:
	manager._print_game_event("Effect Triggered", "Jack/Joker Suit Selection (Maumau)")
	manager.log_message("Player %d is choosing a suit..." % manager.current_player)
	
	# Block input to prevent other players from playing prematurely
	manager.discard_pile.input_disabled = true
	
	# Do NOT cycle turn yet. Wait for selection.
	
	var selector = manager.suit_selector_scene.instantiate()
	# Add to HUD (CanvasLayer)
	if manager.hud_layer:
		manager.hud_layer.add_child(selector)
	else:
		print("ERROR: HUD Layer missing!")
		# Unblock if error
		manager.discard_pile.input_disabled = false
		return
	
	# We need to bind the signal to a handler. 
	# Since this is static, we can't easily bind 'self'. 
	# We should bind a lambda or a method on manager if we want to keep logic here?
	# Or better: The handler logic for "On Suit Selected" involves updating game state.
	# Let's define a static handler here and connect it?
	# Connect: selector.suit_selected.connect(func(suit): _on_suit_selected(manager, suit, selector))
	
	selector.suit_selected.connect(func(suit): _on_suit_selected(manager, suit, selector))

static func _on_suit_selected(manager: Node, suit: String, selector: Node) -> void:
	# Clean up selector (The selector script might queue_free itself? 
	# Looking at typical godot signals, usually we do it here if it's a popup)
	# Assuming selector needs to be closed.
	if is_instance_valid(selector):
		selector.queue_free()

	manager._print_game_event("Selection", "Chose Suit: " + suit)
	manager.log_message("Player %d chose %s!" % [manager.current_player, suit.capitalize()])
	
	# 1. Update Discard Pile Active Suit
	manager.discard_pile.active_suit = suit
	
	manager._update_hud_effects()
	
	# 2. Show Speech Bubble
	# We need to find the specific speech bubble logic.
	
	var current_hand = manager.hands_array[manager.current_player - 1]
	
	if manager.hud_layer:
		var bubble = manager.speech_bubble_scene.instantiate()
		manager.hud_layer.add_child(bubble)
		bubble.global_position = current_hand.get_global_transform_with_canvas().origin + Vector2(0, -100)
		bubble.show_message("I choose " + suit.capitalize() + "!", 2.0)
	
	# 3. Wait 2 seconds then cycle turn
	await manager.get_tree().create_timer(2.0).timeout
	
	# Cycle turn by pending amount (1 for Jack, 2 for Joker)
	manager.cycle_turn(manager.pending_turn_skip)
	# Reset back to default
	manager.pending_turn_skip = 1
	
	# Unblock input
	manager.discard_pile.input_disabled = false
