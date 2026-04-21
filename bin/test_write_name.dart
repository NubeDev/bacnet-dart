import 'dart:async';

import 'package:bacnet_dart/bacnet_dart.dart';

void main() async {
  final client = BacnetClient(
    config: const BacnetClientConfig(timeout: Duration(seconds: 5)),
  );

  await client.start();
  print('Client started.\n');

  const deviceId = 2307528;
  client.addDeviceBinding(deviceId, '192.168.15.10');

  const objType = BacnetObjectType.analogValue;
  const objInstance = 1;
  const prop = BacnetPropertyId.objectName;

  // 1. Read current name
  print('--- Step 1: Read current objectName ---');
  final before = await client.readProperty(deviceId, objType, objInstance, prop);
  print('  AV/1 objectName = "$before"\n');

  // 2. Write new name
  const newName = 'ZoneTemp-AV1';
  print('--- Step 2: Write objectName = "$newName" ---');
  try {
    await client.writeProperty(
      deviceId, objType, objInstance, prop,
      newName,
      tag: 7, // CHARACTER_STRING
    );
    print('  Write OK\n');
  } catch (e) {
    print('  Write FAILED: $e\n');
  }

  // 3. Read back
  print('--- Step 3: Read after rename ---');
  final after = await client.readProperty(deviceId, objType, objInstance, prop);
  print('  AV/1 objectName = "$after"\n');

  // 4. Restore original name
  print('--- Step 4: Restore original name = "$before" ---');
  try {
    await client.writeProperty(
      deviceId, objType, objInstance, prop,
      before,
      tag: 7,
    );
    print('  Restore OK\n');
  } catch (e) {
    print('  Restore FAILED: $e\n');
  }

  // 5. Confirm restored
  print('--- Step 5: Confirm restored ---');
  final restored = await client.readProperty(deviceId, objType, objInstance, prop);
  print('  AV/1 objectName = "$restored"\n');

  client.dispose();
  print('Done.');
}
