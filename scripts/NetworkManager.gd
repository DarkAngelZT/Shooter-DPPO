class_name NetworkManager extends Node

const S_START = 1
const S_GAME_STATE = 2
const S_CLOSE = 3

const C_RESET = 10
const C_OP = 11

var server = TCPServer.new()

var pending_clients:Array[StreamPeerTCP] = []
var clients = {}
var client_id_counter = 0

@export
var reconnect_interval:float = 1
var connected = false

var next_retry_time = 0
var test_recved = false
const ai_pb = preload("res://protobuf/ai_pb.gd")
# Called when the node enters the scene tree for the first time.
func _ready():
	if GameManager.instance.control_mode != GameManager.ControlMode.Manual:
		server.listen(6666)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if GameManager.instance.control_mode == GameManager.ControlMode.Manual:
		return
	
	if server.is_connection_available():
		var connection = server.take_connection()
		pending_clients.append(connection)
	
	for c in pending_clients:
		clients[client_id_counter] = c
		send_client_assignment_msg(c, client_id_counter, client_id_counter)
		client_id_counter += 1		

	pending_clients.clear()
	
	for client in clients.values():
		var byte_count = client.get_available_bytes()
		if byte_count>0:
			var packet = client.get_data(byte_count)
			var msg_recv = ai_pb.ClientMsg.new()
			var result_code = msg_recv.from_bytes(packet[1])
			if result_code == ai_pb.PB_ERR.NO_ERRORS:
				print('receive data')
				print(msg_recv.to_string())
				var msg_type = msg_recv.get_msg_type()
				if msg_type == C_RESET:
					var field_id = msg_recv.get_field_id()
					GameManager.instance.reset_field(field_id)
				elif msg_type == C_OP:
					var id = msg_recv.get_id()
					var action = msg_recv.get_action()
					process_agent_action(id,action)					

func get_client(id):
	if clients.has(id):
		return clients[id]
	else:
		return null

func _angle_to_vect2(angle):
	var x = sin(angle)
	var y = -cos(angle)
	return Vector2(x,y)

func serialize_sensor_data(sensor_data, target_msg):
	var msg = target_msg.new_sesnor_data()
	var player_state = msg.new_player_state()
	#===player state===
	player_state.set_hp(sensor_data.player_data.hp)
	player_state.set_move_dir(sensor_data.player_data.move_dir)
	player_state.set_aim_dir(sensor_data.player_data.aim_dir)
	player_state.set_is_moving(sensor_data.player_data.is_moving)
	player_state.set_shoot_cd_left(sensor_data.player_data.shoot_cd_left)
	for distance in sensor_data.player_data.terrain_info:
		player_state.terrain_info.add_terrain_info(distance)
	#===================
	for i in range(PlayerSensor.NEAR,PlayerSensor.FAR+1):
		#===mob data===
		for m in sensor_data.mob_data[i]:
			var mob_region_info = msg.add_mob_data()
			mob_region_info.set_amount(m.amount)
			mob_region_info.set_dir_info(m.region_dir_info)
		#===mob bullet===
		for b in sensor_data.mob_bullet_data[i]:
			var m_bullet = msg.add_mob_bullet_data()
			m_bullet.set_amount(b.amount)
			m_bullet.set_dir_info(b.dir_info)
		#===player bullet===
		for pb in sensor_data.player_bullet_data[i]:
			var p_bullet = msg.add_player_bullet_data()
			p_bullet.set_amount(pb.amount)
			p_bullet.set_dir_info(pb.dir_info)

func send_server_state(field_id,id,sensor_data,reward,game_end):
	var client = get_client(id)
	if client == null:
		return
	var server_msg = ai_pb.ServerMsg.new()
	server_msg.set_field_id(field_id)
	server_msg.set_id(id)
	server_msg.set_msg_type(S_GAME_STATE)
	server_msg.set_reward(reward)
	server_msg.set_game_end(game_end)
	serialize_sensor_data(sensor_data,server_msg)

	var packed  = server_msg.to_bytes()
	client.put_data(packed)

func send_client_assignment_msg(client,field_id,id):
	var server_msg = ai_pb.ServerMsg.new()
	server_msg.set_field_id(field_id)
	server_msg.set_id(id)
	server_msg.set_msg_type(S_START)

	var packed  = server_msg.to_bytes()
	client.put_data(packed)

func process_agent_action(id,action):
	if action.get_move_state():
		GameData.player_input[id].move_state = GameData.Op_Move
	else:
		GameData.player_input[id].move_state = GameData.Op_Stop
	
	GameData.player_input[id].shooting = action.get_shoot_state()
	var move_dir = _angle_to_vect2(action.get_move_dir())
	var aim_dir = _angle_to_vect2(action.get_aim_dir())
	GameData.player_input[id].direction = move_dir
	GameData.player_input[id].aim_direction = aim_dir

