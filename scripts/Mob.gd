class_name Mob
extends CharacterBase

var spawner:MobSpanwer

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@export
var damage:int

@export
var attack_range:float

@onready
var behaviour_tree:BeehaveTree = $BehaviourTree

@export
var character_mesh:Node3D

var face_target:bool = false

var target_pos:Vector3
func _ready():
	move_speed = GameManager.instance.game_settings.monster_move_speed
	health = GameManager.instance.game_settings.monster_health
	damage = GameManager.instance.game_settings.bullet_damage
	attack_range = GameManager.instance.game_settings.monster_attack_range
	
	#nav_agent.velocity_computed.connect(on_move_velocity)

func _physics_process(delta):
	if not _can_tick_actor_state():
		return

	if is_game_paused():
		if not behaviour_tree.is_paused():
			behaviour_tree.pause()
		return
	else:
		if behaviour_tree.is_paused():
			behaviour_tree.resume()
	
	if is_move_enable():
		nav_move()

func deactivate_for_field_reset() -> void:
	set_physics_process(false)
	set_process(false)
	velocity = Vector3.ZERO
	if behaviour_tree and not behaviour_tree.is_paused():
		behaviour_tree.pause()
	if behaviour_tree:
		behaviour_tree.blackboard.erase_value("target", str(get_instance_id()))
		behaviour_tree.blackboard.erase_value("target")

func die():
	if spawner!= null:
		spawner.on_mob_dead(self)
	queue_free()

func move_to(target):
	if target != target_pos:
		target_pos = target
		nav_agent.set_target_position(target)

func nav_move():
	if not _can_tick_actor_state():
		return

	if nav_agent.is_navigation_finished():
		GameData.actor_info[field_id][id].move_dir = Vector2.ZERO
		adjust_rotation(Vector3.ZERO)
		character_mesh.idle()
		return
	var next_pos:Vector3 = nav_agent.get_next_path_position()	
	var gp = global_position
	gp.y = next_pos.y
	if next_pos.distance_squared_to(gp) < 0.5:
		character_mesh.idle()
		adjust_rotation(Vector3.ZERO)
		return
	var new_velocity:Vector3 = gp.direction_to(next_pos)*move_speed
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(new_velocity)
	else:
		on_move_velocity(new_velocity)
		
	character_mesh.walk()
	
func on_move_velocity(v:Vector3):
	if not _can_tick_actor_state():
		return

	velocity = v
	var dir = v.normalized()
	GameData.actor_info[field_id][id].move_dir = Vector2(dir.x,dir.z)
	move_and_slide()
	adjust_rotation(v)	
		
func adjust_rotation(move_dir:Vector3):
	if not _can_tick_actor_state():
		return

	if face_target:
		var target_player = get_target()
		if is_instance_valid(target_player):
			var dir = target_player.global_position - global_position
			basis = Basis.looking_at(Vector3(dir.x,0,dir.z))
	else:
		if not move_dir.is_zero_approx():
			basis = Basis.looking_at(Vector3(move_dir.x,0,move_dir.z))
	
	var forward = -basis.z
	GameData.actor_info[field_id][id].direction = Vector2(forward.x,forward.z)
	
func get_attack_position() -> Vector3:
	if spawner==null:
		return Vector3.ZERO
	return spawner.owner_field.get_attack_position()
	
func is_reach_destination() -> bool:
	return nav_agent.is_navigation_finished()
	
func set_target(target):
	behaviour_tree.blackboard.set_value("target",target,str(get_instance_id()))
	if id == 101:
		behaviour_tree.blackboard.set_value("target",target)
	
func get_target() -> Node3D:
	var target = behaviour_tree.blackboard.get_value("target", null, str(get_instance_id()))
	if is_instance_valid(target):
		return target
	return null
	
func is_target_in_range()->bool:
	var target = get_target()
	if is_instance_valid(target):
		var d = global_position.distance_to(target.global_position)
		return d <= attack_range
	else:
		return false

func get_bullet_speed()->float:
	return GameManager.instance.game_settings.bullet_speed_monster

func is_move_enable()->bool:
	if GameManager.instance.game_mode == GameManager.GameMode.Train:
		return TrainingManager.enable_mob_move()
	return true

func is_shoot_enable()->bool:
	if GameManager.instance.game_mode == GameManager.GameMode.Train:
		return TrainingManager.enable_mob_shoot()
	return true
	
func bind_bullet_event(bullet):
	bullet.hit.connect(GameManager.instance.on_mob_bullet_hit)

func _can_tick_actor_state() -> bool:
	if is_queued_for_deletion():
		return false
	if not GameData.actor_info.has(field_id):
		return false
	return GameData.actor_info[field_id].has(id)
