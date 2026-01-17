class_name TenEffect
extends RefCounted

const MODE_MAUMAU = "MAU_MAU"
const MODE_WANWAN = "WAN_WAN"

static func execute(manager: Node, card: Node) -> void:
	var mode = manager._get_effective_mode(manager.current_player)
	if mode == MODE_WANWAN:
		_execute_wanwan(manager, card)
	else:
		_execute_maumau(manager, card)

static func _execute_wanwan(manager: Node, card: Node) -> void:
	print("Effect: 10 [WAN WAN] -> Delegating to Mau Mau")
	_execute_maumau(manager, card)

static func _execute_maumau(manager: Node, _card: Node) -> void:
	print("Effect: Simon Says (10)")
	
	# Block interaction
	_set_hands_interaction(manager, false) 
	
	# Challenge Phase
	if not manager.word_chain.is_empty():
		manager.log_message("Simon Says: Recite the chain!")
		for i in range(manager.word_chain.size()):
			var correct = manager.word_chain[i]
			var options = _generate_simon_options(manager, correct)
			
			manager.log_message("Challenge %d/%d..." % [i + 1, manager.word_chain.size()])
			manager.simon_popup.start_challenge(correct, options)
			
			var success = await manager.simon_popup.challenge_completed
			if not success:
				manager.log_message("WRONG! The chain breaks!")
				var penalty = manager.word_chain.size() + 1
				var victim_hand = manager.hands_array[manager.current_player - 1]
				manager.distribute_cards(victim_hand, penalty)
				manager.word_chain.clear()
				_finish_simon_turn(manager, false)
				return # Exit immediately on failure
	
	# Input Phase (If success or empty)
	manager.log_message("Simon Says: Add a new word!")
	manager.simon_popup.start_input_mode()
	var new_word = await manager.simon_popup.word_submitted
	manager.log_message("Player wrote: " + new_word)
	manager.word_chain.append(new_word)
	_finish_simon_turn(manager, true)

static func _finish_simon_turn(manager: Node, _success: bool) -> void:
	# Restore interaction
	_set_hands_interaction(manager, true)
	manager.cycle_turn(1)

static func _set_hands_interaction(manager: Node, enabled: bool) -> void:
	for hand in manager.hands_array:
		hand.allow_remote_interaction = enabled

static func _generate_simon_options(manager: Node, correct: String) -> Array[String]:
	var opts: Array[String] = [correct]
	var pool = manager.dict_pt if manager.simon_dict_mode == "PT" else manager.dict_en
	# We need to duplicate pool to not mess up original if shuffle is in place (Godot shuffle is in place)
	# But actually shuffle acts on the array. We shouldn't shuffle the source dictionary?
	# Original code: `pool.shuffle()` -> This shuffles the manager's `dict_pt`! 
	# Which isn't terrible but maybe not intended? 
	# Checking original code: `pool = dict_pt... pool.shuffle()`. Yes it shuffles the source.
	# I'll stick to original behavior but maybe copy it to be safe if `dict_pt` order matters (it doesn't seem to).
	# Ideally: var temp_pool = pool.duplicate()
	var temp_pool = pool.duplicate()
	temp_pool.shuffle()
	
	for w in temp_pool:
		if w != correct and opts.size() < 4:
			opts.append(w)
			
	opts.shuffle()
	return opts
