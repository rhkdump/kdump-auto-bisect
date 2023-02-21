#!/bin/bash
CONFIG_FILE='/etc/kernel-auto-bisect.conf'
# path to kernel source directory
KERNEL_SRC_PATH='/root/.kab_src'
# mail-box to receive report
REPORT_EMAIL=''
LOG_PATH=''
REMOTE_LOG_PATH=''
BISECT_WHAT=''
KERNEL_RPM_LIST=''
KERNEL_RPMS_DIR='/root/kernel_rpms'
BISECT_KDUMP=NO
BAD_IF_FAILED_TO_SWITCH=YES
# remote host who will receive logs.
LOG_HOST=''

read_conf() {
	# Following steps are applied in order: strip trailing comment, strip trailing space,
	# strip heading space, match non-empty line, remove duplicated spaces between conf name and value
	[ -f "$CONFIG_FILE" ] && sed -n -e "s/#.*//;s/\s*$//;s/^\s*//;s/\(\S\+\)\s*\(.*\)/\1 \2/p" $CONFIG_FILE
}

check_config() {
	while read -r config_opt config_val; do
		eval "$config_opt"="$config_val"
	done <<<"$(read_conf)"

	if [[ $BISECT_WHAT != NVR && $BISECT_WHAT != SOURCE ]]; then
		echo BISECT_WHAT must be chosen between SOURCE and NVR
		exit
	elif [[ $BISECT_WHAT == NVR ]]; then
		if [[ ! -f $KERNEL_RPM_LIST ]]; then
			echo "$KERNEL_RPM_LIST doesn't exist"
			exit 1
		fi
	fi

	if [[ $BISECT_WHAT == SOURCE ]]; then
		if [[ -z $KERNEL_SRC_PATH ]]; then
			echo "You need to specify the KERNEL_SRC_PATH"
			exit 1
		fi

		if ! is_git_repo $KERNEL_SRC_PATH; then
			echo $'$KERNEL_SRC_PATH is not a git repo.\n'
			exit 1
		fi
	fi

	if [[ ! -e $REPRODUCER ]]; then
		echo "$REPRODUCER doesn't exist."
		exit 1
	fi

	source "$REPRODUCER"
}

safe_cd() {
	cd "$1" || {
		echo "Failed to cd $1"
		exit 1
	}
}

LOG() {
	echo "$(date "+%b %d %H:%M:%S") - $@" >>"${LOG_PATH}"
	if [ ! -z "${LOG_HOST}" ]; then
		ssh root@"${LOG_HOST}" "echo "$(date +%b%d:%H:%M:%S) - $@">> ${REMOTE_LOG_PATH}"
	fi
}

are_you_root() {
	if [ "$(id -u)" != 0 ]; then
		echo $'\nScript can only be executed by root.\n'
		exit 1
	fi
}

is_git_repo() {
	[[ -d $1/.git ]]
}

