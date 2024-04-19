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

var face_target:bool = false

var target_pos:Vector3
func _ready():
	move_speed = GameManager.instance.game_settings.monster_move_speed
	health = GameManager.instance.game_settings.monster_health
	damage = GameManager.instance.game_settings.bullet_damage
	attack_range = GameManager.instance.game_settings.monster_attack_range
	
	#nav_agent.velocity_computed.connect(on_move_velocity)

func _physics_process(delta):
	nav_move()

func die():
	spawner.on_mob_dead(self)
	queue_free()

func on_bullet_hit(other):
	if other is Player:
		other.take_damage(damage)

func move_to(target):
	if target != target_pos:
		target_pos = target
		nav_agent.set_target_position(target)

func nav_move():
	if nav_agent.is_navigation_finished():
		adjust_rotation(Vector3.ZERO)
		return
	var next_pos:Vector3 = nav_agent.get_next_path_position()	
	var gp = global_position
	gp.y = next_pos.y
	var new_velocity:Vector3 = gp.direction_to(next_pos)*move_speed
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(new_velocity)
	else:
		on_move_velocity(new_velocity)
	
func on_move_velocity(v:Vector3):
	velocity = v
	var dir = v.normalized()
	GameData.actor_info[field_id][id].move_dir = Vector2(dir.x,dir.z)
	move_and_slide()
	adjust_rotation(v)
		
func adjust_rotation(move_dir:Vector3):
	if face_target:
		var target_player = get_target()
		if target_player:
			var dir = target_player.global_position - global_position
			basis = Basis.looking_at(Vector3(dir.x,0,dir.z))
	else:
		if not move_dir.is_zero_approx():
			basis = Basis.looking_at(Vector3(move_dir.x,0,move_dir.z))
	
func get_attack_position() -> Vector3:
	return spawner.owner_field.get_attack_position()
	
func is_reach_destination() -> bool:
	return nav_agent.is_navigation_finished()
	
func set_target(target):
	behaviour_tree.blackboard.set_value("target",target,str(get_instance_id()))
	if id == 101:
		behaviour_tree.blackboard.set_value("target",target)
	
func get_target() -> Node3D:
	return behaviour_tree.blackboard.get_value("target",null,str(get_instance_id()))
	
func is_target_in_range()->bool:
	var target = get_target()
	if target:
		var d = global_position.distance_to(target.global_position)
		return d <= attack_range
	else:
		return false

func get_bullet_speed()->float:
	return GameManager.instance.game_settings.bullet_speed_monster
	
