#!/bin/sh
# /etc/init.d/user.sh - SliTaz default user for live mode and /home.
#
# This script is called from the main boot script /etc/init/rcS
# to add a user for live mode and mount /home before we start Slim
# since we need a user to autologin and provide a desktop
#
# Default user account without password (uid=1000). In live mode the option
# user=name can be used, but user must be added before home= to have home dir.
# This option is not handled by a loop and case like others and has no
# effect on an installed system.
#
. /etc/init.d/rc.functions

if ! grep -q "100[0-9]:100[0-9]" /etc/passwd; then
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
	adduser -D -s /bin/sh -g "SliTaz User" -G users -h /home/$USER $USER
	passwd -d $USER >/dev/null
	status
	# Audio and cdrom group.
	addgroup $USER audio
	addgroup $USER cdrom
	addgroup $USER video
	addgroup $USER tty
	# Slim default user.
	if [ -f /etc/slim.conf ]; then
		sed -i s/"default_user .*"/"default_user        $USER"/\
			/etc/slim.conf
	fi
fi

# Check for a specified home partition (home=*) and check for
# user home dir. Note: home=usb is a shorter and easier way to
# have home=/dev/sda1.
#
if grep -q "home=" /proc/cmdline; then
	DEVICE=${opt#home=}
	[ "$DEVICE" = "usb" ] && DEVICE=sda1
	echo "Home has been specified to $DEVICE..."
	DEVID=`/sbin/blkid | sed 'p;s/"//g' | grep "$DEVICE" | sed 's/:.*//;q'`
	if [ -z "$DEVID" ]; then
		USBDELAY=`cat /sys/module/usb_storage/parameters/delay_use`
		USBDELAY=$((2+$USBDELAY))
		echo "Sleeping $USBDELAY s to let the kernel detect the device... "
		sleep $USBDELAY
	fi
	USER=`cat /etc/passwd | sed '/:1000:/!d;s/:.*//;q'`
	DEVID=$DEVICE
	if [ -x /sbin/blkid ]; then
		# Can be a label, uuid, type or devname. DEVID gives us first: /dev/name.
		DEVID=`/sbin/blkid | sed 'p;s/"//g' | grep "$DEVICE" | sed 's/:.*//;q'`
	fi
	DEVID=${DEVID##*/}
	if [ -n "$DEVID" ] && grep -q "$DEVID" /proc/partitions ; then
		echo "Mounting /home on /dev/$DEVID... "
		[ -d /home/$USER ] && mv /home/$USER /tmp/$USER-files
		mount /dev/$DEVID /home -o uid=1000,gid=1000 2>/dev/null \
			|| mount /dev/$DEVID /home
		# Check if swap file must be generated in /home: swap=size (Mb).
		# This option is only used within home=device.
		if grep -q "swap=[1-9]*" /proc/cmdline; then
			SWAP_SIZE=`sed 's/.*swap=\([^ ]*\).*/\1/' < /proc/cmdline`
			# DD to gen a virtual disk.
			echo "Generating swap file: /home/swap ($SWAP_SIZE)..."
			dd if=/dev/zero of=/home/swap bs=1M count=$SWAP_SIZE
			# Make the Linux swap filesystem.
			mkswap /home/swap
			add_swap_in_fstab /home/swap
		fi
	else
		echo "Unable to find $DEVICE... "
	fi
	# Move all user dir if needed.
	if [ ! -d "/home/$USER" ] ; then
		mv /tmp/$USER-files /home/$USER
		chown -R $USER.users /home/$USER
	else
		rm -rf /tmp/$USER-files
	fi
	# Install all packages in /home/boot/packages. In live CD and
	# USB mode the option home= mounts the device on /home, so we
	# already have a boot directory with the Kernel and rootfs.
	if [ -d "/home/boot/packages" ]; then
		for pkg in /home/boot/packages/*.tazpkg
		do
			tazpkg install $pkg
		done
	fi
	# We can have custom files in /home/boot/rootfs to overwrite
	# the one packed into the Live system.
	if [ -d "/home/boot/rootfs" ]; then
		cp -a /home/boot/rootfs/* /
	fi
fi
