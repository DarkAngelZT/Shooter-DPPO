import torch
import torch.multiprocessing as mp
import numpy as np

memory_capacity = 10000

class GameRecord(object):
	"""docstring for GameRecord"""
	def __init__(self):
		super(GameRecord, self).__init__()
		self.lock = mp.Lock()
		self.s=[]
		self.a=[]
		self.r=[]
		self.s_prime=[]
		self.done = []
		self.memory_amount = 0
		self.memory_index = 0

	def add_record(self, state, action, reward, next_state, done):
		with self.lock:
			self.s.append(state)
			self.a.append(action)
			self.r.append(reward)
			self.s_prime.append(next_state)
			self.done.append(done)

			self.memory_index += 1
			self.memory_amount+=1

	def reset(self):
		with self.lock:
			self.s=[]
			self.a=[]
			self.r=[]
			self.s_prime=[]
			self.done = []

			self.memory_amount = 0
			self.memory_index = 0

class TrafficLight:
	def __init__(self):
		self.lock = mp.Lock()
		self.val = mp.Value("b",False)

	def get(self):
		with self.lock:
			return self.val.value

	def switch(self):
		with self.lock:
			self.val.value = not self.val.value

class Counter(object):
	def __init__(self):
		self.val = mp.Value("c",0)
		self.lock = mo.Lock()

	def get(self):
		with self.lock:
			return self.val.value

	def reset(self):
		with self.lock:
			self.val.value = 0

	def increase(self):
		with self.lock:
			self.val.value += 1