from shrike.coro import *
# we are forced to the '_' prefix because <yield> is a keyword.
# this extra import gets around the interpration of _xxx as module private.
from shrike.coro import _yield
from shrike.poller import the_poller
from shrike.socket import *

# next: priority queue for events, with_timeout().

_exit = False

def event_loop():
    global _exit
    while not _exit:
        while shrike.run():
            pass
        shrike.the_poller.poll()
