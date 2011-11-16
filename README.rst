
Shrike
======

Shrike implements cooperative threading for CPython.  It uses
techniques similar to POSIX's deprecated ucontext(3) routines.

Design
------

The main technical difference between this and other user-threading
libraries is that it uses two stacks: one stack is the normal C stack,
where the scheduler runs.  The other stack is used exclusively for
user threads.  When a thread yields back to the scheduler, the
scheduler will preserve the live part of its stack in the heap.  Just
before the thread is resumed, that slice is replaced onto the
user-thread stack.  Combined with other techniques, it becomes
possible to scale to millions of threads.

Implementation
--------------

Shrike is written in Cython_, and when combined with a scalable
event-driven kernel interface like kqueue(), enables the construction
of high-performance network servers that don't fall down when hit with
a few hundred connections.

History
-------

[XXX put a history here of egroups-coro, stackless, minstack, shrapnel]

.. _Cython: http://cython.org/
