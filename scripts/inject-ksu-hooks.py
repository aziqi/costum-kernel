#!/usr/bin/env python3
"""Deterministic manual-hook injection for KernelSU-Next (non-GKI, kernel 4.4).

Run from the kernel source root (e.g. kernel_a9). Injects the four manual hooks
that KernelSU-Next legacy branch's Kbuild requires: it hard-errors unless
`ksu_handle_sys_reboot` is present in kernel/reboot.c, so all hooks must be present.

Target API (KernelSU-Next legacy branch):
  fs/exec.c      -> ksu_handle_execveat_sucompat(fd, filename_ptr, argv, envp, flags)
  fs/open.c      -> ksu_handle_faccessat(dfd, filename_user, mode, flags)
  fs/stat.c      -> ksu_handle_stat(dfd, filename_user, flags)
  kernel/reboot.c -> ksu_handle_sys_reboot(magic1, magic2, cmd, arg)

Anchors are stable for the 4.4 CAF tree. If an anchor is missing the script
aborts instead of producing a silently broken kernel.
"""
import os
import sys

ROOT = os.getcwd()


def p(rel):
    return os.path.join(ROOT, rel)


# --- fs/exec.c ---
EXEC_EXTERN = (
    "#ifdef CONFIG_KSU\n"
    "__attribute__((hot))\n"
    "extern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr,\n"
    "\t\t\t\t void *argv, void *envp, int *flags);\n"
    "#endif\n\n"
)
EXEC_CALL = (
    "#ifdef CONFIG_KSU\n"
    "\tksu_handle_execveat_sucompat((int *)AT_FDCWD, &filename, &argv, &envp, 0);\n"
    "#endif\n"
)

# --- fs/open.c ---
OPEN_EXTERN = (
    "#ifdef CONFIG_KSU\n"
    "__attribute__((hot))\n"
    "extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user,\n"
    "\t\t\t\tint *mode, int *flags);\n"
    "#endif\n\n"
)
OPEN_CALL = (
    "#ifdef CONFIG_KSU\n"
    "\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n"
    "#endif\n"
)

# --- fs/stat.c ---
STAT_EXTERN = (
    "#ifdef CONFIG_KSU\n"
    "__attribute__((hot))\n"
    "extern int ksu_handle_stat(int *dfd, const char __user **filename_user,\n"
    "\t\t\t\tint *flags);\n"
    "#endif\n\n"
)
STAT_CALL = (
    "#ifdef CONFIG_KSU\n"
    "\tksu_handle_stat(&dfd, &filename, &flag);\n"
    "#endif\n"
)

# --- kernel/reboot.c ---
REBOOT_EXTERN = (
    "#ifdef CONFIG_KSU\n"
    "extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);\n"
    "#endif\n\n"
)
REBOOT_CALL = (
    "#ifdef CONFIG_KSU\n"
    "\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);\n"
    "#endif\n"
)


def read(rel):
    with open(p(rel), "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


def write(rel, s):
    with open(p(rel), "w", encoding="utf-8") as f:
        f.write(s)


def inject_call(rel, anchor, block, marker):
    if not os.path.exists(p(rel)):
        print("MISSING", rel)
        sys.exit(1)
    s = read(rel)
    if marker in s:
        print("SKIP (present):", rel)
        return
    if anchor not in s:
        print("ANCHOR NOT FOUND in", rel, "->", repr(anchor))
        sys.exit(1)
    write(rel, s.replace(anchor, block + anchor, 1))
    print("INJECTED call:", rel)


def inject_extern_before(rel, anchor, block, marker):
    s = read(rel)
    if marker in s.split(anchor, 1)[0]:
        print("SKIP extern (present):", rel)
        return
    if anchor not in s:
        print("ANCHOR NOT FOUND in", rel, "->", repr(anchor))
        sys.exit(1)
    write(rel, s.replace(anchor, block + anchor, 1))
    print("INJECTED extern:", rel)


def main():
    # --- fs/exec.c ---
    if "ksu_handle_execveat_sucompat(" not in read("fs/exec.c"):
        inject_extern_before("fs/exec.c", "int do_execve(struct filename",
                             EXEC_EXTERN, "ksu_handle_execveat_sucompat(")
        s = read("fs/exec.c")
        anchor = "return do_execveat_common(AT_FDCWD, filename, argv, envp, 0);"
        if anchor not in s:
            print("ANCHOR NOT FOUND fs/exec.c", repr(anchor))
            sys.exit(1)
        write("fs/exec.c", s.replace(anchor, EXEC_CALL + anchor))
        print("INJECTED call: fs/exec.c")
    else:
        print("SKIP (present): fs/exec.c")

    # --- fs/open.c ---
    inject_call("fs/open.c", "if (mode & ~S_IRWXO)", OPEN_CALL, "ksu_handle_faccessat(")
    inject_extern_before("fs/open.c", "SYSCALL_DEFINE3(faccessat",
                         OPEN_EXTERN, "ksu_handle_faccessat(")

    # --- fs/stat.c ---
    inject_call("fs/stat.c", "error = vfs_fstatat", STAT_CALL, "ksu_handle_stat(")
    inject_extern_before("fs/stat.c", "SYSCALL_DEFINE4(newfstatat",
                         STAT_EXTERN, "ksu_handle_stat(")

    # --- kernel/reboot.c ---
    inject_call("kernel/reboot.c",
                "/* We only trust the superuser with rebooting the system. */",
                REBOOT_CALL, "ksu_handle_sys_reboot(")
    inject_extern_before("kernel/reboot.c", "SYSCALL_DEFINE4(reboot",
                         REBOOT_EXTERN, "ksu_handle_sys_reboot(")

    print("All KernelSU-Next manual hooks injected.")


if __name__ == "__main__":
    main()
