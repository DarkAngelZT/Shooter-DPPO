import os
import socket
import torch
import model
import ai_pb2
import numpy as np

from torch.nn import functional as F

import model.Actor as Actor
import model.Critic as Critic

STATE_DIM = 201
ACTION_DIM = 4
HIDDEN_LAYER = 600

A_UPDATE_STEP = 6

buffer_size = 1024

S_START = 1
S_GAME_STATE = 2
S_CLOSE = 3

C_RESET = 10
C_OP = 11

actor_lr = 3e-4
critic_lr = 1e-3
gamma = 0.93
lmbda = 0.9
eps = 0.2

def random_normal(mu,std):
	a = torch.normal(mu,std)
	return [a.item()]

def process_action(a_mean):
	a = random_normal(a_mean,1)
	move_d = np.clip(a[0], -1,1)*180
	aim_d = np.clip(a[1],-1,1)*180
	move_state = a[2] >= 0
	shoot_state = a[3] >= 0
	return [move_d,aim_d,move_state,shoot_state]

def process_state(sensor_data):
	pass

class PlayMode(object):
	"""游戏模式"""
	def __init__(self):
		super(PlayMode, self).__init__()
		self.net = Actor(STATE_DIM,ACTION_DIM,HIDDEN_LAYER)
		self.client = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
		self.field_id = 0
		self.id = 0

	def take_action(self,state):
		mean = self.net.get_action(state)
		return process_action(mean)

	def process_server_msg(self, in_msg):
		msg_type = in_msg.msg_type
		if msg_type == S_START:
			self.field_id = in_msg.field_id
			self.id = in_msg.id
			return True
		elif msg_type == S_CLOSE:
			return False
		elif msg_type == S_GAME_STATE:
			if in_msg.game_end:
				out_msg = ai_pb2.ClientMsg()
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
		self.client.connect(("127.0.0.1",6666))
		server_msg = ai_pb2.ServerMsg()
		while True:
			data = self.client.recv(buffer_size)
			server_msg.ParseFromString(data)
			if not self.process_server_msg(server_msg, client_msg):
				break
		self.client.close()

class TrainMode(object):
	"""docstring for TrainMode"""
	def __init__(self):
		super(TrainMode, self).__init__()
		self.s=[]
		self.a=[]
		self.r=[]
		self.s_prime=[]
		self.done = []

		self.actor = Actor(STATE_DIM,ACTION_DIM,HIDDEN_LAYER)
		self.critic = Critic(STATE_DIM)
		self.actor_opt = torch.optim.Adam(self.actor.parameters(), lr=actor_lr)
		self.critic_opt = torcj.optim.Adam(self.critic.parameters(),lr=critic_lr)

	def make_sample(self):
		pass

	def compute_advantage(gamma, lmbda, td_delta):
		td_delta = td_delta.detach().numpy()
		adv_list = []
		adv = 0
		for delta in td_delta[::-1]:
			adv = gamma*lmbda*adv + delta
			adv_list.append(adv)
		adv_list.reverse()
		return torch.FloatTensor(adv_list)

	def train_tmp(self):
		states,actions,rewards,next_states, done = self.make_sample()

		td_target = rewards+gamma*self.critic(next_states)*(1-done)
		q = self.critic(state)
		td_delta = td_target - q
		advantage = self.compute_advantage(gamma,lmbda)

		action_, old_log_probs = self.actor(states)

		for _ in range(A_UPDATE_STEP):			
			_, log_prob = self.actor(states)

			ratio = torch.exp(log_prob-old_log_probs)
			surr1 = ratio *advantage
			surr2 = torch.clamp(ratio, 1 - eps, 1 + eps) * advantage

			new_q = self.critic(state)
			actor_loss = torch.mean(-torch.min(surr1,surr2)).float()
			critic_loss = torch.mean(F.mse_loss(new_q,td_target.detach()))
			self.actor_opt.zero_grad()
			self.critic_opt.zero_grad()
			actor_loss.backward()
			critic_loss.backward()
			self.actor_opt.step()
			self.critic_opt.step()
		