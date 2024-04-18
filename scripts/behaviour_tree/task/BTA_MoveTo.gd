class_name BTA_MoveTo extends ActionLeaf

@export
var check_target_movement:bool = true
@export
var position_diff_threshold:float = 2

var target_pos:Vector3

func before_run(actor, blackboard: Blackboard):
	if check_target_movement:
		var target = blackboard.get_value("target",null,str(actor.get_instance_id()))
		if target != null:
			target_pos = target.global_position

func tick(actor, blackboard: Blackboard):
	var attack_pos: Vector3 = blackboard.get_value("attack_position",null,str(actor.get_instance_id()))
	if attack_pos:
		if check_target_movement:
			var target = blackboard.get_value("target",null,str(actor.get_instance_id()))
			if target != null:
				var current_pos = target.global_position
				current_pos.y = target_pos.y
				if target_pos.distance_to(current_pos) > position_diff_threshold:
					#如果玩家位移超过阈值，则停止移动，重新选点
					return SUCCESS
		actor.move_to(attack_pos)
		if actor.is_reach_destination():
			return SUCCESS
		else:
			return RUNNING
	else:
		return FAILURE

