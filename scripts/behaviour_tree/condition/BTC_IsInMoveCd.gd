class_name BTC_IsInMoveCd extends ConditionLeaf

@export
var cool_down:float = 3

func tick(actor, blackboard: Blackboard):
	var last_move_time = blackboard.get_value("last_move_time",null,str(actor.get_instance_id()))
	if last_move_time == null or Time.get_ticks_msec() - last_move_time > cool_down*1000:
		return FAILURE
	else:
		return SUCCESS
