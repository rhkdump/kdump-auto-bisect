#!/bin/bash

# DO NOT execute this script manually!
source /usr/bin/kab-lib.sh
LOG reboot complete
# we don't care about 2nd kernel, just in case
kernel=`which_kernel`
if [ $kernel == 2 ]; then
	LOG entering 2nd kernel
	exit 0
fi

LOG entering 1st kernel
echo world >> /home/freeman/project/kdump-auto-bisect/log.txt
# only for the reboot after kernel installation
if [ -e "/etc/.kdump-auto-bisect.reboot" ]; then
	LOG reboot-file detected
	rm -f "/etc/.kdump-auto-bisect.reboot" && \
	LOG reboot-file removed
	LOG triggering panic
	trigger_pannic
	exit 0
fi

# only for the reboot after crash
LOG reboot from crash
cd $KERNEL_SRC_PATH

LOG detecting good or bad
detect_good_bad
can_we_stop
ret=$?
if [ "$ret" == 1 ]; then
	LOG $success_string
	LOG stoping
	success_report
	LOG report sent
	rm -f "/etc/.kdump-auto-bisect.undergo"
	disable_service
	LOG stoped
else
	kernel_compile_install
	do_test
fi
cd -
