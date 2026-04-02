#!/usr/bin/env bash
# TRMNL OpenFrame installer / updater
# Sets up the TRMNL display client on a Debian Trixie based system.
# Designed for the OpenFrame / O2 Joggler but should work on any
# Debian-based system with a framebuffer at /dev/fb0.
#
# First install:
#   curl -sS https://raw.githubusercontent.com/birdslikewires/openframe-trmnl/main/install.sh | sudo bash
#
# To update:
#   sudo bash /opt/trmnl/install.sh

set -euo pipefail

INSTALL_DIR="/opt/trmnl"
CONFIG_FILE="/etc/trmnl.conf"
SERVICE_FILE="/etc/systemd/system/trmnl.service"
BASE_URL="https://raw.githubusercontent.com/birdslikewires/openframe-trmnl/main"

# --- Colour output helpers ---
red()   { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
bold()  { echo -e "\033[1m$*\033[0m"; }

# --- Sanity checks ---
if [[ "$EUID" -ne 0 ]]; then
	red "Error: this script must be run as root (use sudo)."
	exit 1
fi

if [[ ! -e /dev/fb0 ]]; then
	red "Error: /dev/fb0 not found. Is the framebuffer available?"
	exit 1
fi

bold "TRMNL OpenFrame installer"
echo ""

# --- API key ---
if [[ -f "$CONFIG_FILE" ]] && grep -q "TRMNL_API_KEY" "$CONFIG_FILE"; then
	bold "Existing config found at $CONFIG_FILE — skipping API key prompt."
	bold "Edit $CONFIG_FILE manually if you need to change the key."
else
	echo "You'll need your TRMNL BYOD API key."
	echo "Find it at: https://usetrmnl.com -> top-right menu -> device settings"
	echo ""
	read -rp "Enter your TRMNL API key: " API_KEY < /dev/tty

	if [[ -z "$API_KEY" ]]; then
		red "Error: API key cannot be empty."
		exit 1
	fi

	cat > "$CONFIG_FILE" <<-EOF
		# TRMNL OpenFrame configuration
		# https://usetrmnl.com
		TRMNL_API_KEY="${API_KEY}"
	EOF

	chmod 600 "$CONFIG_FILE"
	green "Config written to $CONFIG_FILE"
fi

# --- Dependencies ---
bold "Checking dependencies..."

MISSING_PKGS=()
for pkg in python3-pil curl jq; do
	if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
		MISSING_PKGS+=("$pkg")
	fi
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
	bold "Installing: ${MISSING_PKGS[*]}"
	apt-get update -qq
	apt-get install -y "${MISSING_PKGS[@]}"
	green "Dependencies installed."
else
	green "All dependencies already present."
fi

# --- Install / update client files ---
bold "Installing TRMNL client..."

mkdir -p "$INSTALL_DIR"

curl -sS "$BASE_URL/trmnl.sh"    -o "$INSTALL_DIR/trmnl.sh"
curl -sS "$BASE_URL/display.py"  -o "$INSTALL_DIR/display.py"
curl -sS "$BASE_URL/install.sh"  -o "$INSTALL_DIR/install.sh"
chmod +x "$INSTALL_DIR/trmnl.sh" "$INSTALL_DIR/install.sh"

green "Client installed to $INSTALL_DIR/"

# --- Install systemd unit ---
bold "Installing systemd service..."

curl -sS "$BASE_URL/trmnl.service" -o "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable trmnl.service
systemctl restart trmnl.service

green "Service installed and started."
echo ""

# --- Done ---
green "✓ TRMNL OpenFrame setup complete."
echo ""
echo "Useful commands:"
echo "  View logs:      journalctl -u trmnl -f"
echo "  Restart:        systemctl restart trmnl"
echo "  Stop:           systemctl stop trmnl"
echo "  Edit config:    nano $CONFIG_FILE"
