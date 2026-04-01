#!/usr/bin/env bash

## trmnl.sh v0.05 (19th February 2025) by Andrew Davison

source ~/.trmnl_key
image="/home/$USER/scripts/openframe/trmnl/happy.png"

while true; do

	# Try to get the image through the API.
	response=$(curl -s -m 10 https://usetrmnl.com/api/display \
		--header "access-token:$trmnl_key" \
		--header "battery-voltage:3.83" \
		--header "fw-version:6.9" \
		--header "rssi:-69")
	image_url=$(echo "$response" | jq -r '.image_url')
	refresh_rate=$(echo "$response" | jq -r '.refresh_rate')
	[ "$refresh_rate" != "" ] || refresh_rate=6

	# Chuck out some logging so we know what's happening.
	[ "$1" == "debug" ] && echo "$response" | jq
	echo "image_url = $image_url"
	echo "refresh_rate = $refresh_rate"

	# Got the URL? Grab the file, update the path.
	if [ "$image_url" != "" ]; then

		wget -q -O /tmp/trmnl.bmp "$image_url"
		if [ $? -ne 0 ]; then
			refresh_rate=10
		else
			image="/tmp/trmnl.bmp"
		fi

	fi

	# Try to display the image.
	if which display > /dev/null 2>&1; then

		#convert $image -negate $image
		display -window root $image

	elif which fbi > /dev/null 2>&1; then

		fbi -vt 1 -noverbose -t $refresh_rate -1 $image > /dev/null 2>&1
		setterm --term xterm -clear -cursor off > /dev/tty1

	else

		echo "No means to display the image. Please install fbi or imagemagick."
		exit 1

	fi

	[ "$1" == "debug" ] && break || sleep $refresh_rate 2>/dev/null

done

exit 0
