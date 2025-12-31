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
    "--check")
      assert_root
      _check
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

_check() {
  echo "Dry-run mode: showing what would be changed"
  echo ""
  export DRY_RUN=1

  # Check nag patch status
  echo "=== Nag Patch Status ==="
  temp="$(mktemp)" && trap "rm -f $temp" EXIT
  emit_buster > "$temp"
  chmod +x "$temp"
  "$temp"

  echo ""
  echo "=== Installation Status ==="
  if [ -f "$path_buster" ]; then
    echo "Hook script: installed at $path_buster"
  else
    echo "Hook script: not installed (would install to $path_buster)"
  fi

  if [ -f "$path_apt_conf" ]; then
    echo "dpkg hooks: installed at $path_apt_conf"
  else
    echo "dpkg hooks: not installed (would install to $path_apt_conf)"
  fi

  echo ""
  echo "No changes were made."
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
  --check       Dry-run mode: show what would be changed
  --help, -h    Show this help message
  --version, -v Show version information

Description:
  Patches the Proxmox web UI to remove the "No valid subscription" popup
  and sets up no-subscription apt repositories. A dpkg hook ensures the
  patch is reapplied after package updates.

Examples:
  sudo ./install.sh              # Install
  sudo ./install.sh --check      # Dry-run (no changes)
  sudo ./install.sh --uninstall  # Uninstall

More info: https://github.com/poindexter12/pve-nag-buster
EOF
}

emit_proxmox_sources() {
    cat <<HEREDOC_proxmox_sources
# Proxmox VE no-subscription repository
# Generated by pve-nag-buster

Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: $RELEASE
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg

HEREDOC_proxmox_sources
}

emit_ceph_sources() {
    cat <<HEREDOC_ceph_sources
# Ceph no-subscription repository
# Generated by pve-nag-buster

Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: $RELEASE
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg

HEREDOC_ceph_sources
}

emit_debian_sources() {
    cat <<HEREDOC_debian_sources
# Debian repository
# Generated by pve-nag-buster

Types: deb
URIs: http://deb.debian.org/debian
Suites: $RELEASE $RELEASE-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://deb.debian.org/debian-security
Suites: $RELEASE-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

HEREDOC_debian_sources
}

emit_buster_conf() {
    cat <<'HEREDOC_buster_conf'
// dpkg hooks for pve-nag-buster
// Re-applies nag removal patch when proxmox-widget-toolkit or pve-manager is updated

DPkg::Pre-Install-Pkgs {
    "while read -r pkg; do case $pkg in *proxmox-widget-toolkit* | *pve-manager*) touch /run/.pve-nag-buster && exit 0; esac done < /dev/stdin";
};

DPkg::Post-Invoke {
    "[ -f /run/.pve-nag-buster ] && { /usr/share/pve-nag-buster.sh; rm -f /run/.pve-nag-buster; }; exit 0";
};

HEREDOC_buster_conf
}

emit_buster() {
    cat <<'HEREDOC_buster'
#!/bin/sh
#
# pve-nag-buster.sh https://github.com/poindexter12/pve-nag-buster
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

set -eu

NAGFILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
SCRIPT="$(basename "$0")"
DRY_RUN="${DRY_RUN:-0}"

# Patching strategies (tried in order):
# 1. Function wrapper injection - most resilient across versions
# 2. Legacy conditional replacement - fallback for older PVE

log() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] $*"
  else
    echo "$SCRIPT: $*"
  fi
}

patch_nag() {
  if [ ! -f "$NAGFILE" ]; then
    log "proxmoxlib.js not found, skipping nag removal"
    return 0
  fi

  # Check if already patched (look for our injection marker)
  if grep -q "orig_cmd(); return;" "$NAGFILE" 2>/dev/null; then
    log "Already patched"
    return 0
  fi

  # Strategy 1: Function wrapper injection (PVE 7.x - 9.x)
  # Injects early return into subscription check callback
  if grep -qE 'function\s*\(orig_cmd\)\s*\{' "$NAGFILE" 2>/dev/null; then
    log "Would patch via function wrapper injection"
    if [ "$DRY_RUN" = "1" ]; then
      log "  Backup: $NAGFILE -> $NAGFILE.orig"
      log "  Inject: orig_cmd(); return; into subscription callback"
      log "  Restart: pveproxy.service"
      return 0
    fi
    cp "$NAGFILE" "$NAGFILE.orig"
    sed -Ei "s/(function\s*\(orig_cmd\)\s*\{)/\1 orig_cmd(); return;/" "$NAGFILE"
    systemctl restart pveproxy.service
    log "Nag removed successfully"
    return 0
  fi

  # Strategy 2: Legacy conditional replacement (PVE 6.x)
  if grep -q "data.status.toLowerCase() !== 'active'" "$NAGFILE" 2>/dev/null; then
    log "Would patch via legacy conditional replacement"
    if [ "$DRY_RUN" = "1" ]; then
      log "  Backup: $NAGFILE -> $NAGFILE.orig"
      log "  Replace: status check with 'false'"
      log "  Restart: pveproxy.service"
      return 0
    fi
    cp "$NAGFILE" "$NAGFILE.orig"
    sed -i "s/data.status.toLowerCase() !== 'active'/false/g" "$NAGFILE"
    systemctl restart pveproxy.service
    log "Nag removed successfully"
    return 0
  fi

  log "WARNING - No known nag pattern found in proxmoxlib.js"
  log "This may indicate a new PVE version with changed code"
  return 1
}

disable_enterprise_repo() {
  # Handle .list format (PVE 6.x - 7.x)
  PAID_LIST="/etc/apt/sources.list.d/pve-enterprise.list"
  if [ -f "$PAID_LIST" ]; then
    log "Disabling PVE enterprise repo (.list)..."
    if [ "$DRY_RUN" = "1" ]; then
      log "  Move: $PAID_LIST -> ${PAID_LIST%.list}.disabled"
    else
      mv -f "$PAID_LIST" "${PAID_LIST%.list}.disabled"
    fi
  fi

  # Handle .sources format (PVE 8.x+, deb822 style)
  PAID_SOURCES="/etc/apt/sources.list.d/pve-enterprise.sources"
  if [ -f "$PAID_SOURCES" ]; then
    if ! grep -q "^Enabled: false" "$PAID_SOURCES" 2>/dev/null; then
      log "Disabling PVE enterprise repo (.sources)..."
      if [ "$DRY_RUN" = "1" ]; then
        log "  Append: 'Enabled: false' to $PAID_SOURCES"
      else
        echo "Enabled: false" >> "$PAID_SOURCES"
      fi
    fi
  fi

  # Handle Ceph enterprise repo (.sources format)
  CEPH_SOURCES="/etc/apt/sources.list.d/ceph.sources"
  if [ -f "$CEPH_SOURCES" ]; then
    if ! grep -q "^Enabled: false" "$CEPH_SOURCES" 2>/dev/null; then
      log "Disabling Ceph enterprise repo..."
      if [ "$DRY_RUN" = "1" ]; then
        log "  Append: 'Enabled: false' to $CEPH_SOURCES"
      else
        echo "Enabled: false" >> "$CEPH_SOURCES"
      fi
    fi
  fi
}

patch_nag
disable_enterprise_repo

HEREDOC_buster
}

_main "$@"
