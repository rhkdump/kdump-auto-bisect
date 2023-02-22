#!/bin/bash

source /usr/bin/kab-lib.sh

check_config
are_you_root
initiate "$1" "$2"
install_kernel
enable_service
do_test
