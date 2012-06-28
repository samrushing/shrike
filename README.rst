Shrike
======

Shrike implements cooperative threading for Python_.  It uses
techniques similar to POSIX's deprecated ucontext_ (3) routines.  [That
means it uses a bit of assembly magic to swap between two CPU
contexts].

Note
----

Shrike as a project was obsoleted by the open-sourcing of Shrapnel.
Please see https://github.com/ironport/shrapnel/


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

Note: Since Shrapnel_ was open-sourced in late 2011, this project will suffer
one of three fates:

  1) new features merged into shrapnel
  2) discarded
  3) act as a compatible, conservative, minimalist implementation of the shrapnel/coro API.

I'm leaning toward #3 myself, but as usual free time and requirements will affect the outcome.
One possible advantage that shrike may have over shrapnel: it may very well run on Windows,
if a select()-based poller is written.

[XXX put a history here of egroups-coro, stackless, minstack, shrapnel]

.. _Cython: http://cython.org/
.. _Python: http://www.python.org/
.. _ucontext: http://pubs.opengroup.org/onlinepubs/7908799/xsh/ucontext.h.html
.. _Shrapnel: http://github.com/ironport/shrapnel/
