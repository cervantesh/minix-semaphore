#ifndef _MINIX_SEMAPHORE_H
#define _MINIX_SEMAPHORE_H

#include <sys/cdefs.h>

#define MINIX_SEM_MAX		64
#define MINIX_SEM_VALUE_MAX	32767U

__BEGIN_DECLS
int minix_sem_create(int id, unsigned int value);
int minix_sem_down(int id);
int minix_sem_up(int id);
int minix_sem_destroy(int id);
__END_DECLS

#endif /* _MINIX_SEMAPHORE_H */
