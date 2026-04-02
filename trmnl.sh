#!/usr/bin/env bash

## TRMNL display client for OpenFrame
##  Polls the TRMNL cloud API and writes the response image to the framebuffer.

set -euo pipefail

CONFIG_FILE="/etc/trmnl.conf"
IMAGE_FILE="/tmp/trmnl.img"
IMAGE_TMP="/tmp/trmnl.img.tmp"
FRAMEBUFFER="/dev/fb0"
API_ENDPOINT="https://usetrmnl.com/api/display"
DEFAULT_REFRESH=900  # fallback if API doesn't return a refresh rate
MIN_REFRESH=60       # never poll faster than this regardless of API response

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# --- Load config ---
if [[ ! -f "$CONFIG_FILE" ]]; then
	log "Error: config file not found at $CONFIG_FILE" >&2
	exit 1
fi

# shellcheck source=/etc/trmnl.conf
source "$CONFIG_FILE"

if [[ -z "${TRMNL_API_KEY:-}" ]]; then
	log "Error: TRMNL_API_KEY not set in $CONFIG_FILE" >&2
	exit 1
fi

# --- Hide console cursor and disable screen blanking ---
printf '\033[?25l\033[9;0]' > /dev/tty1 2>/dev/null || true

# --- Main loop ---
while true; do
	# Fetch display metadata from TRMNL API
	RESPONSE=$(curl -sS --max-time 30 \
		-H "access-token: ${TRMNL_API_KEY}" \
		"$API_ENDPOINT") || {
		log "Warning: failed to reach TRMNL API, retrying in ${DEFAULT_REFRESH}s" >&2
		sleep "$DEFAULT_REFRESH"
		continue
	}

	IMAGE_URL=$(echo "$RESPONSE" | jq -r '.image_url // empty')
	FILENAME=$(echo "$RESPONSE"  | jq -r '.filename // empty')
	REFRESH=$(echo "$RESPONSE"   | jq -r '.refresh_rate // empty')

	# Fall back to default refresh rate if API didn't return one; enforce minimum
	REFRESH=${REFRESH:-$DEFAULT_REFRESH}
	(( REFRESH < MIN_REFRESH )) && REFRESH=$MIN_REFRESH

	if [[ "$FILENAME" == "sleep" ]]; then
		log "Sleep requested; turning off display and waiting ${REFRESH}s"
		of-backlight 0 || log "Warning: openframe command failed" >&2
		sleep "$REFRESH"
		continue
	fi

	if [[ -z "$IMAGE_URL" ]]; then
		log "Warning: no image_url in API response, retrying in ${REFRESH}s" >&2
		sleep "$REFRESH"
		continue
	fi

	# Download the image atomically (temp file then move, so fbi never sees a partial write)
	if curl -sS --max-time 30 -o "$IMAGE_TMP" "$IMAGE_URL"; then
		mv "$IMAGE_TMP" "$IMAGE_FILE"
	else
		log "Warning: failed to download image, retrying in ${REFRESH}s" >&2
		rm -f "$IMAGE_TMP"
		sleep "$REFRESH"
		continue
	fi

	# Write to framebuffer
	python3 /opt/trmnl/display.py "$IMAGE_FILE" "$FRAMEBUFFER" || {
		log "Warning: display.py failed to write to framebuffer" >&2
	}

	NEXT_REFRESH=$(date -d "+${REFRESH} seconds" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
	log "Display updated; next refresh in ${REFRESH}s (at ${NEXT_REFRESH})"
	sleep "$REFRESH"
done
