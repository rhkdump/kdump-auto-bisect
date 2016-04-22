#!/bin/bash

# DO NOT execute this script manually!
. /home/freeman/project/kdump-auto-bisect/kab-lib.sh
# we don't care about 2nd kernel, just in case
kernel=`which_kernel`
if [ $kernel == 2 ]; then
	exit 0
fi

# only for the reboot after kernel installation
if [ -e "${KERNEL_SRC_PATH}/.kdump-auto-bisect.reboot" ]; then
	rm -f "${KERNEL_SRC_PATH}/.kdump-auto-bisect.reboot" && \
	trigger_pannic
	exit 0
fi

# only for the reboot after crash
cd $KERNEL_SRC_PATH

detect_good_bad
can_we_stop
ret=$?
if [ "$ret" == 1 ]; then
	success_report
    git bisect reset
	rm -f "${KERNEL_SRC_PATH}/.kdump-auto-bisect.undergo"
else
	kernel_compile_install
	do_test
fi
cd -
