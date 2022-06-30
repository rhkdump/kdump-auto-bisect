# !/bin/bash

CONFIG_FILE='/etc/kdump-auto-bisect.conf'
# path to kernel source directory
KERNEL_SRC_PATH=''
# mail-box to recieve report
REPORT_EMAIL=''
LOG_PATH=''
REMOTE_LOG_PATH=''
INSTALL_KERNEL_BY=''
KERNEL_RPM_DIR=''
KERNEL_RPM_LIST=''
KERNEL_RPMS_DIR=''
# remote host who will receive logs.
LOG_HOST=''

read_conf() {
	# Following steps are applied in order: strip trailing comment, strip trailing space,
	# strip heading space, match non-empty line, remove duplicated spaces between conf name and value
	[ -f "$CONFIG_FILE" ] && sed -n -e "s/#.*//;s/\s*$//;s/^\s*//;s/\(\S\+\)\s*\(.*\)/\1 \2/p" $CONFIG_FILE
}

function check_config() {
	while read config_opt config_val; do
		case "$config_opt" in
		\#* | "") ;;

		KERNEL_SRC_PATH)
			echo KERNEL_SRC_PATH set to ${config_val}
			KERNEL_SRC_PATH=${config_val}
			;;
		LOG_PATH)
			echo LOG_PATH set to ${config_val}
			LOG_PATH=${config_val}
			;;
		LOG_HOST)
			echo LOG_HOST set to ${config_val}
			LOG_HOST=${config_val}
			;;
		REMOTE_LOG_PATH)
			echo REMOTE_LOG_PATH set to ${config_val}
			REMOTE_LOG_PATH=${config_val}
			;;
		REPORT_EMAIL)
			echo REPORT_EMAIL set to ${config_val}
			REPORT_EMAIL=${config_val}
			;;
		INSTALL_KERNEL_BY)
			echo INSTALL_KERNEL_BY set to ${config_val}
			INSTALL_KERNEL_BY=${config_val}
			;;
		KERNEL_RPM_LIST)
			echo KERNEL_RPM_LIST set to ${config_val}
			KERNEL_RPM_LIST=${config_val}
			;;
		*) ;;

		esac
	done <<<"$(read_conf)"

	if [[ $INSTALL_KERNEL_BY != rpm && $INSTALL_KERNEL_BY != compile ]]; then
		echo INSTALL_KERNEL_BY must be chosen between rpm and compile
		exit
	elif [[ $INSTALL_KERNEL_BY == rpm ]]; then
		if [[ ! -f $KERNEL_RPM_LIST ]]; then
			echo "$KERNEL_RPM_LIST doesn't exist"
			exit 1
		fi
	fi

	if [[ -z $KERNEL_SRC_PATH ]]; then
		echo "You need to specify the KERNEL_SRC_PATH"
		exit 1
	fi

	if [[ -z $KERNEL_RPMS_DIR ]]; then
		KERNEL_RPMS_DIR=/root/kernel_rpms
	fi
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

generate_git_repo_from_package_list() {
	local _package_list

	_package_list=$KERNEL_RPM_LIST
	repo_path=$KERNEL_SRC_PATH

	if [[ -d $repo_path ]]; then
		rm -rf $repo_path
	fi

	mkdir $repo_path
	cd $repo_path
	git init
	touch kernel_url kernel_release
	git add kernel_url kernel_release
	git commit -m "init"

	while read -r _url; do
		echo $_url >kernel_url
		_str=$(basename $_url)
		_str=${_str#kernel-core-}
		kernel_release=${_str%.rpm}
		echo $kernel_release >kernel_release
		git commit -m "$kernel_release" kernel_release kernel_url
		release_commit_map[$kernel_release]=$(git rev-parse HEAD)
	done <$_package_list
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

	if [[ $INSTALL_KERNEL_BY == rpm ]]; then
		declare -A release_commit_map
		generate_git_repo_from_package_list
		mkdir -p $KERNEL_RPMS_DIR
		_good_commit=${release_commit_map[$1]}
		_bad_commit=${release_commit_map[$2]}
	else
		_good_commit=$1
		_bad_commit=$2
	fi

	LOG starting kab

	if [ -z ${LOG_HOST} ]; then
		echo "you can check logs in /boot/.kdump-auto-bisect.log"
	else
		echo "or at /var directory in ${LOG_HOST}"
		ssh-keygen
		ssh-copy-id -f root@${LOG_HOST}
		LOG using remote log
	fi
	touch "/boot/.kdump-auto-bisect.undergo"
	git bisect reset
	LOG bisect restarting
	git bisect start
	LOG good at $1
	LOG bad at $2
	git bisect good $_good_commit
	git bisect bad $_bad_commit
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

reboot_to_kernel_once() {
	kernel_release=$1

	# older grubby doesn't accept "--info $kernel_release"
	index=$(grubby --info /boot/vmlinuz-$kernel_release | sed -nE "s/index=([[:digit:]])/\1/p")
	if ! grub2-reboot $index; then
		LOG "Failed to set $kernel_release as default entry"
		exit
	fi
}

install_kernel_rpm() {
	kernel_release=$(<kernel_release)
	url=$(<kernel_url)
	_dest=$KERNEL_RPMS_DIR/kernel-core-${kernel_release}.rpm
	wget -c $url -O $_dest

	dnf install $_dest -y

	grubby --set-default /boot/vmlinuz-$(uname -r)
	reboot_to_kernel_once $kernel_release
	LOG kernel rpm $_dest installation complete
	touch "/boot/.kdump-auto-bisect.reboot"
	LOG reboot file created
}

remove_kernel_rpm() {
	kernel_release=$(<kernel_release)
	dnf remove -y kernel-core-$kernel_release
}

success_string=''

function detect_good_bad() {
	if [[ $INSTALL_KERNEL_BY == rpm ]]; then
		remove_kernel_rpm
	fi

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
	sync
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
