#!/usr/bin/env bash
# First-time install of the Xray REALITY + Seafile stack on Ubuntu LTS.
#
# Usage (on the server, from the folder holding install.sh, lib.sh and templates/):
#   sudo bash install.sh
#
# Renders templates/ into this folder:
#   .env, compose.yml, Caddyfile, xray/server.json   (server)
#   clients/<email>.config.json, clients/<email>.link.txt   (first client)
# Refuses to run twice: regenerating secrets would lock Seafile out of its DB.
# Add more clients later with add_user.sh.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- preflight --

require_root_tty
. /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || die "Ubuntu only (found: ${ID:-unknown})."

if [[ -e "$DIR/.env" || -e "$DIR/xray/server.json" ]]; then
  die "Already installed ($DIR/.env or xray/server.json exists). Refusing to regenerate secrets. Use add_user.sh to add clients."
fi

swap_mb=$(free -m | awk '/^Swap:/ {print $2}')
if (( swap_mb < 1900 )); then
  warn "Swap is ${swap_mb} MB; this stack needs >= 2 GB on a 1 GB RAM server."
  if [[ ! -e /swapfile ]]; then
    read -rp "Create a 2 GB swapfile at /swapfile (persistent via /etc/fstab)? [Y/n] " ans
    if [[ "${ans,,}" != n* ]]; then
      fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      grep -qE '^/swapfile\s' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
      log "Swap enabled: $(free -m | awk '/^Swap:/ {print $2}') MB"
    fi
  else
    warn "/swapfile exists but swap is low; check 'swapon --show'."
  fi
fi

# ------------------------------------------------------------------- docker --

install_docker() {
  log "Installing Docker Engine + Compose plugin from Docker's apt repository"

  # Remove distro packages that conflict with docker-ce
  local p conflicts=()
  for p in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    if dpkg -s "$p" &>/dev/null; then conflicts+=("$p"); fi
  done
  if (( ${#conflicts[@]} )); then
    apt-get remove -y "${conflicts[@]}"
  fi

  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  log "Docker and Compose plugin already installed: $(docker --version)"
else
  install_docker
fi
ensure_pkgs openssl jq

# ------------------------------------------------------------------- prompts --

echo
read -rp "Domain (e.g. example.com, DNS must already point here): " DOMAIN
DOMAIN="${DOMAIN,,}"
[[ "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]] || die "Invalid domain: $DOMAIN"

prompt_email "Email (ACME, Seafile admin login, first proxy client): "

while :; do
  read -rsp "Seafile admin password (min 8 chars, no single quotes): " PASSWORD; echo
  read -rsp "Repeat password: " PASSWORD2; echo
  if [[ "$PASSWORD" != "$PASSWORD2" ]]; then warn "Passwords do not match."; continue; fi
  if (( ${#PASSWORD} < 8 )); then warn "Too short."; continue; fi
  if [[ "$PASSWORD" == *"'"* ]]; then warn "Single quotes are not allowed."; continue; fi
  break
done
unset PASSWORD2

# ------------------------------------------------------------------ secrets --

log "Generating secrets (pulling $XRAY_IMAGE for the REALITY key pair)"
x25519_keys
CLIENT_UUID=$(new_uuid)
CLIENT_SHORT_ID=$(new_short_id)

# ------------------------------------------------------------------- render --

declare -A VARS=(
  [DOMAIN]="$DOMAIN"
  [ACME_EMAIL]="$EMAIL"
  [ADMIN_EMAIL]="$EMAIL"
  [ADMIN_PASSWORD]="$PASSWORD"
  [JWT_PRIVATE_KEY]="$(hex64)"
  [DB_PASSWORD]="$(hex64)"
  [MYSQL_ROOT_PASSWORD]="$(hex64)"
  [REALITY_PRIVATE_KEY]="$REALITY_PRIVATE_KEY"
  [XRAY_CLIENTS]="[{\"id\": \"$CLIENT_UUID\", \"flow\": \"xtls-rprx-vision\", \"email\": \"$EMAIL\"}]"
  [XRAY_SHORT_IDS]="[\"$CLIENT_SHORT_ID\"]"
)

log "Rendering templates into $DIR"
install -d -m 700 "$DIR/xray"
install -d -m 755 "$DIR/data/caddy/data" "$DIR/data/caddy/config" "$DIR/data/mysql" "$DIR/data/seafile"

render "$TPL/.env.template"       "$DIR/.env"               600
render "$TPL/compose.yml"  "$DIR/compose.yml" 644
render "$TPL/Caddyfile"           "$DIR/Caddyfile"          644
# 644 so the container user can read it; the xray/ dir (700) keeps other host users out
render "$TPL/xray/server.json"    "$DIR/xray/server.json"   644
VARS=()
unset PASSWORD REALITY_PRIVATE_KEY

# ----------------------------------------------------------------- validate --

log "Validating"
cd "$DIR"
docker compose config -q
xray_test "$DIR/xray/server.json"

write_client "$EMAIL" "$CLIENT_UUID" "$CLIENT_SHORT_ID" "$DOMAIN" "$REALITY_PUBLIC_KEY"

# -------------------------------------------------------------------- start --

echo
read -rp "Start the stack now (docker compose up -d)? [y/N] " ans
if [[ "${ans,,}" == y* ]]; then
  docker compose up -d
  log "Started. First Seafile start takes a few minutes; then set 'workers = 2' in"
  log "  data/seafile/seafile/conf/gunicorn.conf.py and run: docker compose restart seafile"
else
  log "Not started. Start later with: cd $DIR && docker compose up -d"
fi

cat <<EOF

Done.
  Seafile:        https://$DOMAIN  (login: $EMAIL)
  Client config:  $CLIENT_FILE
  Share link:     $LINK_FILE   (import into v2rayN / v2rayNG)

Copy the client files to a computer (run there; Windows Terminal, macOS, Linux):
  scp "<host>:$DIR/clients/*" .

Firewall: allow only 22, 80 and 443/tcp.
QR code for any client later: sudo bash $DIR/show_qr.sh
EOF

offer_qr "$LINK_FILE"
