import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bacnet_dart/bacnet_dart.dart';
import 'package:bacnet_dart/src/codec/bvlc.dart';
import 'package:bacnet_dart/src/transport/udp_transport.dart';

void main() async {
  // --- Step 1: Check we can resolve the interface ---
  print('=== Network Interfaces ===');
  final interfaces = await NetworkInterface.list();
  for (final iface in interfaces) {
    for (final addr in iface.addresses) {
      print('  ${iface.name}: ${addr.address} (${addr.type.name})');
    }
  }

  // --- Step 2: Raw UDP test — send Who-Is manually ---
  print('\n=== Raw UDP Test ===');
  final bindAddr = InternetAddress('192.168.15.15');
  final socket = await RawDatagramSocket.bind(bindAddr, 47808, reuseAddress: true);
  socket.broadcastEnabled = true;
  print('Bound to ${socket.address.address}:${socket.port}');

  // BACnet Who-Is packet (hand-crafted)
  // BVLC: 81 0B 00 08 (broadcast, length=8)
  // NPDU: 01 00 (version 1, no flags)
  // APDU: 10 08 (unconfirmed, who-is)
  final whoIs = Uint8List.fromList([
    0x81, 0x0B, 0x00, 0x08, // BVLC
    0x01, 0x00, // NPDU
    0x10, 0x08, // APDU: Who-Is
  ]);

  final broadcastAddr = InternetAddress('192.168.15.255');
  final sent = socket.send(whoIs, broadcastAddr, 47808);
  print('Sent $sent bytes to ${broadcastAddr.address}:47808');

  // Also try 255.255.255.255
  final sent2 = socket.send(whoIs, InternetAddress('255.255.255.255'), 47808);
  print('Sent $sent2 bytes to 255.255.255.255:47808');

  print('Listening for responses (10 seconds)...\n');

  socket.listen((event) {
    if (event == RawSocketEvent.read) {
      final dg = socket.receive();
      if (dg != null) {
        final hex = dg.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        print('  RX from ${dg.address.address}:${dg.port} (${dg.data.length} bytes)');
        print('     $hex');

        // Try to decode
        final data = Uint8List.fromList(dg.data);
        final bvlc = decodeBvlcHeader(data);
        if (bvlc != null) {
          print('     BVLC: func=0x${bvlc.function_.toRadixString(16)}, len=${bvlc.length}');
        }
      }
    }
  });

  await Future<void>.delayed(const Duration(seconds: 10));
  socket.close();
  print('\nDone.');
}
