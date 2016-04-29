# !/bin/bash

# TODO create a configfile for these
# path to kernel source directory
KERNEL_SRC_PATH='/home/freeman/project/linux/'
# mail-box to recieve report
REPORT_EMAIL='zhangzhengyu@ncic.ac.cn'
LOG_PATH='/boot/.kdump-auto-bisect.log'

function LOG()
{
	echo "`date +%b%d:%H:%M:%S` - $@">> ${LOG_PATH}
}

function are_you_root()
{
	if [ "$(id -u)" != 0 ];then
    		echo $'\nScript can only be executed by root.\n'
		exit -1
	fi
}

function is_git_repo()
{
	if [  ! -d .git ]; then
		echo $'\nScript can only be executed in git repo.\n'
		exit -1
	fi
}

function initiate() #TODO
{
	if [ -e "/boot/.kdump-auto-bisect.undergo" ]; then
		echo $'\nThere might be another operation undergoing, if you want to start over, delete any file named '.kdump-auto-bisect.*' in kernel source directory and run this script again.\n';
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
	read -p "This operatin will clear contents in '/var/crash', continue?(y/n)" ans
	if [ $ans = "n" ]; then
		echo Abort
		exit -1
	fi
	rm -rf /var/crash/*
#   read -p "You are requried to edit grub.cfg file, to add a booting entry for your kernel  2) make sure 'crashkernel=xxxM' is added. Hit 'y' if you have modified grub.cfg (y/n)" ans
#	if [ ! $ans = "y" ]; then
#		echo Abort
#		exit 0
#	fi
#	echo "select your booting entry:"
#	/usr/bin/select-default-grub-entry.sh
#	read -p "Now provide the suffix of your kernel/initramfs.img, which is the string after 'vmlinuz-' of your kernel/initramfs.img:" KERNEL_SUFFIX
	touch "/boot/.kdump-auto-bisect.undergo"
#	touch /boot/vmlinuz-$KERNEL_SUFFIX
#	touch /boot/initramfs-${KERNEL_SUFFIX}.img
	git bisect reset
	LOG bisect restarting
	git bisect start
	LOG good at $1
	LOG bad at $2
	git bisect good $1
	git bisect bad $2
}

# TODO you might want to modified this function to suit your own machine
function kernel_compile_install() #TODO
{
    #TODO threading according to /proc/cpuinfo
    CURRENT_COMMIT=`git log --oneline | cut -d ' ' -f 1 | head -n 1`
	LOG building kernel: ${CURRENT_COMMIT}
	yes $'\n' | make oldconfig && \
	make -j2 && \
	make -j2 modules && \
	make modules_install && \
	make install
	LOG kernel building complete
	# notice that next reboot should use new kernel
    	grubby --set-default-index=0
	# TODO log which kernel
	# for i in `ls -alt /boot/vmlinuz* | head -n 3 | cut -d " " -f 10 | cut -d "-" -f 2 `; do new_boot_entry="Fedora ($i) 24 (Workstation Edition)"; break; done
	# new_kernel_version=`ls -l /boot/vmlinuz | cut -d " " -f 11 | cut -d "-" -f 2`
	# new_boot_entry="Fedora ($new_kernel_version) 23 (Workstation Edition)" # TODO
    	# grub2-set-default "$new_boot_entry"
	# LOG select new kernel "$new_boot_entry"
	# rm /boot/vmlinuz
	# newkernel=`ls -alt /boot/vmlinuz* | head -n 1 | cut -d " " -f 10`
	# echo "error! empty string" | esmtp $REPORT_EMAIL
	# mv -f $newkernel /boot/vmlinuz-$KERNEL_SUFFIX
	# newinitramfs=`ls -alt /boot/initramfs* | head -n 1 | cut -d " " -f 9`
	# echo "error! empty string" | esmtp $REPORT_EMAIL
	touch "/boot/.kdump-auto-bisect.reboot"
	LOG reboot file created
}

success_string=''

function detect_good_bad()
{
	if [ `ls /var/crash | wc -l` -ne 0 ];then
		LOG good
		success_string=`git bisect good | grep "is the first bad commit"`
		rm -rf /var/crash/*
		LOG remove /var/crash/*
	else
		LOG bad
		success_string=`git bisect bad | grep "is the first bad commit"`
	fi
}

function can_we_stop()
{
	if [ -z $success_string ]; then
		return 0; # not yet
	else
		return 1; # yes, we can stop
	fi
}

function do_test()
{
	# real test happens after reboot
	LOG rebooting
	reboot
}

function success_report() 
{
	# sending email
	echo $success_string | esmtp $REPORT_EMAIL

}

function enable_service()
{
	systemctl enable kdump-auto-bisect
	LOG kab service enabled
}

function disable_service()
{
	systemctl disable kdump-auto-bisect
	LOG kab service disabled
}

# utilities for testing kdump
function trigger_pannic()
{
	# it is dangerous not to check kdump service status TODO
	kdump_status=`kdumpctl status`
	LOG ${kdump_status}
	sleep 5
	echo 1 > /proc/sys/kernel/sysrq
	echo c > /proc/sysrq-trigger
}

function which_kernel()
{
	if [ -e /proc/vmcore ]; then
		echo 2
	else
		echo 1
	fi
}	
