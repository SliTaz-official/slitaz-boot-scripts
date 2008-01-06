#!/bin/sh
# /etc/init.d/hwconf.sh - SliTaz hardware autoconfiguration.
#
. /etc/init.d/rc.functions

# Sound configuration stuff. First check if sound=no and remoce all sound
# Kernel modules.
#
if grep -q -w "sound=no" /proc/cmdline; then
	echo -n "Removing all sound kernel modules..."
	rm -rf /lib/modules/`uname -r`/kernel/sound
	status
	echo -n "Removing all sound packages..."
	for i in $(grep -l '^DEPENDS=.*alsa-lib' /var/lib/tazpkg/installed/*/receipt) ; do
		pkg=${i#/var/lib/tazpkg/installed/}
		echo 'y' | tazpkg remove ${pkg%/*} > /dev/null
	done
	echo 'y' | tazpkg remove alsa-lib > /dev/null
	status
else
	# Config or not config
	if grep -q -w "sound=noconf" /proc/cmdline; then
		echo "Sound configuration is disable from cmdline..."
	elif [ ! -f /var/lib/sound-card-driver ]; then
		if [ -f /usr/sbin/soundconf ]; then
			# Start soundconf to config driver and load module for Live mode
			/usr/sbin/soundconf
		else
			echo "Unable to found : /usr/sbin/soundconf"
		fi
	else
		# /var/lib/sound-card-driver exist so sound is already configured.
		continue
	fi
fi

# Creat /dev/cdrom if needed (symlink does not exist on LiveCD). Chmod hack
# for Asunder and burnbox allowing all users to burn/rip CD/DVD.
#
DRIVE_NAME=`cat /proc/sys/dev/cdrom/info | grep "drive name" | cut -f 3`
if [ ! "`readlink /dev/cdrom`" ]; then
	echo -n "Creating symlink : /dev/cdrom..."
	ln -s /dev/$DRIVE_NAME /dev/cdrom
	chmod 0666 /dev/cdrom
	status
fi
chmod 0666 /dev/$DRIVE_NAME
