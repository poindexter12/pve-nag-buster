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

# Patching strategies (tried in order):
# 1. Function wrapper injection - most resilient across versions
# 2. Legacy conditional replacement - fallback for older PVE

patch_nag() {
  if [ ! -f "$NAGFILE" ]; then
    echo "$SCRIPT: proxmoxlib.js not found, skipping nag removal"
    return 0
  fi

  # Check if already patched (look for our injection marker)
  if grep -q "orig_cmd(); return;" "$NAGFILE" 2>/dev/null; then
    echo "$SCRIPT: Already patched"
    return 0
  fi

  # Strategy 1: Function wrapper injection (PVE 7.x - 9.x)
  # Injects early return into subscription check callback
  if grep -qE 'function\s*\(orig_cmd\)\s*\{' "$NAGFILE" 2>/dev/null; then
    echo "$SCRIPT: Patching via function wrapper injection..."
    cp "$NAGFILE" "$NAGFILE.orig"
    sed -Ei "s/(function\s*\(orig_cmd\)\s*\{)/\1 orig_cmd(); return;/" "$NAGFILE"
    systemctl restart pveproxy.service
    echo "$SCRIPT: Nag removed successfully"
    return 0
  fi

  # Strategy 2: Legacy conditional replacement (PVE 6.x)
  if grep -q "data.status.toLowerCase() !== 'active'" "$NAGFILE" 2>/dev/null; then
    echo "$SCRIPT: Patching via legacy conditional replacement..."
    cp "$NAGFILE" "$NAGFILE.orig"
    sed -i "s/data.status.toLowerCase() !== 'active'/false/g" "$NAGFILE"
    systemctl restart pveproxy.service
    echo "$SCRIPT: Nag removed successfully"
    return 0
  fi

  echo "$SCRIPT: WARNING - No known nag pattern found in proxmoxlib.js"
  echo "$SCRIPT: This may indicate a new PVE version with changed code"
  return 1
}

disable_enterprise_repo() {
  # Handle .list format (PVE 6.x - 7.x)
  PAID_LIST="/etc/apt/sources.list.d/pve-enterprise.list"
  if [ -f "$PAID_LIST" ]; then
    echo "$SCRIPT: Disabling PVE enterprise repo (.list)..."
    mv -f "$PAID_LIST" "${PAID_LIST%.list}.disabled"
  fi

  # Handle .sources format (PVE 8.x+, deb822 style)
  PAID_SOURCES="/etc/apt/sources.list.d/pve-enterprise.sources"
  if [ -f "$PAID_SOURCES" ]; then
    if ! grep -q "^Enabled: false" "$PAID_SOURCES" 2>/dev/null; then
      echo "$SCRIPT: Disabling PVE enterprise repo (.sources)..."
      echo "Enabled: false" >> "$PAID_SOURCES"
    fi
  fi

  # Handle Ceph enterprise repo (.sources format)
  CEPH_SOURCES="/etc/apt/sources.list.d/ceph.sources"
  if [ -f "$CEPH_SOURCES" ]; then
    if ! grep -q "^Enabled: false" "$CEPH_SOURCES" 2>/dev/null; then
      echo "$SCRIPT: Disabling Ceph enterprise repo..."
      echo "Enabled: false" >> "$CEPH_SOURCES"
    fi
  fi
}

patch_nag
disable_enterprise_repo
