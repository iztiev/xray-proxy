#!/usr/bin/env bash
# Show a client's share link as a QR code in the terminal (for phone apps).
#
# Usage (on the server, in the install folder):
#   sudo bash show_qr.sh            # pick from a numbered list
#   sudo bash show_qr.sh <email>    # show that client directly

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

declare -F show_qr >/dev/null || { echo "lib.sh next to this script is outdated; upload the current lib.sh." >&2; exit 1; }
require_root_tty
[[ -d "$DIR/clients" ]] || die "No clients/ folder in $DIR. Run install.sh first."

if [[ -n "${1:-}" ]]; then
  LINK="$DIR/clients/${1,,}.link.txt"
  [[ -f "$LINK" ]] || die "No share link for ${1,,} ($LINK)."
else
  shopt -s nullglob
  LINKS=("$DIR"/clients/*.link.txt)
  shopt -u nullglob
  (( ${#LINKS[@]} )) || die "No share links in $DIR/clients."

  echo
  echo "Clients:"
  for i in "${!LINKS[@]}"; do
    name=$(basename "${LINKS[$i]}" .link.txt)
    printf '  %2d) %s\n' "$((i + 1))" "$name"
  done
  echo

  read -rp "Number of the client to show: " n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#LINKS[@]} )) || die "Invalid choice: $n"
  LINK="${LINKS[$((n - 1))]}"
fi

show_qr "$LINK"
