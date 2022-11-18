install:
	cp -f kdump-auto-bisect.service /etc/systemd/system/
	cp -f `pwd`/kab.sh /usr/bin/kab.sh
	cp -f `pwd`/kab-lib.sh /usr/bin/kab-lib.sh
	cp -f `pwd`/kab-daemon.sh /usr/bin/kab-daemon.sh
	cp -f `pwd`/select-default-grub-entry.sh /usr/bin/select-default-grub-entry.sh
	cp -f `pwd`/kdump-auto-bisect.conf.template /etc/kdump-auto-bisect.conf

uninstall:
	systemctl stop kdump-auto-bisect.service
	systemctl disable kdump-auto-bisect.service
	rm -f /etc/systemd/system/kdump-auto-bisect.service
	rm -f /usr/bin/kab.sh
	rm -f /usr/bin/kab-lib.sh
	rm -f /usr/bin/kab-daemon.sh
	rm -f /usr/bin/select-default-grub-entry.sh
	rm -f /etc/kdump-auto-bisect.conf
