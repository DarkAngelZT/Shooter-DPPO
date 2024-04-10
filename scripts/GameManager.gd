class_name GameManager
extends Node

static var instance
enum GameMode {
	Train = 1,
	Play = 2
}

enum ControlMode{
	Manual = 1,
	AI = 2
}

@export
var field_amount:int = 1

@export
var TraningRoot:Node3D

@export
var ArenaRoot:Node3D

@export
var player_prefab: PackedScene

@export
var enemy_prefab:PackedScene

@export
var training_field_prefab:PackedScene

@export
var game_settings:GameSettings

@export
var train_camera:Node3D

@export
var game_camera:Node3D

@export
var game_mode:GameMode = GameMode.Train

@export
var control_mode:ControlMode = ControlMode.Manual

var training_fields = {} #{field_id:field}
var players = {} #{field_id:player}
var monsters = {} #{field_id:{monster_id:monster}}
# Called when the node enters the scene tree for the first time.
func _enter_tree():
	instance = self
	
func _ready():
	
	if control_mode == ControlMode.Manual or game_mode == GameMode.Play:
		create_game_data(1)
	elif game_mode == GameMode.Train:
		for x in range(field_amount):
			create_game_data(x)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func create_game_data(amount):
	for i in range(amount):
		GameData.player_input[i]=GameData.PlayerInputState.new(i)
		GameData.game_end[i]=false
		GameData.actor_info[i]={}

func _physics_process(delta):
	if control_mode == ControlMode.Manual:
		var dir = Input.get_vector("move_right","move_left","move_forward","move_back")
		
		var moving = dir.length() > 0
		if moving:
			GameData.player_input[0].direction = dir.normalized()
			GameData.player_input[0].move_state = GameData.Op_Move
		else:
			GameData.player_input[0].move_state = GameData.Op_Stop
			
		var shooting = Input.is_action_pressed("shoot")
		GameData.player_input[0].shooting = shooting

func load_field(center):
	var field = training_field_prefab.instantiate()
	field.position = center
	return field

func reset_field(field_id):
	if training_fields.has(field_id):
		var field = training_fields[field_id]
		field.reset()

func spawn_player(scene_root, position, rotation=Quaternion.IDENTITY):
	var player = player_prefab.instantiate()
	scene_root.add_child(player)
	player.position = position
	player.basis = Basis(rotation)
	return player
	
func spawn_monster(scene_root, position, rotation=Quaternion.IDENTITY):
	var mob = enemy_prefab.instantiate()
	scene_root.add_child(mob)
	mob.position = position
	mob.basis = Basis(rotation)
	return mob

