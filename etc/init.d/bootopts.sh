#!/bin/sh
#
# /etc/init.d/bootopts.sh : SliTaz boot options from the cmdline
#
# Earlier boot options are in rcS, ex: config= and modprobe=
#
. /etc/init.d/rc.functions

# Get first usb disk
usb_device() {
	cd /sys/block
	for i in sd* sda ; do
		grep -qs 1 $i/removable && break
	done
	echo $i
}

# Parse /proc/cmdline for boot options.
echo "Checking for SliTaz cmdline options..."

# Default user account without password (uid=1000). In live mode the option
# user=name can be used, but user must be added before home= to have home dir.
# This option is not handled by a loop and case like others and has no
# effect on an installed system.
if ! grep -q "100[0-9]:100" /etc/passwd; then

	if fgrep -q "user=" /proc/cmdline; then
		USER=$(cat /proc/cmdline | sed 's/.*user=\([^ ]*\).*/\1/')
		# Avoid usage of an existing system user or root.
		if grep -q ^$USER /etc/passwd; then
			USER=tux
		fi
	else
		USER=tux
	fi
	
	# Make sure we have users applications.conf
	if [ ! -f "/etc/skel/.config/slitaz/applications.conf" -a \
	     -f "/etc/slitaz/applications.conf" ]; then
		mkdir -p /etc/skel/.config/slitaz
		cp /etc/slitaz/applications.conf /etc/skel/.config/slitaz
	fi
	
	echo -n "Configuring user and group: $USER..."
	adduser -D -s /bin/sh -g "SliTaz User" -G users -h /home/$USER $USER
	passwd -d $USER >/dev/null
	for group in audio cdrom video tty plugdev disk
	do
		addgroup $USER ${group}
	done
	status
	
	# Slim default user
	if [ -f /etc/slim.conf ]; then
		sed -i s/"default_user .*"/"default_user    $USER"/ /etc/slim.conf
	fi
fi

for opt in $(cat /proc/cmdline)
do
	case $opt in
		eject)
			# Eject cdrom.
			eject /dev/cdrom ;;
		autologin)
			# Autologin option to skip first graphic login prompt.
			echo "auto_login        yes" >> /etc/slim.conf ;;
		lang=*)
			# Check for a specified locale (lang=*).
			LANG=${opt#lang=}
			/sbin/tazlocale $LANG ;;
		kmap=*)
			# Check for a specified keymap (kmap=*).
			KEYMAP=${opt#kmap=}
			echo -n "Setting system keymap to: $KEYMAP..."
			echo "$KEYMAP" > /etc/keymap.conf
			status ;;
		font=*)
			# Check for a specified console font (font=*).
			FONT=${opt#font=}
			echo -n "Setting console font to: $FONT..."
			for con in 1 2 3 4 5 6; do setfont $FONT -C /dev/tty$con; done
			status ;;
		home=*)
			# Check for a specified home partition (home=*) and check for
			# user home dir. Note: home=usb is a shorter and easier way to
			# have home=/dev/sda1.
			DEVICE=${opt#home=}
			[ "$DEVICE" = "usb" ] && DEVICE="$(usb_device)1"
			echo "Home has been specified to $DEVICE..."
			DEVID=`/sbin/blkid | sed 'p;s/"//g' | fgrep "$DEVICE" | sed 's/:.*//;q'`
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
				DEVID=`/sbin/blkid | sed 'p;s/"//g' | fgrep "$DEVICE" | sed 's/:.*//;q'`
			fi
			DEVID=${DEVID##*/}
			if [ -n "$DEVID" ] && fgrep -q "$DEVID" /proc/partitions ; then
				echo "Mounting /home on /dev/$DEVID... "
				[ -d /home/$USER ] && mv /home/$USER /tmp/$USER-files
				mount /dev/$DEVID /home &&
				case "$(/sbin/blkid | grep /dev/$DEVID:)" in
				*\"ntfs\"*|*\"vfat\"*) mount.posixovl -F /home -- -oallow_other -odefault_permissions -osuid ;;
				esac
				mount /home -o remount,uid=1000,gid=100 2>/dev/null
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
			fi ;;
		laptop)
			# Enable Kernel Laptop mode.
			echo "5" > /proc/sys/vm/laptop_mode ;;
		mount)
			# Mount all ext3 partitions found (opt: mount).
			# Get the list of partitions.
			DEVICES_LIST=`fdisk -l | sed '/83 Linux/!d;s/ .*//'`
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
			done ;;
		mount-packages)
			# Mount and install packages-XXX.iso (useful without Internet
			# connection).
			PKGSIGN="LABEL=\"packages-$(cat /etc/slitaz-release)\" TYPE=\"iso9660\""
			PKGDEV=$(blkid | grep "$PKGSIGN" | cut -d: -f1)
			[ -z "$PKGDEV" -a -L /dev/cdrom ] && \
				PKGDEV=$(blkid /dev/cdrom | grep "$PKGSIGN" | cut -d: -f1)
			if [ -n "$PKGDEV" ]; then
				echo -n "Mounting packages archive from $PKGDEV..."
				mkdir /packages && mount -t iso9660 -o ro $PKGDEV /packages
				status
				/packages/install.sh
			fi ;;
		wm=*)
			# Check for a Window Manager (for a flavor, default WM can be changed
			# with boot options or via /etc/slitaz/applications.conf).
			WM=${opt#wm=}
			case $WM in
				ob|openbox|openbox-session)
					WM=openbox-session ;;
				e17|enlightenment|enlightenment_start)
					WM=enlightenment ;;
				razorqt|razor-session)
					WM=razor-session ;;
			esac
			sed -i s/"WINDOW_MANAGER=.*"/"WINDOW_MANAGER=\"$WM\""/ \
				/etc/slitaz/applications.conf ;;
		*)
			continue ;;
	esac
done
