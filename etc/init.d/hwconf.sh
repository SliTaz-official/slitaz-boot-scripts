#!/bin/sh
# /etc/init.d/hwconf.sh - SliTaz hardware autoconfiguration.
#

# Sound configuration stuff. First check if sound=no and remoce all sound
# Kernel modules.
#
if grep -q "sound=no" /proc/cmdline; then
	echo -n "Removing all sound kernel modules..."
	rm -rf /lib/modules/`uname -r`/kernel/sound
	status
else
	# Config or not config
	if grep -q "sound=noconf" /proc/cmdline; then
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

# Creat /dev/cdrom if needed (symlink does not exist on LiveCD.
#
if [ ! "`readlink /dev/cdrom`" ]; then
	DRIVE_NAME=`cat /proc/sys/dev/cdrom/info | grep "drive name" | cut -f 3`
	echo -n "Creating symlink : /dev/cdrom..."
	ln -s /dev/$DRIVE_NAME /dev/cdrom
	status
fi

