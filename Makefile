install:
	systemctl stop kdump-auto-bisect.service
	systemctl disable kdump-auto-bisect.service
	cp kdump-auto-bisect.service /etc/systemd/system/
	ln -s -f /home/freeman/project/kdump-auto-bisect/kab.sh /usr/bin/kab.sh
	ln -s -f /home/freeman/project/kdump-auto-bisect/kab-lib.sh /usr/bin/kab-lib.sh
	ln -s -f /home/freeman/project/kdump-auto-bisect/kab-daemon.sh /usr/bin/kab-daemon.sh
	ln -s -f /home/freeman/project/kdump-auto-bisect/select-default-grub-entry.sh /usr/bin/select-default-grub-entry.sh
