class_name Player
extends CharacterBase

signal on_player_dead

@export
var character_mesh:Node3D

@export
var damage:int

# Called when the node enters the scene tree for the first time.
func _ready():
	move_speed = GameManager.instance.game_settings.player_move_speed
	health = GameManager.instance.game_settings.player_health
	damage = GameManager.instance.game_settings.bullet_damage

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	super._process(delta)

func _physics_process(delta):
	if is_game_paused() or GameData.game_end[field_id]:
		return
		
	if GameData.actor_info[field_id][id].hp<=0:
		return
	var input = GameData.player_input[id]
	if is_instance_valid(input):		
		basis = Basis.looking_at(Vector3(input.aim_direction.x,0,input.aim_direction.y))
		GameData.actor_info[field_id][id].direction = input.aim_direction
		
		if is_move_enable():
			var direction = Vector3.ZERO
			direction.z = input.direction.y
			direction.x = input.direction.x
			if input.move_state == GameData.Op_Move:
				var speed = direction * move_speed
				velocity = speed
				character_mesh.walk()
				move_and_slide()
				GameData.actor_info[field_id][id].move_dir=Vector2(direction.x,direction.z)
				#if is_out_of_field():
					#GameData.game_end[field_id]=true
			elif input.move_state == GameData.Op_Stop:
				velocity = Vector3.ZERO
				GameData.actor_info[field_id][id].move_dir=Vector2.ZERO
				character_mesh.idle()
	
	if input.shooting:
		shoot()
		
func die():
	#effect
	on_player_dead.emit(self)
	#destroy
	queue_free()
	
func on_bullet_hit(other):
	if other is Mob:
		other.take_damage(damage)
		
func get_bullet_speed()->float:
	return GameManager.instance.game_settings.bullet_speed_player
	
func get_sensor_data():
	return $PlayerSensor.gether_sensor_data()
	
func take_damage(damage):
	super.take_damage(damage)
	if GameManager.instance.game_mode == GameManager.GameMode.Play:
		UIManager.instance.set_health(GameData.actor_info[field_id][id].hp)
	
func shoot():
	if can_shoot:
		GameData.player_shooted[id] = true
	super.shoot()

func is_move_enable()->bool:
	if GameManager.instance.game_mode == GameManager.GameMode.Train:
		return TrainingManager.enable_player_move()
	return true

func is_shoot_enable()->bool:
	if GameManager.instance.game_mode == GameManager.GameMode.Train:
		return TrainingManager.enable_player_shoot()
	return true

func is_out_of_field():
	if GameManager.instance.game_mode == GameManager.GameMode.Train:
		var d = max(abs(position.x),abs(position.z))
		return d>14
	else:
		return false
