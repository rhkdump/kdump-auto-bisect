#!/bin/bash

# DO NOT execute this script manually!
source /usr/bin/kab-lib.sh
check_config
LOG reboot complete
# we don't care about 2nd kernel, just in case
kernel=$(which_kernel)
if [ $kernel == 2 ]; then
	LOG entering 2nd kernel
	exit 0
fi

LOG entering 1st kernel
# only for the reboot after kernel installation
if [ -e "/boot/.kdump-auto-bisect.reboot" ]; then
	LOG reboot-file detected
	rm -f "/boot/.kdump-auto-bisect.reboot"
	sync
	LOG reboot-file removed
	LOG triggering panic
	sync
	if [[ $INSTALL_KERNEL_BY == compile ]]; then
		cd $KERNEL_SRC_PATH
		if [[ $(uname -r) != $(make kernelrelease) ]]; then
			reboot
		fi
	fi

	trigger_pannic
	exit 0
fi

# only for the reboot after crash
LOG reboot from crash
cd $KERNEL_SRC_PATH
LOG now in $KERNEL_SRC_PATH

LOG detecting good or bad
detect_good_bad
can_we_stop
ret=$?
if [ "$ret" == 1 ]; then
	LOG $success_string
	LOG stoping
	success_report
	LOG report sent
	rm -f "/boot/.kdump-auto-bisect.undergo"
	disable_service
	LOG stoped
else
	if [[ $INSTALL_KERNEL_BY == compile ]]; then
		kernel_compile_install
	elif [[ $INSTALL_KERNEL_BY == rpm ]]; then
		install_kernel_rpm
	fi
	do_test
fi
cd -
