class_name BTA_SelectAttackLocation extends ActionLeaf


func tick(actor, blackboard: Blackboard):	
	var position:Vector3 = actor.get_attack_position()
	blackboard.set_value("attack_position",position,str(actor.get_instance_id()))
	return SUCCESS
