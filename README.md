# KAB - Kernel Auto-bisect

KAB is an automated git bisect tool to locate the first bad commit or kernel version. It aims at bisecting kernel issues.

## Quick start


### Source bisecting

Take [2123230 – kdump cannot save core file when boot system with "nr_cpus=2"](https://bugzilla.redhat.com/show_bug.cgi?id=2123230) as an example, the initial good and bad commits are d2c104a3426be9991b35c65f0f260a107c4b2942 and v5.4-rc1 respectively.

1. Clone this repository and install KAB with command `make install`
2. Edit /etc/kernel-auto-bsiect.conf
```
BISECT_WHAT=SOURCE
KERNEL_SRC_REPO https://github.com/torvalds/linux.git
REPRODUCER /root/kdump-reproducer.sh

# Bisect kdump kernel issues
BISECT_KDUMP YES
```
3. Provide a reproducer
```sh
#!/bin/bash
#/root/kdump-reproducer.sh
before_bisect() {
    rm -rf /var/crash/*
}

on_test() {
        if [ $(ls /var/crash | wc -l) -ne 0 ]; then
                rm -rf /var/crash/*
                return 0
        else
                return 1
        fi
}
```
4. Start KAB,
```sh
$ kab.sh d2c104a3426be9991b35c65f0f260a107c4b2942 v5.4-rc1
```
5. Check /boot/.kernel-auto-bisect.log to find out the first bad commit
```
Feb 22 03:56:00 - starting kab
Feb 22 03:56:05 - bisect restarting
Feb 22 03:56:05 - good at d2c104a3426be9991b35c65f0f260a107c4b2942
Feb 22 03:56:05 - bad at v5.4-rc1
Feb 22 03:56:07 - building kernel: 8b53c76533aa
Feb 22 04:02:41 - kernel building complete
Feb 22 04:02:42 - kab service enabled
Feb 22 04:02:42 - rebooting
Feb 22 04:02:59 - reboot complete
Feb 22 04:03:00 - triggering panic
Feb 22 04:03:08 - reboot complete
Feb 22 04:03:08 - detecting good or bad
Feb 22 04:03:09 - bad
...
Feb 22 05:22:11 - 43931d350f30c6cd8c2f498d54ef7d65750abc92 is the first bad commit
Feb 22 05:22:11 - report sent
Feb 22 05:22:11 - kab service disabled
Feb 22 05:22:11 - stopped
```
### Version bisecting

You can also bisect built kernel packages by specifying `BISECT_WAHT` and `DISTRIBUTION` in /etc/kernel-auto-bsiect.conf,
```
BISECT_WHAT VERSION
DISTRIBUTION RHEL9
REPRODUCER /root/reproduce.sh
```

Then start KAB with the initial good and bad versions,
```
$ kab.sh 5.14.0-162.el9.x86_64 5.14.0-241.el9.x86_64
```

## FAQ

### How to receive report via email?

esmtp should be configured properly if you want to receive report via email. An esmtprc template is available in KAB's repo.


### How to stop KAB?
After this script find the first bad commit, it will stop automatically.

To stop the process manually, you should log in the system and disable the service called kernel-auto-bisect:

    systemctl disable kernel-auto-bisect

### Why only building kernel drivers that are in-use or included in initramfs?

This is because it is much faster than `make oldconfig`. Taking [2123230 – kdump cannot save core file when boot system with "nr_cpus=2"](https://bugzilla.redhat.com/show_bug.cgi?id=2123230) as an example, the bisecting took 3 hours to finish while `make oldconfig` took 23 hours.


Credit for initial scripts from:
Zhengyu Zhang <freeman.zhang1992@gmail.com>
