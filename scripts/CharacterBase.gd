class_name CharacterBase
extends CharacterBody3D

@export
var field_id:int

@export
var id:int

@export
var bullet_prefab:PackedScene

@export
var shoot_position:Node3D

@export
var shoot_interval_sec:float = 0.6

@export
var health:int = 100

@export
var move_speed:float = 1

var can_shoot:bool = false

var last_shoot_time: int = 0

var is_dead:bool = false

func set_can_shoot(v):
	can_shoot = v
	if GameData.actor_info[field_id].has(id):
		GameData.actor_info[field_id][id].can_shoot = v

func _process(delta):
	if is_dead:
		return
	var now = Time.get_ticks_msec()
	if now - last_shoot_time > shoot_interval_sec*1000:
		set_can_shoot(true)
		
func shoot():
	if can_shoot:
		last_shoot_time = Time.get_ticks_msec()
		var bullet = bullet_prefab.instantiate()
		bullet.position = shoot_position.global_position
		bullet.basis = basis
		bullet.direction = -global_basis.z
		
		bullet.speed = get_bullet_speed()
		
		bullet.hit.connect(on_bullet_hit)
		GameManager.instance.root.add_child(bullet)
		set_can_shoot(false)

func on_bullet_hit(other):
	pass

func die():
	pass

func take_damage(damage):
	if is_dead:
		return
	health = maxi(health - damage, 0)
	GameData.actor_info[field_id][id].hp=health
	if health<=0:
		is_dead = true
		die()
		
func get_bullet_speed()->float:
	return 0
