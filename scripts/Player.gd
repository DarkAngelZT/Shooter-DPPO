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
	if is_game_paused():
		return
		
	if GameData.actor_info[field_id][id].hp<=0:
		return
	var input = GameData.player_input[id]
	if is_instance_valid(input):
		var direction = Vector3.ZERO
		direction.z = input.direction.y
		direction.x = input.direction.x
		basis = Basis.looking_at(Vector3(input.aim_direction.x,0,input.aim_direction.y))
		GameData.actor_info[field_id][id].direction = input.aim_direction
		
		if input.move_state == GameData.Op_Move:
			var speed = direction * move_speed
			velocity = speed
			character_mesh.walk()
			move_and_slide()
			GameData.actor_info[field_id][id].move_dir=Vector2(direction.x,direction.z)
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
