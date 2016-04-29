# KAB - Kdump Auto-bisect

KAB is an automated git bisect tool to locate bad commit. It aims at debuging
kdump, but the framework itself is general enough to be easily adopted to
bisect other kernel projects.

Install KAB with command `make install`

Configure: you should provide mailbox, kernel source path, etc to KAB by edit
variables in the head of kab-lib.sh.

To start auto-bisect, run `kab.sh <good-commit> <bad-commit>` in kernel source
directory. KAB will then locate the first bad commit automatically. You will
receive a report email if success, if you provide mailbox in configuration. Or
you can check the log file in /boot to get information.

To stop the process manually, you should log in the system via level 1 (Single
User Mode) and disable the service called kdump-auto-bisect:

    systemctl disable kdump-auto-bisect
