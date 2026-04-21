import 'dart:async';

import 'package:bacnet_dart/bacnet_dart.dart';

void main() async {
  final client = BacnetClient(
    config: const BacnetClientConfig(timeout: Duration(seconds: 5)),
  );

  print('Starting BACnet client on eno1:47808...');
  await client.start(interface_: 'eno1');
  print('Client started. Sending Who-Is...\n');

  final devices = <int, IAmResponse>{};

  // Collect I-Am responses
  client.events.listen((event) {
    if (event is IAmResponse) {
      devices[event.deviceId] = event;
      print('  I-Am: device ${event.deviceId} '
          'at ${event.sourceAddress.address}:${event.sourcePort} '
          '(vendor: ${event.vendorId})');
    }
  });

  client.sendWhoIs();

  // Wait for responses
  print('Waiting 5 seconds for I-Am responses...');
  await Future<void>.delayed(const Duration(seconds: 5));

  print('\n--- Discovery complete: ${devices.length} device(s) found ---\n');

  if (devices.isEmpty) {
    print('No devices found. Check network / interface.');
    client.dispose();
    return;
  }

  // For each discovered device, read its object list
  for (final entry in devices.entries) {
    final deviceId = entry.key;
    final iam = entry.value;
    print('=== Device $deviceId (${iam.sourceAddress.address}) ===');

    // Read device name
    try {
      final name = await client.readProperty(
        deviceId,
        BacnetObjectType.device,
        deviceId,
        BacnetPropertyId.objectName,
      );
      print('  Name: $name');
    } catch (e) {
      print('  Name: (failed: $e)');
    }

    // Read object list count
    int objectCount = 0;
    try {
      final count = await client.readProperty(
        deviceId,
        BacnetObjectType.device,
        deviceId,
        BacnetPropertyId.objectList,
        arrayIndex: 0,
      );
      objectCount = count is int ? count : 0;
      print('  Objects: $objectCount');
    } catch (e) {
      print('  Object count: (failed: $e)');
    }

    // Read each object from the list
    if (objectCount > 0) {
      print('  --- Object List ---');
      for (var i = 1; i <= objectCount; i++) {
        try {
          final objId = await client.readProperty(
            deviceId,
            BacnetObjectType.device,
            deviceId,
            BacnetPropertyId.objectList,
            arrayIndex: i,
          );

          if (objId is ObjectId) {
            final typeName = BacnetObjectType.getName(objId.type);

            // Try to read the object's name
            String objName = '?';
            try {
              final n = await client.readProperty(
                deviceId,
                objId.type,
                objId.instance,
                BacnetPropertyId.objectName,
              );
              objName = n?.toString() ?? '?';
            } catch (_) {}

            // Try to read present value (skip for device objects)
            String pvStr = '';
            if (objId.type != BacnetObjectType.device) {
              try {
                final pv = await client.readProperty(
                  deviceId,
                  objId.type,
                  objId.instance,
                  BacnetPropertyId.presentValue,
                );
                pvStr = ' = $pv';
              } catch (_) {
                pvStr = ' = (unreadable)';
              }
            }

            print('  [$i] $typeName/${objId.instance} "$objName"$pvStr');
          } else {
            print('  [$i] raw: $objId');
          }
        } catch (e) {
          print('  [$i] (failed: $e)');
        }
      }
    }
    print('');
  }

  client.dispose();
  print('Done.');
}
