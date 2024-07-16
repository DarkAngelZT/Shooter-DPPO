import os
import sys
import socket
import torch
import model
import ai_pb2
import util
import numpy as np
import time
import select

from torch.nn import functional as F
import torch.multiprocessing as mp

from model import Actor
from model import Critic

STATE_DIM = 205
ACTION_DIM = 4
HIDDEN_LAYER = 600

A_UPDATE_STEP = 6
C_UPDATE_STEP = 6

buffer_size = 1024

S_START = 1
S_GAME_STATE = 2
S_CLOSE = 3
S_SAVE = 4

C_RESET = 10
C_OP = 11
C_PAUSE = 12
C_RESUME = 13

actor_lr = 3e-4
critic_lr = 1e-3
gamma = 0.93
lmbda = 0.9
eps = 0.2
batch_size = 64
auto_save_ep = 10

worker_amount = 3

def conv_bool(b):
	return 1 if b else 0

def random_normal(mu,std):
	a = torch.normal(mu,std)
	return a.detach().tolist()[0]

def process_action(a_mean):
	a = random_normal(a_mean,1)
	move_d = np.clip(a[0], -1,1)*180
	aim_d = np.clip(a[1],-1,1)*180
	move_state = a[2] >= 0
	shoot_state = a[3] >= 0
	return [move_d,aim_d,move_state,shoot_state]

def process_state(sensor_data):
	player_data = [
	sensor_data.player_state.hp, sensor_data.player_state.move_dir,sensor_data.player_state.aim_dir,
	conv_bool(sensor_data.player_state.is_moving), sensor_data.player_state.shoot_cd_left ]
	player_terrian_data = [i for i in sensor_data.player_state.terrain_info]
	mob_data = [d for m in sensor_data.mob_data for d in (m.amount,m.dir_info)]
	mob_bullet = [d for m in sensor_data.mob_bullet_data for d in (m.amount,m.dir_info)]
	player_bullet = [d for m in sensor_data.player_bullet_data for d in (m.amount,m.dir_info)]
	data = np.hstack([player_data,player_terrian_data,mob_data,mob_bullet,player_bullet])
	return torch.FloatTensor(data)

class PlayMode(object):
	"""游戏模式"""
	def __init__(self):
		super(PlayMode, self).__init__()
		self.net = Actor(STATE_DIM,ACTION_DIM,HIDDEN_LAYER)
		self.client = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
		self.field_id = 0
		self.id = 0

	def load(self,fname):
		self.net.load_state_dict(torch.load(fname))
		print("load net finish")

	def take_action(self,state):
		mean = self.net.get_action(state)
		return process_action(mean)

	def process_server_msg(self, in_msg):
		msg_type = in_msg.msg_type
		if msg_type == S_START:
			self.field_id = in_msg.field_id
			self.id = in_msg.id
			print("get player info: field: %i, id: %i"%(self.field_id,self.id))
			return True
		elif msg_type == S_CLOSE:
			return False
		elif msg_type == S_GAME_STATE:
			out_msg = ai_pb2.ClientMsg()
			if in_msg.game_end:				
				out_msg.field_id = self.field_id
				out_msg.id = self.id
				out_msg.msg_type = C_RESET
				msg = out_msg.SerializeToString()
				self.client.send(msg)
				return True

			raw_sensor_data = in_msg.sensor_data
			sensor_data = process_state(raw_sensor_data)
			action = self.take_action(sensor_data)
			out_msg.field_id = self.field_id
			out_msg.id = self.id
			out_msg.msg_type = C_OP
			a = out_msg.action
			a.move_dir,a.aim_dir,a.move_state,a.shoot_state = action
			msg = out_msg.SerializeToString()
			self.client.send(msg)
			return True

	def main_loop(self):
		print('start play mode')
		self.client.connect(("127.0.0.1",6666))
		server_msg = ai_pb2.ServerMsg()
		while True:
			data = self.client.recv(buffer_size)
			server_msg.ParseFromString(data)
			if not self.process_server_msg(server_msg):
				break
		self.client.close()

