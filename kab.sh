#!/bin/bash

. kab-lib.sh

are_you_root
is_git_repo
initiate $1 $2
kernel_compile_install
enable_service
do_test
