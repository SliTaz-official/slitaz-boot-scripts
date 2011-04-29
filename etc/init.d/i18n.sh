#!/bin/sh
# /etc/init.d/i18n.sh - Internationalization initialization.
#
# This script configures SliTaz default keymap, locale, timezone.
#
. /etc/init.d/rc.functions

# Locale config.
if [ -s "/etc/locale.conf" ]; then
	. /etc/locale.conf
	echo -n "Locale configuration: $LANG" && status
else
	tazlocale
fi

# Keymap config.
if [ -s "/etc/keymap.conf" ]; then
	keymap=`cat /etc/keymap.conf`
	echo -n "Keymap configuration: $keymap" && status
	if [ -x /bin/loadkeys ]; then
		loadkeys $keymap
	else
		loadkmap < /usr/share/kmap/$keymap.kmap
	fi
else
	tazkeymap
fi

# Timezone config. Set timezone using the keymap config for fr, be, fr_CH
# and ca with Montreal.
if [ ! -s "/etc/TZ" ]; then
	keymap=`cat /etc/keymap.conf`
	case "$keymap" in
		fr-latin1|be-latin1)
			echo -n "Setting timezone to Europe/Paris... "
			echo "Europe/Paris" > /etc/TZ && status
			;;
		fr_CH-latin1|de_CH-latin1)
			echo -n "Setting timezone to Europe/Zurich... "
			echo "Europe/Zurich" > /etc/TZ && status
			;;
		cf)
			echo -n "Setting timezone to America/Montreal... "
			echo "America/Montreal" > /etc/TZ && status
			;;
		*)
			echo -n "Setting default timezone to UTC... "
			echo "UTC" > /etc/TZ && status
			;;
	esac
fi

