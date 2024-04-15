class_name Mob
extends CharacterBase

var spawner:MobSpanwer

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@export
var damage:int

var target_pos:Vector3
func _ready():
	move_speed = GameManager.instance.game_settings.monster_move_speed
	health = GameManager.instance.game_settings.monster_health
	damage = GameManager.instance.game_settings.bullet_damage
	
	nav_agent.velocity_computed.connect(on_move_velocity)

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
		return
	var next_pos:Vector3 = nav_agent.get_next_path_position()
	var new_velocity:Vector3 = global_position.direction_to(next_pos)*move_speed
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(new_velocity)
	else:
		on_move_velocity(new_velocity)
	
func on_move_velocity(v):
	velocity = v
	move_and_slide()
	
