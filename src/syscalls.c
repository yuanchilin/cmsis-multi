/*
 * Minimal syscall stubs for ARM Cortex-M3 bare-metal
 * Provides stubs for newlib syscalls to avoid linker errors.
 *
 * picolibc (Clang/LLVM) provides its own syscall stubs,
 * so these are only needed for newlib (GCC).
 */
#if !defined(__clang__)
#include <sys/stat.h>

void _exit(int status) {
    while (1) { }
}

int _close(int file) {
    return -1;
}

int _fstat(int file, struct stat *st) {
    st->st_mode = S_IFCHR;
    return 0;
}

int _isatty(int file) {
    return 1;
}

int _lseek(int file, int ptr, int dir) {
    return 0;
}

int _read(int file, char *ptr, int len) {
    return 0;
}

caddr_t _sbrk(int incr) {
    extern char end asm("end");
    static char *heap_end = &end;
    char *prev_heap_end = heap_end;
    heap_end += incr;
    return (caddr_t) prev_heap_end;
}

int _write(int file, char *ptr, int len) {
    return len;
}
#endif
