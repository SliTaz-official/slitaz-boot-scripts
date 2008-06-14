#!/bin/sh
# /etc/init.d/network.sh - Network initialisation boot script.
# Config file is: /etc/network.conf
#
. /etc/init.d/rc.functions
. /etc/network.conf

# Set hostname.
echo -n "Setting hostname... "
/bin/hostname -F /etc/hostname
status

# Configure loopback interface.
echo -n "Configure loopback... "
/sbin/ifconfig lo 127.0.0.1 up
/sbin/route add 127.0.0.1 lo
status

# For a dynamic IP with DHCP.
if [ "$DHCP" = "yes" ] ; then
	echo "Starting udhcpc client on: $INTERFACE... "
	/sbin/udhcpc -b -i $INTERFACE -p /var/run/udhcpc.$INTERFACE.pid
fi

# For a static IP.
if [ "$STATIC" = "yes" ] ; then
	echo "Configuring static IP on $INTERFACE: $IP... "
	/sbin/ifconfig $INTERFACE $IP netmask $NETMASK up
	/sbin/route add default gateway $GATEWAY
	# Multi-DNS server in $DNS_SERVER.
	/bin/mv /etc/resolv.conf /tmp/resolv.conf.$$
	for NS in $DNS_SERVER
	do
		echo "nameserver $NS" >> /etc/resolv.conf
	done
fi

# For wifi. Users just have to enable it throught yes and usually
# essid any will work and interafce is wlan0.
if [ "$WIFI" = "yes" ] || grep -q "wifi" /proc/cmdline; then
	if [ -n "$NDISWRAPPER_DRIVERS" -a -x /usr/sbin/ndiswrapper ]; then
		for i in $NDISWRAPPER_DRIVERS; do
			ndiswrapper -i $i
		done
		modprobe ndiswrapper
	fi
	IWCONFIG_ARGS=""
	[ -n "$WIFI_MODE" ] && IWCONFIG_ARGS="$IWCONFIG_ARGS mode $WIFI_MODE"
	[ -n "$WIFI_KEY" ] && IWCONFIG_ARGS="$IWCONFIG_ARGS key $WIFI_KEY"
	[ -n "$WIFI_CHANNEL" ] && IWCONFIG_ARGS="$IWCONFIG_ARGS channel $WIFI_CHANNEL"
	ifconfig $WIFI_INTERFACE up
	iwconfig $WIFI_INTERFACE essid $WIFI_ESSID $IWCONFIG_ARGS
	echo "Starting udhcpc client on: $WIFI_INTERFACE... "
	/sbin/udhcpc -b -i $WIFI_INTERFACE \
		-p /var/run/udhcpc.$WIFI_INTERFACE.pid
fi
