/* Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 * Scoped by the cbd/rild init services' LD_PRELOAD. Translate their legacy
 * auxiliary mount paths into the standard writable /mnt/vendor hierarchy.
 * No framework process loads this library; all other paths pass unchanged.
 */
#undef _FORTIFY_SOURCE
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/vfs.h>
#include <unistd.h>

static const char* translate(const char* path, char out[PATH_MAX]) {
    if (!path) return path;
    if ((strncmp(path, "/efs", 4) == 0 || strncmp(path, "/mnv", 4) == 0) &&
            (path[4] == '/' || path[4] == '\0')) {
        int n = snprintf(out, PATH_MAX, "/mnt/vendor%s", path);
        if (n < 0 || n >= PATH_MAX) { errno = ENAMETOOLONG; return NULL; }
        return out;
    }
    return path;
}

int open(const char* path, int flags, ...) {
    int (*real)(const char*, int, ...) = dlsym(RTLD_NEXT, "open");
    if (!real) { errno = ENOSYS; return -1; }
    mode_t mode = 0;
    if ((flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE) {
        va_list args; va_start(args, flags); mode = va_arg(args, int); va_end(args);
    }
    char buffer[PATH_MAX]; const char* mapped = translate(path, buffer);
    if (!mapped) { if (!path) errno = EFAULT; return -1; }
    return real(mapped, flags, mode);
}
int __open_2(const char* path, int flags) {
    // The fortified entry never supplies a mode argument.
    if ((flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE) {
        errno = EINVAL; return -1;
    }
    return open(path, flags);
}
FILE* fopen(const char* path, const char* mode) {
    FILE* (*real)(const char*, const char*) = dlsym(RTLD_NEXT, "fopen");
    if (!real) { errno = ENOSYS; return NULL; }
    char buffer[PATH_MAX]; const char* mapped = translate(path, buffer);
    if (!mapped) { if (!path) errno = EFAULT; return NULL; }
    return real(mapped, mode);
}
#define PATH_CALL(name, decl, call) \
int name decl { \
    int (*real) decl = dlsym(RTLD_NEXT, #name); \
    if (!real) { errno = ENOSYS; return -1; } \
    char buffer[PATH_MAX]; const char* mapped = translate(path, buffer); \
    if (!mapped) { if (!path) errno = EFAULT; return -1; } \
    return real call; \
}
PATH_CALL(access, (const char* path, int mode), (mapped, mode))
PATH_CALL(chmod, (const char* path, mode_t mode), (mapped, mode))
PATH_CALL(chown, (const char* path, uid_t uid, gid_t gid), (mapped, uid, gid))
PATH_CALL(mkdir, (const char* path, mode_t mode), (mapped, mode))
PATH_CALL(unlink, (const char* path), (mapped))
PATH_CALL(statfs, (const char* path, struct statfs* info), (mapped, info))
