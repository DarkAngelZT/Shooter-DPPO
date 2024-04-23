class_name BTA_SetMoveCd extends ActionLeaf


func tick(actor, blackboard: Blackboard):
	blackboard.set_value("last_move_time",Time.get_ticks_msec(),str(actor.get_instance_id()))
	return SUCCESS

