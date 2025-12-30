#!/bin/sh
# build.sh - Assembles install.sh from source components
set -eu

cd "$(dirname "$0")/.."
src_dir="./source"
dst="./install.sh"

echo "Building $dst from $src_dir/..."

# Start fresh
: > "$dst"

# Emit base installer logic
echo "  Adding base.sh..."
cat "$src_dir/base.sh" >> "$dst"

# Helper to create emit_* functions with heredocs
emit_function() {
    name="$1"
    file="$2"
    echo "  Adding emit_${name}()..."
    {
        printf 'emit_%s() {\n' "$name"
        printf '    cat <<HEREDOC_%s\n' "$name"
        cat "$src_dir/$file"
        printf '\nHEREDOC_%s\n' "$name"
        printf '}\n\n'
    } >> "$dst"
}

# Add emit functions for each component
emit_function "proxmox_sources" "apt.sources.proxmox"
emit_function "ceph_sources" "apt.sources.ceph"
emit_function "debian_sources" "apt.sources.debian"
emit_function "buster_conf" "apt.conf.buster"
emit_function "buster" "buster.sh"

# Add main entry point
echo '_main "$@"' >> "$dst"

# Make executable
chmod +x "$dst"

echo "Build complete: $dst"
echo "Size: $(wc -c < "$dst") bytes"
