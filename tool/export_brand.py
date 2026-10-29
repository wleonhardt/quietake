#!/usr/bin/env python3
"""Export Quietake's SVG master using rsvg-convert (librsvg)."""
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / 'assets/brand/quietake.svg'
RES = ROOT / 'android/app/src/main/res'
IOS = ROOT / 'ios/Runner/Assets.xcassets'


def png(source, destination, size):
    subprocess.run(['rsvg-convert', '-w', str(size), '-h', str(size),
                    '-o', str(destination), str(source)], check=True)


def export():
    png(MASTER, ROOT / 'assets/brand/quietake.png', 256)
    png(MASTER, ROOT / 'release/artwork/store-icon.png', 512)
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                          ('xxhdpi', 144), ('xxxhdpi', 192)]:
        png(MASTER, RES / f'mipmap-{density}/ic_launcher.png', size)
    for entry in json.loads((IOS / 'AppIcon.appiconset/Contents.json').read_text())['images']:
        size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
        png(MASTER, IOS / 'AppIcon.appiconset' / entry['filename'], size)
    for scale, suffix in [(1, ''), (2, '@2x'), (3, '@3x')]:
        png(MASTER, IOS / f'LaunchImage.imageset/LaunchImage{suffix}.png', 168 * scale)

    paths = [element for element in ET.parse(MASTER).getroot()
             if element.tag.endswith('path')]
    vector = ET.Element('vector', {
        'xmlns:android': 'http://schemas.android.com/apk/res/android',
        'android:width': '108dp', 'android:height': '108dp',
        'android:viewportWidth': '108', 'android:viewportHeight': '108'})
    group = ET.SubElement(vector, 'group', {'android:scaleX': '.084375',
        'android:scaleY': '.084375', 'android:translateX': '10.8', 'android:translateY': '10.8'})
    for path in paths:
        ET.SubElement(group, 'path', {'android:fillColor': path.attrib['fill'],
            'android:fillAlpha': path.attrib.get('fill-opacity', '1'),
            'android:pathData': path.attrib['d'],
            'android:fillType': 'evenOdd' if path.attrib.get('fill-rule') == 'evenodd' else 'nonZero'})
    ET.indent(vector)
    ET.ElementTree(vector).write(RES / 'drawable/quietake_foreground.xml', encoding='unicode')
    for path in group:
        path.set('android:fillColor', '#FFFFFF')
    ET.ElementTree(vector).write(RES / 'drawable/quietake_monochrome.xml', encoding='unicode')

    graphic = ROOT / 'release/artwork/feature-graphic.svg'
    mark = MASTER.read_text().replace('width="1024" height="1024" viewBox=',
        'x="38" y="60" width="380" height="380" viewBox=', 1)
    graphic.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500">\n'
        '<rect width="1024" height="500" fill="#121923"/>\n' + mark + '\n'
        '<text x="440" y="225" font-family="Arial, sans-serif" font-size="70" '
        'font-weight="700" fill="#EDF3FF">Quietake</text>\n'
        '<text x="444" y="280" font-family="Arial, sans-serif" font-size="28" '
        'fill="#BFD1FF">Private camera</text>\n'
        '<text x="444" y="325" font-family="Arial, sans-serif" font-size="20" '
        'fill="#EDF3FF">Capture. Keep. Yours.</text>\n</svg>\n')
    subprocess.run(['rsvg-convert', '-o', str(graphic.with_suffix('.png')), str(graphic)], check=True)


if __name__ == '__main__':
    export()
