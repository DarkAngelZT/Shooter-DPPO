import torch
import torch.nn as nn
import torch.optim as optim

STATE_DIM = 201
ACTION_DIM = 4
HIDDEN_LAYER = 600

class Actor(nn.Module):
	"""Actor Net"""
	def __init__(self, n_states,n_actions, hidden_dim):
		super(Actor, self).__init__()
		self.model = nn.Sequential(
			nn.Linear(n_states, hidden_dim),
			nn.ReLu(inplace=True),
			nn.Linear(hidden_dim,hidden_dim),
			nn.ReLu(inplace=True)
			nn.Linear(hidden_dim,n_actions)
		)
	
	def forward(self, inputs):
		pass
