class_name MauMauPile
extends Pile

@onready var Alert = get_node_or_null("Alert")

func _card_can_be_added(_cards: Array) -> bool:
	var top = get_top_cards(1)	
	
	print(_cards[0].card_info["suit"]);
	
	if(len(top) <= 0):
		if(Alert):
			Alert.text = "pode ser qqr carta, suave";
		return true;
		
	if(len(_cards) > 1):
		if(Alert):
			Alert.text = "como diabos voce chegou aqui?";
		return false
	
	if(top[0].card_info["suit"] == _cards[0].card_info["suit"]):
		if(Alert):
			Alert.text = "de boas, naipes iguais";
		return true;
	
	if(top[0].card_info["value"] == _cards[0].card_info["value"]):
		if(Alert):
			Alert.text = "De boa, valores iguais	";
		return true;
		
		
	if(Alert):
		Alert.text = "jogada invalida";
	return false;
