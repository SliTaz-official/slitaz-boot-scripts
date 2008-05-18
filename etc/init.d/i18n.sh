#!/bin/sh
# /etc/init.d/i18n.sh - Internalisation initialisation.
# This script configure SliTaz default keymap, locale and timezone.
#
. /etc/init.d/rc.functions

# Locale config.
#
echo "Cheking if /etc/locale.conf exist... "
if [ -s "/etc/locale.conf" ]; then
	echo -n "Locale configuration file exist... "
	status
else
	tazlocale
fi

# Keymap config.
#
if [ -s "/etc/keymap.conf" ]; then
	KEYMAP=`cat /etc/keymap.conf`
	echo "Keymap configuration: $KEYMAP"
	if [ -x /bin/loadkeys ]; then
		loadkeys $KEYMAP
	else
		loadkmap < /usr/share/kmap/$KEYMAP.kmap
	fi
else
	tazkeymap
fi

# Timezone config. Set timezone using the keymap config for fr, be, fr_CH
# and ca with Montreal.
#
if [ ! -s "/etc/TZ" ]; then
	KEYMAP=`cat /etc/keymap.conf`
	case "$KEYMAP" in
		fr-latin1|be-latin1)
			echo -n "Setting time zone to Europe/Paris... "
			echo "Europe/Paris" > /etc/TZ && status
			;;
		fr_CH-latin1|de_CH-latin1)
			echo -n "Setting time zone to Europe/Zurich... "
			echo "Europe/Zurich" > /etc/TZ && status
			;;
		cf)
			echo -n "Setting time zone to America/Montreal... "
			echo "America/Montreal" > /etc/TZ && status
			;;
		*)
			echo -n "Setting default time zone to UTC... "
			echo "UTC" > /etc/TZ && status
			;;
	esac
fi

# Firefox hack to get the right locale.
#
if grep -q "fr_*" /etc/locale.conf; then
	# But is the fox installed ?
	if [ -f "/var/lib/tazpkg/installed/firefox/receipt" ]; then
		. /var/lib/tazpkg/installed/firefox/receipt
		sed -i 's/en-US/fr/' /etc/firefox/pref/firefox-l10n.js
	fi
fi

# Gen a motd in french if fr_* or in English by default.
#
if [ ! -s "/etc/motd" ]; then
if grep -q "fr_*" /etc/locale.conf; then
		# FR
		cat > /etc/motd << "EOF"


  (°-  { La documentation est dans /usr/share/doc. Utiliser 'less -EM' pour,
  //\    lire des fichiers et 'clex' pour les gérer, devenir root avec 'su',
  v_/_   éditer avec 'nano'. Taper 'startx' pour lancer une session X. }

  SliTaz GNU/Linux est distribuée dans l'espoir qu'elle sera utile, mais
  alors SANS AUCUNE GARANTIE.


EOF
	else
		# EN
		cat > /etc/motd << "EOF"


  (°-  { Get documentation in /usr/share/doc. Use 'less -EM' to read files,
  //\    become root with 'su', manage files with 'clex', edit using 'nano'.
  v_/_   Type 'startx' to start a X window session. }

  SliTaz GNU/Linux is distributed in the hope that it will be useful, but
  with ABSOLUTELY NO WARRANTY.


EOF

	fi

fi
