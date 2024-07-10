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
	

static var game_end = {} #{field_id:true/false}
static var player_input = {} #{field_id:PlayerInputState}
static var actor_info = {} #{field_id:{actor_id:ActorState}}
static var game_pause = {} #{field_id:true/false}

static var ai_need_update = {} #{field_id:frame_to_run}