class TrainMode(object):
	"""docstring for TrainMode"""
	def __init__(self):
		super(TrainMode, self).__init__()
		self.actor = Actor(STATE_DIM,ACTION_DIM,HIDDEN_LAYER)
		self.critic = Critic(STATE_DIM,HIDDEN_LAYER)
		self.actor_opt = torch.optim.Adam(self.actor.parameters(), lr=actor_lr)
		self.critic_opt = torch.optim.Adam(self.critic.parameters(),lr=critic_lr)

		mp_manager = mp.Manager()
		self.record = util.GameRecord(mp_manager)
		self.traffic_signal = util.TrafficLight()
		self.record_counter = util.Counter()

		self.process = []
		self.power = util.TrafficLight()

		self.actor.share_memory()

	def make_sample(self):
		s,a,r,s_,d = self.record.get_records()
		return torch.FloatTensor(s),torch.FloatTensor(a),torch.FloatTensor(r),torch.FloatTensor(s_),torch.FloatTensor(d)

	def compute_advantage(self, gamma, lmbda, td_delta):
		td_delta = td_delta.detach().numpy()
		adv_list = []
		adv = 0
		for delta in td_delta[::-1]:
			adv = gamma*lmbda*adv + delta
			adv_list.append(adv)
		adv_list.reverse()
		return torch.FloatTensor(adv_list)

	def train(self):
		states,actions,rewards,next_states, done = self.make_sample()

		td_target = rewards+gamma*self.critic(next_states)*(1-done)
		q = self.critic(states)
		td_delta = td_target - q
		advantage = self.compute_advantage(gamma, lmbda, td_delta)

		action_, old_log_probs = self.actor(states)

		for i in range(A_UPDATE_STEP):		
			_, log_prob = self.actor(states)

			ratio = torch.exp(log_prob-old_log_probs.detach())
			surr1 = ratio * advantage.detach()
			surr2 = torch.clamp(ratio, 1 - eps, 1 + eps) * advantage.detach()

			new_q = self.critic(states)

			actor_loss = torch.mean(-torch.min(surr1,surr2)).float()
			critic_loss = torch.mean(F.mse_loss(new_q,td_target.detach()))
			self.actor_opt.zero_grad()
			self.critic_opt.zero_grad()
			actor_loss.backward()
			critic_loss.backward()
			self.actor_opt.step()
			self.critic_opt.step()
	
	def save(self,folder, ep_num):
		root = ''
		if folder:
			root = "%s\\"%folder
		folder_name = '%sep_%i'%(root,ep_num)
		if not os.path.exists(folder_name):
			os.mkdir(folder_name)

		torch.save(self.actor.state_dict(),'%s\\actor_%i.pth'%(folder_name,ep_num))
		torch.save(self.critic.state_dict(),'%s\\critic_%i.pth'%(folder_name,ep_num))
		print('saved net to %s'%folder_name)
	
	def load(self, folder, a_fname,c_fname):
		actor_path = '%s\\%s.pth'%(folder,a_fname)
		critic_path = '%s\\%s.pth'%(folder,c_fname)
		if os.path.exists(actor_path) and os.path.exists(critic_path):
			self.actor.load_state_dict(torch.load(actor_path))
			self.critic.load_state_dict(torch.load(critic_path))
			print('load net success')

	def chief_logic(self,traffic_signal, record_counter,shared_record, shared_actor, power):
		client = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
		client.setblocking(False)
		client.settimeout(2)
		try:
			client.connect(("127.0.0.1",6699)) # 控制用连接
		except BlockingIOError as e:
			pass
		
		print('chief connected')
		ep_num = 0
		next_update_time = 0
		server_msg = ai_pb2.ServerCtrlMsg()
		r_list = [client]
		w_list = []
		x_list = []
		running = True		
		while running:
			readable,writable,exceptions = select.select(r_list,w_list,x_list,0.1)
			for s in readable:
				data = s.recv(buffer_size)
				server_msg.ParseFromString(data)
				cmd = server_msg.cmd
				if cmd == S_CLOSE:
					power.switch()
					running = False
				if cmd == S_SAVE:
					# save nerual network
					self.save('',ep_num)
			for s in exceptions:
				r_list.remove(s)
			
			if not traffic_signal.get():
				self.train()
				record_counter.reset()
				shared_record.reset()
				ep_num += 1
				if ep_num % auto_save_ep == 0:
					self.save('',ep_num)
				traffic_signal.switch()

		client.close()

	def main_loop(self):
		print("start training mode")
		main_p = mp.Process(target=self.chief_logic,args=(self.traffic_signal,self.record_counter,self.record,self.actor,self.power))
		self.process.append(main_p)

		for i in range(worker_amount):
			p = mp.Process(target=worker,args=(self.traffic_signal,self.record_counter,self.record,self.actor,self.power))
			self.process.append(p)

		for p in self.process:
			p.start()

		for p in self.process:
			p.join()


