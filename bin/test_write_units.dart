import 'dart:async';

import 'package:bacnet_dart/bacnet_dart.dart';

// BACnet engineering units (ASHRAE 135 clause 21.7)
const units = {
  62: 'degrees-celsius',
  64: 'degrees-fahrenheit',
  98: 'percent',
  95: 'no-units',
  19: 'liters-per-second',
  85: 'cubic-meters-per-hour',
  118: 'kilopascals',
  53: 'pascals',
  18: 'liters-per-minute',
};

String unitName(int id) => units[id] ?? 'unit-$id';

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
  const prop = BacnetPropertyId.units;

  // 1. Read current units
  print('--- Step 1: Read current units ---');
  final before = await client.readProperty(deviceId, objType, objInstance, prop);
  print('  AV/1 units = $before (${unitName(before is int ? before : -1)})\n');

  // 2. Write degrees-celsius (62)
  const newUnit = 62; // degrees-celsius
  print('--- Step 2: Write units = $newUnit (${unitName(newUnit)}) ---');
  try {
    await client.writeProperty(
      deviceId, objType, objInstance, prop,
      newUnit,
      tag: 9, // ENUMERATED
    );
    print('  Write OK\n');
  } catch (e) {
    print('  Write FAILED: $e\n');
  }

  // 3. Read back
  print('--- Step 3: Read after change ---');
  final after = await client.readProperty(deviceId, objType, objInstance, prop);
  print('  AV/1 units = $after (${unitName(after is int ? after : -1)})\n');

  // 4. Restore original
  print('--- Step 4: Restore original units = $before ---');
  try {
    await client.writeProperty(
      deviceId, objType, objInstance, prop,
      before,
      tag: 9,
    );
    print('  Restore OK\n');
  } catch (e) {
    print('  Restore FAILED: $e\n');
  }

  // 5. Confirm
  print('--- Step 5: Confirm restored ---');
  final restored = await client.readProperty(deviceId, objType, objInstance, prop);
  print('  AV/1 units = $restored (${unitName(restored is int ? restored : -1)})\n');

  client.dispose();
  print('Done.');
}
