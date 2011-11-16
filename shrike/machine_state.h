// -*- Mode: C -*-

#if defined (__i386__)

typedef struct {
  void * stack;
  void * frame;
  void * insn;
  void * ebx;
  void * esi;
  void * edi;
} machine_state;

#define STACK_PAD (3 * sizeof (void *))

#elif defined (__x86_64__)

typedef struct {
  void * stack;
  void * frame;
  void * insn;
  void * rbx;
  void * r12;
  void * r13;
  void * r14;
  void * r15;
} machine_state;

// "In other words, the value (%rsp + 8) is always
//  a multiple of 16 when control is transferred to the function
//  entry point"

#define STACK_PAD (1 * sizeof (void *))

#else
#error machine state not defined for this architecture
#endif
