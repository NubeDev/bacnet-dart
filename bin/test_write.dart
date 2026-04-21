import 'dart:async';

import 'package:bacnet_dart/bacnet_dart.dart';

void main() async {
  final client = BacnetClient(
    config: const BacnetClientConfig(timeout: Duration(seconds: 5)),
  );

  await client.start();
  print('Client started.\n');

  // Device discovered earlier
  const deviceId = 2307528;
  client.addDeviceBinding(deviceId, '192.168.15.10');

  const objType = BacnetObjectType.analogOutput;
  const objInstance = 3;
  const prop = BacnetPropertyId.presentValue;

  // 1. Read current value
  print('--- Step 1: Read current value ---');
  final before = await client.readProperty(deviceId, objType, objInstance, prop);
  print('  AO/3 presentValue = $before\n');

  // 2. Write at priority 16 — AO is commandable, no out-of-service needed
  const overrideValue = 99.9;
  print('--- Step 2: Write $overrideValue @ priority 16 ---');
  try {
    await client.writeProperty(
      deviceId, objType, objInstance, prop,
      overrideValue,
      priority: 16,
      tag: AppTag.real,
    );
    print('  Write OK\n');
  } catch (e) {
    print('  Write FAILED: $e\n');
  }

  // 3. Read back
  print('--- Step 3: Read after write ---');
  final afterWrite = await client.readProperty(deviceId, objType, objInstance, prop);
  print('  AO/3 presentValue = $afterWrite\n');

  // 4. Release — write null at priority 16
  print('--- Step 4: Release (write null @ priority 16) ---');
  try {
    await client.writeProperty(
      deviceId, objType, objInstance, prop,
      null,
      priority: 16,
      tag: AppTag.null_,
    );
    print('  Release OK\n');
  } catch (e) {
    print('  Release FAILED: $e\n');
  }

  // 5. Read final
  print('--- Step 5: Read after release ---');
  final afterRelease = await client.readProperty(deviceId, objType, objInstance, prop);
  print('  AO/3 presentValue = $afterRelease\n');

  client.dispose();
  print('Done.');
}
