class_name Bullet extends Node3D

signal hit

@export
var speed:float = 0

@export_flags_3d_physics var ray_collision_mask

var direction:Vector3
var space_state
var instigator
var instigator_field_id
var instigator_id
# Called when the node enters the scene tree for the first time.
func _ready():
	space_state = get_world_3d().direct_space_state

func _physics_process(delta):
	if GameData.game_pause[instigator_field_id]:
		return
		
	var old_position = position
	var new_position = position + direction*(speed*delta)
	var query = PhysicsRayQueryParameters3D.create(old_position,new_position,ray_collision_mask)
	var result = space_state.intersect_ray(query)
	if result:
		var target_pos = Vector3(position)
		target_pos.x = result.position.x
		target_pos.z = result.position.z
		GameManager.instance.spawn_blast(result.position)
		on_hit(result.collider)
	else:
		position = new_position
	
func on_hit(other):
	hit.emit(other)
	queue_free()

func on_field_reset(field_id):
	if field_id == instigator_field_id:
		queue_free()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		GameManager.instance.on_field_reset.disconnect(on_field_reset)
