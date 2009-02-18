#!/bin/sh
# /etc/init.d/hwconf.sh - SliTaz hardware autoconfiguration.
#
. /etc/init.d/rc.functions

# Detect PCI devices and load kernel module only at first boot
# or in LiveCD mode.
if [ ! -s /var/lib/detected-modules ]; then

	. /etc/rcS.conf
	
	# We need module_name to match output of lsmod.
	echo "Detecting PCI devices..."
	MODULES_LIST=`lspci -k | grep "modules" | cut -d ":" -f 2 | sed s/-/_/g`
	for mod in $MODULES_LIST
	do
		if ! lsmod | grep -q "$mod"; then
			if [ -f "$(modprobe -l $mod)" ]; then
				echo "Loading Kernel modules: $mod"
				detect="$detect $mod"
				/sbin/modprobe $mod
			else
				echo "Missing module: $mod"
			fi
		fi
	done
	# yenta_socket = laptop
	if `lsmod | grep -q "yenta_socket"`; then
		detect="$detect ac battery"
		modprobe ac
		modprobe battery
		sed -i 's/= cpu/= batt\n}\n\nPlugin {\n    type = cpu/' \
			/etc/lxpanel/default/panels/panel 2> /dev/null
	fi
	echo "$detect" > /var/lib/detected-modules
	# Now add modules to rcS.conf
	load=`echo "$LOAD_MODULES $detect" | sed s/"  "/" "/g`
	sed -i s/"LOAD_MODULES=\"$LOAD_MODULES\""/"LOAD_MODULES=\"$load\""/ \
		/etc/rcS.conf
	# Retry a network connection with DHCP.
	if ifconfig -a | grep -q "eth0"; then
		if [ ! -f /var/run/udhcpc.eth0.pid ]; then
			echo "Starting udhcpc client on: eth0... "
			/sbin/udhcpc -b -i eth0 -p /var/run/udhcpc.eth0.pid
		fi
	fi
fi

# Sound configuration stuff. First check if sound=no and remove all
# sound Kernel modules.
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
		echo "Sound configuration was disabled from cmdline...";;
	*)
		if [ -x /usr/sbin/soundconf ]; then
			echo "Using sound kernel module $DRIVER..."
			/usr/sbin/soundconf -M $DRIVER
		fi;;
	esac
# Sound card may already be detected by PCI-detect.
elif [ -d /proc/asound ]; then
	cp /proc/asound/modules /var/lib/sound-card-driver
	/usr/bin/amixer >/dev/null || /usr/sbin/soundconf
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
elif [ ! -s /var/lib/sound-card-driver ]; then
	if [ -x /usr/sbin/soundconf ]; then
		/usr/sbin/soundconf
	else
		echo "Unable to find: /usr/sbin/soundconf"
	fi
fi

# Screen size config for slim/Xvesa (last config dialog before login).
if [ ! -s /etc/X11/screen.conf -a -x /usr/bin/slim ]; then
	# $HOME is not yet set.
	HOME=/root
	if grep -q "screen=*" /proc/cmdline; then
		export NEW_SCREEN=`cat /proc/cmdline | sed 's/.*screen=\([^ ]*\).*/\1/'`
		if [ "$NEW_SCREEN" = "text" ]; then
			echo -n "Disabling X login manager: slim..."
			sed -i s/'slim'/''/ /etc/rcS.conf
			status
		else
			tazx `cat /etc/X11/wm.default`
		fi
	else
		tazx `cat /etc/X11/wm.default`
	fi
fi
