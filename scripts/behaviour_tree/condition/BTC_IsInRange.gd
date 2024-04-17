class_name BTC_IsInRange extends ConditionLeaf

@export
var range:float = 4

func tick(actor, blackboard: Blackboard):
	var target = blackboard.get_value("target")
	if target:
		var in_range = target.global_position.distance_to(actor.global_position) <= range
		if in_range:
			return SUCCESS
		else:
			return FAILURE
	return FAILURE

