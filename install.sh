#!/usr/bin/env bash
# TRMNL OpenFrame bootstrap installer
# Sets up the TRMNL display client on a Debian Trixie based system.
# Designed for the OpenFrame / O2 Joggler but should work on any
# Debian-based system with a framebuffer at /dev/fb0.
#
# Usage:
#   git clone https://github.com/birdslikewires/openframe-trmnl /opt/trmnl
#   sudo bash /opt/trmnl/install.sh
#
# To update:
#   git -C /opt/trmnl pull && sudo systemctl restart trmnl

set -euo pipefail

INSTALL_DIR="/opt/trmnl"
CONFIG_FILE="/etc/trmnl.conf"
SERVICE_FILE="/etc/systemd/system/trmnl.service"
REPO_URL="https://github.com/birdslikewires/openframe-trmnl"

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

# --- Clone or verify repo ---
bold "Setting up TRMNL client..."

if [[ -d "$INSTALL_DIR/.git" ]]; then
	green "Repo already present at $INSTALL_DIR"
elif [[ -f "$INSTALL_DIR/trmnl.sh" ]]; then
	red "Error: $INSTALL_DIR exists but is not a git repo. Remove it and re-run."
	exit 1
else
	bold "Cloning repo to $INSTALL_DIR..."
	git clone "$REPO_URL" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/trmnl.sh"
green "Client ready at $INSTALL_DIR/"

# --- Install systemd unit ---
bold "Installing systemd service..."

cp "$INSTALL_DIR/trmnl.service" "$SERVICE_FILE"

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
