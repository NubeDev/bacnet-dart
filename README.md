# bacnet_dart

Pure Dart BACnet/IP protocol stack. No FFI, no native code — works on Android, iOS, macOS, Linux, and Windows via `dart:io` UDP.

## Features

- **Who-Is / I-Am** — device discovery via broadcast
- **ReadProperty** — read a single property from any BACnet object
- **WriteProperty** — write with priority and application tag support
- **ReadPropertyMultiple (RPM)** — batch read multiple properties/objects in one request
- **AtomicReadFile** — read file data (stream and record access)
- **AtomicWriteFile** — write file data (stream and record access)
- **Device scanning** — enumerate all objects on a device via object list
- **Friendly error codes** — human-readable BACnet error class/code translation with hints

## Usage

```dart
import 'package:bacnet_dart/bacnet_dart.dart';

final client = BacnetClient(
  config: const BacnetClientConfig(timeout: Duration(seconds: 5)),
);
await client.start();
```

### Device Discovery

```dart
client.sendWhoIs();
client.events.listen((event) {
  if (event is IAmResponse) {
    print('Found device ${event.deviceId} @ ${event.sourceAddress.address}');
  }
});
```

### Read / Write Property

```dart
const deviceId = 2307528;
client.addDeviceBinding(deviceId, '192.168.15.10');

// Read
final value = await client.readProperty(
  deviceId,
  BacnetObjectType.analogValue, 1,
  BacnetPropertyId.presentValue,
);

// Write (tag must match the object type)
await client.writeProperty(
  deviceId,
  BacnetObjectType.analogOutput, 3,
  BacnetPropertyId.presentValue,
  99.9,
  priority: 16,
  tag: AppTag.real,
);
```

### ReadPropertyMultiple

```dart
final results = await client.readPropertyMultiple(deviceId, [
  RpmReadAccessSpec(
    objectType: BacnetObjectType.analogInput,
    objectInstance: 1,
    properties: [
      RpmPropertyRef(BacnetPropertyId.presentValue),
      RpmPropertyRef(BacnetPropertyId.objectName),
    ],
  ),
]);

for (final obj in results) {
  for (final prop in obj.properties) {
    if (prop.isError) {
      print('Error: ${formatBacnetError(prop.errorClass!, prop.errorCode!)}');
    } else {
      print('${prop.propertyId} = ${prop.value}');
    }
  }
}
```

### File Read / Write

```dart
// Read entire file (stream mode, chunked)
final bytes = await client.readFileAll(deviceId, fileInstance, chunkSize: 1);
print(utf8.decode(bytes));

// Read single chunk
final ack = await client.readFile(
  deviceId, fileInstance,
  startPosition: 0, count: 1, isStream: true,
);

// Write file (stream mode)
await client.writeFile(
  deviceId, fileInstance,
  fileData,
  startPosition: 0,
);

// Write file (record mode)
await client.writeFileRecords(
  deviceId, fileInstance,
  [record1, record2],
  startRecord: 0,
);
```

### Error Handling

All BACnet errors are thrown as `BacnetException` with human-readable descriptions:

```dart
try {
  await client.writeProperty(...);
} on BacnetException catch (e) {
  print(e.friendlyName);      // "property / inconsistent-parameters"
  print(e.hint);               // "The value type or priority does not match..."
  print(e.toFriendlyString()); // full formatted description
}
```

Helper functions are also available standalone:

```dart
print(errorClassName(2));  // "property"
print(errorCodeName(9));   // "inconsistent-parameters"
print(formatBacnetError(2, 9)); // full description with hint
```

## Notes

- **Port conflict**: Only one process can bind to UDP port 47808 at a time. Stop any other BACnet clients (Node.js server, runtime, etc.) before running tests.
- **Analog Value writes**: Non-commandable AVs require `out-of-service = true` before writing to `present-value`. Analog Outputs (AO) are commandable and accept writes directly.
- **Value types matter**: Writing an `int` to an analog point that expects a `REAL` (float) will cause `inconsistent-parameters`. The client auto-coerces when `tag: AppTag.real` is specified.
- **File writes**: Some devices require writing the exact file size. Read the file first, modify the bytes, then write back the full content.
- **Stream vs record**: File access mode depends on the device. Some support stream reads but not stream writes (or vice versa). Try both if one fails.
