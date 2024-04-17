class_name BTA_FaceToTarget extends ActionLeaf

@export var enable:bool = true

func tick(actor, blackboard: Blackboard):
	actor.face_target = enable
	return SUCCESS

