#!/bin/bash

# DO NOT execute this script manually!
source /usr/bin/kab-lib.sh
check_config
LOG reboot complete

safe_cd "$KERNEL_SRC_PATH"

if [[ -e /boot/.kdump-auto-bisect.reboot ]]; then
	set_switch_status
	rm -f /boot/.kdump-auto-bisect.reboot
	# For kdump issue, need to trigger kernel crash
	panic_for_kdump
fi

LOG detecting good or bad
detect_good_bad
if can_we_stop; then
	LOG "$success_string"
	LOG stoping
	success_report
	LOG report sent
	rm -f "/boot/.kdump-auto-bisect.undergo"
	call_func after_bisect
	disable_service
	LOG stoped
else
	install_kernel
	do_test
fi
