#!/bin/sh
# /etc/init.d/bootopts.sh - SliTaz boot options from the cmdline.
#
. /etc/init.d/rc.functions

# Mount /home and check for user hacker home dir.
#
mount_home()
{
	echo "Home has been specified to $DEVICE..."
	echo -n "Sleeping 10 s to let the kernel detect the device... "
	sleep 10
	status
	if grep -q "$DEVICE" /proc/partitions ; then
		echo "Mounting /home on /dev/$DEVICE... "
		mv /home/hacker /tmp/hacker-home
		mount -t ext3 /dev/$DEVICE /home
	else
		echo "Unable to find $DEVICE in /proc/partitions... "
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
		echo "Swap memory detected on : $SWAP_DEV"
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

