#!/bin/sh
#
# /etc/init.d/system.sh : SliTaz hardware configuration
#
# This script configures the sound card and screen. Tazhw is used earlier
# at boot time to autoconfigure PCI and USB devices. It also configures
# system language, keyboard and TZ in live mode and start X.
#
. /etc/init.d/rc.functions
. /etc/rcS.conf

# Parse cmdline args for boot options (See also rcS and bootopts.sh).
XARG=""
for opt in $(cat /proc/cmdline)
do
	case $opt in
		console=*)
			sed -i "s/tty1/${opt#console=}/g;/^tty[2-9]::/d" \
				/etc/inittab ;;
		sound=*)
			DRIVER=${opt#sound=} ;;
		xarg=*)
			XARG="$XARG ${opt#xarg=}" ;;
		*)
			continue ;;
	esac
done

# Locale config
if [ ! -s "/etc/locale.conf" ]; then
	echo "Setting system locale to: POSIX (English)"
	echo -e "LANG=POSIX\nLC_ALL=POSIX" > /etc/locale.conf
fi
. /etc/locale.conf
echo -n "Setting system locale: $LANG"
export LC_ALL=$LANG
. /lib/libtaz.sh && status

# Keymap config: Default to us in live mode if kmap= was not used.
if [ ! -s "/etc/keymap.conf" ]; then
	echo "Setting system keymap to: us (USA)"
	echo "us" > /etc/keymap.conf
fi
kmap=$(cat /etc/keymap.conf)
echo -n "Loading console keymap: $kmap"
/sbin/tazkeymap $kmap >/dev/null
status

# Timezone config: Set timezone using the keymap config for fr, be, fr_CH
# and ca with Montreal.
if [ ! -s "/etc/TZ" ]; then
	case "$kmap" in
		fr-latin1|be-latin1)
			echo "Europe/Paris" > /etc/TZ ;;
		fr_CH-latin1|de_CH-latin1)
			echo "Europe/Zurich" > /etc/TZ ;;
		cf) echo "America/Montreal" > /etc/TZ ;;
		*) echo "UTC" > /etc/TZ ;;
	esac
fi

# Activate an eventual swap file or partition
if [ "$(blkid | grep 'TYPE="swap"')" ]; then
	for swd in $(blkid | sed '/TYPE="swap"/!d;s/:.*//'); do
		if ! grep -q "$swd	" /etc/fstab; then
			echo "Swap memory detected on: $swd"
		cat >> /etc/fstab <<EOT
$swd	swap	swap	defaults	0 0
EOT
		fi
	done
fi
if grep -q swap /etc/fstab; then
	echo -n "Activating swap memory..."
	swapon -a && status
fi

# Start TazPanel
[ -x /usr/bin/tazpanel ] && tazpanel start

# Kernel polling for automount
echo 5000 > /sys/module/block/parameters/events_dfl_poll_msecs 2>/dev/null

# Sound configuration stuff. First check if sound=no and remove all
# sound Kernel modules.
if [ -n "$DRIVER" ]; then
	case "$DRIVER" in
		no)
			echo -n "Removing all sound kernel modules..."
			rm -rf /lib/modules/$(uname -r)/kernel/sound
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
# Sound card may already be detected by kernel/udev
elif [ -d /proc/asound ]; then
	if [ -s /var/lib/alsa/asound.state ]; then
		# Restore sound config for installed system
		echo "Restoring last alsa configuration..."
		(sleep 2; alsactl restore) &
	else
		# Initialize sound card
		alsactl init
	fi
else
	echo "WARNING: Unable to configure sound card"
fi
