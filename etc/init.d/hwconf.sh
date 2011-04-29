#!/bin/sh
# /etc/init.d/hwconf.sh - SliTaz hardware configuration.
#
# This script configures the sound card and screen. Tazhw is used earlier
# at boot time to autoconfigure PCI and USB devices.
#
. /etc/init.d/rc.functions

# Parse cmdline args for boot options (See also rcS and bootopts.sh).
XARG=""
for opt in `cat /proc/cmdline`
do
	case $opt in
		sound=*)
			DRIVER=${opt#sound=} ;;
		xarg=*)
			XARG="$XARG ${opt#xarg=}" ;;
		screen=text)
				SCREEN=text
				# Disable X.
				echo -n "Disabling X login manager: slim..."
				. /etc/rcS.conf
				RUN_DAEMONS=`echo $RUN_DAEMONS | sed s/' slim'/''/`
				sed -i s/"RUN_DAEMONS.*"/"RUN_DAEMONS=\"$RUN_DAEMONS\"/" /etc/rcS.conf
				status ;;
		screen=*)
			SCREEN=${opt#screen=} ;;
		*)
			continue ;;
	esac
done

# Sound configuration stuff. First check if sound=no and remove all
# sound Kernel modules.
if [ -n "$DRIVER" ]; then
	case "$DRIVER" in
	no)
		echo -n "Removing all sound kernel modules..."
		rm -rf /lib/modules/`uname -r`/kernel/sound
		status
		echo -n "Removing all sound packages..."
		for i in $(grep -l '^DEPENDS=.*alsa-lib' /var/lib/tazpkg/installed/*/receipt) ; do
			pkg=${i#/var/lib/tazpkg/installed/}
			echo 'y' | tazpkg remove ${pkg%/*} > /dev/null
		done
		for i in alsa-lib mhwaveedit asunder libcddb ; do
			echo 'y' | tazpkg remove $i > /dev/null
		done
		status ;;
	noconf)
		echo "Sound configuration was disabled from cmdline..." ;;
	*)
		if [ -x /usr/sbin/soundconf ]; then
			echo "Using sound kernel module $DRIVER..."
			/usr/sbin/soundconf -M $DRIVER
		fi ;;
	esac
# Sound card may already be detected by PCI-detect.
elif [ -d /proc/asound ]; then
	# Restore sound config for installed system.
	if [ -s /etc/asound.state ]; then
		echo -n "Restoring last alsa configuration..."
		alsactl restore
		status
	else
		/usr/sbin/setmixer
	fi
	# Start soundconf to config driver and load module for Live mode
	# if not yet detected.
	/usr/bin/amixer >/dev/null || /usr/sbin/soundconf
else
	echo "Unable to configure sound card."
fi
