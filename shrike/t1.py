import shrike
import sys

import random
W = sys.stderr.write
z = 0

# two threads fight to increase or decrease a global integer
n = 1000

def thing0 (c):
    global n
    while c:
        r = random.randint (0, 100)
        n += r
        c -= 1
        shrike._yield()
    print 'exited thing0'
    
def thing1 (c):
    global n
    while c:
        r = random.randint (0, 100)
        n -= r
        c -= 1
        shrike._yield()
    print 'exited thing1'

c0 = shrike.spawn (thing0, 100)
c1 = shrike.spawn (thing1, 100)

for i in range (101):
    shrike.run()
    print n
