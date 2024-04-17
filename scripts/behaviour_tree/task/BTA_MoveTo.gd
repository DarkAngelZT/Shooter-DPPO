class_name BTA_MoveTo extends ActionLeaf


func tick(actor, blackboard: Blackboard):
	var target_pos: Vector3 = blackboard.get_value("attack_position")
	if target_pos:
		actor.move_to(target_pos)
		if actor.is_reach_destination():
			return SUCCESS
		else:
			return RUNNING
	else:
		return FAILURE

