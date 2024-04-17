class_name BTA_Attack extends ActionLeaf


func tick(actor, blackboard: Blackboard):
	actor.shoot()
	return SUCCESS

