#!/usr/bin/env bash
# Install (or remove) the hotspot helpers and the polkit action.
#
#   sudo ./contrib/install.sh
#   sudo ./contrib/install.sh --uninstall
#
# Three files, all outside the plugin directory, so --uninstall is what makes
# `omarchy plugin remove` actually complete.
#
# This replaced a hand-edited /etc/sudoers.d rule. Nothing here needs your
# username: the polkit action is scoped to whoever is logged in locally and
# active, which is both narrower than a sudoers grant and one less thing to get
# wrong at install time.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE=/usr/local/bin/hotspot-share
VIF=/usr/local/bin/phone-share-vif
POLICY=/usr/share/polkit-1/actions/io.github.rawritude.simple-hotspot.policy
LEGACY_SUDOERS=/etc/sudoers.d/hotspot-share

[ "$(id -u)" -eq 0 ] || { echo "run me as root: sudo $0" >&2; exit 1; }

if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$SHARE" "$VIF" "$POLICY" "$LEGACY_SUDOERS"
  rm -rf /run/phone-share-vif
  echo "removed:"
  printf '  %s\n' "$SHARE" "$VIF" "$POLICY"
  echo
  # Left alone on purpose: the saved SSID and password. Deleting them as a side
  # effect of removing a widget would silently un-pair every phone that has
  # joined. `nmcli connection delete Hotspot` if that is what you want.
  echo "note: the stored Hotspot connection (SSID + password) is left in place."
  exit 0
fi

# The polkit action pins this exact path; installing the helper anywhere else
# leaves the action pointing at nothing and every toggle failing.
install -Dm755 "$HERE/../bin/hotspot-share"   "$SHARE"
install -Dm755 "$HERE/../bin/phone-share-vif" "$VIF"
install -Dm644 "$HERE/io.github.rawritude.simple-hotspot.policy" "$POLICY"

# Earlier versions shipped a NOPASSWD sudoers rule for the same command. Leaving
# it behind would keep a strictly broader grant alive for no reason, so an
# upgrade removes it.
if [ -e "$LEGACY_SUDOERS" ]; then
  rm -f "$LEGACY_SUDOERS"
  echo "removed superseded sudoers grant: $LEGACY_SUDOERS"
fi

echo "installed:"
printf '  %s\n' "$SHARE" "$VIF" "$POLICY"
echo
command -v dnsmasq >/dev/null 2>&1 || echo "note: dnsmasq is not installed; NetworkManager needs it to hand out DHCP."
