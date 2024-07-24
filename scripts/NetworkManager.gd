class_name NetworkManager extends Node

const S_START = 1
const S_GAME_STATE = 2
const S_CLOSE = 3
const S_SAVE = 4
const S_EP = 5

const C_RESET = 10
const C_OP = 11
const C_PAUSE = 12
const C_RESUME = 13
const C_EP = 14

static var instance:NetworkManager

var server = TCPServer.new()
var server_ctrl = TCPServer.new()

var pending_clients:Array[StreamPeerTCP] = []
var clients = {}
var client_id_counter = 0
var ctrl_client:StreamPeerTCP

@export
var reconnect_interval:float = 1
var connected = false

var training = false

var next_retry_time = 0
var test_recved = false
const ai_pb = preload("res://protobuf/ai_pb.gd")

func _enter_tree():
	instance = self
	
func _ready():
	if GameManager.instance.control_mode != GameManager.ControlMode.Manual:
		server.listen(6666)
		
	if GameManager.instance.game_mode == GameManager.GameMode.Train:
		training = true
		server_ctrl.listen(6699)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if GameManager.instance.control_mode == GameManager.ControlMode.Manual:
		return
	
	if training and server_ctrl.is_connection_available():
		ctrl_client = server_ctrl.take_connection()
		clients[-1] = ctrl_client
	
	if server.is_connection_available():
		var connection = server.take_connection()
		pending_clients.append(connection)
	
	for c in pending_clients:
		clients[client_id_counter] = c
		send_client_assignment_msg(c, client_id_counter, client_id_counter)
		GameData.game_pause[client_id_counter] = false
		client_id_counter += 1	

	pending_clients.clear()
	
	for client in clients.values():
		var byte_count = client.get_available_bytes()
		if byte_count>0:
			var packet = client.get_data(byte_count)
			var msg_recv = ai_pb.ClientMsg.new()
			var result_code = msg_recv.from_bytes(packet[1])
			if result_code == ai_pb.PB_ERR.NO_ERRORS:
				var msg_type = msg_recv.get_msg_type()
				if msg_type == C_RESET:
					var field_id = msg_recv.get_field_id()
					GameManager.instance.reset_field(field_id)
					GameData.ai_need_update[field_id] = 1
				elif msg_type == C_OP:
					var id = msg_recv.get_id()
					var action = msg_recv.get_action()
					process_agent_action(id,action)	
					#在下一帧发送state和reward
					GameData.ai_need_update[msg_recv.get_field_id()] = 2
				elif msg_type == C_PAUSE:
					GameManager.instance.pause_game(msg_recv.get_field_id())
				elif msg_type == C_RESUME:
					GameManager.instance.resume_game(msg_recv.get_field_id())
				elif msg_type == C_EP:
					GameManager.instance.increase_ep()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if ctrl_client != null and ctrl_client.get_status() == StreamPeerTCP.STATUS_CONNECTED :
			var ctrl_msg = ai_pb.ServerCtrlMsg.new()
			ctrl_msg.set_cmd(S_CLOSE)
			var packed = ctrl_msg.to_bytes()
			ctrl_client.put_data(packed)
		
		var serverMsg = ai_pb.ServerMsg.new()
		serverMsg.set_msg_type(S_CLOSE)
		var packed = serverMsg.to_bytes()
		for client in clients.values():
			client.put_data(packed)

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
	var msg = target_msg.new_sensor_data()
	var player_state = msg.new_player_state()
	#===player state===
	player_state.set_hp(sensor_data.player_data.hp)
	player_state.set_move_dir(sensor_data.player_data.move_dir)
	player_state.set_is_moving(sensor_data.player_data.is_moving)
	for distance in sensor_data.player_data.terrain_info:
		player_state.add_terrain_info(distance)
	#===================
	var region_info = sensor_data.compose_final_cell()
	for info in region_info:
		msg.add_region_info(info)

func send_server_state(field_id,id,sensor_data,reward,game_end):
	var client = get_client(id)
	if client == null:
		return false
	var server_msg = ai_pb.ServerMsg.new()
	server_msg.set_field_id(field_id)
	server_msg.set_id(id)
	server_msg.set_msg_type(S_GAME_STATE)
	server_msg.set_reward(reward)
	server_msg.set_game_end(game_end)
	if sensor_data != null:
		serialize_sensor_data(sensor_data,server_msg)

	var packed  = server_msg.to_bytes()
	client.put_data(packed)
	return true

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
	
	#GameData.player_input[id].shooting = action.get_shoot_state()
	var move_dir = _angle_to_vect2(action.get_move_dir())
	GameData.player_input[id].direction = move_dir

func request_save():
	if ctrl_client.get_status() == StreamPeerTCP.STATUS_CONNECTED :
		var ctrl_msg = ai_pb.ServerCtrlMsg.new()
		ctrl_msg.set_cmd(S_SAVE)
		var packed = ctrl_msg.to_bytes()
		ctrl_client.put_data(packed)
