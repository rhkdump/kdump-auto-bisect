# !/bin/bash

# TODO create a configfile for these
# path to kernel source directory
KERNEL_SRC_PATH='/home/freeman/project/linux/'
# match the name in grub.cfg
KERNEL_SUFFIX='kdump-auto-bisect' 
# mail-box to recieve report
REPORT_EMAIL='zhangzhengyu@ncic.ac.cn'

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
	if [ -e $KERNEL_SRC_PATH/.kdump-auto-bisect.undergo ]; then
		echo $'\nThere might be another operation undergoing, if you want to start again, delete any file named '.kdump-auto-bisect.*' in kernel source directory and run this script again.\n'
		exit -1
	fi
	read -p "This operatin will clear '/var/crash', continue?(y/n)" ans
	if [ $ans = "n" ]; then
		echo Abort
		exit -1
	fi
	rm -rf /var/crash/*
	read -p "You are requried to edit grub.cfg file, to add a booting entry for your kernel  2) make sure 'crashkernel=xxxM' is added. Hit 'y' if you have modified grub.cfg (y/n)" ans
	if [ ! $ans = "y" ]; then
		echo Abort
		exit 0
	fi
	echo "select your booting entry:"
	/usr/bin/select-default-grub-entry.sh
	read -p "Now provide the suffix of your kernel/initramfs.img, which is the string after 'vmlinuz-' of your kernel/initramfs.img:" KERNEL_SUFFIX
	touch $KERNEL_SRC_PATH"/.kdump-auto-bisect.undergo"
	touch /boot/vmlinuz-$KERNEL_SUFFIX
	touch /boot/initramfs-${KERNEL_SUFFIX}.img #TODO
	git bisect reset
	git bisect start
	echo good at $1
	echo bad at $2
	git bisect good $1
	git bisect bad $2
}

# TODO you might want to modified this function to suit your own machine
function kernel_compile_install() #TODO
{
	yes $'\n' | make oldconfig && \
	make -j2 && \
	make -j2 modules && \
	make modules_install && \
	make install
	# we do not count on that unstable 'make install' command
	# we will do some of its work manually
	# notice that next reboot should use new kernel
	#rm /boot/vmlinuz
	#newkernel=`ls -alt /boot/vmlinuz* | head -n 1 | cut -d " " -f 10`
	#echo "error! empty string" | esmtp $REPORT_EMAIL
	#mv -f $newkernel /boot/vmlinuz-$KERNEL_SUFFIX
	#newinitramfs=`ls -alt /boot/initramfs* | head -n 1 | cut -d " " -f 9`
	#echo "error! empty string" | esmtp $REPORT_EMAIL
	#mv -f $newinitramfs /boot/initramfs-${KERNEL_SUFFIX}.img

	touch $KERNEL_SRC_PATH"/.kdump-auto-bisect.reboot"
}

success_string=''

function detect_good_bad()
{
	if [ -e /var/crash/* ];then
		echo good
		success_string=`git bisect good | grep "is the first bad commit"`
		rm -rf /var/crash/*
	else
		echo bad
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
}

# utilities for testing kdump
function trigger_pannic()
{
	# it is dangerous not to check kdump service status TODO
	systemctl start kdump && \
	echo 1 > /proc/sys/kernel/sysrq && \
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

## only for the first run
#if [ ! -e $KERNEL_SRC_PATH"/.kdump-auto-bisect.undergo" ]; then
#	are_you_root
#	is_git_repo
#	initiate
#	kernel_compile_install
#	do_test
#	exit 0
#fi
#
## only for the reboot after kernel installation
#if [ -e $KERNEL_SRC_PATH"/.kdump-auto-bisect.reboot" ]; then
#	rm -f $KERNEL_SRC_PATH"/.kdump-auto-bisect.reboot"
#	trigger_pannic
#	exit 0
#fi
#
## only for the reboot after crash
#cd $KERNEL_SRC_PATH
#
#detect_good_bad
#can_we_stop
#ret=$?
#if [ "$ret" == 1 ]; then
#	success_report
#	rm -f $KERNEL_SRC_PATH"/.kdump-auto-bisect.undergo"
#else
#	kernel_compile_install
#	do_test
#fi
#cd -
