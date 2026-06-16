/* PM-backed counting semaphores. */

#include "pm.h"
#include <minix/callnr.h>
#include <minix/semaphore.h>
#include <errno.h>
#include <string.h>
#include "mproc.h"

#define SEM_SLOT(id)	((id) - 1)

struct sem_queue {
	int proc[NR_PROCS];
	unsigned int head;
	unsigned int size;
};

struct pm_semaphore {
	int in_use;
	unsigned int value;
	struct sem_queue waiters;
};

static struct pm_semaphore sem_table[MINIX_SEM_MAX];

static int valid_id(int id)
{
	return id >= 1 && id <= MINIX_SEM_MAX;
}

static void queue_init(struct sem_queue *q)
{
	q->head = 0;
	q->size = 0;
}

static int queue_contains(const struct sem_queue *q, int proc_nr)
{
	unsigned int i;

	for (i = 0; i < q->size; i++) {
		unsigned int pos = (q->head + i) % NR_PROCS;

		if (q->proc[pos] == proc_nr)
			return TRUE;
	}

	return FALSE;
}

static int queue_push(struct sem_queue *q, int proc_nr)
{
	unsigned int pos;

	if (q->size >= NR_PROCS)
		return EAGAIN;
	if (queue_contains(q, proc_nr))
		return OK;

	pos = (q->head + q->size) % NR_PROCS;
	q->proc[pos] = proc_nr;
	q->size++;
	return OK;
}

static int queue_pop(struct sem_queue *q)
{
	int proc_nr;

	if (q->size == 0)
		return NONE;

	proc_nr = q->proc[q->head];
	q->head = (q->head + 1) % NR_PROCS;
	q->size--;

	if (q->size == 0)
		q->head = 0;

	return proc_nr;
}

static void queue_remove(struct sem_queue *q, int proc_nr)
{
	struct sem_queue next;
	unsigned int i;

	queue_init(&next);

	for (i = 0; i < q->size; i++) {
		unsigned int pos = (q->head + i) % NR_PROCS;

		if (q->proc[pos] != proc_nr)
			(void) queue_push(&next, q->proc[pos]);
	}

	*q = next;
}

static void wake_waiters(struct pm_semaphore *sem, int result)
{
	int proc_nr;

	while ((proc_nr = queue_pop(&sem->waiters)) != NONE) {
		mproc[proc_nr].mp_flags &= ~SEMAPHORE_BLOCKED;
		reply(proc_nr, result);
	}
}

int do_sem_create(void)
{
	int id = m_in.m_lc_pm_sem.id;
	unsigned int value = m_in.m_lc_pm_sem.value;
	struct pm_semaphore *sem;

	if (!valid_id(id))
		return EINVAL;
	if (value > MINIX_SEM_VALUE_MAX)
		return EINVAL;

	sem = &sem_table[SEM_SLOT(id)];
	if (sem->in_use)
		return EEXIST;

	memset(sem, 0, sizeof(*sem));
	sem->in_use = TRUE;
	sem->value = value;
	queue_init(&sem->waiters);

	return OK;
}

int do_sem_down(void)
{
	int id = m_in.m_lc_pm_sem.id;
	struct pm_semaphore *sem;
	int r;

	if (!valid_id(id))
		return EINVAL;

	sem = &sem_table[SEM_SLOT(id)];
	if (!sem->in_use)
		return EINVAL;

	if (sem->value > 0) {
		sem->value--;
		return OK;
	}

	r = queue_push(&sem->waiters, who_p);
	if (r != OK)
		return r;

	mp->mp_flags |= SEMAPHORE_BLOCKED;
	return SUSPEND;
}

int do_sem_up(void)
{
	int id = m_in.m_lc_pm_sem.id;
	struct pm_semaphore *sem;
	int proc_nr;

	if (!valid_id(id))
		return EINVAL;

	sem = &sem_table[SEM_SLOT(id)];
	if (!sem->in_use)
		return EINVAL;

	proc_nr = queue_pop(&sem->waiters);
	if (proc_nr != NONE) {
		mproc[proc_nr].mp_flags &= ~SEMAPHORE_BLOCKED;
		reply(proc_nr, OK);
		return OK;
	}

	if (sem->value == MINIX_SEM_VALUE_MAX)
		return EOVERFLOW;

	sem->value++;
	return OK;
}

int do_sem_destroy(void)
{
	int id = m_in.m_lc_pm_sem.id;
	struct pm_semaphore *sem;

	if (!valid_id(id))
		return EINVAL;

	sem = &sem_table[SEM_SLOT(id)];
	if (!sem->in_use)
		return EINVAL;

	wake_waiters(sem, EIDRM);
	memset(sem, 0, sizeof(*sem));

	return OK;
}

void sem_cleanup_proc(struct mproc *rmp)
{
	int proc_nr = (int)(rmp - mproc);
	unsigned int i;

	for (i = 0; i < MINIX_SEM_MAX; i++) {
		if (sem_table[i].in_use)
			queue_remove(&sem_table[i].waiters, proc_nr);
	}

	rmp->mp_flags &= ~SEMAPHORE_BLOCKED;
}

void sem_cancel_proc(struct mproc *rmp)
{
	int proc_nr = (int)(rmp - mproc);
	unsigned int i;

	if (!(rmp->mp_flags & SEMAPHORE_BLOCKED))
		return;

	for (i = 0; i < MINIX_SEM_MAX; i++) {
		if (sem_table[i].in_use)
			queue_remove(&sem_table[i].waiters, proc_nr);
	}

	rmp->mp_flags &= ~SEMAPHORE_BLOCKED;
	reply(proc_nr, EINTR);
}
