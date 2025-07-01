#ifndef CETHREAD_H
#define CETHREAD_H

#include <stdatomic.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef STACK_SIZE
#define STACK_SIZE (1024 * 1024)  // 1MiB
#endif // STACK_SIZE

typedef struct {
  void *(*start_routine)(void *);
  void *arg;
  void *retval;
} thread_arg_t;

typedef struct {
  pid_t tid;                 // id thread
  void *stack;               // pointer to stack
  thread_arg_t *thread_arg;  // argument
} CEthread_t;

typedef struct {
  atomic_flag flag;
} CEmutex_t;

// Context from Function src/lib/cethread.c
int CEthread_create(CEthread_t *thread, void *(*start_routine)(void *),
                    void *arg);
int CEthread_join(CEthread_t thread, void **retval);
void CEthread_end(void *retval);

int CEmutex_init(CEmutex_t *mutex);
int CEmutex_destroy(CEmutex_t *mutex);
int CEmutex_lock(CEmutex_t *mutex);
int CEmutex_unlock(CEmutex_t *mutex);

#endif  // CETHREAD_H
