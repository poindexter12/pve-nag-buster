#!/bin/sh
# shellcheck disable=SC2064
set -eu

# pve-nag-buster https://github.com/poindexter12/pve-nag-buster
# Copyright (C) 2019 /u/seaQueue (reddit.com/u/seaQueue)
#
# Removes Proxmox VE 6.x - 9.x license nags automatically after updates
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# ensure a predictable environment
PATH=/usr/sbin:/usr/bin:/sbin:/bin
\unalias -a

VERSION="1.0.0"

# initialize paths
_init() {
  path_apt_conf="/etc/apt/apt.conf.d/86pve-nags"
  path_apt_sources_proxmox="/etc/apt/sources.list.d/pve-no-subscription.sources"
  path_apt_sources_ceph="/etc/apt/sources.list.d/ceph-no-subscription.sources"
  path_apt_sources_debian="/etc/apt/sources.list.d/debian.sources"
  path_buster="/usr/share/pve-nag-buster.sh"
}

# installer main body
_main() {
  # ensure $1 exists so 'set -u' doesn't error out
  { [ "$#" -eq "0" ] && set -- ""; } > /dev/null 2>&1

  _init

  case "$1" in
    "--uninstall")
      assert_root
      _uninstall
      ;;
    "--install" | "")
      assert_root
      _install
      ;;
    "--help" | "-h")
      _help
      ;;
    "--version" | "-v")
      _version
      ;;
    *)
      _usage
      exit 1
      ;;
  esac
  exit 0
}

_uninstall() {
  echo "Uninstalling pve-nag-buster..."
  [ -f "$path_apt_conf" ] && rm -f "$path_apt_conf" && echo "  Removed $path_apt_conf"
  [ -f "$path_buster" ] && rm -f "$path_buster" && echo "  Removed $path_buster"

  echo ""
  echo "Script and dpkg hooks removed."
  echo "The following files were NOT removed (delete manually if desired):"
  printf '  %s\n' "$path_apt_sources_proxmox"
  printf '  %s\n' "$path_apt_sources_ceph"
  printf '  %s\n' "$path_apt_sources_debian"
}

_install() {
  # Detect release codename
  VERSION_CODENAME=''
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ -n "$VERSION_CODENAME" ]; then
    RELEASE="$VERSION_CODENAME"
  else
    RELEASE=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)
  fi
  export RELEASE

  echo "Detected release: $RELEASE"

  # Create apt sources
  echo "Creating Proxmox no-subscription repo source..."
  emit_proxmox_sources > "$path_apt_sources_proxmox"

  echo "Creating Ceph no-subscription repo source..."
  emit_ceph_sources > "$path_apt_sources_ceph"

  echo "Creating Debian repo source..."
  emit_debian_sources > "$path_apt_sources_debian"

  # Create dpkg hooks
  echo "Creating dpkg hooks in /etc/apt/apt.conf.d..."
  emit_buster_conf > "$path_apt_conf"

  # Install hook script
  temp="$(mktemp)" && trap "rm -f $temp" EXIT
  emit_buster > "$temp"
  echo "Installing hook script as $path_buster"
  install -o root -m 0550 "$temp" "$path_buster"

  # Run initial patch
  echo "Running patch script..."
  "$path_buster"

  echo ""
  echo "Installation complete!"
  return 0
}

assert_root() { [ "$(id -u)" -eq '0' ] || { echo "This action requires root." && exit 1; }; }

_version() {
  echo "pve-nag-buster $VERSION"
}

_usage() {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo "Try '$(basename "$0") --help' for more information."
}

_help() {
  cat <<EOF
pve-nag-buster $VERSION - Remove Proxmox VE subscription nag

Usage: $(basename "$0") [OPTIONS]

Options:
  --install     Install pve-nag-buster (default if no option given)
  --uninstall   Remove hook script and dpkg configuration
  --help, -h    Show this help message
  --version, -v Show version information

Description:
  Patches the Proxmox web UI to remove the "No valid subscription" popup
  and sets up no-subscription apt repositories. A dpkg hook ensures the
  patch is reapplied after package updates.

Examples:
  sudo ./install.sh              # Install
  sudo ./install.sh --uninstall  # Uninstall

More info: https://github.com/poindexter12/pve-nag-buster
EOF
}

