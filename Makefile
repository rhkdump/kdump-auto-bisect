install:
	cp -f kernel-auto-bisect.service /etc/systemd/system/
	cp -f `pwd`/kab.sh /usr/bin/kab.sh
	cp -f `pwd`/kab-lib.sh /usr/bin/kab-lib.sh
	cp -f `pwd`/kab-daemon.sh /usr/bin/kab-daemon.sh
	chcon -t bin_t /usr/bin/kab-daemon.sh 
	cp -f `pwd`/kernel-auto-bisect.conf.template /etc/kernel-auto-bisect.conf

uninstall:
	systemctl stop kernel-auto-bisect.service
	systemctl disable kernel-auto-bisect.service
	rm -f /etc/systemd/system/kernel-auto-bisect.service
	rm -f /usr/bin/kab.sh
	rm -f /usr/bin/kab-lib.sh
	rm -f /usr/bin/kab-daemon.sh
	rm -f /etc/kernel-auto-bisect.conf
