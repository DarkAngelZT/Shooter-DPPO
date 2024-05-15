import os
import socket
import torch
import model

import model.Actor as Actor
import model.Critic as Critic

STATE_DIM = 201
ACTION_DIM = 4
HIDDEN_LAYER = 600

def process_action(action):
	move_d = action[0]*180
	aim_d = action[1]*180
	move_state = (action[2] >= 0)
	shoot_state = (action[3] >= 0)
	return [move_d,aim_d,move_state,shoot_state]

class PlayMode(object):
	"""游戏模式"""
	def __init__(self):
		super(PlayMode, self).__init__()
		self.net = Actor(STATE_DIM,ACTION_DIM,HIDDEN_LAYER)
		self.client = socket.socket(socket.AF_INET,socket.SOCK_STREAM)

	def take_action(self,state):
		action = self.net(state)
		return process_action(action)

	def main_loop():
		while True:
			pass