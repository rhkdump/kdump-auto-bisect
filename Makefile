install:
	systemctl stop kdump-auto-bisect.service
	systemctl disable kdump-auto-bisect.service
	cp kdump-auto-bisect.service /etc/systemd/system/
	ln -s -f `pwd`/kab.sh /usr/bin/kab.sh
	ln -s -f `pwd`/kab-lib.sh /usr/bin/kab-lib.sh
	ln -s -f `pwd`/kab-daemon.sh /usr/bin/kab-daemon.sh
	ln -s -f `pwd`/select-default-grub-entry.sh /usr/bin/select-default-grub-entry.sh
