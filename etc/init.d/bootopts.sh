#!/bin/sh
# /etc/init.d/bootopts.sh - SliTaz boot options from the cmdline.
#
. /etc/init.d/rc.functions

# Check if swap file must be generated in /home: swap=size (Mb).
# This option is used with home=device.
gen_home_swap()
{
	if grep -q "swap=[1-9]*" /proc/cmdline; then
		SWAP_SIZE=`cat /proc/cmdline | sed 's/.*swap=\([^ ]*\).*/\1/'`
		# DD to gen a virtual disk.
		echo "Generating swap file: /home/swap ($SWAP_SIZE)..."
		dd if=/dev/zero of=/home/swap bs=1M count=$SWAP_SIZE
		# Make the Linux swap filesystem.
		mkswap /home/swap
	fi
}

# Mount /home and check for user hacker home dir.
#
mount_home()
{
	echo "Home has been specified to $DEVICE..."
	echo "Sleeping 10 s to let the kernel detect the device... "
	sleep 10

	DEVID=$DEVICE
	if [ -x /sbin/blkid ]; then
		# Can be label, uuid or devname. DEVID give us first: /dev/name.
		DEVID=`/sbin/blkid | grep $DEVICE | cut -d: -f1`
		DEVID=${DEVID##*/}
	fi
	if [ -n "$DEVID" ] && grep -q "$DEVID" /proc/partitions ; then
		echo "Mounting /home on /dev/$DEVID... "
		mv /home/hacker /tmp/hacker-home
		mount /dev/$DEVID /home -o uid=500,gid=500 2>/dev/null \
			|| mount /dev/$DEVID /home
		gen_home_swap
	else
		echo "Unable to find $DEVICE... "
	fi
	# Move all hacker dir if needed.
	if [ ! -d "/home/hacker" ] ; then
		mv /tmp/hacker-home /home/hacker
		chown -R hacker.hacker /home/hacker
	else
		rm -rf /tmp/hacker-home
	fi
}

# Parse /proc/cmdline with grep.
#

echo "Parsing kernel cmdline for SliTaz live options... "

# Check for a specified home directory on cmdline (home=*).
#
if grep -q "home=usb" /proc/cmdline; then
	DEVICE=sda1
	mount_home
elif grep -q "home=" /proc/cmdline; then
	DEVICE=`cat /proc/cmdline | sed 's/.*home=\([^ ]*\).*/\1/'`
	mount_home
fi

# Active an eventual swap file in /home and on local hd.
#
if [ -f "/home/swap" ]; then
	echo "Activing swap (/home/swap) memory..."
	swapon /home/swap
fi
if [ "`fdisk -l | grep swap`" ]; then
	for SWAP_DEV in `fdisk -l | grep swap | awk '{ print $1 }'`; do
		echo "Swap memory detected on: $SWAP_DEV"
		swapon $SWAP_DEV
	done
fi

# Check for a specified locale (lang=*).
#
if grep -q "lang=*" /proc/cmdline; then
	LANG=`cat /proc/cmdline | sed 's/.*lang=\([^ ]*\).*/\1/'`
	echo -n "Setting system locale to: $LANG... "
	echo "LANG=$LANG" > /etc/locale.conf
	echo "LC_ALL=$LANG" >> /etc/locale.conf
	status
fi

# Check for a specified keymap (kmap=*).
#
if grep -q "kmap=*" /proc/cmdline; then
	KMAP=`cat /proc/cmdline | sed 's/.*kmap=\([^ ]*\).*/\1/'`
	echo -n "Setting system keymap to: $KMAP..."
	echo "KMAP=$KMAP.kmap" > /etc/kmap.conf
	status
fi

# Laptop option to load ac and battery Kernel modules.
if grep -q "laptop" /proc/cmdline; then
	echo "Loading laptop modules: ac, battery, yenta_socket..."
	modprobe ac
	modprobe battery
	modprobe yenta_socket
	depmod -a
fi

# Check for a Window Manager (for a flavor, default WM can be changed
# with boot option or with an addfile in /etc/X11/wm.default.
if grep -q "wm=" /proc/cmdline; then
	mkdir -p /etc/X11
	WM=`cat /proc/cmdline | sed 's/.*wm=\([^ ]*\).*/\1/'`
	case $WM in
		jwm)
			echo "jwm" > /etc/X11/wm.default ;;
		ob|openbox|openbox-session)
			echo "openbox" > /etc/X11/wm.default ;;
		e17|enlightenment|enlightenment_start)
			echo "enlightenment" > /etc/X11/wm.default ;;
	esac
else
	# If no default WM fallback to JWM.
	if [ ! -f /etc/X11/wm.default ]; then
		echo "jwm" > /etc/X11/wm.default
	fi
fi
