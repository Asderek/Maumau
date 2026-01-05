class_name MauMauPile
extends Pile

@onready var Alert := $Alert

func _card_can_be_added(_cards: Array) -> bool:
	var top = get_top_cards(1)	
	
	print(_cards[0].card_info["suit"]);
	
	if(len(top) <= 0):
		Alert.text = "pode ser qqr carta, suave";
		return true;
		
	if(len(_cards) > 1):
		Alert.text = "como diabos voce chegou aqui?";
		return false
	
	if(top[0].card_info["suit"] == _cards[0].card_info["suit"]):
		Alert.text = "de boas, naipes iguais";
		return true;
	
	if(top[0].card_info["value"] == _cards[0].card_info["value"]):
		Alert.text = "De boa, valores iguais	";
		return true;
		
	Alert.text = "jogada invalida";
	return false;

## Updates visual positions and interaction states for all cards in the pile.
## Positions cards according to layout direction and applies interaction restrictions.
func _update_target_positions() -> void:
	# Calculate top card position for drop zone alignment
	var last_index = _held_cards.size() - 1
	if last_index < 0:
		last_index = 0
	var last_offset = _calculate_offset(last_index)
	
	# Align drop zone with top card if enabled
	if enable_drop_zone and align_drop_zone_with_top_card:
		drop_zone.change_sensor_position_with_offset(last_offset)

	var auxArray = _held_cards.slice(-max_stack_display)
	# Position each card and set interaction state
	for i in range(auxArray.size()):
		var card = auxArray[i]
		var offset = _calculate_offset(i)
		var target_pos = position + offset
		
		# Set card appearance and position
		card.show_front = card_face_up
		card.move(target_pos, 0)
		
		# Apply interaction restrictions
		if not allow_card_movement: 
			card.can_be_interacted_with = false
		elif restrict_to_top_card:
			if i == _held_cards.size() - 1:
				card.can_be_interacted_with = true
			else:
				card.can_be_interacted_with = false
		else:
			card.can_be_interacted_with = true
