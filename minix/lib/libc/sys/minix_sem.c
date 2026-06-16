#include <sys/cdefs.h>
#include "namespace.h"

#include <minix/callnr.h>
#include <minix/semaphore.h>
#include <lib.h>
#include <string.h>

static int
sem_call(int call, int id, unsigned int value)
{
	message m;

	memset(&m, 0, sizeof(m));
	m.m_lc_pm_sem.id = id;
	m.m_lc_pm_sem.value = value;

	return _syscall(PM_PROC_NR, call, &m);
}

int
minix_sem_create(int id, unsigned int value)
{
	return sem_call(PM_SEM_CREATE, id, value);
}

int
minix_sem_down(int id)
{
	return sem_call(PM_SEM_DOWN, id, 0);
}

int
minix_sem_up(int id)
{
	return sem_call(PM_SEM_UP, id, 0);
}

int
minix_sem_destroy(int id)
{
	return sem_call(PM_SEM_DESTROY, id, 0);
}
