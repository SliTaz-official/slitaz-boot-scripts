#!/bin/sh
# /etc/init.d/hwconf.sh - SliTaz hardware autoconfiguration.
#
. /etc/init.d/rc.functions

# Sound configuration stuff. First check if sound=no and remoce all sound
# Kernel modules.
#
if grep -q "sound=" /proc/cmdline; then
	DRIVER=`cat /proc/cmdline | sed 's/.*sound=\([^ ]*\).*/\1/'`
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
		status;;
	noconf)
		echo "Sound configuration is disable from cmdline...";;
	*)
		if [ -x /usr/sbin/soundconf ]; then
			echo "Using sound kernel module $DRIVER..."
			/usr/sbin/soundconf -M $DRIVER
		fi;;
	esac
elif [ ! -f /var/lib/sound-card-driver ]; then
	if [ -x /usr/sbin/soundconf ]; then
		# Start soundconf to config driver and load module for Live mode
		/usr/sbin/soundconf
	else
		echo "Unable to found: /usr/sbin/soundconf"
	fi
fi

# Restore sound config for installed system.
if [ -f /var/lib/sound-card-driver ]; then
	echo -n "Restoring last alsa configuration..."
	alsactl restore
	status
else
	# Remove LXpanel volumealsa if no sound configuration.
	if [ -f /usr/share/lxpanel/profile/default/config ]; then 
		sed -i s/'volumealsa'/'space'/ /usr/share/lxpanel/profile/default/config
	fi
fi

# Screen size config for slim/Xvesa.
if [ ! -f /etc/X11/screen.conf -a -x /usr/bin/slim ]; then
	if grep -q "screen=*" /proc/cmdline; then
		export NEW_SCREEN=`cat /proc/cmdline | sed 's/.*screen=\([^ ]*\).*/\1/'`
		if [ "$NEW_SCREEN" = "text" ]; then
			echo -n "Disabling X login manager: slim..."
			sed -i s/'slim'/''/ /etc/rcS.conf
			status
		else
			tazx
		fi
	else
		tazx
	fi
fi
