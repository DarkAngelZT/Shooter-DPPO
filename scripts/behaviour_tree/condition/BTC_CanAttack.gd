class_name BTC_CanAttack extends ConditionLeaf


func tick(actor, blackboard: Blackboard):
	if actor.can_shoot and actor.is_target_in_range():
		return SUCCESS
	else:
		return FAILURE

