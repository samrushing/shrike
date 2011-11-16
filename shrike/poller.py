# -*- Mode: Python -*-

import select
import shrike
import sys

# kqueue poller using the builtin support in the select module.

from select import KQ_FILTER_READ, KQ_FILTER_WRITE, KQ_EV_ADD, KQ_EV_ONESHOT

W = sys.stderr.write

class UnHandledKevent (Exception):
    pass

class SimultaneousError (Exception):
    pass

class poller:
    def __init__ (self):
        self.kq = select.kqueue()
        self.changelist = []
        self.waiting = {}

    def _set_wait_for (self, coro, key):
        if self.waiting.has_key (key):
            raise SimultaneousError (coro, key)
        else:
            self.waiting[key] = coro

    def _wait_for (self, ident, filter, flags):
        me = shrike.current()
        key = (ident, filter)
        self.changelist.append (select.kevent (ident, filter, flags))
        self._set_wait_for (me, key)
        return me._yield()

    def wait_for_read (self, ob):
        return self._wait_for (ob.fileno(), KQ_FILTER_READ, KQ_EV_ADD | KQ_EV_ONESHOT)

    def wait_for_write (self, ob):
        return self._wait_for (ob.fileno(), KQ_FILTER_WRITE, KQ_EV_ADD | KQ_EV_ONESHOT)

    def poll (self, timeout=30.0, nevents=2000):
        changelist, self.changelist = self.changelist, []
        events = self.kq.control (changelist, nevents, timeout)
        for kev in events:
            key = (kev.ident, kev.filter)
            #W ('event: %r\n' % (key,))
            if self.waiting.has_key (key):
                co = self.waiting.pop (key)
                shrike.schedule (co, kev.data)
            else:
                # don't raise an error here - other coroutines may be waiting to be scheduled.
                # XXX make some kind of notification system for this?
                W ('un-handled kevent ident=%r filter=%r\n' % (kev.ident, kev.filter))

the_poller = poller()
