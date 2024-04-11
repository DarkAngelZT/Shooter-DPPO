class_name MobSpanwer
extends Marker3D

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

var id_counter:int = 100

var last_spawn_time:int = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	size_cube.visible = false
	var scale = size_cube.scale
	size.x = scale.x
	size.y = scale.z


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if can_spawn:
		if Time.get_ticks_msec() - last_spawn_time >= spawn_time_sec*1000:
			spawn()
			last_spawn_time = Time.get_ticks_msec()
	
func spawn():
	if not can_spawn:
		return
	var count = randi_range(1,spawn_limit - monster_amount)
	monster_amount += count
	for i in range(count):
		do_spawn()
	if monster_amount >= spawn_limit:
		can_spawn = false

func assign_id(mob):
	mob.id = id_counter
	id_counter += 1

func do_spawn():
	var game_mgr = GameManager.instance
	if game_mgr != null:
		var pos = Vector3(randf_range(-size.x+1,size.x-1),0.3,randf_range(-size.y+1,size.y-1))
		pos += global_position
		var mob = game_mgr.spawn_monster(self,pos)
		mob.spawner = self
		assign_id(mob)
		on_monster_spawn.emit(mob)

func on_mob_dead(mob):
	monster_amount -= 1
	if monster_amount<0:
		monster_amount = 0
	if monster_amount<spawn_limit:
		can_spawn = true
	on_monster_dead.emit(mob)
	mob.queue_free()
		
func reset():
	can_spawn = true
	monster_amount = 0
