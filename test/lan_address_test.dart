import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quietake/media/media_server.dart';

(String, InternetAddress) network(String name, String ip) =>
    (name, InternetAddress(ip));

void main() {
  test('Android VPN cannot override the Wi-Fi address advertised to TV', () {
    final address = MediaServer.selectLanAddress([
      network('vgate0', '172.30.243.100'),
      network('wlan0', '10.11.30.45'),
    ]);
    expect(address?.address, '10.11.30.45');
  });

  test('Apple tunnel cannot override Wi-Fi', () {
    final address = MediaServer.selectLanAddress([
      network('utun0', '10.6.0.2'),
      network('en0', '192.168.1.2'),
    ]);
    expect(address?.address, '192.168.1.2');
  });

  test('VPN-only connectivity does not count as a casting LAN', () {
    expect(
      MediaServer.selectLanAddress([network('vgate0', '172.30.243.100')]),
      isNull,
    );
  });

  test('wired LAN works and public/loopback addresses are rejected', () {
    expect(
      MediaServer.selectLanAddress([
        network('lo', '127.0.0.1'),
        network('eth0', '10.0.0.2'),
      ])?.address,
      '10.0.0.2',
    );
    expect(
      MediaServer.selectLanAddress([
        network('wlan0', '127.0.0.1'),
        network('en0', '8.8.8.8'),
      ]),
      isNull,
    );
  });
}
