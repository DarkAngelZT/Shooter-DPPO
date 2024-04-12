class_name MobSpanwer
extends Node3D

signal on_monster_dead
signal  on_monster_spawn

@export
var spawn_time_sec:float

@export
var size_cube:Node3D

@export
var spawn_limit:int = 4

var size:Vector2

var monster_amount:int = 0

var can_spawn:bool = true

var next_spawn_time:int = 0

var owner_field:Node3D
# Called when the node enters the scene tree for the first time.
func _ready():
	size_cube.visible = false
	var scale = size_cube.scale
	size.x = scale.x
	size.y = scale.z
	next_spawn_time = Time.get_ticks_msec() + randi_range(2, spawn_time_sec*1000)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if can_spawn:
		if Time.get_ticks_msec() > next_spawn_time:
			spawn()
			next_spawn_time = Time.get_ticks_msec() + randi_range(1.5, spawn_time_sec*1000)
	
func spawn():
	if not can_spawn:
		return
	var count = randi_range(1,spawn_limit - monster_amount)
	monster_amount += count
	for i in range(count):
		do_spawn()
	if monster_amount >= spawn_limit:
		can_spawn = false


func do_spawn():
	var game_mgr = GameManager.instance
	if game_mgr != null:
		var pos = Vector3(randf_range(-size.x*0.5+0.5,size.x*0.5-0.5),0,randf_range(-size.y*0.5+0.5,size.y*0.5-0.5))
		pos += position
		var mob = game_mgr.spawn_monster(owner_field,pos)
		mob.spawner = self		
		on_monster_spawn.emit(mob)

func on_mob_dead(mob):
	monster_amount -= 1
	if monster_amount<0:
		monster_amount = 0
	if not can_spawn && monster_amount<spawn_limit:
		next_spawn_time = Time.get_ticks_msec() + randi_range(1, spawn_time_sec*1000)
		can_spawn = true
	on_monster_dead.emit(mob)
		
func reset():
	can_spawn = true
	monster_amount = 0
	next_spawn_time = Time.get_ticks_msec() + randi_range(2, spawn_time_sec*1000)
