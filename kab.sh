#!/bin/bash

source /usr/bin/kab-lib.sh

check_config
are_you_root
if [[ $INSTALL_KERNEL_BY == compile ]]; then
    is_git_repo
fi
initiate $1 $2
if [[ $INSTALL_KERNEL_BY == compile ]]; then
    kernel_compile_install
elif [[ $INSTALL_KERNEL_BY == rpm ]]; then
    install_kernel_rpm
fi
enable_service
do_test
