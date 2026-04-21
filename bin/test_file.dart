import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bacnet_dart/bacnet_dart.dart';

void main() async {
  final holders = await Process.run('ss', ['-ulnp']);
  if (holders.stdout.toString().contains('47808')) {
    print('ERROR: Port 47808 already in use!');
    return;
  }

  final client = BacnetClient(
    config: const BacnetClientConfig(timeout: Duration(seconds: 5)),
  );

  await client.start();
  print('Client started on port 47808.\n');

  const deviceId = 2307528;
  client.addDeviceBinding(deviceId, '192.168.15.10');
  const fileInstance = 2;

  // 1. Read the full file (stream, 1 byte at a time)
  print('--- Step 1: Read file 10:$fileInstance ---');
  final buf = BytesBuilder();
  var pos = 0;
  try {
    while (true) {
      final ack = await client.readFile(
        deviceId, fileInstance,
        startPosition: pos, count: 1, isStream: true,
      );
      if (ack.data.isNotEmpty && ack.data[0].isNotEmpty) {
        buf.add(ack.data[0]);
        pos += ack.data[0].length;
      }
      if (ack.endOfFile || ack.data.isEmpty || ack.data[0].isEmpty) break;
    }
  } catch (e) {
    // timeout = no more data
  }
  final fileData = buf.toBytes();
  print('  Read ${fileData.length} bytes');
  print('  Hex: ${fileData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}\n');

  // 2. Write the SAME data back (exact same size)
  print('--- Step 2: Write same ${fileData.length} bytes back ---');
  try {
    final ackPos = await client.writeFile(
      deviceId, fileInstance,
      fileData,
      startPosition: 0,
    );
    print('  Write OK — pos: $ackPos\n');
  } catch (e) {
    print('  Write FAILED: $e\n');
  }

  client.dispose();
  print('Done.');
}
