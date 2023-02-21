# KAB - Kernel Auto-bisect

KAB is an automated git bisect tool to locate bad commit. It aims at debugging
kernel.

## Installation
Clone this repository and install KAB with command `make install`

## Configuration
One should provide mailbox, kernel source path, etc to KAB by edit variables in
/etc/kernel-auto-bisect.conf. esmtp should be configured properly if you want to
receive report via email. An esmtprc template is available in KAB's directory.

## Bisect
To start auto-bisect, run `kab.sh <good-commit> <bad-commit>` in kernel source
directory. KAB will then locate the first bad commit automatically. You will
receive a report email if success, if you provide mailbox in configuration. You
can check also the log file on the local machine or a remote machine, if you
configured, to get information.

## How to stop
After this script find the first bad commit, it will stop automatically.

To stop the process manually, you should log in the system via level 1 (Single
User Mode) and disable the service called kernel-auto-bisect:

    systemctl disable kernel-auto-bisect

## Want to get your hands dirty
There is no such thing as an automated debugger. Debugging involves human
engagement. Although KAB is designed for most cases, you may want to get your
hands wet to customize KAB to suit your specific conditions. 

You may want to modify 'kernel_compile_install' in kab-lib.sh if common
compilation and installation precede cannot satisfy your amazing systems.

Credit for initial scripts from:
Zhengyu Zhang <freeman.zhang1992@gmail.com>
