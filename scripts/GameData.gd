class_name GameData

const Op_Stop:int = 0
const Op_Move:int = 1

class PlayerInputState:
	var field_id:int = 0
	var direction : Vector2 = Vector2.UP
	var move_state: int = Op_Stop
	var aim_direction:Vector2 = Vector2.UP
	var shooting:bool = false
	
	func _init(id=0,dir=Vector2.UP,op_state=Op_Stop):
		field_id = id
		direction = dir
		move_state = op_state

	func stop_move() -> void:
		move_state = Op_Stop
		direction = Vector2.ZERO

	func start_move(move_direction:Vector2) -> void:
		move_state = Op_Move
		direction = move_direction.normalized()

class ActorState:
	var field_id:int = 0
	var actor_id:int = 0
	var hp:int = 100
	var can_shoot:bool = true
	var direction:Vector2 = Vector2.UP
	var move_dir:Vector2 = Vector2.UP
	
	func _init(fid=0,aid=0):
		field_id = fid
		actor_id = aid

class TrainingSample:
	var field_id:int
	var sensor_data : Array
	var reward:float
	var game_end:bool

	func _init(fid:int, data, step_reward:float, ended:bool):
		field_id = fid
		sensor_data = data
		reward = step_reward
		game_end = ended
	

# Per-field runtime state.
static var game_end = {} #{field_id:true/false}
static var player_input = {} #{field_id:PlayerInputState}
static var actor_info = {} #{field_id:{actor_id:ActorState}}
static var game_pause = {} #{field_id:true/false}

# Kept for compatibility with the old socket loop. The new in-process training
# loop samples on a timer instead of waiting for NetworkManager callbacks.
static var ai_need_update = {} #{field_id:frame_to_run}

# Reward interval state. These values are reset after each training sample,
# not every physics frame.
static var player_hp_cache = {} # {id:hp}
static var player_shooted = {} # {id:true/false}
static var player_pos_cache = {} # {id:vec}
static var mob_kill_cache = {} # {id:count}

static func reset_runtime() -> void:
	game_end.clear()
	player_input.clear()
	actor_info.clear()
	game_pause.clear()
	ai_need_update.clear()
	player_hp_cache.clear()
	player_shooted.clear()
	player_pos_cache.clear()
	mob_kill_cache.clear()

static func register_field(field_id:int, paused:bool) -> void:
	player_input[field_id] = PlayerInputState.new(field_id)
	game_end[field_id] = false
	game_pause[field_id] = paused
	actor_info[field_id] = {}
	ai_need_update[field_id] = 0
	mob_kill_cache[field_id] = 0

static func register_actor(actor_state:ActorState) -> void:
	if not actor_info.has(actor_state.field_id):
		actor_info[actor_state.field_id] = {}
	actor_info[actor_state.field_id][actor_state.actor_id] = actor_state

static func unregister_actor(field_id:int, actor_id:int) -> void:
	if actor_info.has(field_id):
		actor_info[field_id].erase(actor_id)

static func register_player_reward_baseline(player_id:int, hp:int, position:Vector3) -> void:
	player_hp_cache[player_id] = hp
	player_shooted[player_id] = false
	player_pos_cache[player_id] = position
	mob_kill_cache[player_id] = 0

static func reset_step_reward_stats(player_id:int) -> void:
	player_shooted[player_id] = false
	mob_kill_cache[player_id] = 0

static func update_player_reward_baseline(player_id:int, hp:int, position:Vector3) -> void:
	player_hp_cache[player_id] = hp
	player_pos_cache[player_id] = position
	reset_step_reward_stats(player_id)

static func record_player_shot(player_id:int) -> void:
	player_shooted[player_id] = true

static func record_mob_kill(player_id:int) -> void:
	if not mob_kill_cache.has(player_id):
		mob_kill_cache[player_id] = 0
	mob_kill_cache[player_id] += 1
