/// Helpers for reading/writing BACnet point values (presentValue).
import '../client/bacnet_client.dart';
import '../codec/tag.dart' show AppTag;
import '../constants/property_ids.dart';

/// Extension on [BacnetClient] for common point read/write operations.
extension PointHelpers on BacnetClient {
  /// Read the present value of any BACnet object.
  ///
  /// Returns a Dart-native type: [double] for analog, [int] for binary/multistate.
  Future<dynamic> readPresentValue(
    int deviceId,
    int objectType,
    int objectInstance,
  ) {
    return readProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.presentValue,
    );
  }

  /// Write a numeric present value (analog objects).
  ///
  /// [priority] defaults to 16 (lowest). Use 1-8 for manual overrides.
  Future<void> writePresentValue(
    int deviceId,
    int objectType,
    int objectInstance,
    double value, {
    int priority = 16,
  }) {
    return writeProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.presentValue,
      value,
      priority: priority,
      tag: AppTag.real,
    );
  }

  /// Write a binary/multistate present value (integer enum).
  ///
  /// For binary objects: 0 = inactive, 1 = active.
  /// For multistate objects: 1-based state index.
  Future<void> writePresentValueEnum(
    int deviceId,
    int objectType,
    int objectInstance,
    int value, {
    int priority = 16,
  }) {
    return writeProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.presentValue,
      value,
      priority: priority,
      tag: AppTag.enumerated,
    );
  }
}
