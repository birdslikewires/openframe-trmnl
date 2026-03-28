#!/usr/bin/env python3
"""Write a PNG to the Linux framebuffer — lightweight fbi replacement."""
import sys
from array import array
from PIL import Image

SYSFS = '/sys/class/graphics/fb0'


def _sysfs(name):
    with open(f'{SYSFS}/{name}') as f:
        return f.read().strip()


def show(image_path, fb_path='/dev/fb0'):
    fb_w, fb_h = map(int, _sysfs('virtual_size').split(','))
    bpp = int(_sysfs('bits_per_pixel'))

    img = Image.open(image_path).convert('RGB').resize((fb_w, fb_h), Image.LANCZOS)
    r_ch, g_ch, b_ch = img.split()

    if bpp == 16:
        # Pack as RGB565 little-endian
        data = array('H', (
            ((rv >> 3) << 11) | ((gv >> 2) << 5) | (bv >> 3)
            for rv, gv, bv in zip(r_ch.getdata(), g_ch.getdata(), b_ch.getdata())
        )).tobytes()
    else:
        # 32bpp BGRA — standard layout on Linux x86 framebuffers
        alpha = Image.new('L', img.size, 255)
        data = Image.merge('RGBA', (b_ch, g_ch, r_ch, alpha)).tobytes()

    with open(fb_path, 'wb') as fb:
        fb.write(data)


if __name__ == '__main__':
    fb = sys.argv[2] if len(sys.argv) > 2 else '/dev/fb0'
    show(sys.argv[1], fb)
