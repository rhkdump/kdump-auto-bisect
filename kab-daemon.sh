#!/bin/bash

# DO NOT execute this script manually!
source /usr/bin/kab-lib.sh
check_config
LOG reboot complete

safe_cd "$KERNEL_SRC_PATH"

if did_we_try_reboot; then
	clean_try_reboot_indicator
	set_reboot_status
	# For kdump issue, need to trigger kernel crash
	try_panic_kernel
fi

LOG detecting good or bad
detect_good_bad
if can_we_stop; then
	LOG "$success_string"
	success_report
	LOG report sent
	rm -f "/boot/.kernel-auto-bisect.undergo"
	call_func after_bisect
	disable_service
	LOG stopped
else
	install_kernel
	try_reboot_to_new_kernel
fi
