// -*- Mode: C -*-

#include <stdint.h>
#include "machine_state.h"

//
// swap() is a hand-rolled version of the POSIX 'swapcontext()'function.
// these ucontext routines have been deprecated, and are thus now
//   officially neglected stepchildren in various unix-based OS's.
//
// On FreeBSD, the ucontext api has been made an expensive syscall for some reason.
// On Darwin, the API is deprecated and spits out a warning when you use it.
// On Linux, <try this out on linux>
//

// rather than try to include a bunch of #ifdef magic here to figure out whether
// this platform requires a leading underscore on symbols, just define both labels.

int __swap (machine_state * to_state, machine_state * from_state);

#if defined (__i386__)

__asm__ (
"	.globl __swap\n"
"	.globl ___swap\n"
"__swap:\n"
"___swap:\n"
"	.align	4, 0x90\n"
"	movl 8(%esp), %edx  \n"  // save from_state
"	movl %esp, 0(%edx)  \n"
"	movl %ebp, 4(%edx)  \n"
"	movl (%esp), %eax   \n"
"	movl %eax, 8(%edx)  \n"
"       movl %ebx, 12(%edx) \n"
"       movl %esi, 16(%edx) \n"
"       movl %edi, 20(%edx) \n"
"	movl 4(%esp), %edx  \n" // restore to_state
"       movl 20(%edx), %edi \n"
"       movl 16(%edx), %esi \n"
"       movl 12(%edx), %ebx \n"
"	movl 4(%edx), %ebp  \n"
"	movl 0(%edx), %esp  \n"
"       movl 8(%edx), %eax  \n"
"       movl %eax, (%esp)   \n"
"	ret                 \n" // return to other coro
);

#elif defined (__x86_64__)

// http://en.wikipedia.org/wiki/X86_calling_conventions#x86-64_calling_conventions
// http://x86-64.org/documentation/abi.pdf  [page 15]
// args: rdi, rsi, rdx, rcx, r8, r9, xmm0-7
// saved: rbp, rbx, r12-r15
// we don't bother with floating-point registers; so don't try doing a 
//  context switch in the middle of a floating-point calculation!

__asm__ (
"	.globl	__swap\n"
"	.globl	___swap\n"
"	.align	4, 0x90\n"
"__swap:\n"
"___swap:\n"
"	movq %rsp, 0(%rsi)   \n" // save from_state
"	movq %rbp, 8(%rsi)   \n"
"	movq (%rsp), %rax    \n"
"	movq %rax, 16(%rsi)  \n"
"	movq %rbx, 24(%rsi)  \n"
"	movq %r12, 32(%rsi)  \n"
"	movq %r13, 40(%rsi)  \n"
"	movq %r14, 48(%rsi)  \n"
"	movq %r15, 56(%rsi)  \n"
"	movq 56(%rdi), %r15  \n" // restore to_state
"	movq 48(%rdi), %r14  \n"
"	movq 40(%rdi), %r13  \n"
"	movq 32(%rdi), %r12  \n"
"	movq 24(%rdi), %rbx  \n"
"	movq 8(%rdi), %rbp   \n"
"	movq 0(%rdi), %rsp   \n"
"	movq 16(%rdi), %rax  \n"
"	movq %rax, (%rsp)    \n"
"	ret                  \n" // return to other coro
);

#else
#error machine state not defined for this architecture
#endif

extern void _wrap1 (void * co);
extern void * _yield (void * co);

#ifdef __x86_64__
void
_wrap0 (void * co)
{
  // x86_64 expects <co> to be in a register.  But it's actually on the stack,
  //   because we pushed it there.
  // llvm does the prologue differently...
#ifdef __llvm__
  __asm__ ("movq 16(%%rbp), %[co]" : [co] "=r" (co));
#else
  __asm__ ("movq 8(%%rbp), %[co]" : [co] "=r" (co));
#endif
  _wrap1 (co);
  _yield (co);
}

#else
void
_wrap0 (void * co)
{
  _wrap1 (co);
  _yield (co);
}
#endif
