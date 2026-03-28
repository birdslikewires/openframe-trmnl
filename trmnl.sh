#!/usr/bin/env bash
# TRMNL display client for OpenFrame / O2 Joggler
# Polls the TRMNL cloud API and writes the response image to the framebuffer.

set -euo pipefail

CONFIG_FILE="/etc/trmnl.conf"
IMAGE_FILE="/tmp/trmnl.png"
FRAMEBUFFER="/dev/fb0"
API_ENDPOINT="https://usetrmnl.com/api/display"
DEFAULT_REFRESH=900  # fallback if API doesn't return a refresh rate

# --- Load config ---
if [[ ! -f "$CONFIG_FILE" ]]; then
	echo "Error: config file not found at $CONFIG_FILE" >&2
	exit 1
fi

# shellcheck source=/etc/trmnl.conf
source "$CONFIG_FILE"

if [[ -z "${TRMNL_API_KEY:-}" ]]; then
	echo "Error: TRMNL_API_KEY not set in $CONFIG_FILE" >&2
	exit 1
fi

# --- Main loop ---
while true; do
	# Fetch display metadata from TRMNL API
	RESPONSE=$(curl -sS --max-time 30 \
		-H "access-token: ${TRMNL_API_KEY}" \
		"$API_ENDPOINT") || {
		echo "Warning: failed to reach TRMNL API, retrying in ${DEFAULT_REFRESH}s" >&2
		sleep "$DEFAULT_REFRESH"
		continue
	}

	IMAGE_URL=$(echo "$RESPONSE" | jq -r '.image_url // empty')
	REFRESH=$(echo "$RESPONSE"  | jq -r '.refresh_rate // empty')

	# Fall back to default refresh rate if API didn't return one
	REFRESH=${REFRESH:-$DEFAULT_REFRESH}

	if [[ -z "$IMAGE_URL" ]]; then
		echo "Warning: no image_url in API response, retrying in ${REFRESH}s" >&2
		sleep "$REFRESH"
		continue
	fi

	# Download the image
	curl -sS --max-time 30 -o "$IMAGE_FILE" "$IMAGE_URL" || {
		echo "Warning: failed to download image, retrying in ${REFRESH}s" >&2
		sleep "$REFRESH"
		continue
	}

	# Write to framebuffer
	# -d: framebuffer device
	# -T 1: use virtual console 1
	# -noverbose: suppress output
	# -a: autozoom to fit screen
	# -1: exit after displaying (don't wait for keypress)
	fbi -d "$FRAMEBUFFER" -T 1 -noverbose -a -1 "$IMAGE_FILE" 2>/dev/null || {
		echo "Warning: fbi failed to display image" >&2
	}

	sleep "$REFRESH"
done
