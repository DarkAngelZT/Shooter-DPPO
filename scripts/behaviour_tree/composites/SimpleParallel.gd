@tool
@icon("../../icons/sequence.svg")
class_name SimpleParallelComposite extends Composite

## Simple Parallel 节点会像虚幻里面那样同时运行两个子节点:主节点(第一子节点)和副节点(第二子节点)
## 只有主节点返回RUNNINNG该节点才会继续tick，副节点的返回将会被无视并且按照一般节点规则继续运行
## 当主节点返回SUCCESS或者FAILURE，节点会结束，子节点将会被打断

#how many times should secondary node repeat, zero means loop forever
@export var secondary_node_repeat_count:int = 0

#wether to wait secondary node finish its current tick after primary node finished
@export var delay_mode:bool = false

var delayed_result := SUCCESS
var main_task_finished:bool = false
var secondary_node_running:bool = false
var secondary_node_repeat_left:int = 0

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super._get_configuration_warnings()

	if get_child_count() != 2:
		warnings.append("SimpleParallel should have exactly two child nodes.")
		
	if not get_child(0) is ActionLeaf:
		warnings.append("SimpleParallel should have an action leaf node as first child node.")

	return warnings
	
func tick(actor, blackboard: Blackboard):
	for c in get_children():
		var node_index = c.get_index()
		if node_index == 0 and not main_task_finished:
			if c != running_child:
				c.before_run(actor, blackboard)
				
			var response = c.tick(actor, blackboard)
			if can_send_message(blackboard):
				BeehaveDebuggerMessages.process_tick(c.get_instance_id(), response)
			
			delayed_result = response
			match response:
				SUCCESS,FAILURE:
					_cleanup_running_task(c, actor, blackboard)
					c.after_run(actor, blackboard)
					main_task_finished = true
					if not delay_mode:						
						if secondary_node_running:
							get_child(1).interrupt(actor, blackboard)
						_reset()
						return delayed_result
				RUNNING:
					running_child = c
					if c is ActionLeaf:
						blackboard.set_value("running_action", c, str(actor.get_instance_id()))

		elif node_index == 1:
			if secondary_node_repeat_count == 0 or secondary_node_repeat_left > 0:
				if not secondary_node_running:
					c.before_run(actor, blackboard)
				var subtree_response = c.tick(actor, blackboard)
				if subtree_response != RUNNING:
					secondary_node_running = false
					c.after_run(actor, blackboard)
					if delay_mode and main_task_finished:
						_reset()
						return delayed_result
					elif secondary_node_repeat_left > 0:
						secondary_node_repeat_left -= 1
				else:
					secondary_node_running = true	

	return RUNNING

func before_run(actor: Node, blackboard:Blackboard) -> void:
	secondary_node_repeat_left = secondary_node_repeat_count
	super(actor, blackboard)

func interrupt(actor: Node, blackboard: Blackboard) -> void:
	if not main_task_finished:
		get_child(0).interrupt(actor, blackboard)
	if secondary_node_running:
		get_child(1).interrupt(actor, blackboard)
	_reset()
	super(actor, blackboard)

func after_run(actor: Node, blackboard: Blackboard) -> void:
	_reset()
	super(actor, blackboard)

func _reset() -> void:
	main_task_finished = false
	secondary_node_running = false

## Changes `running_action` and `running_child` after the node finishes executing.
func _cleanup_running_task(finished_action: Node, actor: Node, blackboard: Blackboard):
	var blackboard_name = str(actor.get_instance_id())
	if finished_action == running_child:
		running_child = null
		if finished_action == blackboard.get_value("running_action", null, blackboard_name):
			blackboard.set_value("running_action", null, blackboard_name)
			
func get_class_name() -> Array[StringName]:
	var classes := super()
	classes.push_back(&"SimpleParallelComposite")
	return classes
