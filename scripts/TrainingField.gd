class_name TrainingField
extends Node3D

signal on_reset
signal on_player_spawn
signal on_player_dead

@export
var id:int
@export
var player_spawn:Node3D
@export
var mob_spawner:Array[Node3D]

var monsters = {}

var player:Node3D

var mob_id_counter:int = 100

func reset():
	for m in monsters.values():
		m.queue_free()
	monsters.clear()
	for spawner in mob_spawner:
		spawner.reset()
	player.queue_free()
	GameData.actor_info[id].clear()
	init(id)
	on_reset.emit(self)
# Called when the node enters the scene tree for the first time.
func _ready():
	for spawner in mob_spawner:
		spawner.owner_field = self
		spawner.on_monster_dead.connect(on_mob_dead)
		spawner.on_monster_spawn.connect(on_monster_spawned)


func init(field_id):
	id = field_id
	player = GameManager.instance.spawn_player(self, player_spawn.global_position)
	
	player.field_id = field_id
	player.id = field_id
	player.name = "Player_"+str(player.id)
	var state = GameData.ActorState.new(field_id,player.id)
	state.hp = GameManager.instance.game_settings.player_health
	GameData.actor_info[field_id][player.id]=state
	player.on_player_dead.connect(on_player_die)
	on_player_spawn.emit(player)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func on_monster_spawned(mob):
	if is_instance_valid(mob):
		mob.field_id = id
		mob.id = mob_id_counter
		mob_id_counter += 1
		mob.name = "Monster_"+str(mob.id)
		var state = GameData.ActorState.new(id,mob.id)
		GameData.actor_info[id][mob.id]=state
		monsters[mob.id] = mob

func on_mob_dead(mob):
	if is_instance_valid(mob):
		GameData.actor_info[id].erase(mob.id)
		monsters.erase(mob.id)
		mob.queue_free()

func on_player_die(player):
	on_player_dead.emit(player)
	player = null
 
