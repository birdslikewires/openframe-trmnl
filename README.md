# TRMNL for OpenFrame / O2 Joggler

A lightweight TRMNL display client for the [OpenFrame](https://en.wikipedia.org/wiki/O2_Joggler) / O2 Joggler — an Intel Atom-based 7" touchscreen appliance with an 800×480 display.

Polls the [TRMNL](https://usetrmnl.com) cloud API and writes the dashboard image directly to the Linux framebuffer. No X11, no desktop environment — minimal footprint designed to fit on the device's 1GB internal flash.

## Requirements

- Debian Trixie (or compatible) base OS
- A TRMNL account with a [BYOD licence](https://shop.trmnl.com/products/byod)
- Your TRMNL API key

## Installation

```bash
curl -sS https://raw.githubusercontent.com/YOUR_USERNAME/openframe-trmnl/main/install.sh | sudo bash
```

Or clone the repo and run locally:

```bash
git clone https://github.com/YOUR_USERNAME/openframe-trmnl.git
cd openframe-trmnl
sudo bash install.sh
```

The installer will:
- Prompt for your TRMNL API key and write it to `/etc/trmnl.conf`
- Install dependencies (`fbida`, `curl`, `jq`) if not already present
- Install the polling script to `/opt/trmnl/trmnl.sh`
- Install and enable a systemd service that starts on boot

## Configuration

Edit `/etc/trmnl.conf`:

```bash
TRMNL_API_KEY="your_api_key_here"
```

## Device model

When setting up your BYOD device in the TRMNL dashboard, select:

**Inky Impression 7.3 - 800×480**

This is the closest match currently available — same resolution, full colour PNG output. An OpenFrame-specific entry may be added in future.

## Useful commands

```bash
journalctl -u trmnl -f      # live logs
systemctl restart trmnl     # restart the client
systemctl stop trmnl        # stop the client
```

## How it works

The client polls `https://usetrmnl.com/api/display` with your API key, receives a PNG image URL and a refresh interval, downloads the image, and displays it on `/dev/fb0` using `fbi`. It then sleeps for the instructed interval before polling again.

## Acknowledgements

Built for the [Joggler community](https://www.jogglerwiki.com). TRMNL is developed by [usetrmnl.com](https://usetrmnl.com).
