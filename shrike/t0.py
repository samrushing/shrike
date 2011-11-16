import shrike
import sys

W = sys.stderr.write
z = 0

def thing (x):
    global z
    while 1:
        W ('[%d]' % (z,))
        z += x
        shrike._yield()
    return z

c0 = shrike.spawn (thing, 5)

print z

for x in range (100):
    c0._resume (0)

print z
