#!/bin/bash

source /usr/bin/kab-lib.sh

check_config
are_you_root
is_git_repo
initiate $1 $2
kernel_compile_install
enable_service
do_test
