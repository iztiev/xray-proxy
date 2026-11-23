#!/usr/bin/env bash
# Add a proxy client to an installed stack.
#
# Usage (on the server, in the install folder):
#   sudo bash add_user.sh
#
# Asks for an email, then:
#   - adds a client (new UUID, flow xtls-rprx-vision) and a new shortId to xray/server.json
#     (previous version kept as xray/server.json.bak-<timestamp>)
#   - writes clients/<email>.config.json and clients/<email>.link.txt
#   - offers to restart xray so the new client takes effect
# The REALITY key pair and all other secrets are left untouched.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_root_tty
require_installed

# ------------------------------------------------------------------ prompt --

prompt_email "Email for the new client: "

if jq -e --arg e "$EMAIL" "[$VLESS | .settings.clients[].email] | index(\$e)" "$SERVER_CFG" >/dev/null; then
  die "Client $EMAIL already exists in $SERVER_CFG."
fi
[[ ! -e "$DIR/clients/$EMAIL.config.json" ]] || die "$DIR/clients/$EMAIL.config.json already exists."

# ------------------------------------------------------------ server values --

DOMAIN=$(jq -r "$VLESS | .streamSettings.realitySettings.serverNames[0]" "$SERVER_CFG")
priv=$(jq -r "$VLESS | .streamSettings.realitySettings.privateKey" "$SERVER_CFG")
[[ -n "$DOMAIN" && "$DOMAIN" != null && -n "$priv" && "$priv" != null ]] \
  || die "Could not read serverNames/privateKey from $SERVER_CFG."

log "Deriving REALITY public key from the server private key"
x25519_keys "$priv"
unset priv REALITY_PRIVATE_KEY

CLIENT_UUID=$(new_uuid)
while :; do
  CLIENT_SHORT_ID=$(new_short_id)
  jq -e --arg s "$CLIENT_SHORT_ID" "[$VLESS | .streamSettings.realitySettings.shortIds[]] | index(\$s)" \
    "$SERVER_CFG" >/dev/null || break
done

# ----------------------------------------------------------- update server --

log "Adding $EMAIL to $SERVER_CFG"
apply_server_cfg --arg id "$CLIENT_UUID" --arg email "$EMAIL" --arg sid "$CLIENT_SHORT_ID" "
  ($VLESS) |= (
    .settings.clients += [{id: \$id, flow: \"xtls-rprx-vision\", email: \$email}]
    | .streamSettings.realitySettings.shortIds += [\$sid]
  )"

# ------------------------------------------------------------ client files --

write_client "$EMAIL" "$CLIENT_UUID" "$CLIENT_SHORT_ID" "$DOMAIN" "$REALITY_PUBLIC_KEY"

prompt_restart_xray

cat <<EOF

Done.
  Client config:  $CLIENT_FILE
  Share link:     $LINK_FILE   (import into v2rayN / v2rayNG)

Copy to a computer (run there; Windows Terminal, macOS, Linux):
  scp "<host>:$DIR/clients/$EMAIL.*" .
EOF

offer_qr "$LINK_FILE"
