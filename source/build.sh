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
# $1: function name
# $2: source file
# $3: if "literal", use quoted heredoc (no variable expansion)
emit_function() {
    name="$1"
    file="$2"
    literal="${3:-}"
    echo "  Adding emit_${name}()..."
    {
        printf 'emit_%s() {\n' "$name"
        if [ "$literal" = "literal" ]; then
            # Quoted heredoc - no variable/command expansion (for scripts)
            printf "    cat <<'HEREDOC_%s'\n" "$name"
        else
            # Unquoted heredoc - allows $RELEASE expansion (for templates)
            printf '    cat <<HEREDOC_%s\n' "$name"
        fi
        cat "$src_dir/$file"
        printf '\nHEREDOC_%s\n' "$name"
        printf '}\n\n'
    } >> "$dst"
}

# Add emit functions for each component
# Templates use $RELEASE - need unquoted heredoc for expansion
emit_function "proxmox_sources" "apt.sources.proxmox"
emit_function "ceph_sources" "apt.sources.ceph"
emit_function "debian_sources" "apt.sources.debian"
# Config and scripts - use quoted heredoc (literal, no expansion)
emit_function "buster_conf" "apt.conf.buster" "literal"
emit_function "buster" "buster.sh" "literal"

# Add main entry point
echo '_main "$@"' >> "$dst"

# Make executable
chmod +x "$dst"

echo "Build complete: $dst"
echo "Size: $(wc -c < "$dst") bytes"