def worker(traffic_signal, record_counter,shared_record, shared_actor, power):
	client = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
	client.connect(("127.0.0.1",6666))
	paused = False
	restart = True
	game_end = False
	server_msg = ai_pb2.ServerMsg()
	state = None
	action = None
	s=[]
	a=[]
	r=[]
	s_=[]
	done = []

	field_id = 0
	cid = 0

	while True:
		if not power.get():
			break
		data = client.recv(buffer_size)
		server_msg.ParseFromString(data)
		msg_type = server_msg.msg_type
		if msg_type == S_START:
			field_id = server_msg.field_id
			cid = server_msg.id
			continue
		elif msg_type == S_CLOSE:
			break
		elif msg_type == S_GAME_STATE:
			game_end = server_msg.game_end

			sensor_data = None

			if not game_end:
				raw_sensor_data = server_msg.sensor_data
				sensor_data = process_state(raw_sensor_data)
			if restart or state == None:
				state = sensor_data
				action = None
				restart = False

			elif paused:
				state = sensor_data
				action = None
				paused = False

			elif action != None:
				if not traffic_signal.get():
					if not game_end:
						out_msg = ai_pb2.ClientMsg()
						out_msg.field_id = field_id
						out_msg.id = cid
						out_msg.msg_type = C_PAUSE
						msg = out_msg.SerializeToString()
						client.send(msg)
						paused = True

					while not traffic_signal.get():
						time.sleep(0.1)
					s,a,r,s_,done = [], [], [], [], []

					if paused:
						time.sleep(0.1)
						out_msg = ai_pb2.ClientMsg()
						out_msg.field_id = field_id
						out_msg.id = cid
						out_msg.msg_type = C_RESUME
						msg = out_msg.SerializeToString()
						client.send(msg)
						paused = False
						time.sleep(0.1) #必须停一下，不然消息包会被后面的消息覆盖

				s.append(state.detach().tolist())
				a.append(action)
				r.append([server_msg.reward])
				if sensor_data is not None:					
					s_.append(sensor_data.detach().tolist())
				else:
					s_.append(state.detach().tolist())
				done.append([0 if game_end else 1])
				state = sensor_data
				record_counter.increase()
				count = record_counter.get()
				if count >= batch_size or game_end:
					shared_record.add_records(s,a,r,s_,done)

					if count>=batch_size:
						traffic_signal.turn_off()

			out_msg = ai_pb2.ClientMsg()
			if game_end:				
				out_msg.field_id = field_id
				out_msg.id = cid
				out_msg.msg_type = C_RESET
				msg = out_msg.SerializeToString()
				client.send(msg)
				restart = True
			else:
				mean = shared_actor.get_action(state)
				action = process_action(mean)
				out_msg.field_id = field_id
				out_msg.id = cid
				out_msg.msg_type = C_OP
				out_a = out_msg.action
				out_a.move_dir,out_a.aim_dir,out_a.move_state,out_a.shoot_state = action
				msg = out_msg.SerializeToString()
				client.send(msg)

	client.close()


#=============main=================
if __name__ == '__main__':
	argc = len(sys.argv)
	cmd_mode = sys.argv[1] if argc>1 else 'play'
	mode = None
	if cmd_mode == 'play':
		mode = PlayMode()
		if argc > 2:
			fname = sys.argv[2]
			mode.load(fname)
	elif cmd_mode == 'train':
		mode = TrainMode()
		if argc > 4:
			folder = sys.argv[2]
			a_name = sys.argv[3]
			c_name = sys.argv[4]
			mode.load(folder,a_name,c_name)

	if mode != None:
		mode.main_loop()
	else:
		print("invalid mode: %s"%cmd_mode)