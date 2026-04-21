import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

void main() async {
  // Bind to 0.0.0.0 (any) like Python does, not to the specific IP
  final socket = await RawDatagramSocket.bind(
    InternetAddress.anyIPv4,
    47808,
    reuseAddress: true,
  );
  socket.broadcastEnabled = true;
  print('Bound to ${socket.address.address}:${socket.port}');

  // Who-Is packet
  final whoIs = Uint8List.fromList([
    0x81, 0x0B, 0x00, 0x08,
    0x01, 0x00,
    0x10, 0x08,
  ]);

  // Listen first
  socket.listen((event) {
    if (event == RawSocketEvent.read) {
      final dg = socket.receive();
      if (dg != null) {
        final hex = dg.data
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        print('  RX from ${dg.address.address}:${dg.port} '
            '(${dg.data.length} bytes): $hex');
      }
    }
  });

  // Send to subnet broadcast
  final sent1 = socket.send(whoIs, InternetAddress('192.168.15.255'), 47808);
  print('Sent $sent1 bytes to 192.168.15.255:47808');

  final sent2 = socket.send(whoIs, InternetAddress('255.255.255.255'), 47808);
  print('Sent $sent2 bytes to 255.255.255.255:47808');

  print('Waiting 10 seconds...\n');
  await Future<void>.delayed(const Duration(seconds: 10));
  socket.close();
  print('Done.');
}
