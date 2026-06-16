/* test 95 - PM-backed MINIX semaphores */

#include <sys/types.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <errno.h>
#include <minix/semaphore.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>

int max_error = 0;
#include "common.h"

#define TEST_SEM_BASIC		1
#define TEST_SEM_FIFO		2
#define TEST_SEM_DESTROY	3
#define TEST_SEM_EINTR		4

static volatile sig_atomic_t got_signal;

static void
kill_child(pid_t pid)
{
	int status;

	if (pid > 0) {
		(void) kill(pid, SIGKILL);
		(void) waitpid(pid, &status, 0);
	}
}

static int
wait_child_timeout(pid_t pid, int *status, unsigned int seconds)
{
	unsigned int i;
	pid_t r;

	for (i = 0; i < seconds; i++) {
		do {
			r = waitpid(pid, status, WNOHANG);
		} while (r < 0 && errno == EINTR);
		if (r == pid)
			return 1;
		if (r < 0)
			return 0;
		sleep(1);
	}

	do {
		r = waitpid(pid, status, WNOHANG);
	} while (r < 0 && errno == EINTR);

	return r == pid;
}

static int
read_byte_timeout(int fd, char *byte, unsigned int seconds, int errn)
{
	fd_set readfds;
	struct timeval timeout;
	int r;

	FD_ZERO(&readfds);
	FD_SET(fd, &readfds);
	timeout.tv_sec = seconds;
	timeout.tv_usec = 0;

	r = select(fd + 1, &readfds, NULL, NULL, &timeout);
	if (r < 0)
		e(errn);
	if (r == 0)
		return 0;
	if (read(fd, byte, 1) != 1)
		e(errn);

	return 1;
}

static void
expect_exit_ok(pid_t pid, unsigned int seconds, int errn)
{
	int status;

	if (!wait_child_timeout(pid, &status, seconds)) {
		kill_child(pid);
		e(errn);
	}
	if (status != 0)
		e(errn);
}

static void
expect_ok(int r, int errn)
{
	if (r != 0)
		e(errn);
}

static void
expect_fail_errno(int r, int expected_errno, int errn)
{
	if (r != -1 || errno != expected_errno)
		e(errn);
}

static void
child_waiter(int semid, int gate_fd, int ready_fd, int acquired_fd, char mark)
{
	char gate;

	if (read(gate_fd, &gate, 1) != 1)
		exit(9);
	if (write(ready_fd, &mark, 1) != 1)
		exit(10);
	if (minix_sem_down(semid) != 0)
		exit(11);
	if (write(acquired_fd, &mark, 1) != 1)
		exit(12);
	exit(0);
}

static void
test_basic(void)
{
	int semid;

	subtest = 1;
	semid = TEST_SEM_BASIC;
	(void) minix_sem_destroy(semid);

	expect_ok(minix_sem_create(semid, 1), 1);
	expect_fail_errno(minix_sem_create(semid, 1), EEXIST, 2);
	expect_ok(minix_sem_down(semid), 3);
	expect_ok(minix_sem_up(semid), 4);
	expect_ok(minix_sem_destroy(semid), 5);
	expect_fail_errno(minix_sem_down(semid), EINVAL, 6);
}

static void
test_fifo_blocking(void)
{
	int semid, gate[2], ready[2], acquired[2];
	pid_t first, second;
	char buf[2], mark;

	subtest = 2;
	semid = TEST_SEM_FIFO;
	(void) minix_sem_destroy(semid);
	expect_ok(minix_sem_create(semid, 0), 10);

	if (pipe(gate) != 0 || pipe(ready) != 0 || pipe(acquired) != 0)
		e(11);

	first = fork();
	if (first == 0)
		child_waiter(semid, gate[0], ready[1], acquired[1], '1');
	if (first < 0)
		e(12);

	mark = 'g';
	if (write(gate[1], &mark, 1) != 1)
		e(13);
	if (!read_byte_timeout(ready[0], buf, 5, 14)) {
		kill_child(first);
		e(14);
	}
	if (read_byte_timeout(acquired[0], buf, 1, 15)) {
		kill_child(first);
		e(15);
	}

	second = fork();
	if (second == 0)
		child_waiter(semid, gate[0], ready[1], acquired[1], '2');
	if (second < 0) {
		kill_child(first);
		e(16);
	}

	if (write(gate[1], &mark, 1) != 1)
		e(17);
	if (!read_byte_timeout(ready[0], buf + 1, 5, 18)) {
		kill_child(first);
		kill_child(second);
		e(18);
	}
	if (read_byte_timeout(acquired[0], buf, 1, 19)) {
		kill_child(first);
		kill_child(second);
		e(19);
	}

	if (buf[0] != '1' || buf[1] != '2') {
		kill_child(first);
		kill_child(second);
		e(20);
	}

	expect_ok(minix_sem_up(semid), 21);
	if (!read_byte_timeout(acquired[0], buf, 5, 22)) {
		kill_child(first);
		kill_child(second);
		e(22);
	}
	if (buf[0] != '1') {
		kill_child(first);
		kill_child(second);
		e(23);
	}

	expect_ok(minix_sem_up(semid), 24);
	if (!read_byte_timeout(acquired[0], buf, 5, 25)) {
		kill_child(first);
		kill_child(second);
		e(25);
	}
	if (buf[0] != '2') {
		kill_child(first);
		kill_child(second);
		e(26);
	}

	expect_exit_ok(first, 5, 27);
	expect_exit_ok(second, 5, 28);

	expect_ok(minix_sem_destroy(semid), 29);
	close(gate[0]);
	close(gate[1]);
	close(ready[0]);
	close(ready[1]);
	close(acquired[0]);
	close(acquired[1]);
}

