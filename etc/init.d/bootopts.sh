#!/bin/sh
# /etc/init.d/bootopts.sh - SliTaz boot options from the cmdline.
#
# Earlier boot options are in rcS, ex: config= and modprobe=
#
. /etc/init.d/rc.functions

# Update fstab for swapon/swapoff
add_swap_in_fstab()
{
	grep -q "$1	" /etc/fstab || cat >> /etc/fstab <<EOT
$1	swap	swap	default	0 0
EOT
}

# Default user account without password (uid=1000). In live mode the option
# user=name can be used, but user must be added before home= to have home dir.
# This option is not handled by a loop and case like others and has no
# effect on an installed system.
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
	# /home/$USER files from /etc/skel.
	# make user be only read/write by user
	chmod -R 700 /home/$USER
	# Slim default user.
	if [ -f /etc/slim.conf ]; then
		sed -i s/"default_user .*"/"default_user        $USER"/\
			/etc/slim.conf
	fi
fi

# Parse /proc/cmdline for boot options.
echo "Parsing kernel cmdline for SliTaz live options... "

for opt in `cat /proc/cmdline`
do
	case $opt in
		eject)
			# Eject cdrom.
			eject /dev/cdrom ;;
		laptop)
			# Laptop option to load related Kernel modules.
			echo "Loading laptop modules: ac, battery, fan, yenta_socket..."
			for mod in ac battery fan yenta_socket
			do
				modprobe $mod
			done
			grep -qs batt /etc/lxpanel/default/panels/panel ||
			sed -i 's/= cpu/= batt\n}\n\nPlugin {\n    type = cpu/' \
				/etc/lxpanel/default/panels/panel 2> /dev/null
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
		*)
			continue ;;
	esac
done

# Activate an eventual swap file or partition.
if [ "`fdisk -l | grep swap`" ]; then
	for SWAP_DEV in `fdisk -l | sed '/swap/!d;s/ .*//'`; do
		echo "Swap memory detected on: $SWAP_DEV"
		add_swap_in_fstab $SWAP_DEV
	done
fi
if grep -q swap /etc/fstab; then
	echo "Activating swap memory..."
	swapon -a
fi
