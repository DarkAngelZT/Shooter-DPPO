class_name Mob
extends CharacterBase

var spawner:MobSpanwer

@export
var damage:int

func _ready():
	move_speed = GameManager.instance.game_settings.monster_move_speed
	health = GameManager.instance.game_settings.monster_health
	damage = GameManager.instance.game_settings.bullet_damage

func _physics_process(delta):
	pass

func die():
	spawner.on_mob_dead(self)
	queue_free()

func on_bullet_hit(other):
	if other is Player:
		other.take_damage(damage)
