#!/bin/bash

source /usr/bin/kab-lib.sh

check_config
are_you_root
safe_cd "$KERNEL_SRC_PATH"
initiate "$1" "$2"
install_kernel
enable_service
do_test
