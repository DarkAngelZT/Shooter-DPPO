class_name BTC_CanAttack extends ConditionLeaf


func tick(actor, blackboard: Blackboard):
	if actor.can_shoot:
		return SUCCESS
	else:
		return FAILURE

