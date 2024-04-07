class_name GameData

const Op_Stop:int = 0
const Op_Move:int = 1

class PlayerInputState:
	var direction : Vector2 = Vector2.UP
	var move_state: int = Op_Stop

class AtorState:
	var field_id:int = 0
	var actor_id:int = 0
	var hp:int = 100
	var alive:bool = true
	var can_shoot:bool = true
	var direction:Vector2 = Vector2.UP
	var move_dir:Vector2 = Vector2.UP
	

static var game_end
static var player_input:PlayerInputState


