#!/bin/bash
# Manual fallback script to apply KSU non-kprobe hooks on kernel 4.4
# Run this inside the kernel source root if integrate-no-kprobe.py fails.

echo "Applying manual hooks to fs/exec.c..."
sed -i '/static int do_execveat_common(/i #ifdef CONFIG_KSU\nextern bool ksu_execveat_hook __read_mostly;\nextern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);\nextern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);\n#endif\n' fs/exec.c

sed -i '/static int do_execveat_common(/,/return __do_execve_file/ s/return __do_execve_file/#ifdef CONFIG_KSU\n\tif (unlikely(ksu_execveat_hook))\n\t\tksu_handle_execveat(\&fd, \&filename, \&argv, \&envp, \&flags);\n\telse\n\t\tksu_handle_execveat_sucompat(\&fd, \&filename, \&argv, \&envp, \&flags);\n#endif\n\treturn __do_execve_file/' fs/exec.c

echo "Applying manual hooks to fs/open.c..."
sed -i '/long do_sys_open(/,/fd = get_unused_fd_flags/ s/fd = get_unused_fd_flags/#ifdef CONFIG_KSU\n\textern int ksu_handle_sys_open(struct filename *name, int *flags);\n\tksu_handle_sys_open(tmp, \&flags);\n#endif\n\tfd = get_unused_fd_flags/' fs/open.c

echo "Applying manual hooks to fs/read_write.c..."
sed -i '/ssize_t vfs_read(/,/if (file->f_op->read)/ s/if (file->f_op->read)/#ifdef CONFIG_KSU\n\textern int ksu_handle_vfs_read(struct file **file_ptr, char __user **buf_ptr, size_t *count_ptr, loff_t **pos);\n\tksu_handle_vfs_read(\&file, \&buf, \&count, \&pos);\n#endif\n\tif (file->f_op->read)/' fs/read_write.c

echo "Applying manual hooks to fs/stat.c..."
sed -i '/int vfs_fstatat(/,/if ((flag \&/ s/if ((flag \&/#ifdef CONFIG_KSU\n\textern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n\tksu_handle_stat(\&dfd, \&filename, \&flag);\n#endif\n\tif ((flag \&/' fs/stat.c

echo "Manual hooks applied successfully."
