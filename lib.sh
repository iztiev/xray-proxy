# Shared helpers for install.sh and add_user.sh. Sourced, not executed.
# shellcheck shell=bash

shopt -u patsub_replacement 2>/dev/null || true   # bash 5.2: keep '&' literal in ${var//pat/rep}

XRAY_IMAGE="ghcr.io/xtls/xray-core:latest"
CLIENT_SOCKS_PORT=10808
CLIENT_HTTP_PORT=10809

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$DIR/templates"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

require_root_tty() {
  [[ $EUID -eq 0 ]] || die "Run as root: sudo bash $0"
  [[ -t 0 ]] || die "Needs an interactive terminal (use 'ssh -t')."
  [[ -d "$TPL" ]] || die "templates/ not found next to the script ($TPL)."
}

is_valid_email() {
  [[ "$1" =~ ^[a-z0-9._%+-]+@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]]
}

# Prompts for an email, lowercases it, validates. Result in $EMAIL.
prompt_email() {
  read -rp "$1" EMAIL
  EMAIL="${EMAIL,,}"
  is_valid_email "$EMAIL" || die "Invalid email: $EMAIL"
}

# x25519_keys [private_key]
# Without an argument generates a new pair; with one derives its public key.
# Sets REALITY_PRIVATE_KEY and REALITY_PUBLIC_KEY.
# Newer xray prints "PrivateKey/Password", older "Private key/Public key".
x25519_keys() {
  local out args=(x25519)
  [[ -n "${1:-}" ]] && args+=(-i "$1")
  out=$(docker run --rm "$XRAY_IMAGE" "${args[@]}" 2>&1 | tr -d '\r')
  # Label formats seen across versions: "Private key:", "PrivateKey:", "Public key:",
  # "Password:", "Password (PublicKey):". Match on the label start, take the value
  # after the last ':'; keys are base64url, so they never contain ':'.
  REALITY_PRIVATE_KEY=$(awk -F: 'tolower($1) ~ /^ *private/ {gsub(/ /, "", $NF); print $NF; exit}' <<<"$out")
  REALITY_PUBLIC_KEY=$(awk -F: 'tolower($1) ~ /^ *(password|public)/ {gsub(/ /, "", $NF); print $NF; exit}' <<<"$out")
  if [[ ! "$REALITY_PRIVATE_KEY" =~ ^[A-Za-z0-9_-]{43}$ || ! "$REALITY_PUBLIC_KEY" =~ ^[A-Za-z0-9_-]{43}$ ]]; then
    # Show only the labels, never the key values
    die "Could not parse 'xray x25519' output. Labels seen: $(cut -d: -f1 <<<"$out" | paste -sd '|')"
  fi
}

new_uuid()     { cat /proc/sys/kernel/random/uuid; }
new_short_id() { openssl rand -hex 8; }
hex64()        { openssl rand -hex 32; }   # 32 random bytes = 64 hex chars