generate_git_repo_from_package_list() {
	local _package_list

	_package_list=$KERNEL_RPM_LIST
	repo_path=$KERNEL_SRC_PATH

	if [[ -d $repo_path ]]; then
		rm -rf $repo_path
	fi

	mkdir -p $repo_path
	safe_cd "$repo_path"

	git init
	# configure name and email to make git happy
	git config user.name kernel-auto-bisect
	git config user.email kernel-auto-bisect
	touch kernel_url kernel_release
	git add kernel_url kernel_release
	git commit -m "init" >/dev/null

	while read -r _url; do
		echo "$_url" >kernel_url
		_str=$(basename "$_url")
		_str=${_str#kernel-core-}
		kernel_release=${_str%.rpm}
		echo "$kernel_release" >kernel_release
		git commit -m "$kernel_release" kernel_release kernel_url
		release_commit_map[$kernel_release]=$(git rev-parse HEAD)
	done <"$_package_list"
}

# install packages needed for kernel development
install_kernel_devel() {
	dnf --setopt=install_weak_deps=False install audit-libs-devel binutils-devel clang dwarves llvm perl python3-devel elfutils-devel java-devel ncurses-devel newt-devel numactl-devel pciutils-devel perl-generators xz-devel xmlto bison openssl-devel bc openssl gcc-plugin-devel cpio xz tar git -qy
}

# Only call a function if it's defined
call_func() {
	local _func=$1
	declare -F "$_func" && $_func
}

initiate() {
	if [ -e "/boot/.kernel-auto-bisect.undergo" ]; then
		echo '''
        
There might be another operation undergoing, delete any file named
'.kernel-auto-bisect.*' in /boot directory and run this script again.

'''
		exit 1
	fi

	if [[ $BISECT_WHAT == NVR ]]; then
		dnf install git wget -qy
		declare -A release_commit_map
		generate_git_repo_from_package_list
		mkdir -p $KERNEL_RPMS_DIR
		_good_commit=${release_commit_map[$1]}
		_bad_commit=${release_commit_map[$2]}

	else
		_good_commit=$1
		_bad_commit=$2

		# only build kernel modules that are in-use or included in initramfs
		lsinitrd /boot/initramfs-$(uname -r).img | sed -n -E "s/.*\/(\w+).ko.xz/\1/p" | xargs -n 1 modprobe

		yes '' | make localmodconfig
		sed -i "/rhel.pem/d" .config

		install_kernel_devel
	fi

	LOG starting kab

	if [ -z "${LOG_HOST}" ]; then
		echo "you can check logs in /boot/.kernel-auto-bisect.log"
	else
		echo "or at /var directory in ${LOG_HOST}"
		ssh-keygen
		ssh-copy-id -f root@"${LOG_HOST}"
		LOG using remote log
	fi

	call_func before_bisect

	touch "/boot/.kernel-auto-bisect.undergo"
	git bisect reset
	LOG bisect restarting
	git bisect start
	LOG good at "$1"
	LOG bad at "$2"
	git bisect good "$_good_commit"
	git bisect bad "$_bad_commit"
}

# To speed-up building, only build kernel modules that are in-use or included in initrd
compile_install_kernel() {
	CURRENT_COMMIT=$(git rev-parse --short HEAD)
	LOG building kernel: "${CURRENT_COMMIT}"

	./scripts/config --set-str CONFIG_LOCALVERSION -"${CURRENT_COMMIT}"
	yes $'\n' | make -j$(grep '^processor' /proc/cpuinfo | wc -l)
	if ! make modules_install -j || ! make install; then
		LOG "failed to build kernel"
		exit
	fi

	LOG kernel building complete
	# notice that next reboot should use new kernel
	grubby --set-default /boot/vmlinuz-$(uname -r)
	krelease=$(make kernelrelease)
	reboot_to_kernel_once "$krelease"
}

# use grub2-reboot to reboot to the new kernel only once
# so in case we can still go back to a good kernel if the new kernel goes rogue e.g. it may hang
reboot_to_kernel_once() {
	kernel_release=$1

	# note older grubby doesn't accept "--info $kernel_release"
	index=$(grubby --info /boot/vmlinuz-"$kernel_release" | sed -nE "s/index=([[:digit:]])/\1/p")
	if ! grub2-reboot "$index"; then
		LOG "Failed to set $kernel_release as default entry for the next boot only"
		exit
	fi
}

get_default_kernel() {
	grubby --info=DEFAULT | sed -En 's/^kernel="(.*)"/\1/p'
}

install_kernel_rpm() {
	# dnf will make the newly installed kernel as default boot entry
	local _default_kernel=$(get_default_kernel)

	kernel_release=$(<kernel_release)
	url=$(<kernel_url)
	url_module=$(sed -En "s/kernel-core/kernel-modules/p" <<<"$url")
	_dest=$KERNEL_RPMS_DIR/kernel-core-${kernel_release}.rpm
	_dest_module=$KERNEL_RPMS_DIR/kernel-modules-${kernel_release}.rpm
	wget -c "$url" -O "$_dest"
	wget -c "$url_module" -O "$_dest_module"

	dnf install "$_dest" "$_dest_module" -qy

	# restore the default boot entry
	grubby --set-default "$_default_kernel"
	reboot_to_kernel_once "$kernel_release"
	LOG kernel rpm "$_dest" installation complete
}

install_kernel() {
	if [[ $BISECT_WHAT == SOURCE ]]; then
		compile_install_kernel
	elif [[ $BISECT_WHAT == NVR ]]; then
		install_kernel_rpm
	fi
}

remove_kernel_rpm() {
	# Current running kernel is marked as protected and dnf won't remove it.
	# So use rpm instead.
	rpm -e "kernel-core-$1" "kernel-modules-$1"
}

# clean up old kernel to prevent
cleanup_kernel() {
	local _kernel_release=$1

	if [[ $BISECT_WHAT == NVR ]]; then
		remove_kernel_rpm "$_kernel_release"
	else
		/usr/bin/kernel-install remove "$_kernel_release"
	fi
}

success_string=''

SWITCH_SUCESS_FILE=/boot/.kernel-auto-bisect.switched
is_switch_sucessful() {
	[[ -e $SWITCH_SUCESS_FILE ]]
}

clean_switch_status() {
	rm -f $SWITCH_SUCESS_FILE
}

set_switch_status() {
	local _release=$(get_kernel_release)

	if [[ $(uname -r) == $_release ]]; then
		touch $SWITCH_SUCESS_FILE
	fi
}

detect_good_bad() {
	local _result=BAD
	local _old_kernel_release=$(get_kernel_release)

	if is_switch_sucessful; then
		clean_switch_status

		if on_test; then
			_result=GOOD
		fi
	else
		if [[ $BAD_IF_FAILED_TO_SWITCH == NO ]]; then
			LOG "Booted kernel is not the new kernel, abort!"
			exit 1
		fi
	fi

	if [[ $_result == GOOD ]]; then
		LOG good
		success_string=$(git bisect good | grep "is the first bad commit")
	else
		LOG bad
		success_string=$(git bisect bad | grep "is the first bad commit")
	fi

	cleanup_kernel "$_old_kernel_release"
}

can_we_stop() {
	if [ -z "$success_string" ]; then
		return 1 # not yet
	else
		return 0 # yes, we can stop
	fi
}

do_test() {
	# real test happens after reboot
	LOG rebooting
	touch "/boot/.kernel-auto-bisect.reboot"
	sync
	reboot
}

success_report() {
	# sending email
	echo "$success_string" | esmtp "$REPORT_EMAIL"
}

enable_service() {
	systemctl enable kernel-auto-bisect
	LOG kab service enabled
}

disable_service() {
	systemctl disable kernel-auto-bisect
	LOG kab service disabled
}

# utilities for testing kdump
trigger_pannic() {
	kdump_status=$(kdumpctl status)
	LOG "${kdump_status}"

	count=0
	while ! kdumpctl status; do
		sleep 5
		count=$((count + 5))
		if [[ $count -gt 60 ]]; then
			LOG "Something is wrong. Please fix it and trigger panic manually"
			exit
		fi
	done

	LOG "${kdump_status}"
	echo 1 >/proc/sys/kernel/sysrq
	echo c >/proc/sysrq-trigger
}

# Trigger kernel panic only when
#   1. Bisecting kdump kernel
#   2. The booted kernel is the new kernel
panic_for_kdump() {
	if [[ $BISECT_KDUMP == YES ]] && is_switch_sucessful; then
		LOG triggering panic
		sync
		trigger_pannic
	fi
}

# get kernel release
get_kernel_release() {
	local _release

	if [[ $(pwd) != $KERNEL_SRC_PATH ]]; then
		LOG "get_kernel_release should have $KERNEL_SRC_PATH as PWD, abort!"
		exit 1
	fi

	if [[ $BISECT_WHAT == SOURCE ]]; then
		_release=$(make kernelrelease)
	else
		_release=$(cat kernel_release)
	fi

	echo -n "$_release"
}
