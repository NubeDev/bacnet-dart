import 'package:bacnet_dart/bacnet_dart.dart';

void main() async {
  final client = BacnetClient();
  await client.start();

  const deviceId = 2307528;
  client.addDeviceBinding(deviceId, '192.168.15.10');

  // --- Device info ---
  print('=== Device Info ===');
  final info = await client.readDeviceInfo(deviceId);
  print('  Name:     ${info.name}');
  print('  Model:    ${info.modelName}');
  print('  Vendor:   ${info.vendorName} [${info.vendorId}]');
  print('  FW:       ${info.firmwareRevision}');
  print('  App SW:   ${info.applicationSoftwareVersion}');
  print('  Protocol: ${info.protocolVersion}.${info.protocolRevision}');
  print('  Status:   ${info.systemStatus}');
  print('  Max APDU: ${info.maxApduLength}');
  print('  Objects:  ${info.objectCount}');
  print('');

  // --- Point helpers ---
  print('=== Point Helpers (AV/1) ===');
  final pv = await client.readPresentValue(
    deviceId, BacnetObjectType.analogValue, 1,
  );
  print('  Present value: $pv');

  // --- Object helpers ---
  print('\n=== Object Helpers (AV/1) ===');
  final name = await client.readObjectName(
    deviceId, BacnetObjectType.analogValue, 1,
  );
  print('  Name:  $name');

  final units = await client.readUnits(
    deviceId, BacnetObjectType.analogValue, 1,
  );
  print('  Units: $units');

  final desc = await client.readDescription(
    deviceId, BacnetObjectType.analogValue, 1,
  );
  print('  Desc:  $desc');

  // --- Priority helpers ---
  print('\n=== Priority Helpers (AV/1) ===');

  print('  Override @ priority 1 = 77.7');
  await client.overrideValue(
    deviceId, BacnetObjectType.analogValue, 1, 77.7, priority: 1,
  );

  final afterOverride = await client.readPresentValue(
    deviceId, BacnetObjectType.analogValue, 1,
  );
  print('  PV after override: $afterOverride');

  print('  Release priority 1...');
  await client.releasePriority(
    deviceId, BacnetObjectType.analogValue, 1, priority: 1,
  );

  final afterRelease = await client.readPresentValue(
    deviceId, BacnetObjectType.analogValue, 1,
  );
  print('  PV after release: $afterRelease');

  client.dispose();
  print('\nDone.');
}
