# KAB - Kdump Auto-bisect

KAB is an automated git bisect tool to locate bad commit. It aims at debuging
kdump, but the framework itself is general enough to be easily adopted to
bisect other kernel projects.

## Preparation
You need a stable computer system with kdump operational and install wget if
you choose to bisect kernel RPMs.

## Installation
Clone this repository and install KAB with command `make install`

## Configuration
One should provide mailbox, kernel source path, etc to KAB by edit variables in
/etc/kdump-auto-bisect.conf. esmtp should be configured properly if you want to
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
User Mode) and disable the service called kdump-auto-bisect:

    systemctl disable kdump-auto-bisect

## Want to get your hands wet
There is no such thing as an automated debugger. Debuging involves human
engagement. Alhough KAB is designed for most cases, you may want to get your
hands wet to customize KAB to suit your specific conditions. 

You may want to modify 'kernel_compile_install' in kab-lib.sh if common
compilation and installation precedure cannot satisfy your amazing systems.

You may want to modify 'detect_good_bad' in kab-lib.sh if the existence of
/var/crash/ is not your standard to judge good commits or bad ones.

Credit for initial scripts from:
Zhengyu Zhang <freeman.zhang1992@gmail.com>
