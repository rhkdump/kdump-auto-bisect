# !/bin/bash

CONFIG_FILE='/etc/kdump-auto-bisect.conf'
# path to kernel source directory
KERNEL_SRC_PATH=''
# mail-box to recieve report
REPORT_EMAIL=''
LOG_PATH=''
REMOTE_LOG_PATH=''
# remote host who will receive logs.
LOG_HOST=''

function check_config() {
	while read config_opt config_val; do
		config_val_striped=$(echo ${config_val} | sed -e 's/\(.*\)#.*/\1/')
		case "$config_opt" in
		\#* | "") ;;

		KERNEL_SRC_PATH)
			echo KERNEL_SRC_PATH set to ${config_val_striped}
			KERNEL_SRC_PATH=${config_val_striped}
			;;
		LOG_PATH)
			echo LOG_PATH set to ${config_val_striped}
			LOG_PATH=${config_val_striped}
			;;
		LOG_HOST)
			echo LOG_HOST set to ${config_val_striped}
			LOG_HOST=${config_val_striped}
			;;
		REMOTE_LOG_PATH)
			echo REMOTE_LOG_PATH set to ${config_val_striped}
			REMOTE_LOG_PATH=${config_val_striped}
			;;
		REPORT_EMAIL)
			echo REPORT_EMAIL set to ${config_val_striped}
			REPORT_EMAIL=${config_val_striped}
			;;
		*) ;;

		esac
	done <${CONFIG_FILE}
}

function LOG() {
	echo "$(date +%b%d:%H:%M:%S) - $@" >>${LOG_PATH}
	if [ ! -z ${LOG_HOST} ]; then
		ssh root@${LOG_HOST} "echo "$(date +%b%d:%H:%M:%S) - $@">> ${REMOTE_LOG_PATH}"
	fi
}

function are_you_root() {
	if [ "$(id -u)" != 0 ]; then
		echo $'\nScript can only be executed by root.\n'
		exit -1
	fi
}

function is_git_repo() {
	if [ ! -d .git ]; then
		echo $'\nScript can only be executed in git repo.\n'
		exit -1
	fi
}

function initiate() {
	if [ -e "/boot/.kdump-auto-bisect.undergo" ]; then
		echo '''
        
There might be another operation undergoing, delete any file named
'.kdump-auto-bisect.*' in /boot directory and run this script again.

'''
		exit -1
	fi
	read -p "Make sure kdump works in current system, continue?(y/n)" ans
	if [ ! $ans = "y" ]; then
		echo Abort
		exit -1
	fi
	# TODO efi
	if [ -d /sys/firmware/efi ]; then
		read -p "EFI is not well supported, continue?(y/n)" ans
		if [ ! $ans = "y" ]; then
			echo Abort
			exit -1
		fi
	fi
	read -p "This will clear contents in '/var/crash', continue?(y/n)" ans
	if [ $ans = "n" ]; then
		echo Abort
		exit -1
	fi
	rm -rf /var/crash/*
	if [ -z ${LOG_HOST} ]; then
		echo "you can check logs in /boot/.kdump-auto-bisect.log"
	else
		echo "or at /var directory in ${LOG_HOST}"
		ssh-keygen
		ssh-copy-id -f root@${LOG_HOST}
		LOG using remote log
	fi
	LOG starting kab
	touch "/boot/.kdump-auto-bisect.undergo"
	git bisect reset
	LOG bisect restarting
	git bisect start
	LOG good at $1
	LOG bad at $2
	git bisect good $1
	git bisect bad $2
}

# you might want to modified this function to suit your own machine
function kernel_compile_install() {
	#TODO threading according to /proc/cpuinfo
	CURRENT_COMMIT=$(git log --oneline | cut -d ' ' -f 1 | head -n 1)
	LOG building kernel: ${CURRENT_COMMIT}
	yes $'\n' | make oldconfig &&
		make -j2 &&
		make -j2 modules &&
		make modules_install &&
		make install
	LOG kernel building complete
	# notice that next reboot should use new kernel
	grubby --set-default-index=0
	touch "/boot/.kdump-auto-bisect.reboot"
	LOG reboot file created
}

success_string=''

function detect_good_bad() {
	if [ $(ls /var/crash | wc -l) -ne 0 ]; then
		LOG good
		success_string=$(git bisect good | grep "is the first bad commit")
		rm -rf /var/crash/*
		LOG remove /var/crash/*
	else
		LOG bad
		success_string=$(git bisect bad | grep "is the first bad commit")
	fi
}

function can_we_stop() {
	if [ -z $success_string ]; then
		return 0 # not yet
	else
		return 1 # yes, we can stop
	fi
}

function do_test() {
	# real test happens after reboot
	LOG rebooting
	reboot
}

function success_report() {
	# sending email
	echo $success_string | esmtp $REPORT_EMAIL

}

function enable_service() {
	systemctl enable kdump-auto-bisect
	LOG kab service enabled
}

function disable_service() {
	systemctl disable kdump-auto-bisect
	LOG kab service disabled
}

# utilities for testing kdump
function trigger_pannic() {
	# it is dangerous not to check kdump service status TODO
	kdump_status=$(kdumpctl status)
	LOG ${kdump_status}
	sleep 5
	echo 1 >/proc/sys/kernel/sysrq
	echo c >/proc/sysrq-trigger
}

function which_kernel() {
	if [ -e /proc/vmcore ]; then
		echo 2
	else
		echo 1
	fi
}
