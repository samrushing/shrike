# -*- Mode: Python -*-

import shrike
import sys
W = sys.stderr.write

def session (conn, addr):
    while 1:
        block = conn.recv (1024)
        if not block:
            break
        elif block == 'quit\r\n':
            break
        elif block == 'shutdown\r\n':
            shrike._exit = True
            break
        else:
            conn.send (block)
    conn.close()

def server (port):
    s = shrike.tcp_socket()
    s.set_reuse_addr()
    s.bind (('', port))
    s.listen (5)
    while not shutdown:
        conn, addr = s.accept()
        shrike.spawn (session, conn, addr)

# this doesn't quite cut it... need a proper _exit condition.

shutdown = False

shrike.spawn (server, 8888)
shrike.event_loop()
