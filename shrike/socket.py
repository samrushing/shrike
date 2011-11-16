# -*- Mode: Python -*-

import _socket
import errno
import shrike

# goal: a socket object that will play along with the rest of Python as much as possible.

# XXX consider supporting multiple types of socket objects:
#   <socket>, <_socket>, ssl, raw file descriptors, etc...

class socket:

    __slots__ = ['_sock']

    def __init__ (self, family=_socket.AF_INET, type=_socket.SOCK_STREAM, proto=0, _sock=None):
        if _sock is None:
            self._sock = _socket.socket (family, type, proto)
        else:
            self._sock = _sock
        self._sock.setblocking (0)
        
    # --- socket methods ---

    def bind (self, *args, **kwargs):
        return self._sock.bind (*args, **kwargs)

    def listen (self, *args, **kwargs):
        return self._sock.listen (*args, **kwargs)

    def setsockopt (self, *args, **kwargs):
        return self._sock.setsockopt (*args, **kwargs)

    def accept (self):
        while 1:
            try:
                conn, addr = self._sock.accept()
                return socket (_sock=conn), addr
            except _socket.error as err:
                if err.errno == errno.EWOULDBLOCK:
                    shrike.the_poller.wait_for_read (self._sock)
                else:
                    raise

    def send (self, data):
        while 1:
            try:
                return self._sock.send (data)
            except _socket.error as err:
                if err.errno == errno.EWOULDBLOCK:
                    shrike.the_poller.wait_for_write (self._sock)
                else:
                    raise

    # XXX look into recv_into()
    def recv (self, size):
        while 1:
            try:
                return self._sock.recv (size)
            except _socket.error as err:
                if err.errno == errno.EWOULDBLOCK:
                    shrike.the_poller.wait_for_read (self._sock)
                else:
                    raise

    def close (self):
        self._sock.close()

    # --- utility methods ---

    def set_reuse_addr (self):
        # try to re-use a server port if possible
        try:
            self._sock.setsockopt (
                _socket.SOL_SOCKET, _socket.SO_REUSEADDR,
                self._sock.getsockopt (
                    _socket.SOL_SOCKET, _socket.SO_REUSEADDR
                    ) | 1
                )
        except socket.error:
            pass

def tcp_socket():
    return socket (_socket.AF_INET, _socket.SOCK_STREAM)

def unix_socket():
    return socket (_socket.AF_UNIX, _socket.SOCK_STREAM)    

def udp_socket():
    return socket (_socket.AF_INET, _socket.SOCK_DGRAM)    