static void
destroy_waiter(int semid, int ready_fd)
{
	char mark;

	mark = 'r';
	if (write(ready_fd, &mark, 1) != 1)
		exit(20);

	if (minix_sem_down(semid) != -1 || errno != EIDRM)
		exit(21);

	exit(0);
}

static void
test_destroy_wakes_waiter(void)
{
	int semid, ready[2];
	pid_t child;
	char mark;
	int status;

	subtest = 3;
	semid = TEST_SEM_DESTROY;
	(void) minix_sem_destroy(semid);
	expect_ok(minix_sem_create(semid, 0), 30);

	if (pipe(ready) != 0)
		e(31);

	child = fork();
	if (child == 0)
		destroy_waiter(semid, ready[1]);
	if (child < 0)
		e(32);

	if (!read_byte_timeout(ready[0], &mark, 5, 33)) {
		kill_child(child);
		e(33);
	}
	if (mark != 'r')
		e(34);

	if (wait_child_timeout(child, &status, 2))
		e(35);

	expect_ok(minix_sem_destroy(semid), 36);
	if (!wait_child_timeout(child, &status, 5)) {
		kill_child(child);
		e(37);
	}
	if (status != 0)
		e(38);

	close(ready[0]);
	close(ready[1]);
}

static void
signal_handler(int signo)
{
	got_signal = signo;
}

static void
eintr_waiter(int semid, int ready_fd)
{
	char mark;
	struct sigaction sa;

	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = signal_handler;
	if (sigemptyset(&sa.sa_mask) != 0 || sigaction(SIGUSR1, &sa, NULL) != 0)
		exit(40);

	mark = 'r';
	if (write(ready_fd, &mark, 1) != 1)
		exit(41);

	if (minix_sem_down(semid) != -1 || errno != EINTR)
		exit(42);
	if (got_signal != SIGUSR1)
		exit(43);

	exit(0);
}

static void
test_signal_interrupts_waiter(void)
{
	int semid, ready[2];
	pid_t child;
	char mark;
	int status;
	unsigned int i;

	subtest = 4;
	semid = TEST_SEM_EINTR;
	(void) minix_sem_destroy(semid);
	expect_ok(minix_sem_create(semid, 0), 40);

	if (pipe(ready) != 0)
		e(41);

	child = fork();
	if (child == 0)
		eintr_waiter(semid, ready[1]);
	if (child < 0)
		e(42);

	if (!read_byte_timeout(ready[0], &mark, 5, 43)) {
		kill_child(child);
		e(43);
	}
	if (mark != 'r')
		e(44);

	for (i = 0; i < 10; i++) {
		if (kill(child, SIGUSR1) != 0) {
			if (wait_child_timeout(child, &status, 0))
				break;
			e(45);
		}
		if (wait_child_timeout(child, &status, 1))
			break;
	}
	if (i == 10) {
		kill_child(child);
		e(46);
	}
	if (status != 0)
		e(47);

	expect_ok(minix_sem_destroy(semid), 48);
	close(ready[0]);
	close(ready[1]);
}

int
main(int argc, char *argv[])
{
	int mask;

	mask = 0xFFFF;
	start(95);
	if (argc == 2)
		mask = atoi(argv[1]);

	if (mask & 0001)
		test_basic();
	if (mask & 0002)
		test_fifo_blocking();
	if (mask & 0004)
		test_destroy_wakes_waiter();
	if (mask & 0010)
		test_signal_interrupts_waiter();

	quit();
	return -1;
}
