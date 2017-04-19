from matplotlib import pyplot as plt
import numpy as np

#nodes = 101
it = 1

raw = []
intermediate = []
data = []
with open('output.txt', 'r') as f:
	for line in f:
		raw = line.split(' ')
		intermediate = [raw[i] for i in range(0, len(raw) - 1) if raw[i] != '']
		if (len(intermediate) == 4):
			numprocs = int(intermediate[0])
			nodes = int(intermediate[1]) + 1
			data.extend(intermediate[2:])
		else:
			data.extend(intermediate)

data = [float(data[i]) for i in range(0, len(data))]
x    = np.linspace(0.0, 1.0, len(data[0:nodes]))

#plt.ion()
for i in range(0, len(data), it*nodes):
	plt.plot(x, data[i:(i + nodes)], '--')
	#plt.pause(0.1)

#plt.plot(x, data[-nodes:])
plt.show()
