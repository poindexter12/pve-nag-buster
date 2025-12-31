# shellcheck shell=sh
# Terminal colors (disabled if not a terminal)
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
