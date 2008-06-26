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
	USER=`cat /etc/passwd | grep 1000 | cut -d ":" -f 1`
	DEVID=$DEVICE
	if [ -x /sbin/blkid ]; then
		# Can be label, uuid or devname. DEVID give us first: /dev/name.
		DEVID=`/sbin/blkid | grep $DEVICE | cut -d: -f1`
		DEVID=${DEVID##*/}
	fi
	if [ -n "$DEVID" ] && grep -q "$DEVID" /proc/partitions ; then
		echo "Mounting /home on /dev/$DEVID... "
		mv /home/$USER /tmp/$USER-files
		mount /dev/$DEVID /home -o uid=1000,gid=1000 2>/dev/null \
			|| mount /dev/$DEVID /home
		gen_home_swap
	else
		echo "Unable to find $DEVICE... "
	fi
	# Move all hacker dir if needed.
	if [ ! -d "/home/$USER" ] ; then
		mv /tmp/$USER-files /home/$USER
		chown -R $USER.$USER /home/$USER
	else
		rm -rf /tmp/$USER-files
	fi
}

# Mount all ext3 partitions found (opt: mount).
mount_partitions()
{
	# Get the list partitions.
	DEVICES_LIST=`fdisk -l | grep 83 | cut -d " " -f 1`
	# Mount filesystems rw.
	for device in $DEVICES_LIST
	do
		name=${device#/dev/}
		# Device can be already used by home=usb.
		if ! mount | grep ^$device >/dev/null; then
			echo "Mounting partition: $name on /mnt/$name"
			mkdir /mnt/$name
			mount $device /mnt/$name
		fi
	done
}

# Parse /proc/cmdline with grep.
#

echo "Parsing kernel cmdline for SliTaz live options... "

# user=name: Default user account witout password (uid=1000).
#
if ! grep -q "1000:1000" /etc/passwd; then
	if grep -q "user=" /proc/cmdline; then
		USER=`cat /proc/cmdline | sed 's/.*user=\([^ ]*\).*/\1/'`
		# Avoid usage of an existing system user or root.
		if grep -q ^$USER /etc/passwd; then
			USER=tux
		fi
	else
		USER=tux
	fi
	echo -n "Configuring user and group: $USER..."
	echo "$USER:x:1000:1000:SliTaz User,,,:/home/$USER:/bin/sh" >> /etc/passwd
	echo "$USER::14035:0:99999:7:::" >> /etc/shadow
	echo "$USER:x:1000:" >> /etc/group
	echo "$USER:!::" >> /etc/gshadow
	status
	# slitaz-base-files are now modified
	echo "slitaz-boot-scripts" > \
		/var/lib/tazpkg/installed/slitaz-base-files/modifiers
	# Audio group.
	sed -i s/"audio:x:20:"/"audio:x:20:$USER"/ /etc/group
	# /home/$USER files from /etc/skel.
	if [ -d /etc/skel ]; then
		cp -a /etc/skel /home/$USER
		# Path for user dektop files.
		for i in /home/$USER/.local/share/applications/*.desktop
		do
			sed -i s/"user_name"/"$USER"/g $i
		done
	else
		mkdir -p /home/$USER
	fi
	# set permissions.
	chown -R $USER.$USER /home/$USER
	# Slim default user.
	if [ -f /etc/slim.conf ]; then
		sed -i s/"default_user        hacker"/"default_user        $USER"/\
			/etc/slim.conf
	fi
fi

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
	KEYMAP=`cat /proc/cmdline | sed 's/.*kmap=\([^ ]*\).*/\1/'`
	echo -n "Setting system keymap to: $KEYMAP..."
	echo "$KEYMAP" > /etc/keymap.conf
	status
fi

# Laptop option to load ac and battery Kernel modules.
if grep -q "laptop" /proc/cmdline; then
	echo "Loading laptop modules: ac, battery, yenta_socket..."
	modprobe ac
	modprobe battery
	modprobe yenta_socket
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
	# If no default WM fallback to Openbox.
	if [ ! -f /etc/X11/wm.default ]; then
		echo "openbox" > /etc/X11/wm.default
	fi
fi

# Check for option mount.
if grep -q "mount" /proc/cmdline; then
	mount_partitions
fi
