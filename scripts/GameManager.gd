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
var training_field_size:float = 32

@export
var TraningRoot:Node3D

@export
var ArenaRoot:Node3D

@export
var root:Node3D

@export
var player_prefab: PackedScene

@export
var enemy_prefab:PackedScene

@export
var training_field_prefab:PackedScene

@export
var arena_prefab:PackedScene

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
	
	if game_mode == GameMode.Play:
		create_game_data(1)
		var field = load_arena()
		train_camera.set_active(false)
		game_camera.set_active(true)
		
	elif game_mode == GameMode.Train:
		create_game_data(field_amount)
		initialize_training_fields()
		
		train_camera.set_active(true)
		game_camera.set_active(false)

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
		var dir = Input.get_vector("move_left","move_right","move_forward","move_back")
		
		var moving = dir.length() > 0
		if moving:
			GameData.player_input[0].direction = dir.normalized()
			GameData.player_input[0].move_state = GameData.Op_Move
		else:
			GameData.player_input[0].move_state = GameData.Op_Stop
			
		var shooting = Input.is_action_pressed("shoot")
		GameData.player_input[0].shooting = shooting
		#鼠标位置
		var camera = get_viewport().get_camera_3d()
		var cursor_pos = get_viewport().get_mouse_position()
		var cursor_dist = camera.project_position(cursor_pos,50)
		
		var result_dir = cursor_dist - players[0].global_position
		var aim_dir = Vector2(result_dir.x,result_dir.z)
		aim_dir = aim_dir.normalized()
		GameData.player_input[0].aim_direction = aim_dir

func load_trainning_field(center):
	var field = training_field_prefab.instantiate()
	field.position = center
	return field
	
func load_arena():
	var field = arena_prefab.instantiate()
	field.global_position = ArenaRoot.position
	field.id = 0
	ArenaRoot.add_child(field)
	field.init(0)
	game_camera.target = field.player
	return field
	
func initialize_training_fields():
	var col:int =1
	var row:int =1
	col = ceili(sqrt(field_amount))
	row = ceili(float(field_amount)/col)
	var start_x = -col/2*training_field_size
	var start_y = -row/2*training_field_size
	var id_counter = 0
	var amount = 0
	for r in range(row):
		for c in range(col):
			var center = Vector3(start_x+(training_field_size+2)*c,0,start_y+(training_field_size+2)*r)
			var field = load_trainning_field(center)
			field.init(id_counter)
			TraningRoot.add_child(field)
			id_counter += 1
			amount += 1
			if amount == field_amount:
				break

func reset_field(field_id):
	if training_fields.has(field_id):
		var field = training_fields[field_id]
		field.reset()

func spawn_player(scene_root, position, rotation=Quaternion.IDENTITY):
	var player = player_prefab.instantiate()
	scene_root.add_child(player)
	player.global_position = position
	player.basis = Basis(rotation)
	return player
	
func spawn_monster(scene_root, position, rotation=Quaternion.IDENTITY):
	var mob = enemy_prefab.instantiate()
	scene_root.add_child(mob)
	mob.position = position
	mob.basis = Basis(rotation)
	return mob

