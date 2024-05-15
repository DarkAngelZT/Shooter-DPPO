import torch
import torch.nn as nn
import torch.optim as optim


class Actor(nn.Module):
	"""Actor Net"""
	def __init__(self, n_states,n_actions, hidden_dim):
		super(Actor, self).__init__()
		self.model = nn.Sequential(
			nn.Linear(n_states, hidden_dim),
			nn.ReLU(inplace=True),
			nn.Linear(hidden_dim,hidden_dim),
			nn.ReLU(inplace=True)
			nn.Linear(hidden_dim,n_actions),
			nn.Tanh()
		)
	
	def forward(self, inputs):
		return self.model(inputs)

class Critic(nn.Module):
	"""Critic Net"""
	def __init__(self, n_states):
		super(Critic, self).__init__()
		self.model = nn.Sequential(
			nn.Linear(n_states, hidden_dim*3),
			nn.ReLU(inplace=True),
			nn.Linear(hidden_dim*3,1)
		)
	
	def forward(self, inputs):
		return self.model(inputs)
