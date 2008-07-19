#!/bin/sh
# /etc/init.d/network.sh - Network initialization boot script.
# Config file is: /etc/network.conf
#
. /etc/init.d/rc.functions
. /etc/network.conf

# Set hostname.
echo -n "Setting hostname... "
/bin/hostname -F /etc/hostname
status

# Configure loopback interface.
echo -n "Configuring loopback... "
/sbin/ifconfig lo 127.0.0.1 up
/sbin/route add 127.0.0.1 lo
status

# For wifi. Users just have to enable it throught yes and usually
# essid any will work and interface is autodetected.
if [ "$WIFI" = "yes" ] || grep -q "wifi" /proc/cmdline; then
	if [ -n "$NDISWRAPPER_DRIVERS" -a -x /usr/sbin/ndiswrapper ]; then
		for i in $NDISWRAPPER_DRIVERS; do
			ndiswrapper -i $i
		done
		modprobe ndiswrapper
	fi
	if ! iwconfig $WIFI_INTERFACE 2>&1 | grep -iq "essid"; then
		WIFI_INTERFACE=$(grep : /proc/net/dev | cut -d: -f1 | \
			while read dev; do iwconfig $dev 2>&1 | \
			grep -iq "essid" && { echo $dev ; break; }; \
                        done)
                [ -n "$WIFI_INTERFACE" ] && sed -i "s/^WIFI_INTERFACE=.*/WIFI_INTERFACE=\"$WIFI_INTERFACE\"/" /etc/network.conf
        fi
        [ -n "$WPA_DRIVER" ] && WPA_DRIVER="wext"
	if iwconfig $WIFI_INTERFACE 2>&1 | grep -iq "essid"; then
		IWCONFIG_ARGS=""
		[ -n "$WIFI_MODE" ] && IWCONFIG_ARGS="$IWCONFIG_ARGS mode $WIFI_MODE"
		[ -n "$WIFI_KEY" ] && case "$WIFI_KEY_TYPE" in
		wep|WEP) IWCONFIG_ARGS="$IWCONFIG_ARGS key $WIFI_KEY";;
		wpa|WPA) cat > /tmp/wpa.conf <<EOF
ap_scan=1
network={
	ssid="$WIFI_ESSID"
	scan_ssid=1
	proto=WPA
	key_mgmt=WPA-PSK
	psk="$WIFI_KEY"
	priority=5
}
EOF
			wpa_supplicant -B -w -c/tmp/wpa.conf -D$DRIVER -i$WIFI_INTERFACE
			;;
		any|ANY) cat > /tmp/wpa.conf <<EOF
ap_scan=1
network={
	ssid="$WIFI_ESSID"
	scan_ssid=1
	key_mgmt=WPA-EAP WPA-PSK IEEE8021X NONE
	group=CCMP TKIP WEP104 WEP40
	pairwise=CCMP TKIP
	psk="$WIFI_KEY"
	priority=5
}
EOF
			wpa_supplicant -B -w -c/tmp/wpa.conf -D$WPA_DRIVER -i$WIFI_INTERFACE
			;;
		esac
		[ -n "$WIFI_CHANNEL" ] && IWCONFIG_ARGS="$IWCONFIG_ARGS channel $WIFI_CHANNEL"
		ifconfig $WIFI_INTERFACE up
		iwconfig $WIFI_INTERFACE txpower on
		iwconfig $WIFI_INTERFACE essid $WIFI_ESSID $IWCONFIG_ARGS
		INTERFACE=$WIFI_INTERFACE
        fi
fi

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
