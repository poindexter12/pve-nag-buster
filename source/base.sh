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

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  BOLD=''
  NC=''
fi

msg()     { printf "%b\n" "$*"; }
msg_ok()  { msg "${GREEN}✓${NC} $*"; }
msg_info() { msg "${BLUE}→${NC} $*"; }
msg_warn() { msg "${YELLOW}!${NC} $*"; }
msg_err() { msg "${RED}✗${NC} $*" >&2; }
msg_header() { msg "\n${BOLD}$*${NC}"; }

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
  msg_header "Uninstalling pve-nag-buster"
  [ -f "$path_apt_conf" ] && rm -f "$path_apt_conf" && msg_ok "Removed $path_apt_conf"
  [ -f "$path_buster" ] && rm -f "$path_buster" && msg_ok "Removed $path_buster"

  msg ""
  msg_ok "Script and dpkg hooks removed"
  msg_warn "The following files were NOT removed (delete manually if desired):"
  msg "    $path_apt_sources_proxmox"
  msg "    $path_apt_sources_ceph"
  msg "    $path_apt_sources_debian"
}

_install() {
  msg_header "Installing pve-nag-buster"

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

  msg_info "Detected release: ${BOLD}$RELEASE${NC}"

  # Create apt sources
  msg_info "Creating apt sources..."
  emit_proxmox_sources > "$path_apt_sources_proxmox"
  msg_ok "Proxmox no-subscription repo"
  emit_ceph_sources > "$path_apt_sources_ceph"
  msg_ok "Ceph no-subscription repo"
  emit_debian_sources > "$path_apt_sources_debian"
  msg_ok "Debian repo"

  # Create dpkg hooks
  msg_info "Creating dpkg hooks..."
  emit_buster_conf > "$path_apt_conf"
  msg_ok "Installed $path_apt_conf"

  # Install hook script
  temp="$(mktemp)" && trap "rm -f $temp" EXIT
  emit_buster > "$temp"
  install -o root -m 0550 "$temp" "$path_buster"
  msg_ok "Installed $path_buster"

  # Run initial patch
  msg_info "Running patch script..."
  "$path_buster"

  msg ""
  msg_ok "${BOLD}Installation complete!${NC}"
  return 0
}

assert_root() { [ "$(id -u)" -eq '0' ] || { msg_err "This action requires root."; exit 1; }; }

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

