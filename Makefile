install:
	systemctl stop kdump-auto-bisect.service
	systemctl disable kdump-auto-bisect.service
	cp -f kdump-auto-bisect.service /etc/systemd/system/
	cp -f `pwd`/kab.sh /usr/bin/kab.sh
	cp -f `pwd`/kab-lib.sh /usr/bin/kab-lib.sh
	cp -f `pwd`/kab-daemon.sh /usr/bin/kab-daemon.sh
	cp -f `pwd`/select-default-grub-entry.sh /usr/bin/select-default-grub-entry.sh

uninstall:
	systemctl stop kdump-auto-bisect.service
	systemctl disable kdump-auto-bisect.service
	rm /etc/systemd/system/kdump-auto-bisect.service
	rm /usr/bin/kab.sh
	rm /usr/bin/kab-lib.sh
	rm /usr/bin/kab-daemon.sh
	rm /usr/bin/select-default-grub-entry.sh
