class_name BTC_HasTarget extends ConditionLeaf


func tick(actor, blackboard: Blackboard):
	var target = blackboard.get_value("target")
	if target:
		return SUCCESS
	else:
		return FAILURE

