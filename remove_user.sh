#!/usr/bin/env bash
# Remove a proxy client from an installed stack.
#
# Usage (on the server, in the install folder):
#   sudo bash remove_user.sh
#
# Lists clients from xray/server.json, asks which one to remove, then:
#   - deletes the client (UUID) and its shortId from xray/server.json
#     (previous version kept as xray/server.json.bak-<timestamp>)
#   - deletes clients/<email>.config.json and clients/<email>.link.txt
#   - offers to restart xray so the removal takes effect
# Seafile accounts are not touched (the Seafile admin login is separate).

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_root_tty
require_installed

# -------------------------------------------------------------------- list --

mapfile -t EMAILS < <(jq -r "$VLESS | .settings.clients[] | (.email // \"(no email) \" + .id)" "$SERVER_CFG")
(( ${#EMAILS[@]} )) || die "No clients in $SERVER_CFG."

echo
echo "Clients:"
for i in "${!EMAILS[@]}"; do
  printf '  %2d) %s\n' "$((i + 1))" "${EMAILS[$i]}"
done
echo

if (( ${#EMAILS[@]} == 1 )); then
  die "Only one client left; refusing to remove it (nobody could connect). Add another first."
fi

read -rp "Number of the client to remove: " n
[[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#EMAILS[@]} )) || die "Invalid choice: $n"
idx=$((n - 1))
EMAIL="${EMAILS[$idx]}"

read -rp "Remove $EMAIL? [y/N] " ans
[[ "${ans,,}" == y* ]] || die "Cancelled."

# --------------------------------------------------------------- shortId --

# Clients and shortIds are separate lists in the server config; the client file
# records which shortId belongs to this client.
CLIENT_FILE="$DIR/clients/$EMAIL.config.json"
SID=""
if [[ -f "$CLIENT_FILE" ]]; then
  SID=$(jq -r '.outbounds[] | select(.protocol == "vless") | .streamSettings.realitySettings.shortId // empty' "$CLIENT_FILE")
fi

sid_count=$(jq "[$VLESS | .streamSettings.realitySettings.shortIds[]] | length" "$SERVER_CFG")
if [[ -z "$SID" ]]; then
  warn "No client file with a shortId for $EMAIL; shortIds left unchanged (UUID removal alone revokes access)."
elif (( sid_count <= 1 )); then
  warn "Its shortId is the only one left; keeping it (REALITY needs at least one)."
  SID=""
fi

# ----------------------------------------------------------- update server --

log "Removing $EMAIL from $SERVER_CFG"
apply_server_cfg --argjson i "$idx" --arg sid "$SID" "
  ($VLESS) |= (
    .settings.clients |= del(.[\$i])
    | if \$sid != \"\" then .streamSettings.realitySettings.shortIds -= [\$sid] else . end
  )"

rm -f "$DIR/clients/$EMAIL.config.json" "$DIR/clients/$EMAIL.link.txt"
log "Deleted client files for $EMAIL (if present)."

prompt_restart_xray

echo
log "Done. Also delete the copies of $EMAIL.* on your devices."
