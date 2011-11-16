# -*- Mode: Cython -*-

# thinking about the n-stack thing.
# so each coro will have to know which stack it's associated with
# so instead of a 'sched' object we have a 'stack' object.
# the 'sched' object will then own N stack objects.

cdef extern from "machine_state.h":
    ctypedef struct machine_state:
        void ** stack
        void ** frame
        void * insn
        # more slots for saved registers...
    enum:
        STACK_PAD

cdef extern void _wrap0 (void *)
cdef extern void __swap (machine_state *, machine_state *)

# forward declarations
cdef class sched
cdef class coro

# globals
cpdef sched the_scheduler = sched()

from cpython cimport PyMem_Malloc, PyMem_Free
from libc.stdint cimport intptr_t, int64_t
from libc.string cimport memcpy

import sys
W = sys.stderr.write

# can't use cpython/state.pxd because it doesn't declare any of the
# slots *or* _PyThreadState_Current

cdef extern from "frameobject.h":
    ctypedef struct PyFrameObject:
        pass

cdef extern from "Python.h":

    ctypedef struct PyThreadState:
        PyFrameObject * frame
        int recursion_depth
        void * curexc_type, * curexc_value, * curexc_traceback
        void * exc_type, * exc_value, * exc_traceback

    PyThreadState * _PyThreadState_Current

class ScheduleError (Exception):
    pass

class DeadCoroutine (Exception):
    pass

cdef class stack:

    cdef int size
    cdef void * base
    cdef machine_state state

    def __init__ (self, size=4*1024*1024):
        self.size = size
        self.base = PyMem_Malloc (size)
        if self.base == NULL:
            raise MemoryError
        
    def __repr__ (self):
        return '<stack size=0x%x base=0x%x>' % (self.size, <intptr_t>self.base)

cdef int next_coro_id = 1

all_threads = {}

cdef class coro:
    cdef machine_state state
    cdef stack stack
    cdef void * stack_copy
    cdef size_t stack_size
    cdef PyFrameObject * frame
    cdef public bint started, dead, scheduled
    cdef public int id
    cdef public object fun, args, kwargs, value
    cdef int recursion_depth
    
    def __init__ (self, stack, fun, args, kwargs):
        global next_coro_id
        self.stack = stack
        self.fun = fun
        self.args = args
        self.kwargs = kwargs
        self.id = next_coro_id
        next_coro_id += 1
        all_threads[self.id] = self
        self.dead = False
        self.started = False
        self.scheduled = False

    def __dealloc__ (self):
        if self.stack_copy:
            PyMem_Free (self.stack_copy)

    cdef _die (self):
        self.dead = True
        del all_threads[self.id]

    cdef _bootstrap (self):
        cdef void ** stack_top
        stack_top = <void **> (self.stack.base + (self.stack.size - STACK_PAD))
        stack_top[-2] = NULL
        stack_top[-1] = <void *> self
        self.state.stack = &(stack_top[-3])
        self.state.frame = &(stack_top[-2])
        self.state.insn = <void *> _wrap0
        self.started = True

    cpdef _yield (self):
        # save/restore current frame
        # always runs from within a coro
        if not self.dead:
            the_scheduler._current = None
            the_scheduler._last = self
        self.frame = _PyThreadState_Current.frame
        _PyThreadState_Current.frame = NULL
        self.recursion_depth = _PyThreadState_Current.recursion_depth
        __swap (&(the_scheduler.state), &(self.state))
        _PyThreadState_Current.frame = self.frame
        self.frame = NULL
        v, self.value = self.value, None
        return v

    cpdef _resume (self, value):
        cdef PyFrameObject * main_frame
        # always runs from within main
        if self.dead:
            raise DeadCoroutine (self)
        else:
            if not self.started:
                self._bootstrap()
            self.scheduled = False
            self.value = value
            the_scheduler._current = self
            memcpy (self.state.stack, self.stack_copy, self.stack_size)
            main_frame = _PyThreadState_Current.frame
            _PyThreadState_Current.recursion_depth = self.recursion_depth
            _PyThreadState_Current.frame = NULL
            __swap (&(self.state), &(the_scheduler.state))
            _PyThreadState_Current.frame = main_frame
            the_scheduler._current = None
            if self.dead:
                the_scheduler._last = None
            else:
                the_scheduler.preserve_last()

cdef class coval:
    cdef coro co
    cdef object val
    def __cinit__ (self, coro co, object val):
        self.co = co
        self.val = val

cdef class sched:
    cdef machine_state state
    cdef public coro _current, _last
    cdef public list scheduled
    cdef list stacks
    cdef int nstacks, stack_index

    def __init__ (self, int nstacks=5):
        assert (nstacks > 0)
        self.nstacks = nstacks
        self.stacks = [stack() for x in range (nstacks)]
        self.stack_index = 0
        self.scheduled = []

    cdef preserve_last (self):
        # save the stack slice of the coro that just yielded.
        cdef void * stack_top
        cdef size_t size
        cdef coro last = self._last
        cdef stack stack = last.stack
        if self._last is not None:
            # 1) identify the slice
            stack_top = stack.base + stack.size
            size = stack_top - last.state.stack
            # 2) get some storage
            if last.stack_size != size:
                if last.stack_copy:
                    PyMem_Free (last.stack_copy)
                last.stack_copy = PyMem_Malloc (size)
                if not last.stack_copy:
                    raise MemoryError
                last.stack_size = size
            # 3) make the copy
            memcpy (last.stack_copy, last.state.stack, size)
            self._last = None

    cpdef _schedule (self, coro co, object value):
        if co.dead:
            raise DeadCoroutine (self)
        elif co.scheduled:
            raise ScheduleError (self)
        else:
            self.scheduled.append (coval (co, value))
            co.scheduled = True

    def spawn (self, fun, *args, **kwargs):
        cdef coro co
        self.stack_index = (self.stack_index + 1) % self.nstacks
        co = coro (self.stacks[self.stack_index], fun, args, kwargs)
        self.scheduled.append (coval (co, None))
        co.scheduled = True
        return co

    def _yield (self):
        # a.k.a. yield_and_schedule()
        self._schedule (self._current, None)
        self._current._yield()

    def run (self):
        cdef list to_run = self.scheduled
        cdef coval item
        self.scheduled = []
        for item in to_run:
            item.co._resume (item.val)
        return len (self.scheduled) > 0

cdef public void _internal_yield "_yield" (coro co):
    co._yield()

spawn    = the_scheduler.spawn
_yield   = the_scheduler._yield
run      = the_scheduler.run
schedule = the_scheduler._schedule

def current():
    return the_scheduler._current

import sys

def traceback_string():
    # XXX do a better job
    #return '%r:%r:%r' % sys.exc_info()
    import asyncore
    return asyncore.compact_traceback()

cdef public void _wrap1 "_wrap1" (coro co):
    try:
        co.fun (*co.args, **co.kwargs)
    except:
        sys.stderr.write (
            'thread %d: error %s\n' % (
                co.id, traceback_string()
                )
            )
    co._die()