# render <template> <output> <mode>
# Literal {{NAME}} replacement from the global associative array VARS.
# Fails if any {{…}} is left.
render() {
  local src="$1" dst="$2" mode="$3" content k left
  content=$(<"$src")
  for k in "${!VARS[@]}"; do
    content=${content//"{{$k}}"/"${VARS[$k]}"}
  done
  left=$(grep -oE '\{\{[A-Z0-9_]+\}\}' <<<"$content" | sort -u | tr '\n' ' ' || true)
  [[ -z "$left" ]] || die "Unfilled variables in $src: $left"
  install -m "$mode" /dev/null "$dst"
  printf '%s\n' "$content" > "$dst"
}

# write_client <email> <uuid> <short_id> <domain> <public_key>
# Renders clients/<email>.config.json and clients/<email>.link.txt.
write_client() {
  local email="$1" uuid="$2" sid="$3" domain="$4" pub="$5"
  local cfg="$DIR/clients/$email.config.json" link="$DIR/clients/$email.link.txt"

  install -d -m 700 "$DIR/clients"
  declare -gA VARS=(
    [DOMAIN]="$domain"
    [CLIENT_EMAIL]="$email"
    [CLIENT_UUID]="$uuid"
    [CLIENT_SHORT_ID]="$sid"
    [REALITY_PUBLIC_KEY]="$pub"
    [CLIENT_SOCKS_PORT]="$CLIENT_SOCKS_PORT"
    [CLIENT_HTTP_PORT]="$CLIENT_HTTP_PORT"
  )
  render "$TPL/xray/client.json" "$cfg" 600
  VARS=()

  # Share link for v2rayN / v2rayNG import
  install -m 600 /dev/null "$link"
  printf 'vless://%s@%s:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=%s&fp=chrome&pbk=%s&sid=%s&type=tcp#%s\n' \
    "$uuid" "$domain" "$domain" "$pub" "$sid" "${email//@/%40}" > "$link"

  # Let the sudo user scp the client files back without root
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    chown -R "$SUDO_USER": "$DIR/clients"
  fi

  xray_test "$cfg"
  CLIENT_FILE="$cfg"
  LINK_FILE="$link"
}

# xray_check <config.json>: parse-check a config with the xray image; on failure
# prints xray's messages and returns 1. Runs as root (--user 0) so it can read
# 600 files (client configs); the image's default user may not be root.
xray_check() {
  local out
  if ! out=$(docker run --rm --user 0:0 -v "$1:/c.json:ro" "$XRAY_IMAGE" run -test -c /c.json 2>&1); then
    printf '%s\n' "$out" | tail -n 15 >&2
    return 1
  fi
}

xray_test() {
  xray_check "$1" || die "xray rejected $1 (messages above)."
}

# ------------------------------------------------------- server config edits --

SERVER_CFG="$DIR/xray/server.json"
VLESS='.inbounds[] | select(.protocol == "vless")'   # jq path to the VLESS inbound

require_installed() {
  [[ -f "$SERVER_CFG" && -f "$DIR/.env" ]] || die "Not installed ($SERVER_CFG missing). Run install.sh first."
  command -v docker &>/dev/null || die "docker not found. Run install.sh first."
  ensure_pkgs jq openssl
}

# apply_server_cfg <jq args...>
# Runs jq on the server config, validates the result with xray, keeps a timestamped
# backup and atomically replaces the config. On any failure the config is unchanged.
apply_server_cfg() {
  local tmp
  tmp=$(mktemp "$SERVER_CFG.XXXXXX")
  if ! jq "$@" "$SERVER_CFG" > "$tmp"; then
    rm -f "$tmp"; die "jq failed; $SERVER_CFG unchanged."
  fi
  chmod 644 "$tmp"
  if ! xray_check "$tmp"; then
    rm -f "$tmp"; die "xray rejected the new config; $SERVER_CFG unchanged."
  fi
  cp -p "$SERVER_CFG" "$SERVER_CFG.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$tmp" "$SERVER_CFG"
}

prompt_restart_xray() {
  local ans
  echo
  read -rp "Restart xray now to apply (drops current proxy connections for a moment)? [y/N] " ans
  if [[ "${ans,,}" == y* ]]; then
    (cd "$DIR" && docker compose restart xray)
    log "xray restarted."
  else
    log "Not restarted. Apply later with: cd $DIR && docker compose restart xray"
  fi
}

# ------------------------------------------------------------------ QR codes --

# show_qr <link file>: print the share link as a QR code in the terminal.
# Needs a UTF-8 terminal (Windows Terminal, macOS Terminal, any Linux terminal).
show_qr() {
  ensure_pkgs qrencode
  echo
  qrencode -t ansiutf8 -m 2 < "$1"
  echo
  log "Scan with v2rayNG / Streisand / V2Box / Shadowrocket. Clear the screen afterwards (clear)."
}

# offer_qr <link file>: ask, then show_qr. The code is a credential, so it is opt-in.
offer_qr() {
  local ans
  echo
  read -rp "Show the client's QR code now (for phones)? [y/N] " ans
  if [[ "${ans,,}" == y* ]]; then show_qr "$1"; fi
}

ensure_pkgs() {
  local p missing=()
  for p in "$@"; do
    if ! command -v "$p" &>/dev/null; then missing+=("$p"); fi
  done
  if (( ${#missing[@]} )); then
    apt-get update && apt-get install -y "${missing[@]}"
  fi
}
